-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : xpm_sim.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2017-10-09
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

use STD.textio.all;
use ieee.std_logic_textio.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.TimingPkg.all;
use work.XpmPkg.all;
use work.DtiPkg.all;
use work.DtiSimPkg.all;

entity dti_sim is
end dti_sim;

architecture top_level_app of dti_sim is

  signal clk156, rst156 : sl;
  signal clk186, rst186 : sl;
  signal fifoRst : sl;

  signal usConfig     : DtiUsLinkConfigArray(1 downto 0) := (others=>DTI_US_LINK_CONFIG_INIT_C);
  signal usStatus     : DtiUsLinkStatusArray(1 downto 0);
  signal usIbMaster   : AxiStreamMasterArray(1 downto 0);
  signal usIbSlave    : AxiStreamSlaveArray (1 downto 0);
  signal usIbClk      : slv                 (1 downto 0);
  signal usObMaster   : AxiStreamMasterArray(1 downto 0);
  signal usObSlave    : AxiStreamSlaveArray (1 downto 0);
  signal usObClk      : slv                 (1 downto 0);
  signal usFull       : Slv16Array          (1 downto 0);
  signal usObTrig     : XpmPartitionDataArray(1 downto 0);
  signal usObTrigV    : slv                  (1 downto 0);

  signal dsStatus : DtiDsLinkStatusArray(MaxDsLinks-1 downto 0);
  
  signal ctlRxM, ctlTxM : AxiStreamMasterArray(1 downto 0) := (others=>AXI_STREAM_MASTER_INIT_C);
  signal ctlRxS, ctlTxS : AxiStreamSlaveArray (1 downto 0) := (others=>AXI_STREAM_SLAVE_INIT_C);

  signal timingBus : TimingBusType;
  signal exptBus   : ExptBusType;

  type UsMasterArray is array (natural range<>) of AxiStreamMasterArray(MaxDsLinks-1 downto 0);
  signal usEvtMasters : UsMasterArray(MaxUsLinks-1 downto 0)        := (others=>(others=>AXI_STREAM_MASTER_INIT_C));
  type UsSlaveArray  is array (natural range<>) of AxiStreamSlaveArray (MaxDsLinks-1 downto 0);
  signal usEvtSlaves  : UsSlaveArray (MaxUsLinks-1 downto 0) := (others=>(others=>AXI_STREAM_SLAVE_FORCE_C));
  
  type DsMasterArray is array (natural range<>) of AxiStreamMasterArray(MaxUsLinks-1 downto 0);
  signal dsEvtMasters : DsMasterArray(MaxDsLinks-1 downto 0)        := (others=>(others=>AXI_STREAM_MASTER_INIT_C));
  type DsSlaveArray  is array (natural range<>) of AxiStreamSlaveArray (MaxUsLinks-1 downto 0);
  signal dsEvtSlaves  : DsSlaveArray (MaxDsLinks-1 downto 0) := (others=>(others=>AXI_STREAM_SLAVE_FORCE_C));
  signal dsObMaster   : AxiStreamMasterArray(MaxDsLinks-1 downto 0);
  signal dsObSlave    : AxiStreamSlaveArray (MaxDsLinks-1 downto 0);
  signal dsObClk      : slv                 (MaxDsLinks-1 downto 0);
  
  signal dsFull     : slv(MaxDsLinks-1 downto 0) := (others=>'0');

  signal xpmDsRxClk  , xpmDsTxClk   : slv(NDSLinks-1 downto 0);
  signal xpmDsRxRst  , xpmDsTxRst   : slv(NDSLinks-1 downto 0);
  signal xpmDsRxData , xpmDsTxData  : Slv16Array(NDSLinks-1 downto 0);
  signal xpmDsRxDataK, xpmDsTxDataK : Slv2Array (NDSLinks-1 downto 0);

  signal bpTxLinkUp : sl := '1';
  signal bpTxData   : slv(15 downto 0);
  signal bpTxDataK  : slv( 1 downto 0);
  signal bpRxLinkUp : slv(NBPLinks-1 downto 0);
  signal bpRxLinkFull : Slv16Array(NBPLinks-1 downto 0);

  signal dsLinkUp     : slv(MaxDsLinks-1 downto 0);
  signal dsRxErrs     : Slv32Array(MaxDsLinks-1 downto 0);
  signal dsFullIn     : slv(MaxDsLinks-1 downto 0);
  
  -- for debug only --
  signal tbusI : TimingBusType;
  signal tbus  : TimingBusType;
  signal xbusI : ExptBusType;
  signal xbus  : ExptBusType;
  signal p0l0a : sl;

  signal timingBusO     : TimingBusType;
  signal exptBusO       : ExptBusType;

    function HexChar(v : in slv(3 downto 0)) return character is
      variable result : character := '0';
    begin
      case(v) is
      when x"0" => result := '0';
      when x"1" => result := '1';
      when x"2" => result := '2';
      when x"3" => result := '3';
      when x"4" => result := '4';
      when x"5" => result := '5';
      when x"6" => result := '6';
      when x"7" => result := '7';
      when x"8" => result := '8';
      when x"9" => result := '9';
      when x"A" => result := 'a';
      when x"B" => result := 'b';
      when x"C" => result := 'c';
      when x"D" => result := 'd';
      when x"E" => result := 'e';
      when x"F" => result := 'f';
      when others => null;
    end case;
    return result;
  end function;

  function HexString(v : in slv(31 downto 0)) return string is
    variable result : string(8 downto 1);
  begin
    for i in 0 to 7 loop
      result(i+1) := HexChar(v(4*i+3 downto 4*i));
    end loop;
    return result;
  end function;

