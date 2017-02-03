-------------------------------------------------------------------------------
-- File       : TargetTemplate.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-04-14
-- Last update: 2016-11-14
-------------------------------------------------------------------------------
-- Description: Firmware Target's Top Level
-- 
-- Note: Common-to-Application interface defined in HPS ESD: LCLSII-2.7-ES-0536
-- 
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 AMC Carrier Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 AMC Carrier Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.AxiLitePkg.all;
use work.TimingPkg.all;
use work.AmcCarrierPkg.all;
use work.AppTopPkg.all;

entity TargetTemplate is
   generic (
      TPD_G : time := 1 ns);
   port (
      -----------------------
      -- Application Ports --
      -----------------------
      -- AMC's JESD Ports
      jesdRxP          : in    Slv7Array(1 downto 0);
      jesdRxN          : in    Slv7Array(1 downto 0);
      jesdTxP          : out   Slv7Array(1 downto 0);
      jesdTxN          : out   Slv7Array(1 downto 0);
      jesdClkP         : in    Slv3Array(1 downto 0);
      jesdClkN         : in    Slv3Array(1 downto 0);
      -- AMC's JTAG Ports
      jtagPri          : inout Slv5Array(1 downto 0);
      jtagSec          : inout Slv5Array(1 downto 0);
      -- AMC's FPGA Clock Ports
      fpgaClkP         : inout Slv2Array(1 downto 0);
      fpgaClkN         : inout Slv2Array(1 downto 0);
      -- AMC's System Reference Ports
      sysRefP          : inout Slv4Array(1 downto 0);
      sysRefN          : inout Slv4Array(1 downto 0);
      -- AMC's Sync Ports
      syncInP          : inout Slv4Array(1 downto 0);
      syncInN          : inout Slv4Array(1 downto 0);
      syncOutP         : inout Slv10Array(1 downto 0);
      syncOutN         : inout Slv10Array(1 downto 0);
      -- AMC's Spare Ports
      spareP           : inout Slv16Array(1 downto 0);
      spareN           : inout Slv16Array(1 downto 0);
      -- RTM's Low Speed Ports
      rtmLsP           : inout slv(53 downto 0);
      rtmLsN           : inout slv(53 downto 0);
      -- RTM's High Speed Ports
      rtmHsRxP         : in    sl;
      rtmHsRxN         : in    sl;
      rtmHsTxP         : out   sl;
      rtmHsTxN         : out   sl;
      genClkP          : in    sl;
      genClkN          : in    sl;      
      ----------------
      -- Core Ports --
      ----------------   
      -- Common Fabricate Clock
      fabClkP          : in    sl;
      fabClkN          : in    sl;
      -- RTM Ethernet Ports
      ethRxP           : in    sl;
      ethRxN           : in    sl;
      ethTxP           : out   sl;
      ethTxN           : out   sl;
      xauiClkP         : in    sl;
      xauiClkN         : in    sl;
      -- Backplane MPS Ports
      mpsClkIn         : in    sl;
      mpsClkOut        : out   sl;
      mpsBusRxP        : in    slv(14 downto 1);
      mpsBusRxN        : in    slv(14 downto 1);
      mpsTxP           : out   sl;
      mpsTxN           : out   sl;
      -- LCLS Timing Ports
      timingRxP        : in    sl;
      timingRxN        : in    sl;
      timingTxP        : out   sl;
      timingTxN        : out   sl;
      timingRefClkInP  : in    sl;
      timingRefClkInN  : in    sl;
      timingRecClkOutP : out   sl;
      timingRecClkOutN : out   sl;
      timingClkSel     : out   sl;
      timingClkScl     : inout sl;
      timingClkSda     : inout sl;
      -- Crossbar Ports
      xBarSin          : out   slv(1 downto 0);
      xBarSout         : out   slv(1 downto 0);
      xBarConfig       : out   sl;
      xBarLoad         : out   sl;
      -- Secondary AMC Auxiliary Power Enable Port
      enAuxPwrL        : out   sl;
      -- IPMC Ports
      ipmcScl          : inout sl;
      ipmcSda          : inout sl;
      -- Configuration PROM Ports
      calScl           : inout sl;
      calSda           : inout sl;
      -- DDR3L SO-DIMM Ports
      ddrClkP          : in    sl;
      ddrClkN          : in    sl;
      ddrDm            : out   slv(7 downto 0);
      ddrDqsP          : inout slv(7 downto 0);
      ddrDqsN          : inout slv(7 downto 0);
      ddrDq            : inout slv(63 downto 0);
      ddrA             : out   slv(15 downto 0);
      ddrBa            : out   slv(2 downto 0);
      ddrCsL           : out   slv(1 downto 0);
      ddrOdt           : out   slv(1 downto 0);
      ddrCke           : out   slv(1 downto 0);
      ddrCkP           : out   slv(1 downto 0);
      ddrCkN           : out   slv(1 downto 0);
      ddrWeL           : out   sl;
      ddrRasL          : out   sl;
      ddrCasL          : out   sl;
      ddrRstL          : out   sl;
      ddrAlertL        : in    sl;
      ddrPg            : in    sl;
      ddrPwrEnL        : out   sl;
      ddrScl           : inout sl;
      ddrSda           : inout sl;
      -- SYSMON Ports
      vPIn             : in    sl;
      vNIn             : in    sl);
