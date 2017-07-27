-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : XpmSim.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2017-07-26
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: XpmApp's Top Level
-- 
-- Note: Common-to-XpmApp interface defined here (see URL below)
--       https://confluence.slac.stanford.edu/x/rLyMCw
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
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.TimingPkg.all;
use work.TPGPkg.all;
use work.XpmPkg.all;

library unisim;
use unisim.vcomponents.all;

entity XpmSim is
  generic ( ENABLE_DS_LINKS_G : slv(NDSLinks-1 downto 0) := (others=>'0');
            ENABLE_BP_LINKS_G : slv(NBPLinks-1 downto 0) := (others=>'0');
            RATE_DIV_G        : integer := 4;
            RATE_SELECT_G     : integer := 1;
            PIPELINE_DEPTH_G  : integer := 200 );
  port ( dsRxClk      : in  slv       (NDSLinks-1 downto 0);
         dsRxRst      : in  slv       (NDSLinks-1 downto 0);
         dsRxData     : in  Slv16Array(NDSLinks-1 downto 0);
         dsRxDataK    : in  Slv2Array (NDSLinks-1 downto 0);
         dsTxClk      : out slv       (NDSLinks-1 downto 0);
         dsTxRst      : out slv       (NDSLinks-1 downto 0);
         dsTxData     : out Slv16Array(NDSLinks-1 downto 0);
         dsTxDataK    : out Slv2Array (NDSLinks-1 downto 0);
         --
         bpTxClk      : out sl;
         bpTxLinkUp   : in  sl;
         bpTxData     : out slv(15 downto 0);
         bpTxDataK    : out slv( 1 downto 0);
         bpRxClk      : in  sl;
         bpRxClkRst   : in  sl;
         bpRxLinkUp   : in  slv       (NBPLinks-1 downto 0);
         bpRxLinkFull : in  Slv16Array(NBPLinks-1 downto 0) );
end XpmSim;

architecture top_level_app of XpmSim is

   -- Reference Clocks and Resets
   signal recTimingClk : sl;
   signal recTimingRst : sl;
   signal regClk       : sl;
   signal regRst       : sl;
   
   signal tpgConfig : TPGConfigType := TPG_CONFIG_INIT_C;
   signal xpmConfig : XpmConfigType := XPM_CONFIG_INIT_C;
   signal xpmStatus : XpmStatusType;
   signal linkStatus: XpmLinkStatusArray(NDSLinks-1 downto 0) := (others=>XPM_LINK_STATUS_INIT_C);
   
   -- Timing Interface (timingClk domain) 
   signal xData     : TimingRxType := TIMING_RX_INIT_C;
   signal timingBus : TimingBusType;
   signal exptBus   : ExptBusType;
   
   signal pconfig : XpmPartitionConfigType := XPM_PARTITION_CONFIG_INIT_C;
   
