-------------------------------------------------------------------------------
-- File       : EventHeaderCacheWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
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
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.TimingPkg.all;
use work.TimingExtnPkg.all;
use work.EventPkg.all;
use work.TDetPkg.all;
use work.XpmPkg.all;
use work.SsiPkg.all;

entity EventHeaderCacheWrapper is
   generic (
      TPD_G              : time                := 1 ns;
      -- USER_AXIS_CONFIG_G : AxiStreamConfigType := TDET_AXIS_CONFIG_C;
      USER_AXIS_CONFIG_G : AxiStreamConfigType := ssiAxiStreamConfig(4);
      PIPE_STAGES_G      : natural             := 0;
      NDET_G             : natural             := 1);
   port (
      -- Trigger Interface (rxClk domain)
      trigBus         : out TDetTrigArray (NDET_G-1 downto 0);
      -- Readout Interface (tdetClk domain)
      tdetClk         : in  sl;
      tdetRst         : in  sl := '0';
      tdetTiming      : in  TDetTimingArray (NDET_G-1 downto 0);
      tdetStatus      : out TDetStatusArray (NDET_G-1 downto 0);
      -- Event stream (tdetClk domain)
      tdetEventMaster : out AxiStreamMasterArray(NDET_G-1 downto 0);
      tdetEventSlave  : in  AxiStreamSlaveArray (NDET_G-1 downto 0);
      -- Transition stream (tdetClk domain)
      tdetTransMaster : out AxiStreamMasterArray(NDET_G-1 downto 0);
      tdetTransSlave  : in  AxiStreamSlaveArray (NDET_G-1 downto 0);
      -- LCLS RX Timing Interface (rxClk domain)
      rxClk           : in  sl;
      rxRst           : in  sl;
      rxControl       : in  TimingPhyControlType;
      timingBus       : in  TimingBusType;
      -- LCLS RX Timing Interface (txClk domain)
      txClk           : in  sl;
      txRst           : in  sl;
      txStatus        : in  TimingPhyStatusType;
      timingPhy       : out TimingPhyType);
end EventHeaderCacheWrapper;

architecture mapping of EventHeaderCacheWrapper is

   signal timingHdr  : TimingHeaderType;  -- prompt
   signal triggerBus : ExptBusType;       -- prompt

   signal appTimingHdr : TimingHeaderType;  -- aligned
   signal appExptBus   : ExptBusType;       -- aligned

   signal pdata  : XpmPartitionDataArray(NDET_G-1 downto 0);
   signal pdataV : slv (NDET_G-1 downto 0);

   signal fullOut : slv(NPartitions-1 downto 0);

   signal tdetMaster : AxiStreamMasterArray (NDET_G-1 downto 0);
   signal tdetSlave  : AxiStreamSlaveArray (NDET_G-1 downto 0);

   signal tdetMasterResize : AxiStreamMasterArray (NDET_G-1 downto 0);
   signal tdetSlaveResize  : AxiStreamSlaveArray (NDET_G-1 downto 0);

   signal hdrOut : EventHeaderArray (NDET_G-1 downto 0);