end TargetTemplate;

architecture top_level of TargetTemplate is

   -- AXI-Lite Interface (regClk domain)
   signal regClk               : sl;
   signal regRst               : sl;
   signal regReadMaster        : AxiLiteReadMasterType;
   signal regReadSlave         : AxiLiteReadSlaveType;
   signal regWriteMaster       : AxiLiteWriteMasterType;
   signal regWriteSlave        : AxiLiteWriteSlaveType;
   -- Timing Interface (timingClk domain) 
   signal timingClk            : sl;
   signal timingRst            : sl;
   signal timingBus            : TimingBusType;
   signal timingPhy            : TimingPhyType;
   signal timingPhyClk         : sl;
   signal timingPhyRst         : sl;
   -- Diagnostic Interface (diagnosticClk domain)
   signal diagnosticClk        : sl;
   signal diagnosticRst        : sl;
   signal diagnosticBus        : DiagnosticBusType;
   --  Waveform interface (waveformClk domain)
   signal waveformClk          : sl;
   signal waveformRst          : sl;
   signal obAppWaveformMasters : WaveformMasterArrayType;
   signal obAppWaveformSlaves  : WaveformSlaveArrayType;
   signal ibAppWaveformMasters : WaveformMasterArrayType;
   signal ibAppWaveformSlaves  : WaveformSlaveArrayType;
   -- Backplane Messaging Interface (bpMsgClk domain)
   signal bpMsgClk             : sl;
   signal bpMsgRst             : sl;
   signal bpMsgBus             : BpMsgBusArray(BP_MSG_SIZE_C-1 downto 0);
   -- Application Debug Interface (ref156MHzClk domain)
   signal obAppDebugMaster     : AxiStreamMasterType;
   signal obAppDebugSlave      : AxiStreamSlaveType;
   signal ibAppDebugMaster     : AxiStreamMasterType;
   signal ibAppDebugSlave      : AxiStreamSlaveType;
   -- BSI Interface (bsiClk domain) 
   signal bsiClk               : sl;
   signal bsiRst               : sl;
   signal bsiBus               : BsiBusType;
   -- MPS Concentrator Interface (ref156MHzClk domain)
   signal mpsObMasters         : AxiStreamMasterArray(14 downto 0);
   signal mpsObSlaves          : AxiStreamSlaveArray(14 downto 0);
   -- Reference Clocks and Resets
   signal recTimingClk         : sl;
   signal recTimingRst         : sl;
   signal ref125MHzClk         : sl;
   signal ref125MHzRst         : sl;
   signal ref156MHzClk         : sl;
   signal ref156MHzRst         : sl;
   signal ref312MHzClk         : sl;
   signal ref312MHzRst         : sl;
   signal ref625MHzClk         : sl;
   signal ref625MHzRst         : sl;
   signal gthFabClk            : sl;
   signal ethPhyReady          : sl;