begin

  --  Generate clocks and resets
  process is
  begin
    regRst <= '1';
    wait for 10 ns;
    regRst <= '0';
    wait;
  end process;
  
  process is
  begin
    regClk <= '1';
    wait for 4.0 ns;
    regClk <= '0';
    wait for 4.0 ns;
  end process;

  recTimingRst <= regRst;
  
  process is
  begin
    recTimingClk <= '1';
    wait for 2.6 ns;
    recTimingClk <= '0';
    wait for 2.6 ns;
  end process;

  dsTxClk <= (others=>recTimingClk);
  dsTxRst <= (others=>recTimingRst);
  bpTxClk <= recTimingClk;
  
  U_TPG : entity work.TPGMini
    port map ( txClk    => recTimingClk,
               txRst    => recTimingRst,
               txRdy    => '1',
               txData   => xData.data,
               txDataK  => xData.dataK,
               statusO  => open,
               configI  => tpgConfig );

  tpgConfig.FixedRateDivisors(RATE_SELECT_G) <= toSlv(RATE_DIV_G,20);
  
  xpmConfig.partition(0) <= pconfig;
  xpmConfig.dsLink(0).txDelay <= toSlv(200,20);
  xpmConfig.dsLink(1).txDelay <= toSlv(200,20);
     
  pconfig.l0Select.enabled <= '1';
  pconfig.l0Select.rateSel <= toSlv(RATE_SELECT_G,16);
  pconfig.l0Select.destSel <= x"8000";
  pconfig.pipeline.depth   <= toSlv(PIPELINE_DEPTH_G,20);
  pconfig.inhibit.setup(0).enable   <= '1';
  pconfig.inhibit.setup(0).limit    <= toSlv(3,4);
  pconfig.inhibit.setup(0).interval <= toSlv(10,12);

  GEN_DS_ENABLE : for i in 0 to NDSLinks-1 generate
    GEN_ENABLE: if ENABLE_DS_LINKS_G(i)='1' generate
      xpmConfig.dsLink(i).enable     <= '1';
      xpmConfig.dsLink(i).partition  <= toSlv( 0, 4);
    end generate;
  end generate;
   
  GEN_BP_ENABLE : for i in 0 to NBPLinks-1 generate
    GEN_ENABLE: if ENABLE_BP_LINKS_G(i)='1' generate
      xpmConfig.bpLink(i).enable     <= '1';
      xpmConfig.dsLink(i).partition  <= toSlv( 0, 4);
    end generate;
  end generate;
   
  GEN_PIPEL : for i in 1 to NPartitions-1 generate
    xpmConfig.partition(i).pipeline.depth <= toSlv(0,20);
  end generate;
   
   process is
   begin
     pconfig.analysis.rst  <= x"f";
     pconfig.analysis.tag  <= x"00000000";
     pconfig.analysis.push <= x"0";
     wait for 100 ns;
     pconfig.analysis.rst  <= x"0";
     wait for 5000 ns;
     wait until regClk='0';
     pconfig.analysis.tag  <= x"00000001";
     pconfig.analysis.push <= x"1";
     wait until regClk='1';
     wait until regClk='0';
     pconfig.analysis.push <= x"0";
     wait until regClk='1';
     wait until regClk='0';
     pconfig.analysis.tag  <= x"00000002";
     pconfig.analysis.push <= x"1";
     wait until regClk='1';
     wait until regClk='0';
     pconfig.analysis.push <= x"0";
     wait until regClk='1';
     wait until regClk='0';
     pconfig.analysis.tag  <= x"00000003";
     pconfig.analysis.push <= x"1";
     wait until regClk='1';
     wait until regClk='0';
     pconfig.analysis.push <= x"0";
     wait;
   end process;
     

   timingBus.valid  <= '1';
   timingBus.stream <= TIMING_STREAM_INIT_C;
   timingBus.v1     <= LCLS_V1_TIMING_DATA_INIT_C;
   timingBus.v2     <= LCLS_V2_TIMING_DATA_INIT_C;

   U_RxLcls2 : entity work.TimingFrameRx
     port map ( rxClk               => recTimingClk,
                rxRst               => recTimingRst,
                rxData              => xData,
                messageDelay        => (others=>'0'),
                messageDelayRst     => '0',
                timingMessage       => timingBus.message,
                timingMessageStrobe => timingBus.strobe,
                exptMessage         => exptBus.message,
                exptMessageValid    => exptBus.valid );
                
   U_Application : entity work.XpmApp
      generic map ( NDsLinks => linkStatus'length,
                    NBpLinks => bpRxLinkUp'length )
      port map (
         -----------------------
         -- Application Ports --
         -----------------------
         -- -- AMC's DS Ports
         dsLinkStatus    => linkStatus,
         dsRxData        => dsRxData,
         dsRxDataK       => dsRxDataK,
         dsTxData        => dsTxData,
         dsTxDataK       => dsTxDataK,
         dsRxClk         => dsRxClk,
         dsRxRst         => dsRxRst,
         dsRxErr         => (others=>'0'),
         -- BP DS Ports
         bpTxData        => bpTxData,
         bpTxDataK       => bpTxDataK,
         bpStatus        => (others=>XPM_BP_LINK_STATUS_INIT_C),
         bpRxLinkFull    => (others=>x"0000"),
         ----------------------
         -- Top Level Interface
         ----------------------
         regclk          => regClk,
         update          => toSlv(1,NPartitions),
         status          => xpmStatus,
         config          => xpmConfig,
         -- Timing Interface (timingClk domain) 
         timingClk         => recTimingClk,
         timingRst         => recTimingRst,
         timingin          => xData,
         timingFbClk       => '0',
         timingFbRst       => '1',
         timingFb          => open );
--         timingBus         => timingBus,
--         exptBus           => exptBus );

end top_level_app;
