-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : hsd_dualv3_sim.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2018-01-05
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 DAQ Software'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 DAQ Software', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;
use ieee.std_logic_unsigned.all;

use STD.textio.all;
use ieee.std_logic_textio.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.TimingPkg.all;
use work.TPGPkg.all;
use work.QuadAdcPkg.all;
use work.SsiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity hsd_dualv3_sim is
end hsd_dualv3_sim;

architecture top_level_app of hsd_dualv3_sim is

   constant NCHAN_C : integer := 4;
   
   signal rst      : sl;
   
    -- AXI-Lite and IRQ Interface
   signal regClk    : sl;
   signal regRst    : sl;
   signal regWriteMaster     : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal regWriteSlave      : AxiLiteWriteSlaveType;
   signal regReadMaster      : AxiLiteReadMasterType := AXI_LITE_READ_MASTER_INIT_C;
   signal regReadSlave       : AxiLiteReadSlaveType;
    -- DMA
   signal dmaClk            : sl;
   signal dmaRst            : sl;
   signal dmaIbMaster       : AxiStreamMasterArray(3 downto 0);
   signal dmaIbSlave        : AxiStreamSlaveArray (3 downto 0) := (others=>AXI_STREAM_SLAVE_FORCE_C);

   signal phyClk            : sl;
   signal refTimingClk      : sl;
   signal adcO              : AdcDataArray(NCHAN_C-1 downto 0);
   signal trigIn            : Slv8Array(3 downto 0);
   signal trigSel, trigSlot : sl;
   
   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(32);
--   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);

   signal dmaData           : slv(31 downto 0);
   signal dmaUser           : slv( 1 downto 0);

   signal axilDone : sl;

   signal config  : QuadAdcConfigType := (
     enable    => toSlv(1,8),
     partition => "0000",
     intlv     => "00",
     samples   => toSlv(0,18),
     prescale  => toSlv(0,6),
     offset    => toSlv(0,20),
     acqEnable => '1',
     rateSel   => (others=>'0'),
     destSel   => (others=>'0'),
     inhibit   => '0',
     dmaTest   => '0',
     trigShift => (others=>'0') );
   
   constant DBG_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(16);
   signal dbgIbMaster : AxiStreamMasterArray(3 downto 0);
   signal evtId   : slv(31 downto 0) := (others=>'0');
   signal fexSize : slv(30 downto 0) := (others=>'0');
   signal fexOvfl : sl := '0';
   signal fexOffs : slv(15 downto 0) := (others=>'0');
   signal fexIndx : slv(15 downto 0) := (others=>'0');

   signal tpgConfig : TPGConfigType := TPG_CONFIG_INIT_C;

   -- Timing Interface (timingClk domain) 
   signal xData     : TimingRxType  := TIMING_RX_INIT_C;
   signal timingBus : TimingBusType := TIMING_BUS_INIT_C;
   signal exptBus   : ExptBusType   := EXPT_BUS_INIT_C;
   signal recTimingClk : sl;
   signal recTimingRst : sl;
   signal ready               : sl;

   signal cfgWriteMaster    : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal cfgWriteSlave     : AxiLiteWriteSlaveType;
   signal cfgReadMaster     : AxiLiteReadMasterType := AXI_LITE_READ_MASTER_INIT_C;
   signal cfgReadSlave      : AxiLiteReadSlaveType;
   signal timingFb          : TimingPhyType;
   
