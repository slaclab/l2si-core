-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : xpm_sim.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2017-09-02
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
use work.XpmPkg.all;
use work.TPGPkg.all;

library unisim;
use unisim.vcomponents.all;

entity xpm_sim is
end xpm_sim;

architecture top_level_app of xpm_sim is

   -- Reference Clocks and Resets
   signal recTimingClk : sl;
   signal recTimingRst : sl;

   signal tpgConfig : TPGConfigType := TPG_CONFIG_INIT_C;
   signal xpmConfig : XpmConfigType := XPM_CONFIG_INIT_C;
   signal xpmStatus : XpmStatusType;

   signal dsLinkStatus: XpmLinkStatusArray(NDSLinks-1 downto 0) := (others=>XPM_LINK_STATUS_INIT_C);
   
   signal simDsTxData  : Slv16Array(NDSLinks-1 downto 0);
   signal simDsTxDataK : Slv2Array (NDSLinks-1 downto 0);
   signal simDsRxData  : Slv16Array(NDSLinks-1 downto 0) := (others=>X"0000");
   signal simDsRxDataK : Slv2Array (NDSLinks-1 downto 0) := (others=>"00");
   signal simDsTxClk   : slv(NDSLinks-1 downto 0);
   signal simDsTxRst   : slv(NDSLinks-1 downto 0);
   signal simDsRxClk   : slv(NDSLinks-1 downto 0);
   signal simDsRxRst   : slv(NDSLinks-1 downto 0);

   signal dsTxData  : Slv16Array(NDSLinks-1 downto 0);
   signal dsTxDataK : Slv2Array (NDSLinks-1 downto 0);
   signal dsRxData  : Slv16Array(NDSLinks-1 downto 0) := (others=>X"0000");
   signal dsRxDataK : Slv2Array (NDSLinks-1 downto 0) := (others=>"00");
   signal dsRxClk   : slv(NDSLinks-1 downto 0);
   signal dsRxRst   : slv(NDSLinks-1 downto 0);

   signal bpRxLinkFull   : Slv16Array        (NBPLinks-1 downto 0) := (others=>(others=>'0'));
   signal bpTxData       : Slv16Array(0 downto 0);
   signal bpTxDataK      : Slv2Array (0 downto 0);
  
   -- Timing Interface (timingClk domain) 
   signal dsPhy     : TimingPhyType;
   signal xData     : TimingRxType := TIMING_RX_INIT_C;
   signal timingBus : TimingBusType;
   signal exptBus   : ExptBusType;
   
   signal regClk    : sl;
   signal regRst    : sl;

   signal pconfig  : XpmPartitionConfigType := XPM_PARTITION_CONFIG_INIT_C;
   signal dsFull   : slv(NPartitions-1 downto 0) := toSlv(1,NPartitions);
   signal timingFb : TimingPhyType := TIMING_PHY_INIT_C;

   signal msgCount : integer := 0;
