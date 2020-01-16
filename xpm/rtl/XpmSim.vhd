-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'L2SI Core'. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'L2SI Core', including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use STD.textio.all;
use ieee.std_logic_textio.all;


library surf;
use surf.StdRtlPkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingExtnPkg.all;
use lcls_timing_core.TimingPkg.all;
use lcls_timing_core.TPGPkg.all;

library l2si_core;
use l2si_core.XpmPkg.all;
use l2si_core.XpmMiniPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
 
library unisim;
use unisim.vcomponents.all;

entity XpmSim is
  generic ( USE_TX_REF        : boolean := false;
            ENABLE_DS_LINKS_G : slv(NDSLinks-1 downto 0) := (others=>'0');
            ENABLE_BP_LINKS_G : slv(NBPLinks-1 downto 0) := (others=>'0');
            RATE_DIV_G        : integer := 4;
            RATE_SELECT_G     : integer := 1;
            PIPELINE_DEPTH_G  : integer := 200 );
  port ( txRefClk     : in  sl := '0';
         dsRxClk      : in  slv       (NDSLinks-1 downto 0);
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

   constant GEN_CLEAR_G : boolean := false;
   constant SIM_ANALYSIS_TAG_G : boolean := false;
   
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
--   signal xData      : TimingRxType := TIMING_RX_INIT_C;
   signal xData      : XpmStreamType := (
     fiducial => '0',
     streams  => (others=>TIMING_SERIAL_INIT_C),
     advance  => (others=>'0') );
   
   signal pconfig : XpmPartitionConfigArray(NPartitions-1 downto 0) := (others=>XPM_PARTITION_CONFIG_INIT_C);
   
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

  NOGEN_REFCLK : if USE_TX_REF=true generate
    recTimingClk <= txRefClk;
  end generate;

  GEN_REFCLK : if USE_TX_REF=false generate
    process is
    begin
      recTimingClk <= '0';
      wait for 2.692 ns;
      recTimingClk <= '1';
      wait for 2.692 ns;
    end process;
  end generate;
  
  dsTxClk <= (others=>recTimingClk);
  dsTxRst <= (others=>recTimingRst);
  bpTxClk <= recTimingClk;
  
  U_TPG : entity lcls_timing_core.TPGMini
    port map ( txClk    => recTimingClk,
               txRst    => recTimingRst,
               txRdy    => '1',
               --txData   => xData.data,
               --txDataK  => xData.dataK,
               streams  => xData.streams(0 downto 0),
               advance  => xData.advance(0 downto 0),
               fiducial => xData.fiducial,
               statusO  => open,
               configI  => tpgConfig );

  tpgConfig.FixedRateDivisors(RATE_SELECT_G) <= toSlv(RATE_DIV_G,20);
  tpgConfig.pulseIdWrEn                      <= '0';
  tpgConfig.timeStampWrEn                    <= '0';
  
  xpmConfig.partition <= pconfig;
  xpmConfig.dsLink(0).txDelay <= toSlv(200,20);
  xpmConfig.dsLink(1).txDelay <= toSlv(200,20);

  GEN_DS_ENABLE : for i in 0 to NDSLinks-1 generate
    GEN_ENABLE: if ENABLE_DS_LINKS_G(i)='1' generate
      xpmConfig.dsLink(i).enable     <= '1';
      xpmConfig.dsLink(i).groupMask  <= x"ff";
    end generate;
  end generate;
   
  GEN_BP_ENABLE : for i in 0 to NBPLinks-1 generate
    GEN_ENABLE: if ENABLE_BP_LINKS_G(i)='1' generate
      xpmConfig.bpLink(i).enable     <= '1';
      xpmConfig.bpLink(i).groupMask  <= x"ff";
    end generate;
  end generate;

  process is
  begin
     for i in 0 to NPartitions-1 loop
       -- Realistic
       -- pconfig(i).pipeline.depth_clks <= toSlv((80+i)*200,16);
       -- pconfig(i).pipeline.depth_fids <= toSlv((80+i),8);
       -- Faster simulation
       pconfig(i).pipeline.depth_clks <= toSlv((20+i)*200,16);
       pconfig(i).pipeline.depth_fids <= toSlv((20+i),8);
     end loop;

     if SIM_ANALYSIS_TAG_G then
       pconfig(0).master        <= '1';
       pconfig(0).analysis.rst  <= x"f";
       pconfig(0).analysis.tag  <= x"00000000";
       pconfig(0).analysis.push <= x"0";
       wait for 100 ns;
       pconfig(0).analysis.rst  <= x"0";
       wait for 5000 ns;
       wait until regClk='0';
       pconfig(0).analysis.tag  <= x"00000001";
       pconfig(0).analysis.push <= x"1";
       wait until regClk='1';
       wait until regClk='0';
       pconfig(0).analysis.push <= x"0";
       wait until regClk='1';
       wait until regClk='0';
       pconfig(0).analysis.tag  <= x"00000002";
       pconfig(0).analysis.push <= x"1";
       wait until regClk='1';
       wait until regClk='0';
       pconfig(0).analysis.push <= x"0";
       wait until regClk='1';
       wait until regClk='0';
       pconfig(0).analysis.tag  <= x"00000003";
       pconfig(0).analysis.push <= x"1";
       wait until regClk='1';
       wait until regClk='0';
       pconfig(0).analysis.push <= x"0";
       wait until regClk='1';
       wait until regClk='0';

       wait for 10000 ns;
   
       wait until regClk='1';
       wait until regClk='0';
       
       for i in 0 to NPartitions-1 loop
         pconfig(i).message.insert  <= '0';
       end loop;

       wait for 120 us;
     else
       wait for 20 us;
     end if;
     
     pconfig(0).l0Select.enabled <= '1';
     pconfig(0).l0Select.rateSel <= toSlv(RATE_SELECT_G,16);
     pconfig(0).l0Select.destSel <= x"8000";
     --pconfig(0).inhibit.setup(0).enable   <= '1';
     --pconfig(0).inhibit.setup(0).limit    <= toSlv(3,4);
     --pconfig(0).inhibit.setup(0).interval <= toSlv(10,12);

     for i in 1 to NPartitions-1 loop
       pconfig(i).l0Select.enabled <= '1';
       pconfig(i).l0Select.rateSel <= toSlv(1,16);
       pconfig(i).l0Select.destSel <= x"8000";
     end loop;

     wait for 20 us;

     pconfig(0).l0Select.enabled <= '0';

     wait for 10 us;

     if GEN_CLEAR_G then
       for i in 0 to NPartitions-1 loop
         pconfig(i).message.hdr     <= MSG_CLEAR_FIFO;
         pconfig(i).message.insert  <= '1';
       end loop;
       
       wait until regClk='1';
       wait until regClk='0';
       
       for i in 0 to NPartitions-1 loop
         pconfig(i).message.insert  <= '0';
       end loop;

       wait for 100 ns;
     end if;
     
     pconfig(0).l0Select.enabled <= '1';
     
     wait;
   end process;

   U_SimSerializer : entity lcls_timing_core.TimingSerializer
     generic map ( STREAMS_C => xData.streams'length )
     port map ( clk       => recTimingClk,
                rst       => recTimingRst,
                fiducial  => xData.fiducial,
                streams   => xData.streams,
                streamIds => (x"0",x"2",x"1"),
                advance   => xData.advance,
                data      => open,
                dataK     => open );
     
   U_Application : entity l2si_core.XpmApp
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
         regrst          => regRst,
         update          => toSlv(1,NPartitions),
         status          => xpmStatus,
         config          => xpmConfig,
         axilReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
         axilWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
         obAppMaster     => open,
         obAppSlave      => AXI_STREAM_SLAVE_INIT_C,
         -- Timing Interface (timingClk domain) 
         timingClk         => recTimingClk,
         timingRst         => recTimingRst,
         timingStream      => xData,
         timingFbClk       => '0',
         timingFbRst       => '1',
         timingFbId        => (others=>'0'),
         timingFb          => open );
     
end top_level_app;
