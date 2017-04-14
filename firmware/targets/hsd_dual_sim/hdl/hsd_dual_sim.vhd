-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : hsd_dual_sim.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2017-03-17
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
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.TimingPkg.all;
use work.TPGPkg.all;
use work.QuadAdcPkg.all;

library unisim;
use unisim.vcomponents.all;

entity hsd_dual_sim is
end hsd_dual_sim;

architecture top_level_app of hsd_dual_sim is

   -- Reference Clocks and Resets
   signal recTimingClk : sl;
   signal recTimingRst : sl;

   signal tpgConfig : TPGConfigType := TPG_CONFIG_INIT_C;
   
   -- Timing Interface (timingClk domain) 
   signal xData     : TimingRxType := TIMING_RX_INIT_C;
   signal timingBus : TimingBusType := TIMING_BUS_INIT_C;
   
   signal phyClk    : sl;
   
   constant NFMC_G : integer := 2;
   constant LCLSII_C : boolean := false;
   constant NCHAN_C : integer := 4*NFMC_G;
   
   signal fmc_to_cpld      : Slv4Array(NFMC_G-1 downto 0) := (others=>(others=>'Z'));
   signal front_io_fmc     : Slv4Array(NFMC_G-1 downto 0) := (others=>(others=>'Z'));
   signal clk_to_fpga_p    :    slv(NFMC_G-1 downto 0) := (others=>'0');
   signal clk_to_fpga_n    :    slv(NFMC_G-1 downto 0) := (others=>'0');
   signal ext_trigger_p    :    slv(NFMC_G-1 downto 0) := (others=>'0');
   signal ext_trigger_n    :    slv(NFMC_G-1 downto 0) := (others=>'0');
   signal sync_from_fpga_p :   slv(NFMC_G-1 downto 0);
   signal sync_from_fpga_n :   slv(NFMC_G-1 downto 0);
   signal adcInput         :    AdcInputArray(NCHAN_C-1 downto 0);
   signal pg_m2c           :    slv(NFMC_G-1 downto 0) := "01";
   signal prsnt_m2c_l      :    slv(NFMC_G-1 downto 0) := "00";
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
   signal dmaIbMaster       : AxiStreamMasterType;
   signal dmaIbSlave        : AxiStreamSlaveType := AXI_STREAM_SLAVE_FORCE_C;
    -- EVR Ports
   signal evrClk              : sl;
   signal evrRst              : sl;
   signal evrBus              : TimingBusType;
   signal exptBus             : ExptBusType;
   signal ready               : sl;

   signal trigIn              : Slv8Array(3 downto 0) := (others=>(others=>'0'));
   signal trigSlot            : sl;
   signal trigSel             : sl;
   signal adcI, adcO          : AdcDataArray(4*NFMC_G-1 downto 0);

begin

   evrClk <= recTimingClk;
   evrRst <= recTimingRst;
   dmaRst <= recTimingRst;
   
   process (phyClk) is
     variable s : slv(7 downto 0) := (others=>'0');
     variable d : slv(2 downto 0) := (others=>'0');
   begin
     for ch in 0 to NCHAN_C-1 loop
       adcInput(ch).clkp <= phyclk;
       adcInput(ch).clkn <= not phyClk;
     end loop;
     if rising_edge(phyClk) then
       for ch in 0 to NCHAN_C-1 loop
         adcInput(ch).datap <= toSlv(ch,3) & s;
         adcInput(ch).datan <= toSlv(ch,3) & (s xor toSlv(255,8));
         adcI(ch).data(7) <= toSlv(ch,3) & s;
         adcI(ch).data(6 downto 0) <= adcI(ch).data(7 downto 1);
       end loop;
       trigIn(0) <= d(0) & trigIn(0)(7 downto 1);
       d := trigSel & d(2 downto 1);
       s := s+1;
     end if;
   end process;

   process is
   begin
     phyClk <= '1';
     wait for 0.4 ns;
     phyClk <= '0';
     wait for 0.4 ns;
   end process;

   process (evrClk) is
   begin
     if rising_edge(evrClk) then
       if timingBus.strobe='1' then
         evrBus <= timingBus;
       end if;
       evrBus.strobe <= timingBus.strobe;
     end if;
   end process;

   process (dmaClk) is
   begin
     if rising_edge(dmaClk) then
       for ch in 0 to NCHAN_C-1 loop
         adcO(ch) <= adcI(ch);
       end loop;
     end if;
   end process;
   
   process is
   begin
     dmaClk <= '1';
     wait for 3.2 ns;
     dmaClk <= '0';
     wait for 3.2 ns;
   end process;
   
   process is
   begin
     recTimingRst <= '1';
     wait for 100 ns;
     recTimingRst <= '0';
     wait;
   end process;
   
   process is
   begin
      recTimingClk <= '1';
      wait for 4.2 ns;
      recTimingClk <= '0';
      wait for 4.2 ns;
   end process;

   regRst <= recTimingRst;
   process is
   begin
     regClk <= '1';
     wait for 4.0 ns;
     regClk <= '0';
     wait for 4.0 ns;
   end process;
     
   U_TPG : entity work.TPGMiniStream
      generic map ( AC_PERIOD => 119000000/360/100 )
      port map ( txClk    => recTimingClk,
                 txRst    => recTimingRst,
                 txRdy    => '1',
                 txData   => xData.data,
                 txDataK  => xData.dataK,
                 config   => tpgConfig );

   U_RxLcls : entity work.TimingStreamRx
     port map ( rxClk               => recTimingClk,
                rxRst               => recTimingRst,
                rxData              => xData,
                timingMessage       => timingBus.stream,
                timingMessageStrobe => timingBus.strobe,
                timingMessageValid  => timingBus.valid );
                
  U_Core : entity work.QuadAdcCore
    generic map ( LCLSII_G    => LCLSII_C,
                  NFMC_G      => NFMC_G,
                  SYNC_BITS_G => 4 )
    port map (
      axiClk              => regClk,
      axiRst              => regRst,
      axilWriteMaster     => regWriteMaster,
      axilWriteSlave      => regWriteSlave,
      axilReadMaster      => regReadMaster,
      axilReadSlave       => regReadSlave,
      -- DMA
      dmaClk              => dmaClk,
      dmaRst              => dmaRst,
      dmaRxIbMaster       => dmaIbMaster,
      dmaRxIbSlave        => dmaIbSlave ,
      -- EVR Ports
      evrClk              => evrClk,
      evrRst              => evrRst,
      evrBus              => evrBus,
      exptBus             => exptBus,
      ready               => ready,
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
       wait until regClk='0';
       wait until regWriteSlave.bvalid='1';
       wait until regClk='1';
       wait until regClk='0';
       regWriteMaster.awvalid <= '0';
       regWriteMaster.wvalid  <= '0';
       regWriteMaster.bready  <= '0';
       wait until regClk='1';
       wait until regClk='0';
       wait until regClk='1';
     end procedure;
  begin
    wait until regRst='0';
    wreg(16,x"00000000"); -- stop
    wreg(20,x"00000009"); -- rateSel
    wreg(24,x"000000ff"); -- channels, noninterleave
    wreg(28,x"00000100"); -- samples
    wreg(32,x"00000001"); -- prsecale
    wreg(16,x"00000001"); -- reset counters
    wreg(16,x"80000000"); -- start
    wreg( 0,x"00000001"); -- irq enable
    wait;
  end process;
   
end top_level_app;
