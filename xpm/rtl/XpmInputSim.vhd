-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : XpmInputSim.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-08
-- Last update: 2019-02-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--   Module to handle simulation of XPM input data
--   LCLS-II Timing Frames (always)
--   Merge receive LCLS-I input stream (option)
--   Clock is either reference clock (no LCLS-I input stream) or
--     186MHz derived from LCLS-I recovered clock (119MHz -> 186MHz)
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 XPM Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'LCLS2 XPM Core', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.AxiPkg.all;
use work.AxiLitePkg.all;
use work.TimingPkg.all;
use work.TimingExtnPkg.all;
--use work.AmcCarrierPkg.all;
--use work.AmcCarrierSysRegPkg.all;
use work.TPGPkg.all;
--use work.XpmPkg.all;
use work.XpmOpts.all;

library unisim;
use unisim.vcomponents.all;

entity XpmInputSim is
   generic ( AXIL_BASE_ADDR_G : slv(31 downto 0) );
   port (
      -- AXI-Lite Interface (axilClk domain)
      axilClk          : in  sl;
      axilRst          : in  sl;
      axilReadMaster   : in  AxiLiteReadMasterType;
      axilReadSlave    : out AxiLiteReadSlaveType;
      axilWriteMaster  : in  AxiLiteWriteMasterType;
      axilWriteSlave   : out AxiLiteWriteSlaveType;
      ----------------------
      -- Top Level Interface
      ----------------------
      timingClk        : in  sl;   -- 186 MHz
      timingClkRst     : in  sl;
      cuTiming         : in  CuTimingType;
      cuTimingV        : in  sl;
      cuDelay          : out slv(17 downto 0);
      --  SC timing input
      usRefClk         : in  sl;   -- 186 MHz
      usRefClkRst      : in  sl;
      --  Cu timing input
      cuRecClk         : in  sl;
      cuRecClkRst      : in  sl;
      cuFiducial       : in  sl;
      --
      simClk           : out sl;   -- 186 MHz
      simClkRst        : out sl;
      simFiducial      : out sl;
      simSync          : out sl;
      simAdvance       : in  sl;
      simStream        : out TimingSerialType );
end XpmInputSim;