begin

   xpmConfig.partition(0) <= pconfig;
   xpmConfig.dsLink(0).txDelay <= toSlv(200,20);
   xpmConfig.dsLink(1).txDelay <= toSlv(200,20);
     
   pconfig.l0Select.rateSel <= x"0001";
   pconfig.l0Select.destSel <= x"8000";
   pconfig.pipeline.depth   <= toSlv(200,20);
   pconfig.inhibit.setup(0).enable   <= '1';
   pconfig.inhibit.setup(0).limit    <= toSlv(3,4);
   pconfig.inhibit.setup(0).interval <= toSlv(50,12);
   
   xpmConfig.dsLink(0).enable     <= '1';
   xpmConfig.dsLink(0).partition  <= toSlv( 0, 4);
   xpmConfig.dsLink(1).enable     <= '1';
   
   GEN_PIPEL : for i in 1 to NPartitions-1 generate
     xpmConfig.partition(i).pipeline.depth <= toSlv(0,20);
   end generate;
   
   dsRxClk <= (others=>recTimingClk);
   dsRxRst <= (others=>recTimingRst);

   regRst <= recTimingRst;
   process is
   begin
     regClk <= '1';
     wait for 4.0 ns;
     regClk <= '0';
     wait for 4.0 ns;
   end process;
     
   -- device link
   process is
   begin
      wait for 100 ns;
      wait until recTimingClk='1';
      wait until recTimingClk='0';
      dsRxDataK(0) <= "01";
      dsRxData (0) <= D_215_C & K_COM_C;
      wait until recTimingClk='1';
      wait until recTimingClk='0';
      dsRxData (0) <= D_215_C & K_SOF_C;
      wait until recTimingClk='1';
      wait until recTimingClk='0';
      dsRxDataK(0) <= "00";
      dsRxData (0) <= x"0000";
      wait until recTimingClk='1';
      wait until recTimingClk='0';
      dsRxDataK(0) <= "01";
      dsRxData (0) <= D_215_C & K_EOF_C;
      wait until recTimingClk='1';
      wait until recTimingClk='0';
      dsRxDataK(0) <= "01";
      dsRxData (0) <= D_215_C & K_COM_C;
   end process;

   -- XPM link
   U_Fb : entity work.XpmTimingFb
     port map ( clk     => recTimingClk,
                rst     => recTimingRst,
                l1input => (others=>XPM_L1_INPUT_INIT_C),
                full    => dsFull,
                phy     => dsPhy );
   dsRxData (1) <= dsPhy.data;
   dsRxDataK(1) <= dsPhy.dataK;
   
   process is
   begin
      wait for 1200 ns;
      dsFull <= dsFull(0) & dsFull(dsFull'left downto 1);
   end process;

   process is
     procedure insertMsg(msg : integer) is
       variable word : slv(3 downto 0);
     begin
       wait until regClk = '1';
       wait until regClk = '0';
       pconfig.message.insert  <= '1';
       pconfig.message.hdr     <= toSlv(msg,15);
       word := toSlv(msgCount,4);
       pconfig.message.payload <= x"0" & word &
                                  x"1" & word &
                                  x"2" & word &
                                  x"3" & word;
       msgCount <= msgCount + 1;
       wait until regClk = '1';
       wait until regClk = '0';
       pconfig.message.insert  <= '0';
     end procedure;
   begin
     pconfig.l0Select.enabled <= '0';
     pconfig.analysis.rst  <= x"f";
     pconfig.analysis.tag  <= x"00000000";
     pconfig.analysis.push <= x"0";
     wait for 100 ns;
     pconfig.analysis.rst  <= x"0";
     wait for 3000 ns;
     insertMsg(1);
     wait for 2000 ns;
     insertMsg(2);
     wait for 2000 ns;
     insertMsg(3);
     wait for 2000 ns;
     insertMsg(4);
     wait for 5000 ns;
     wait until regClk='0';
     pconfig.l0Select.enabled <= '1';
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
     wait for 50 us;
     pconfig.l0Select.enabled <= '0';
     wait for 2000 ns;
     insertMsg(5);
     wait for 2000 ns;
     insertMsg(6);
     wait for 2000 ns;
     insertMsg(7);
     wait for 2000 ns;
     insertMsg(8);
     wait;
   end process;

   simDsRxClk  <= (others=>recTimingClk);
   simDsRxRst  <= (others=>recTimingRst);
   simDsRxData (simDsRxData 'left downto 1) <= (others=>(others=>'0'));
   simDsRxDataK(simDsRxDataK'left downto 1) <= (others=>(others=>'0'));
   simDsRxData (0) <= timingFb.data;
   simDsRxDataK(0) <= timingFb.dataK;

   recTimingClk <= simDsTxClk(0);
   recTimingRst <= simDsTxRst(0);
   xData.data   <= simDsTxData(0);
   xData.dataK  <= simDsTxDataK(0);
   
   U_Sim : entity work.XpmSim
     generic map( ENABLE_DS_LINKS_G => toSlv(1,NDSLinks),
                  ENABLE_BP_LINKS_G => toSlv(0,NBPLinks))
     port map ( dsRxClk      => simDsRxClk,
                dsRxRst      => simDsRxRst,
                dsRxData     => (others=>timingFb.data),
                dsRxDataK    => (others=>timingFb.dataK),
                dsTxClk      => simDsTxClk,
                dsTxRst      => simDsTxRst,
                dsTxData     => simDsTxData,
                dsTxDataK    => simDsTxDataK,
                bpTxLinkUp   => '0',
                bpRxClk      => '0',
                bpRxClkRst   => '0',
                bpRxLinkUp   => (others=>'0'),
                bpRxLinkFull => (others=>(others=>'0')) );

   U_DUT : entity work.XpmApp
      generic map ( NDSLinks => NDSLinks,
                    NBPLinks => NBPLinks )
      port map (
         -----------------------
         -- Application Ports --
         -----------------------
         -- -- AMC's DS Ports
         dsLinkStatus    => dsLinkStatus,
         dsRxData        => dsRxData,
         dsRxDataK       => dsRxDataK,
         dsTxData        => dsTxData,
         dsTxDataK       => dsTxDataK,
         dsRxErr         => (others=>'0'),
         dsRxClk         => dsRxClk,
         dsRxRst         => dsRxRst,
         -- BP ports
         bpTxData        => bpTxData (0),
         bpTxDataK       => bpTxDataK(0),
         bpStatus        => (others=>XPM_BP_LINK_STATUS_INIT_C),
         bpRxLinkFull    => bpRxLinkFull,
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
         timingFbClk       => recTimingClk,
         timingFbRst       => recTimingRst,
         timingFb          => timingFb );

end top_level_app;