begin

   timingHdr          <= toTimingHeader (timingBus);
   triggerBus.message <= ExptMessageType(timingBus.extn);
   triggerBus.valid   <= timingBus.extnValid;

   U_Realign : entity work.EventRealign
      generic map (
         TPD_G => TPD_G)
      port map (
         clk      => rxClk,
         rst      => rxRst,
         timingI  => timingHdr,
         exptBusI => triggerBus,
         timingO  => appTimingHdr,
         exptBusO => appExptBus,
         delay    => open);

   GEN_DET : for i in 0 to NDET_G-1 generate

      trigBus(i).l0a   <= pdata (i).l0a;
      trigBus(i).l0tag <= pdata (i).l0tag;
      trigBus(i).valid <= pdataV(i);

      U_HeaderCache : entity work.EventHeaderCache
         generic map (
            TPD_G => TPD_G)
         port map (
            rst            => rxRst,
            --  Cache Input
            wrclk          => rxClk,
            -- configuration
            enable         => tdetTiming(i).enable,
--          cacheenable     : in  sl := '1';     -- caches headers --
            partition      => tdetTiming(i).partition,
            -- event input
            timing_prompt  => timingHdr,
            expt_prompt    => triggerBus,
            timing_aligned => appTimingHdr,
            expt_aligned   => appExptBus,
            -- trigger output
            pdata          => pdata (i),
            pdataV         => pdataV (i),
            -- status
            cntL0          => tdetStatus(i).cntL0,
            cntL1A         => tdetStatus(i).cntL1A,
            cntL1R         => tdetStatus(i).cntL1R,
            cntWrFifo      => tdetStatus(i).cntWrFifo,
            rstFifo        => open,
            msgDelay       => tdetStatus(i).msgDelay,
            cntOflow       => tdetStatus(i).cntOflow,
            --  Cache Output
            rdclk          => tdetClk,
            advance        => tdetSlave (i).tReady,
            valid          => tdetMaster(i).tValid,
            pmsg           => tdetMaster(i).tDest(0),
            cntRdFifo      => tdetStatus(i).cntRdFifo,
            hdrOut         => hdrOut (i));

      tdetMaster(i).tData(8*TDET_AXIS_CONFIG_C.TDATA_BYTES_C-1 downto 0) <= toSlv(hdrOut(i));
      tdetMaster(i).tLast                                                <= '1';
      tdetMaster(i).tKeep                                                <= genTKeep(TDET_AXIS_CONFIG_C);

      U_Resizer : entity work.AxiStreamResize
         generic map (
            TPD_G               => TPD_G,
            SLAVE_AXI_CONFIG_G  => TDET_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => USER_AXIS_CONFIG_G)
         port map (
            -- Clock and reset
            axisClk     => tdetClk,
            axisRst     => tdetRst,
            -- Slave Port
            sAxisMaster => tdetMaster(i),
            sAxisSlave  => tdetSlave (i),
            -- Master Port
            mAxisMaster => tdetMasterResize(i),
            mAxisSlave  => tdetSlaveResize (i));

      U_DeMux : entity work.AxiStreamDeMux
         generic map (
            TPD_G         => TPD_G,
            PIPE_STAGES_G => PIPE_STAGES_G,
            NUM_MASTERS_G => 2)
         port map (
            axisClk         => tdetClk,
            axisRst         => tdetRst,
            sAxisMaster     => tdetMasterResize(i),
            sAxisSlave      => tdetSlaveResize (i),
            mAxisMasters(0) => tdetEventMaster(i),
            mAxisMasters(1) => tdetTransMaster(i),
            mAxisSlaves (0) => tdetEventSlave (i),
            mAxisSlaves (1) => tdetTransSlave (i));

   end generate;

   fullp : process (tdetTiming) is
      variable vfull : slv(NPartitions-1 downto 0);
   begin
      vfull := (others => '0');
      for i in 0 to NDET_G-1 loop
         if tdetTiming(i).enable = '1' and tdetTiming(i).afull = '1' then
            vfull(conv_integer(tdetTiming(i).partition)) := '1';
         end if;
      end loop;
      fullOut <= vfull;
   end process fullp;

   U_TimingFb : entity work.XpmTimingFb
      generic map (
--       TPD_G   => TPD_G,
         DEBUG_G => true)
      port map (
         clk      => txClk,
         rst      => txRst,
         status   => txStatus,
         pllReset => rxControl.pllReset,
         phyReset => rxControl.reset,
         id       => tdetTiming(0).id,
         l1input  => (others => XPM_L1_INPUT_INIT_C),
         full     => fullOut,
         phy      => timingPhy);

   p_PAddr : process (rxClk) is
   begin
      if rising_edge(rxClk) then
         if (triggerBus.valid = '1' and timingBus.strobe = '1') then
            for i in 0 to NDET_G-1 loop
               tdetStatus(i).partitionAddr <= triggerBus.message.partitionAddr after TPD_G;
            end loop;
         end if;
      end if;
   end process p_PAddr;

end mapping;