architecture mapping of XpmInputSim is

   signal cuClkT           : slv(2 downto 0);
   signal cuRstT           : slv(2 downto 0);
   signal cuSync           : slv(1 downto 0);
   signal mmcmRst          : sl;
   signal cuRxReady        : sl;
   signal cuRxReadyN       : sl;
   signal cuBeamCode       : slv(7 downto 0);
   
   signal isimClk, isimRst : sl;
   signal simTx            : TimingPhyType;

   signal tpgConfig : TPGConfigType := TPG_CONFIG_INIT_C;
   signal tpgStatus : TPGStatusType;
   signal status    : TPGStatusType;
   
   type RegType is record
     config        : TPGConfigType;
     timeStampWrEn : sl;
     pulseIdWrEn   : sl;
     cuDelay       : slv(cuDelay'range);
     cuBeamCode    : slv( 7 downto 0);
     axiWriteSlave : AxiLiteWriteSlaveType;
     axiReadSlave  : AxiLiteReadSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
     config        => TPG_CONFIG_INIT_C,
     timeStampWrEn => '0',
     pulseIdWrEn   => '0',
     cuDelay       => toSlv(200*800,cuDelay'length),
     cuBeamCode    => toSlv(140,8),
     axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
     axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C );

   signal r   : RegType;
   signal rin : RegType := REG_INIT_C;

   constant SIM_INDEX_C       : integer := 0;
   constant MMCM0_INDEX_C     : integer := 1;
   constant MMCM1_INDEX_C     : integer := 2;
   constant MMCM2_INDEX_C     : integer := 3;
   constant NUM_AXI_MASTERS_C : integer := 4;
   
   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) :=
     genAxiLiteConfig( NUM_AXI_MASTERS_C, AXIL_BASE_ADDR_G, 22, 20 );
   
   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray (NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray (NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray  (NUM_AXI_MASTERS_C-1 downto 0);

begin

   isimClk   <= timingClk;
   isimRst   <= timingClkRst;

   GEN_CU_RX_ENABLE : if CU_RX_ENABLE_INIT_C = '1' generate
     simClk    <= cuClkT(2);
     simClkRst <= not cuRxReady;
   end generate;

   GEN_CU_RX_DISABLE : if CU_RX_ENABLE_INIT_C = '0' generate
     simClk    <= usRefClk;
     simClkRst <= usRefClkRst;
   end generate;
   
   simSync     <= mmcmRst;
   
   --------------------------
   -- AXI-Lite: Crossbar Core
   --------------------------  
   U_XBAR : entity work.AxiLiteCrossbar
      generic map (
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => AXI_CROSSBAR_MASTERS_CONFIG_C'length,
         MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves (0) => axilWriteSlave,
         sAxiReadMasters (0) => axilReadMaster,
         sAxiReadSlaves  (0) => axilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);

   P_SyncMiniReset : process ( cuRecClk, cuRecClkRst ) is
   begin
     if cuRecClkRst = '1' then
       cuRxReady <= '0';
     elsif rising_edge(cuRecClk) then
       if cuFiducial = '1' then
         cuRxReady <= '1';
       end if;
     end if;
   end process;
   
   --
   --  How to insure each of these lock at a fixed phase with respect to 71kHz
   --  strobe?
   --
   --  Measure phase offset at 71kHz and shift to a known value.
   --
   BaseEnableDivider : entity work.Divider
     generic map ( Width => 11 )
     port map (
       sysClk   => cuRecClk,
       sysReset => cuFiducial,
       enable   => cuRxReady,
       clear    => '0',
       divisor  => toSlv(1666,11),
       trigO    => mmcmRst);

   cuRxReadyN <= not cuRxReady;
   
   U_MMCM0 : entity work.MmcmPhaseLock
     generic map ( CLKIN_PERIOD_G     => 8.4,    -- ClkIn  = 119MHz
                   CLKOUT_DIVIDE_F    => 17.0,   -- ClkOut =  70MHz
                   CLKFBOUT_MULT_F    => 10.0 )  -- VCO    = 1190MHz
     port map ( clkIn           => cuRecClk,
                rstIn           => cuRxReadyN,
                syncIn          => mmcmRst,
                clkOut          => cuClkT(0),
                rstOut          => cuRstT(0),
                axilClk         => axilClk,
                axilRst         => axilRst,
                axilWriteMaster => axilWriteMasters(MMCM0_INDEX_C),
                axilWriteSlave  => axilWriteSlaves (MMCM0_INDEX_C),
                axilReadMaster  => axilReadMasters (MMCM0_INDEX_C),
                axilReadSlave   => axilReadSlaves  (MMCM0_INDEX_C) );
                
   U_MMCM1 : entity work.MmcmPhaseLock
     generic map ( CLKIN_PERIOD_G     => 14.286,  -- ClkIn  =  70MHz
                   CLKOUT_DIVIDE_F    => 7.0,     -- ClkOut = 130MHz
                   CLKFBOUT_MULT_F    => 13.0 )   -- VCO    = 910MHz
     port map ( clkIn           => cuClkT(0),
                rstIn           => cuRstT(0),
                syncIn          => mmcmRst,
                clkOut          => cuClkT(1),
                rstOut          => cuRstT(1),
                axilClk         => axilClk,
                axilRst         => axilRst,
                axilWriteMaster => axilWriteMasters(MMCM1_INDEX_C),
                axilWriteSlave  => axilWriteSlaves (MMCM1_INDEX_C),
                axilReadMaster  => axilReadMasters (MMCM1_INDEX_C),
                axilReadSlave   => axilReadSlaves  (MMCM1_INDEX_C) );
                
   U_MMCM2 : entity work.MmcmPhaseLock
     generic map ( CLKIN_PERIOD_G     => 7.692,  -- ClkIn  = 130MHz
                   CLKOUT_DIVIDE_F    => 7.0,    -- ClkOut = 185.7MHz
                   CLKFBOUT_MULT_F    => 10.0 )  -- VCO    = 1300MHz
     port map ( clkIn           => cuClkT(1),
                rstIn           => cuRstT(1),
                syncIn          => mmcmRst,
                clkOut          => cuClkT(2),
                rstOut          => cuRstT(2),
                axilClk         => axilClk,
                axilRst         => axilRst,
                axilWriteMaster => axilWriteMasters(MMCM2_INDEX_C),
                axilWriteSlave  => axilWriteSlaves (MMCM2_INDEX_C),
                axilReadMaster  => axilReadMasters (MMCM2_INDEX_C),
                axilReadSlave   => axilReadSlaves  (MMCM2_INDEX_C) );

   U_CuSync0 : entity work.RstSync
     port map ( clk      => cuClkT(0),
                asyncRst => cuFiducial,
                syncRst  => cuSync(0) );
   
   U_CuSync1 : entity work.RstSync
     port map ( clk      => cuClkT(1),
                asyncRst => cuSync(0),
                syncRst  => cuSync(1) );
   
   SC_SIM : if CU_RX_ENABLE_INIT_C = '0' generate
     -- simulated LCLS2 stream
     U_UsSim : entity work.TPGMini
       generic map ( NARRAYSBSA  => 0,
                     STREAM_INTF => true )
       port map ( statusO      => tpgStatus,
                  configI      => tpgConfig,
                  --
                  txClk        => isimClk,
                  txRst        => isimRst,
                  txRdy        => '1',
                  streams  (0) => simStream,
                  streamIds    => open,
                  advance  (0) => simAdvance,
                  fiducial     => simFiducial );
   end generate;

   SC_GEN : if CU_RX_ENABLE_INIT_C = '1' generate
     -- translated LCLS2 stream
     U_XTPG : entity work.XTPG
       port map ( statusO      => tpgStatus,
                  configI      => tpgConfig,
                  beamCode     => cuBeamCode,
                  --
                  txClk        => isimClk,
                  txRst        => isimRst,
                  txRdy        => '1',
                  cuTiming     => cuTiming,
                  cuTimingV    => cuTimingV,
                  stream       => simStream,
                  advance      => simAdvance,
                  fiducial     => simFiducial );
   end generate;

   U_Sync_TimeStamp : entity work.SynchronizerVector
     generic map ( WIDTH_G => 64 )
     port map ( clk        => isimClk,
                dataIn     => r.config.timeStamp,
                dataOut    => tpgConfig.timeStamp );
   U_Sync_TimeStampWr : entity work.Synchronizer
     port map ( clk        => isimClk,
                dataIn     => r.config.timeStampWrEn,
                dataOut    => tpgConfig.timeStampWrEn );
   
   U_Sync_PulseId : entity work.SynchronizerVector
     generic map ( WIDTH_G => 64 )
     port map ( clk        => isimClk,
                dataIn     => r.config.pulseId,
                dataOut    => tpgConfig.pulseId );
   U_Sync_PulseIdWr : entity work.Synchronizer
     port map ( clk        => isimClk,
                dataIn     => r.config.pulseIdWrEn,
                dataOut    => tpgConfig.pulseIdWrEn );

   U_Sync_TimeStampRd : entity work.SynchronizerFifo
     generic map ( DATA_WIDTH_G => 64 )
     port map ( wr_clk  => isimClk,
                din     => tpgStatus.timeStamp,
                rd_clk  => axilClk,
                dout    => status.timeStamp );
   
   U_Sync_PulseIdRd : entity work.SynchronizerFifo
     generic map ( DATA_WIDTH_G => 64 )
     port map ( wr_clk  => isimClk,
                din     => tpgStatus.pulseId,
                rd_clk  => axilClk,
                dout    => status.pulseId );
   
   U_Sync_CuDelay : entity work.SynchronizerVector
     generic map ( WIDTH_G => cuDelay'length )
     port map ( clk        => isimClk,
                dataIn     => r.cuDelay,
                dataOut    => cuDelay );

   U_Sync_CuBeamCode : entity work.SynchronizerVector
     generic map ( WIDTH_G => cuBeamCode'length )
     port map ( clk        => isimClk,
                dataIn     => r.cuBeamCode,
                dataOut    => cuBeamCode );
   
   comb : process ( r, axilRst, axilReadMasters, axilWriteMasters, status ) is
     variable v : RegType;
     variable ep : AxiLiteEndpointType;
   begin
     v := r;
     v.timeStampWrEn        := '0';
     v.pulseIdWrEn          := '0';
     v.config.timeStampWrEn := r.timeStampWrEn;
     v.config.pulseIdWrEn   := r.pulseIdWrEn;
     
     axiSlaveWaitTxn( ep, axilWriteMasters(SIM_INDEX_C), axilReadMasters(SIM_INDEX_C), v.axiWriteSlave, v.axiReadSlave );

     axiSlaveRegister( ep, x"00", 0, v.config.timeStamp(31 downto 0) );
     axiSlaveRegister( ep, x"04", 0, v.config.timeStamp(63 downto 0) );
     axiSlaveRegister( ep, x"08", 0, v.config.pulseId(31 downto 0) );
     axiSlaveRegister( ep, x"0C", 0, v.config.pulseId(63 downto 0) );
     axiWrDetect( ep, x"04", v.timeStampWrEn );
     axiWrDetect( ep, x"0C", v.pulseIdWrEn );

     axiSlaveRegisterR( ep, x"00", 0, status.timeStamp(31 downto 0) );
     axiSlaveRegisterR( ep, x"04", 0, status.timeStamp(63 downto 0) );
     axiSlaveRegisterR( ep, x"08", 0, status.pulseId(31 downto 0) );
     axiSlaveRegisterR( ep, x"0C", 0, status.pulseId(63 downto 0) );
     
     axiSlaveRegister( ep, x"10", 0, v.cuDelay  );
     axiSlaveRegister( ep, x"14", 0, v.cuBeamCode );
     
     axiSlaveDefault( ep, v.axiWriteSlave, v.axiReadSlave );

     axilWriteSlaves(SIM_INDEX_C) <= v.axiWriteSlave;
     axilReadSlaves (SIM_INDEX_C) <= v.axiReadSlave;
     
     if axilRst = '1' then
       v := REG_INIT_C;
     end if;
    
     rin <= v;

   end process comb;

   seq : process ( axilClk ) is
   begin
     if rising_edge(axilClk) then
       r <= rin;
     end if;
   end process seq;

end mapping;
