-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Xpm2Timing.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-08
-- Last update: 2019-02-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
      --recRxData        : out slv(15 downto 0);
      --recRxDataK       : out slv( 1 downto 0);
      --recSof           : out sl;               -- strobe one clk after SOF
      --recEof           : out sl;               -- strobe one clk after EOF
      --recCrcErr        : out sl;               -- latch one clk after CRC (on EOF)
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
use work.AmcCarrierPkg.all;
use work.AmcCarrierSysRegPkg.all;
use work.XpmPkg.all;
use work.XpmBasePkg.all;
use work.XpmOpts.all;

library unisim;
use unisim.vcomponents.all;

entity Xpm2Timing is
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
      --  SC timing input
      usRefClk         : in  sl;   -- 186 MHz
      usRefClkRst      : in  sl;
      usRecClk         : in  sl;
      usRecClkRst      : in  sl;
      usRx             : in  TimingRxType;
      usRxStatus       : in  TimingPhyStatusType;
      usRxControl      : out TimingPhyControlType;
      --  Cu timing input
      cuRecClk         : in  sl;
      cuRecClkRst      : in  sl;
      cuRx             : in  TimingRxType;
      cuRxStatus       : in  TimingPhyStatusType;
      cuRxControl      : out TimingPhyControlType;
      cuSync           : out sl;
      cuRxFiducial     : out sl;
      --
      timingClk        : out sl;   -- 186 MHz
      timingRst        : out sl;
      timingStream     : out XpmStreamType );
end Xpm2Timing;

--
--                timingClk source
--
--  usRxEnable       cuRxEnable
--                 '0'    |    '1'
--             +----------+-----------+
--      '0'    | usRefClk |  cuRxClk* |
--          ---+----------+-----------+
--      '1'    | usRecClk |  usRecClk |
--             +----------+-----------+
--