begin

  dmaData <= dmaIbMaster(0).tData(dmaData'range);
  dmaUser <= dmaIbMaster(0).tUser(dmaUser'range);

  U_CLK : entity work.ClkSim
    generic map ( SELECT_G => "LCLSII" )
    port map ( phyClk   => phyClk,
               evrClk   => refTimingClk );
  
  U_QIN : entity work.AdcRamp
    port map ( phyClk   => phyClk,
               dmaClk   => dmaClk,
               ready    => axilDone,
               adcOut   => adcO,
               trigSel  => trigSel,
               trigOut  => trigIn );

   process is
   begin
     rst <= '1';
     wait for 100 ns;
     rst <= '0';
     wait;
   end process;
   
   regRst       <= rst;
   recTimingRst <= rst;
   
   process is
   begin
     regClk <= '0';
     wait for 3.2 ns;
     regClk <= '1';
     wait for 3.2 ns;
   end process;
     
   U_XPM : entity work.XpmSim
     generic map ( USE_TX_REF => true,
                   RATE_DIV_G => 8 )
     port map ( txRefClk  => refTimingClk,
                dsRxClk   => (others=>recTimingClk),
                dsRxRst   => (others=>'0'),
                dsRxData  => (others=>(others=>'0')),
                dsRxDataK => (others=>"00"),
                --
                bpTxClk    => recTimingClk,
                bpTxLinkUp => '1',
                bpTxData   => xData.data,
                bpTxDataK  => xData.dataK,
                bpRxClk    => '0',
                bpRxClkRst => '0',
                bpRxLinkUp => (others=>'0'),
                bpRxLinkFull => (others=>(others=>'0')) );
   
   U_RxLcls : entity work.TimingFrameRx
     port map ( rxClk               => recTimingClk,
                rxRst               => recTimingRst,
                rxData              => xData,
                messageDelay        => (others=>'0'),
                messageDelayRst     => '0',
                timingMessage       => timingBus.message,
                timingMessageStrobe => timingBus.strobe,
                timingMessageValid  => timingBus.valid,
                exptMessage         => exptBus.message,
                exptMessageValid    => exptBus.valid );
                
  U_Core : entity work.QuadAdcCore
    generic map ( DMA_STREAM_CONFIG_G => AXIS_CONFIG_C )
    port map (
      axiClk              => regClk,
      axiRst              => regRst,
      axilWriteMasters(1) => regWriteMaster,
      axilWriteMasters(0) => cfgWriteMaster,
      axilWriteSlaves (1) => regWriteSlave,
      axilWriteSlaves (0) => cfgWriteSlave,
      axilReadMasters (1) => regReadMaster,
      axilReadMasters (0) => cfgReadMaster,
      axilReadSlaves  (1) => regReadSlave,
      axilReadSlaves  (0) => cfgReadSlave,
      -- DMA
      dmaClk              => dmaClk,
      dmaRst              => dmaRst,
      dmaRxIbMaster       => dmaIbMaster,
      dmaRxIbSlave        => dmaIbSlave ,
      -- EVR Ports
      evrClk              => recTimingClk,
      evrRst              => recTimingRst,
      evrBus              => timingBus,
      exptBus             => exptBus,
--      ready               => ready,
      timingFbClk         => recTimingClk,
      timingFbRst         => recTimingRst,
      timingFb            => timingFb,
      -- ADC
      gbClk               => '0', -- unused
      adcClk              => dmaClk,
      adcRst              => dmaRst,
      adc                 => adcO,
      --
      trigSlot            => trigSlot,
      trigOut             => trigSel,
      trigIn              => trigIn,
      adcSyncRst          => open,
      adcSyncLocked       => '1' );

   GEN_DBG : for i in dbgIbMaster'range generate
     U_DBGFIFO : entity work.AxiStreamFifo
       generic map ( SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_C,
                     MASTER_AXI_CONFIG_G => DBG_AXIS_CONFIG_C )
       port map ( sAxisClk => dmaClk,
                  sAxisRst => dmaRst,
                  sAxisMaster => dmaIbMaster(i),
                  sAxisSlave  => dmaIbSlave (i),
                  mAxisClk    => dmaClk,
                  mAxisRst    => dmaRst,
                  mAxisMaster => dbgIbMaster(i),
                  mAxisSlave  => AXI_STREAM_SLAVE_FORCE_C );
   end generate;
   
   process (dmaClk) is
     type StateType is (S_IDLE, S_HDR, S_FEX, S_END);
     variable v : StateType := S_IDLE;
   begin
     if rising_edge(dmaClk) then
       if dbgIbMaster(0).tValid='1' then
         case (v) is
           when S_IDLE => v := S_HDR;
                          evtId   <= dbgIbMaster(0).tData(31 downto 0);
           when S_HDR  => v := S_FEX;
           when S_FEX  => v := S_END;
                          fexSize <= dbgIbMaster(0).tData(30 downto 0); 
                          fexOvfl <= dbgIbMaster(0).tData(31);
                          fexOffs <= dbgIbMaster(0).tData(47 downto 32);
                          fexIndx <= dbgIbMaster(0).tData(63 downto 48);
           when S_END  => if dbgIbMaster(0).tLast='1' then
                            v := S_IDLE;
                          end if;
           when others => null;
         end case;
       end if;
     end if;
   end process;
   
   process is
     procedure wreg(addr : integer; data : slv(31 downto 0)) is
     begin
       wait until regClk='0';
       regWriteMaster.awaddr  <= toSlv(addr,32);
       regWriteMaster.awvalid <= '1';
       regWriteMaster.wdata   <= data;
       regWriteMaster.wvalid  <= '1';
       regWriteMaster.bready  <= '1';
       wait until regClk='1';
       wait until regWriteSlave.bvalid='1';
       wait until regClk='0';
       wait until regClk='1';
       wait until regClk='0';
       regWriteMaster.awvalid <= '0';
       regWriteMaster.wvalid  <= '0';
       regWriteMaster.bready  <= '0';
       wait for 50 ns;
     end procedure;
  begin
    axilDone <= '0';
    wait until regRst='0';
    wait for 1200 ns;
    wreg(16,x"00000000"); -- prescale
    wreg(20,x"00800004"); -- fexLength/Delay
    wreg(24,x"00040C00"); -- almostFull
    wreg(32,x"00000000"); -- prescale
    wreg(36,x"00800004"); -- fexLength/Delay
    wreg(40,x"00040C00"); -- almostFull
    wreg(256*2+16,x"00000040");
    wreg(256*2+24,x"000003c0");
    wreg(256*2+32,x"00000002");
    wreg(256*2+40,x"00000002");
    wreg( 0,x"00000003"); -- fexEnable
    wait for 600 ns;
    axilDone <= '1';
    wait;
  end process;

   process is
     procedure wreg(addr : integer; data : slv(31 downto 0)) is
     begin
       wait until regClk='0';
       cfgWriteMaster.awaddr  <= toSlv(addr,32);
       cfgWriteMaster.awvalid <= '1';
       cfgWriteMaster.wdata   <= data;
       cfgWriteMaster.wvalid  <= '1';
       cfgWriteMaster.bready  <= '1';
       wait until regClk='1';
       wait until cfgWriteSlave.bvalid='1';
       wait until regClk='0';
       wait until regClk='1';
       wait until regClk='0';
       cfgWriteMaster.awvalid <= '0';
       cfgWriteMaster.wvalid  <= '0';
       cfgWriteMaster.bready  <= '0';
       wait for 50 ns;
     end procedure;
  begin
    wait until regRst='0';
    wait for 1200 ns;
    wreg(16,x"00000010");  -- dmaRst
    wreg(16,x"00000000");
    wreg(20,x"40000000");  -- rateSel/destSel ?
    wreg(24,x"00000001");  -- enable
    wreg(28,x"00000100");  -- samples
    wait until axilDone='1';
    wreg(16,x"80000000");  -- acqEnable
    wait;
  end process;

  GEN_XTC : for i in 0 to 3 generate
    U_XTC : entity work.HsdXtc
      generic map ( filename => "hsd_" & integer'image(i) & ".xtc" )
      port map ( axisClk    => dmaClk,
                 axisMaster => dbgIbMaster(i) );
  end generate;
     
end top_level_app;

