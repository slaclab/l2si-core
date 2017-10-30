-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : hsd_dualv2_sim.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2017-10-22
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

entity hsd_dualv2_sim is
end hsd_dualv2_sim;

architecture top_level_app of hsd_dualv2_sim is

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
   signal dmaIbMaster       : AxiStreamMasterArray(4 downto 0);
   signal dmaIbSlave        : AxiStreamSlaveArray (4 downto 0) := (others=>AXI_STREAM_SLAVE_FORCE_C);

   signal phyClk            : sl;
   signal adcO              : AdcDataArray(NCHAN_C-1 downto 0);
   signal trigIn            : Slv8Array(3 downto 0);
   signal trigSel, trigSlot : sl;
   
--   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(16);
   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);

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
   signal dbgIbMaster : AxiStreamMasterType;
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

   U_QIN : entity work.AdcRamp
--   U_QIN : entity work.AdcStrobe
     generic map ( NCHAN_C => NCHAN_C )
     port map ( phyClk   => phyClk,
                dmaClk   => dmaClk,
                ready    => axilDone,
                adcOut   => adcO,
                trigSel  => trigSel,
                trigOut  => trigIn );

  process is
   begin
     phyClk <= '1';
     wait for 0.4 ns;
     phyClk <= '0';
     wait for 0.4 ns;
   end process;

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
     generic map ( RATE_DIV_G => 8 )
     port map ( dsRxClk   => (others=>recTimingClk),
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

   U_DBGFIFO : entity work.AxiStreamFifo
     generic map ( SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_C,
                   MASTER_AXI_CONFIG_G => DBG_AXIS_CONFIG_C )
     port map ( sAxisClk => dmaClk,
                sAxisRst => dmaRst,
                sAxisMaster => dmaIbMaster(0),
                sAxisSlave  => dmaIbSlave (0),
                mAxisClk    => dmaClk,
                mAxisRst    => dmaRst,
                mAxisMaster => dbgIbMaster,
                mAxisSlave  => AXI_STREAM_SLAVE_FORCE_C );
                
   process (dmaClk) is
     type StateType is (S_IDLE, S_HDR, S_FEX, S_END);
     variable v : StateType := S_IDLE;
   begin
     if rising_edge(dmaClk) then
       if dbgIbMaster.tValid='1' then
         case (v) is
           when S_IDLE => v := S_HDR;
                          evtId   <= dbgIbMaster.tData(31 downto 0);
           when S_HDR  => v := S_FEX;
           when S_FEX  => v := S_END;
                          fexSize <= dbgIbMaster.tData(30 downto 0); 
                          fexOvfl <= dbgIbMaster.tData(31);
                          fexOffs <= dbgIbMaster.tData(47 downto 32);
                          fexIndx <= dbgIbMaster.tData(63 downto 48);
           when S_END  => if dbgIbMaster.tLast='1' then
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
    wait for 200 ns;
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
    wait for 200 ns;
    wreg(16,x"00000010");
    wreg(16,x"00000000");
    wreg(20,x"40000000");
    wreg(24,x"00000001");
    wreg(28,x"00000100");
    wreg(16,x"80000000");
    wait;
  end process;

  process is
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
    
    file results : text;
    variable oline : line;
  begin
    file_open(results, "HSD.xtc", write_mode);
    loop
      wait until rising_edge(dmaClk);
      if dbgIbMaster.tValid='1' then
        write(oline, HexString(dbgIbMaster.tData( 31 downto  0)), right, 9);
        write(oline, HexString(dbgIbMaster.tData( 63 downto 32)), right, 9);
        write(oline, HexString(dbgIbMaster.tData( 95 downto 64)), right, 9);
        write(oline, HexString(dbgIbMaster.tData(127 downto 96)), right, 9);
        if dbgIbMaster.tLast='1' then
          writeline(results, oline);
        end if;
      end if;
    end loop;
    file_close(results);
  end process;
     
end top_level_app;