begin

   U_AppTop : entity work.AppTop
      generic map (
         TPD_G          => TPD_G,
         JESD_RX_LANE_G => (others => 0),
         JESD_TX_LANE_G => (others => 0),
         JESD_REF_SEL_G => (others => DEV_CLK2_SEL_C))
      port map (
         ----------------------
         -- Top Level Interface
         ----------------------
         -- AXI-Lite Interface (regClk domain)
         regClk               => regClk,
         regRst               => regRst,
         regReadMaster        => regReadMaster,
         regReadSlave         => regReadSlave,
         regWriteMaster       => regWriteMaster,
         regWriteSlave        => regWriteSlave,
         -- Timing Interface (timingClk domain) 
         timingClk            => timingClk,
         timingRst            => timingRst,
         timingBus            => timingBus,
         timingPhy            => timingPhy,
         timingPhyClk         => timingPhyClk,
         timingPhyRst         => timingPhyRst,
         -- Diagnostic Interface (diagnosticClk domain)
         diagnosticClk        => diagnosticClk,
         diagnosticRst        => diagnosticRst,
         diagnosticBus        => diagnosticBus,
         -- Waveform interface (waveformClk domain)
         waveformClk          => waveformClk,
         waveformRst          => waveformRst,
         obAppWaveformMasters => obAppWaveformMasters,
         obAppWaveformSlaves  => obAppWaveformSlaves,
         ibAppWaveformMasters => ibAppWaveformMasters,
         ibAppWaveformSlaves  => ibAppWaveformSlaves,
         -- Backplane Messaging Interface (bpMsgClk domain)
         bpMsgClk             => bpMsgClk,
         bpMsgRst             => bpMsgRst,
         bpMsgBus             => bpMsgBus,
         -- Application Debug Interface (ref156MHzClk domain)
         obAppDebugMaster     => obAppDebugMaster,
         obAppDebugSlave      => obAppDebugSlave,
         ibAppDebugMaster     => ibAppDebugMaster,
         ibAppDebugSlave      => ibAppDebugSlave,
         -- BSI Interface (bsiClk domain) 
         bsiClk               => bsiClk,
         bsiRst               => bsiRst,
         bsiBus               => bsiBus,
         -- MPS Concentrator Interface (ref156MHzClk domain)
         mpsObMasters         => mpsObMasters,
         mpsObSlaves          => mpsObSlaves,
         -- Reference Clocks and Resets
         recTimingClk         => recTimingClk,
         recTimingRst         => recTimingRst,
         ref125MHzClk         => ref125MHzClk,
         ref125MHzRst         => ref125MHzRst,
         ref156MHzClk         => ref156MHzClk,
         ref156MHzRst         => ref156MHzRst,
         ref312MHzClk         => ref312MHzClk,
         ref312MHzRst         => ref312MHzRst,
         ref625MHzClk         => ref625MHzClk,
         ref625MHzRst         => ref625MHzRst,
         gthFabClk            => gthFabClk,
         ethPhyReady          => ethPhyReady,
         -----------------------
         -- Application Ports --
         -----------------------
         -- AMC's JESD Ports
         jesdRxP              => jesdRxP,
         jesdRxN              => jesdRxN,
         jesdTxP              => jesdTxP,
         jesdTxN              => jesdTxN,
         jesdClkP             => jesdClkP,
         jesdClkN             => jesdClkN,
         -- AMC's JTAG Ports
         jtagPri              => jtagPri,
         jtagSec              => jtagSec,
         -- AMC's FPGA Clock Ports
         fpgaClkP             => fpgaClkP,
         fpgaClkN             => fpgaClkN,
         -- AMC's System Reference Ports
         sysRefP              => sysRefP,
         sysRefN              => sysRefN,
         -- AMC's Sync Ports
         syncInP              => syncInP,
         syncInN              => syncInN,
         syncOutP             => syncOutP,
         syncOutN             => syncOutN,
         -- AMC's Spare Ports
         spareP               => spareP,
         spareN               => spareN,
         -- RTM's Low Speed Ports
         rtmLsP               => rtmLsP,
         rtmLsN               => rtmLsN,
         -- RTM's High Speed Ports
         rtmHsRxP             => rtmHsRxP,
         rtmHsRxN             => rtmHsRxN,
         rtmHsTxP             => rtmHsTxP,
         rtmHsTxN             => rtmHsTxN,
         genClkP              => genClkP,
         genClkN              => genClkN);

   U_Core : entity work.DebugRtmEthAmcCarrierCore
      generic map (
         TPD_G         => TPD_G,
         DISABLE_BSA_G => true)
      port map (
         ----------------------
         -- Top Level Interface
         ----------------------
         -- AXI-Lite Interface (regClk domain)
         regClk               => regClk,
         regRst               => regRst,
         regReadMaster        => regReadMaster,
         regReadSlave         => regReadSlave,
         regWriteMaster       => regWriteMaster,
         regWriteSlave        => regWriteSlave,
         -- Timing Interface (timingClk domain) 
         timingClk            => timingClk,
         timingRst            => timingRst,
         timingBus            => timingBus,
         timingPhy            => timingPhy,
         timingPhyClk         => timingPhyClk,
         timingPhyRst         => timingPhyRst,
         -- Diagnostic Interface (diagnosticClk domain)
         diagnosticClk        => diagnosticClk,
         diagnosticRst        => diagnosticRst,
         diagnosticBus        => diagnosticBus,
         -- Waveform interface (waveformClk domain)
         waveformClk          => waveformClk,
         waveformRst          => waveformRst,
         obAppWaveformMasters => obAppWaveformMasters,
         obAppWaveformSlaves  => obAppWaveformSlaves,
         ibAppWaveformMasters => ibAppWaveformMasters,
         ibAppWaveformSlaves  => ibAppWaveformSlaves,
         -- Backplane Messaging Interface (bpMsgClk domain)
         bpMsgClk             => bpMsgClk,
         bpMsgRst             => bpMsgRst,
         bpMsgBus             => bpMsgBus,
         -- Application Debug Interface (ref156MHzClk domain)
         obAppDebugMaster     => obAppDebugMaster,
         obAppDebugSlave      => obAppDebugSlave,
         ibAppDebugMaster     => ibAppDebugMaster,
         ibAppDebugSlave      => ibAppDebugSlave,
         -- BSI Interface (bsiClk domain) 
         bsiClk               => bsiClk,
         bsiRst               => bsiRst,
         bsiBus               => bsiBus,
         -- MPS Concentrator Interface (ref156MHzClk domain)
         mpsObMasters         => mpsObMasters,
         mpsObSlaves          => mpsObSlaves,
         -- Reference Clocks and Resets
         recTimingClk         => recTimingClk,
         recTimingRst         => recTimingRst,
         ref125MHzClk         => ref125MHzClk,
         ref125MHzRst         => ref125MHzRst,
         ref156MHzClk         => ref156MHzClk,
         ref156MHzRst         => ref156MHzRst,
         ref312MHzClk         => ref312MHzClk,
         ref312MHzRst         => ref312MHzRst,
         ref625MHzClk         => ref625MHzClk,
         ref625MHzRst         => ref625MHzRst,
         gthFabClk            => gthFabClk,
         ethPhyReady          => ethPhyReady,
         ----------------
         -- Core Ports --
         ----------------   
         -- Common Fabricate Clock
         fabClkP              => fabClkP,
         fabClkN              => fabClkN,
         -- RTM ETH Ports
         ethRxP               => ethRxP,
         ethRxN               => ethRxN,
         ethTxP               => ethTxP,
         ethTxN               => ethTxN,
         xauiClkP             => xauiClkP,
         xauiClkN             => xauiClkN,
         -- Backplane MPS Ports
         mpsClkIn             => mpsClkIn,
         mpsClkOut            => mpsClkOut,
         mpsBusRxP            => mpsBusRxP,
         mpsBusRxN            => mpsBusRxN,
         mpsTxP               => mpsTxP,
         mpsTxN               => mpsTxN,
         -- LCLS Timing Ports
         timingRxP            => timingRxP,
         timingRxN            => timingRxN,
         timingTxP            => timingTxP,
         timingTxN            => timingTxN,
         timingRefClkInP      => timingRefClkInP,
         timingRefClkInN      => timingRefClkInN,
         timingRecClkOutP     => timingRecClkOutP,
         timingRecClkOutN     => timingRecClkOutN,
         timingClkSel         => timingClkSel,
         timingClkScl         => timingClkScl,
         timingClkSda         => timingClkSda,
         -- Crossbar Ports
         xBarSin              => xBarSin,
         xBarSout             => xBarSout,
         xBarConfig           => xBarConfig,
         xBarLoad             => xBarLoad,
         -- Secondary AMC Auxiliary Power Enable Port
         enAuxPwrL            => enAuxPwrL,
         -- IPMC Ports
         ipmcScl              => ipmcScl,
         ipmcSda              => ipmcSda,
         -- Configuration PROM Ports
         calScl               => calScl,
         calSda               => calSda,
         -- DDR3L SO-DIMM Ports
         ddrClkP              => ddrClkP,
         ddrClkN              => ddrClkN,
         ddrDqsP              => ddrDqsP,
         ddrDqsN              => ddrDqsN,
         ddrDm                => ddrDm,
         ddrDq                => ddrDq,
         ddrA                 => ddrA,
         ddrBa                => ddrBa,
         ddrCsL               => ddrCsL,
         ddrOdt               => ddrOdt,
         ddrCke               => ddrCke,
         ddrCkP               => ddrCkP,
         ddrCkN               => ddrCkN,
         ddrWeL               => ddrWeL,
         ddrRasL              => ddrRasL,
         ddrCasL              => ddrCasL,
         ddrRstL              => ddrRstL,
         ddrPwrEnL            => ddrPwrEnL,
         ddrPg                => ddrPg,
         ddrAlertL            => ddrAlertL,
         ddrScl               => ddrScl,
         ddrSda               => ddrSda,
         -- SYSMON Ports
         vPIn                 => vPIn,
         vNIn                 => vNIn);

end top_level;