architecture mapping of Xpm2Timing is

   constant US_INDEX_C        : integer := 0;
   constant CU_INDEX_C        : integer := 1;
   constant SIM_INDEX_C       : integer := 2;
   constant NUM_AXI_MASTERS_C : integer := 3;
   
   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) :=
     genAxiLiteConfig( NUM_AXI_MASTERS_C, AXIL_BASE_ADDR_G, 24, 22 );

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray (NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray (NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray  (NUM_AXI_MASTERS_C-1 downto 0);
   -- Rx ports
   signal cuRxStream       : TimingStreamType;
   signal cuFiducial       : sl;
   signal cuFiducialQ      : sl;
   signal cuValid          : sl;
   signal cuRxValid        : sl;
   signal cuRxV,cuRxVS     : slv(16*TIMING_EXTN_WORDS_C(1)-1 downto 0);
   
   signal usRxMessage      : TimingMessageType;
   signal usRxVector       : slv(16*TIMING_MESSAGE_WORDS_C-1 downto 0);
   signal usRxStrobe       : sl;
   signal usRxValid        : sl;
   signal usRxExtn         : TimingExtnType;
   signal usRxExtnV        : sl;
   
   signal xpmVector        : slv(16*TIMING_EXTN_WORDS_C(0)-1 downto 0);
   signal xpmValid         : sl;
   signal cuRecVector      : slv(16*TIMING_EXTN_WORDS_C(1)-1 downto 0);
   signal cuRecValid       : sl;
   signal cuRxT            : CuTimingType;
   signal cuRxTS           : CuTimingType; -- sync'd to txClk
   signal cuRxTSV          : sl;           -- valid
   signal cuRxTSVd         : sl;           -- delayed
   signal cuDelay          : slv(17 downto 0);
   
   signal itimingClk       : sl;
   signal itimingRst       : sl;

   signal simClk, simRst   : sl;

   signal simStream        : TimingSerialType;
   signal simFiducial      : sl;
   signal simSync          : sl;
   
   signal cuStream         : TimingSerialType;
   signal recStreams       : TimingSerialArray(2 downto 0);

   signal txStreams        : TimingSerialArray(TIMING_EXTN_STREAMS_C downto 0);
   signal txStreamIds      : Slv4Array        (TIMING_EXTN_STREAMS_C downto 0);
   signal txAdvance        : slv              (TIMING_EXTN_STREAMS_C downto 0);
   signal txPhy            : TimingRxType;
   signal txFiducial       : sl;

   type RegType is record
     cuValid : sl;
     count   : slv(cuDelay'range);
   end record;

   constant REG_INIT_C : RegType := (
     cuValid => '0',
     count   => (others=>'0') );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
begin

   timingClk  <= itimingClk;
   timingRst  <= itimingRst;

   cuRxFiducial <= cuFiducial;

   GEN_US_RX_ENABLE : if (US_RX_ENABLE_INIT_C = '1') generate
     cuSync     <= usRxStrobe and usRxMessage.fixedRates(1);
     itimingRst <= usRecClkRst;
     itimingClk <= usRecClk;
     txStreams(0) <= recStreams(0);
     txStreams(2) <= recStreams(2);
     txFiducial   <= usRxStrobe;
   end generate;

   GEN_US_RX_DISABLE : if (US_RX_ENABLE_INIT_C = '0') generate
     cuSync     <= simSync;
     itimingRst <= simRst;
     itimingClk <= simClk;
     txStreams(0) <= simStream;
     txStreams(2) <= TIMING_SERIAL_INIT_C;
     txFiducial   <= simFiducial;
   end generate;

   GEN_CU_RX_ENABLE : if (CU_RX_ENABLE_INIT_C = '1') generate
     txStreams(1) <= cuStream;
   end generate;

   GEN_CU_RX_DISABLE : if (CU_RX_ENABLE_INIT_C = '0' and US_RX_ENABLE_INIT_C = '1') generate
     txStreams(1) <= recStreams(1);
   end generate;

   GEN_NO_RX_ENABLE : if (CU_RX_ENABLE_INIT_C = '0' and US_RX_ENABLE_INIT_C = '0') generate
     txStreams(1) <= TIMING_SERIAL_INIT_C;
   end generate;
   
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

   U_InputSim : entity work.XpmInputSim
     generic map ( AXIL_BASE_ADDR_G => AXI_CROSSBAR_MASTERS_CONFIG_C(SIM_INDEX_C).baseAddr )
     port map ( axilClk         => axilClk,
                axilRst         => axilRst,
                axilWriteMaster => axilWriteMasters(SIM_INDEX_C),
                axilWriteSlave  => axilWriteSlaves (SIM_INDEX_C),
                axilReadMaster  => axilReadMasters (SIM_INDEX_C),
                axilReadSlave   => axilReadSlaves  (SIM_INDEX_C),
                timingClk       => itimingClk,
                timingClkRst    => itimingRst,
                cuTiming        => cuRxTS,
                cuDelay         => cuDelay,
                cuTimingV       => cuRxTSVd,
                usRefClk        => usRefClk,
                usRefClkRst     => usRefClkRst,
                cuRecClk        => cuRecClk,
                cuRecClkRst     => cuRecClkRst,
                cuFiducial      => cuFiducialQ,
                simClk          => simClk,
                simClkRst       => simRst,
                simFiducial     => simFiducial,
                simSync         => simSync,
                simAdvance      => txAdvance(0),
                simStream       => simStream );

   U_CuRx : entity work.TimingRx
     generic map ( CLKSEL_MODE_G => "LCLSI" )
     port map ( rxClk               => cuRecClk,
                rxData              => cuRx,
                rxControl           => cuRxControl,
                rxStatus            => cuRxStatus,
                timingStreamUser    => cuRxStream,
                timingStreamStrobe  => cuFiducial,
                timingStreamValid   => cuRxValid,
                txClk               => '0',
                axilClk             => axilClk,
                axilRst             => axilRst,
                axilReadMaster      => axilReadMasters (CU_INDEX_C),
                axilReadSlave       => axilReadSlaves  (CU_INDEX_C),
                axilWriteMaster     => axilWriteMasters(CU_INDEX_C),
                axilWriteSlave      => axilWriteSlaves (CU_INDEX_C) );

   U_UsRx : entity work.TimingRx
     generic map ( CLKSEL_MODE_G => "LCLSII" )
     port map ( rxClk               => usRecClk,
                rxData              => usRx,
                rxControl           => usRxControl,
                rxStatus            => usRxStatus,
                timingMessage       => usRxMessage,
                timingMessageStrobe => usRxStrobe,
                timingMessageValid  => usRxValid,
                timingExtn          => usRxExtn,
                timingExtnValid     => usRxExtnV,
                txClk               => '0',
                axilClk             => axilClk,
                axilRst             => axilRst,
                axilReadMaster      => axilReadMasters (US_INDEX_C),
                axilReadSlave       => axilReadSlaves  (US_INDEX_C),
                axilWriteMaster     => axilWriteMasters(US_INDEX_C),
                axilWriteSlave      => axilWriteSlaves (US_INDEX_C) );

   --
   --  Generated streams
   --
   cuFiducialQ      <= cuFiducial and cuRxValid;
   cuRxT.epicsTime(63 downto 32)  <= cuRxStream.dbuff.epicsTime(31 downto  0);
   cuRxT.epicsTime(31 downto  0)  <= cuRxStream.dbuff.epicsTime(63 downto 32);
   cuRxT.eventCodes <= cuRxStream.eventCodes;
   cuRxV            <= toSlv(cuRxT);
   cuRxTS           <= toCuTimingType(cuRxVS);
   cuRxTSV          <= cuValid;  -- still need to delay
   
   U_CuSync : entity work.SynchronizerFifo
     generic map ( DATA_WIDTH_G => 16*TIMING_EXTN_WORDS_C(1),
                   ADDR_WIDTH_G => 2 )
     port map ( rst      => itimingRst,
                wr_clk   => cuRecClk,
                wr_en    => cuFiducial,
                din      => cuRxV,
                rd_clk   => itimingClk,
                rd_en    => txFiducial,
                valid    => cuValid,
                dout     => cuRxVS );

   U_CuStream : entity work.WordSerializer
     generic map ( NWORDS_G => TIMING_EXTN_WORDS_C(1) )
     port map ( txClk    => itimingClk,
                txRst    => itimingRst,
                fiducial => txFiducial,
                words    => cuRxVS,
                ready    => cuRxTSVd,
                advance  => txAdvance(1),
                stream   => cuStream );

   --
   --  Reconstructed streams
   --
   usRxVector <= toSlv(usRxMessage);
   
   U_UsRecSerializer : entity work.WordSerializer
     generic map ( NWORDS_G => TIMING_MESSAGE_WORDS_C )
     port map ( txClk    => itimingClk,
                txRst    => itimingRst,
                fiducial => txFiducial,
                words    => usRxVector,
                ready    => usRxValid,
                advance  => txAdvance (0),
                stream   => recStreams(0) );

   cuRecVector <= toSlv(2, usRxExtn);
   cuRecValid  <= usRxExtn.cuValid;

   U_CuRecSerializer : entity work.WordSerializer
     generic map ( NWORDS_G => TIMING_EXTN_WORDS_C(1) )
     port map ( txClk    => itimingClk,
                txRst    => itimingRst,
                fiducial => txFiducial,
                words    => cuRecVector,
                ready    => cuRecValid,
                advance  => txAdvance    (1),
                stream   => recStreams   (1) );
   
   xpmVector   <= toSlv(1, usRxExtn);
   xpmValid    <= usRxExtnV;

   U_XpmRecSerializer : entity work.WordSerializer
     generic map ( NWORDS_G => TIMING_EXTN_WORDS_C(0) )
     port map ( txClk    => itimingClk,
                txRst    => itimingRst,
                fiducial => txFiducial,
                words    => xpmVector,
                ready    => xpmValid,
                advance  => txAdvance    (2),
                stream   => recStreams   (2) );
     
   txStreamIds(0) <= toSlv(0,4);
   txStreamIds(1) <= toSlv(2,4);
   txStreamIds(2) <= toSlv(1,4);
   
   U_SimSerializer : entity work.TimingSerializer
    generic map ( STREAMS_C => TIMING_EXTN_STREAMS_C+1 )
    port map ( clk       => itimingClk,
               rst       => itimingRst,
               fiducial  => txFiducial,
               streams   => txStreams,
               streamIds => txStreamIds,
               advance   => txAdvance,
               data      => open,
               dataK     => open );

   --txPhy.decErr <= "00";
   --txPhy.dspErr <= "00";

   timingStream.fiducial <= txFiducial;
   timingStream.streams  <= txStreams;
   timingStream.advance  <= txAdvance;

   comb : process ( r, itimingRst, cuValid, cuDelay ) is
     variable v : RegType;
   begin
     v := r;

     if cuValid = '1' then
       v.count := r.count + 1;
       if (r.count = cuDelay) then
         v.cuValid := '1';
       end if;
     else
       v.count    := (others=>'0');
       v.cuValid  := '0';
     end if;

     if itimingRst = '1' then
       v := REG_INIT_C;
     end if;

     rin <= v;

     cuRxTSVd <= r.cuValid;
   end process comb;

   seq : process ( itimingClk )
   begin
     if rising_edge (itimingClk) then
       r <= rin;
     end if;
   end process seq;
   
end mapping;