begin

   usConfig(0).enable    <= '1';
   usConfig(0).partition <= toSlv(0,4);
--   usConfig(0).trigDelay <= toSlv(1,8);
   usConfig(0).fwdMask   <= toSlv(3,MaxDsLinks);
   usConfig(0).fwdMode   <= '0';
   usConfig(0).dataSrc   <= x"ABADCAFE";
   usConfig(0).dataType  <= x"FEEDADAD";
   usConfig(0).tagEnable <= '0';
   usConfig(0).l1Enable  <= '0';
     
   usConfig(1).enable    <= '1';
   usConfig(1).hdrOnly   <= '1';
   usConfig(1).partition <= toSlv(0,4);
--   usConfig(1).trigDelay <= toSlv(1,8);
   usConfig(1).fwdMask   <= toSlv(4,MaxDsLinks);
   usConfig(1).fwdMode   <= '0';
   usConfig(1).dataSrc   <= x"ABADCAFF";
   usConfig(1).dataType  <= x"FEEDADAD";
   usConfig(1).tagEnable <= '0';
   usConfig(1).l1Enable  <= '0';

   process is
   begin
     dsFullIn <= (others=>'0');
     wait for 40 us;
     dsFullIn <= toSlv(1,dsFullIn'length);
     wait for 20 us;
     dsFullIn <= (others=>'0');
     wait for 40 us;
     dsFullIn <= toSlv(4,dsFullIn'length);
     wait for 20 us;
     dsFullIn <= (others=>'0');
     wait;
   end process;
   
   process (clk186) is
   begin
     if rising_edge(clk186) then
       tbusI.strobe <= timingBus.strobe;
       if timingBus.strobe='1' then
         tbusI <= timingBus;
         xbusI <= exptBus;
       end if;
       tbus.strobe <= timingBusO.strobe;
       if timingBusO.strobe='1' then
         tbus.message           <= timingBusO.message;
         xbus                   <= exptBusO;
       end if;
     end if;
   end process;
   
   p0l0a <= exptBus.message.partitionWord(0)(0) when timingBus.strobe='1' else
            '0';
   
   process is
   begin
     rst156 <= '1';
     wait for 20 ns;
     rst156 <= '0';
     wait;
   end process;
   
   process is
   begin
      clk156 <= '1';
      wait for 3.2 ns;
      clk156 <= '0';
      wait for 3.2 ns;
   end process;

   process is
   begin
     fifoRst <= '1';
     wait for 50 ns;
     fifoRst <= '0';
     wait;
   end process;

   xpmDsRxClk   <= (others=>clk186);
   xpmDsRxRst   <= (others=>'1');
   xpmDsRxData  <= (others=>(K_COM_C & K_COM_C));
   xpmDsRxDataK <= (others=>"10");
   bpRxLinkUp   <= toSlv(1,NBPLinks);
   bpRxLinkFull(0) <= usFull(0) or usFull(1);
   bpRxLinkFull(NBPLinks-1 downto 1) <= (others=>(others=>'0'));
   
   U_Sim : entity work.XpmSim
     generic map ( PIPELINE_DEPTH_G => 0 )
     port map ( dsRxClk         => xpmDsRxClk,
                dsRxRst         => xpmDsRxRst,
                dsRxData        => xpmDsRxData,
                dsRxDataK       => xpmDsRxDataK,
                dsTxClk         => xpmDsTxClk,
                dsTxRst         => xpmDsTxRst,
                dsTxData        => xpmDsTxData,
                dsTxDataK       => xpmDsTxDataK,
                --
                bpTxClk         => clk186,
                bpTxLinkUp      => bpTxLinkUp,
                bpTxData        => bpTxData,
                bpTxDataK       => bpTxDataK,
                bpRxClk         => clk156,
                bpRxClkRst      => '1',
                bpRxLinkUp      => bpRxLinkUp,
                bpRxLinkFull    => bpRxLinkFull );

   rst186           <= fifoRst;
   timingBus.valid  <= '1';
   timingBus.stream <= TIMING_STREAM_INIT_C;
   timingBus.v1     <= LCLS_V1_TIMING_DATA_INIT_C;
   timingBus.v2     <= LCLS_V2_TIMING_DATA_INIT_C;

   U_RxLcls2 : entity work.TimingFrameRx
     port map ( rxClk               => clk186,
                rxRst               => rst186,
                rxData.data         => xpmDsTxData (0),
                rxData.dataK        => xpmDsTxDataK(0),
                rxData.decErr       => "00",
                rxData.dspErr       => "00",
                messageDelay        => (others=>'0'),
                messageDelayRst     => '0',
                timingMessage       => timingBus.message,
                timingMessageStrobe => timingBus.strobe,
                exptMessage         => exptBus.message,
                exptMessageValid    => exptBus.valid );

   U_Realign : entity work.ExptRealign
     port map ( clk    => clk186,
                rst    => rst186,
                timingI_strobe => timingBus.strobe,
                timingI_pid    => timingBus.message.pulseId,
                timingI_time   => timingBus.message.timeStamp,
                exptBusI       => exptBus,
                timingO_strobe => timingBusO.strobe,
                timingO_pid    => timingBusO.message.pulseId,
                timingO_time   => timingBusO.message.timeStamp,
                exptBusO       => exptBusO );
   
   GEN_US : for i in 0 to 1 generate
     U_DUT : entity work.DtiUsCore
       port map ( sysClk       => clk156,
                  sysRst       => rst156,
                  clear        => fifoRst,
                  config       => usConfig(i),
                  remLinkId    => x"00",
                  status       => usStatus(i),
                  fullOut      => usFull  (i),
                  --
                  --ctlClk       => clk156,
                  --ctlRst       => rst156,
                  --ctlRxMaster  => ctlRxM  (i),
                  --ctlRxSlave   => ctlRxS  (i),
                  --ctlTxMaster  => ctlTxM  (i),
                  --ctlTxSlave   => ctlTxS  (i),
                  ----
                  timingClk    => clk186,
                  timingRst    => rst186,
                  timingBus    => timingBusO,
                  exptBus      => exptBusO,
                  triggerBus   => exptBus,
                  --
                  eventClk     => clk156,
                  eventRst     => rst156,
                  eventMasters => usEvtMasters(i),
                  eventSlaves  => usEvtSlaves (i),
                  dsFull       => dsFull,
                  --
                  ibClk        => usIbClk   (i),
                  ibLinkUp     => '1',
                  ibErrs       => (others=>'0'),
                  ibFull       => '0',
                  ibMaster     => usIbMaster(i),
                  ibSlave      => usIbSlave (i),
                  --
                  obClk        => usObClk   (i),
                  obTrigValid  => usObTrigV (i),
                  obTrig       => usObTrig  (i) );
   end generate;
   
   GEN_USA : for i in 0 to 0 generate
     U_App : entity work.DtiUsSimApp
       generic map ( SERIAL_ID_G => x"ABADCAFE" )
       port map ( amcClk   => clk156,
                  amcRst   => rst156,
                  --
                  fifoRst  => fifoRst,
                  --
                  ibClk    => usIbClk   (i),
                  ibRst    => rst156,
                  ibMaster => usIbMaster(i),
                  ibSlave  => usIbSlave (i),
                  --
                  obClk    => usObClk   (i),
                  obRst    => rst186,
                  obTrig   => usObTrig  (i),
                  obTrigValid => usObTrigV(i),
                  obMaster => usObMaster(i),
                  obSlave  => usObSlave (i));
   end generate;
   
   GEN_DS : for i in 0 to MaxDsLinks-1 generate
     U_DsCore : entity work.DtiDsCore
       port map ( clear         => fifoRst,
                  update        => '1',
                  remLinkID     => x"00",
                  status        => dsStatus(i),
                  --
                  eventClk      => clk156,
                  eventRst      => rst156,
                  eventMasters  => dsEvtMasters(i),
                  eventSlaves   => dsEvtSlaves (i),
                  fullOut       => dsFull      (i),
                  --
                  linkUp        => dsLinkUp    (i),
                  rxErrs        => dsRxErrs    (i),
                  fullIn        => dsFullIn    (i),
                  --
                  obClk         => dsObClk     (i),
                  obMaster      => dsObMaster  (i),
                  obSlave       => dsObSlave   (i) );

     U_DsApp : entity work.DtiDsSimApp
       port map ( amcClk        => clk156,
                  amcRst        => rst156,
                  ibRst         => rst156,
                  linkUp        => dsLinkUp    (i),
                  rxErrs        => dsRxErrs    (i),
                  full          => open,
                  obClk         => dsObClk     (i),
                  obMaster      => dsObMaster  (i),
                  obSlave       => dsObSlave   (i));
     
     GEN_US : for j in 0 to MaxUsLinks-1 generate
       usEvtSlaves (j)(i) <= dsEvtSlaves (i)(j);
       dsEvtMasters(i)(j) <= usEvtMasters(j)(i);
     end generate;

   end generate;

   process
     file   results : text;
     variable oline : line;
   begin
     file_open(results, "headers.txt", write_mode);
     loop
       wait until rising_edge(clk156);
       if usEvtMasters(1)(2).tValid='1' and usEvtSlaves(1)(2).tReady='1' then
         write(oline, HexString(usEvtMasters(1)(2).tData( 31 downto  0)), right, 9);
         write(oline, HexString(usEvtMasters(1)(2).tData( 63 downto 32)), right, 9);
         if usEvtMasters(1)(2).tLast='1' then
           writeline(results, oline);
         end if;
       end if;
     end loop;
     file_close(results);
   end process;
   
end top_level_app;
