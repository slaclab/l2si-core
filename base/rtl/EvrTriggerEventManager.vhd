-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Abstraction interface layer between timing bus trigger/event
-- extension interface and an application that uses triggers and events.
-- Provides programmable trigger delay, event buffering, and flow control
-- feedback.
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

library l2si_core;
use l2si_core.L2SiPkg.all;
use l2si_core.XpmPkg.all;
use l2si_core.XpmExtensionPkg.all;

entity EvrTriggerEventManager is
   generic (
      TPD_G                        : time                 := 1 ns;
      AXIL_BASE_ADDR_G             : slv(31 downto 0)     := (others => '0');
      EVR_CHANNELS_G               : natural              := 1;
      EVR_TRIGGERS_G               : natural range 1 to 8 := 1;
      EVR_TRIG_DEPTH_G             : natural              := 1;
      EVR_TRIG_PIPE_G              : natural              := 0;
      EVENT_AXIS_CONFIG_G          : AxiStreamConfigType  := EVENT_AXIS_CONFIG_C;
      EVENT_CLK_IS_TIMING_RX_CLK_G : boolean              := false);
   port (
      -- Timing Rx interface
      timingRxClk : in  sl;
      timingRxRst : in  sl;
      timingBus   : in  TimingBusType;
      triggerData : out TriggerEventDataArray(EVR_TRIGGERS_G-1 downto 0);

      -- Output Streams
      eventClk         : in  sl;
      eventRst         : in  sl;
      eventAxisMasters : out AxiStreamMasterArray(EVR_TRIGGERS_G-1 downto 0);
      eventAxisSlaves  : in  AxiStreamSlaveArray(EVR_TRIGGERS_G-1 downto 0);
      eventAxisCtrl    : in  AxiStreamCtrlArray(EVR_TRIGGERS_G-1 downto 0);

      -- AXI-Lite
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);

end entity EvrTriggerEventManager;

architecture rtl of EvrTriggerEventManager is

   constant AXIL_MASTERS_C : integer                             := 9;
   constant AXIL_EVR_C     : integer                             := 0;
   constant AXIL_TEB_C     : IntegerArray(0 to EVR_TRIGGERS_G-1) := list(1, EVR_TRIGGERS_G, 1);

   constant AXIL_XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(AXIL_MASTERS_C-1 downto 0) := genAxiLiteConfig(AXIL_MASTERS_C, AXIL_BASE_ADDR_G, 12, 8);

   -- Axi bus sync'd to timingClk
   signal timingAxilReadMaster  : AxiLiteReadMasterType;
   signal timingAxilReadSlave   : AxiLiteReadSlaveType;
   signal timingAxilWriteMaster : AxiLiteWriteMasterType;
   signal timingAxilWriteSlave  : AxiLiteWriteSlaveType;

   -- Fanned out Axi bus
   signal locAxilReadMasters  : AxiLiteReadMasterArray(AXIL_MASTERS_C-1 downto 0);
   signal locAxilReadSlaves   : AxiLiteReadSlaveArray(AXIL_MASTERS_C-1 downto 0)  := (others => AXI_LITE_READ_SLAVE_EMPTY_DECERR_C);
   signal locAxilWriteMasters : AxiLiteWriteMasterArray(AXIL_MASTERS_C-1 downto 0);
   signal locAxilWriteSlaves  : AxiLiteWriteSlaveArray(AXIL_MASTERS_C-1 downto 0) := (others => AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);

   signal evrTriggers : TimingTrigType;


begin



   -----------------------------------------------
   -- Synchronize AXI-Lite bus to timingRxClk
   -----------------------------------------------
   U_AxiLiteAsync_1 : entity surf.AxiLiteAsync
      generic map (
         TPD_G => TPD_G)
      port map (
         sAxiClk         => axilClk,                -- [in]
         sAxiClkRst      => axilRst,                -- [in]
         sAxiReadMaster  => axilReadMaster,         -- [in]
         sAxiReadSlave   => axilReadSlave,          -- [out]
         sAxiWriteMaster => axilWriteMaster,        -- [in]
         sAxiWriteSlave  => axilWriteSlave,         -- [out]
         mAxiClk         => timingRxClk,            -- [in]
         mAxiClkRst      => timingRxRst,            -- [in]
         mAxiReadMaster  => timingAxilReadMaster,   -- [out]
         mAxiReadSlave   => timingAxilReadSlave,    -- [in]
         mAxiWriteMaster => timingAxilWriteMaster,  -- [out]
         mAxiWriteSlave  => timingAxilWriteSlave);  -- [in]

   -----------------------------------------------
   -- Fan out AXI-Lite
   -----------------------------------------------
   U_AxiLiteCrossbar_1 : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => AXIL_XBAR_CONFIG_C)
      port map (
         axiClk              => timingRxClk,            -- [in]
         axiClkRst           => timingRxRst,            -- [in]
         sAxiWriteMasters(0) => timingAxilWriteMaster,  -- [in]
         sAxiWriteSlaves(0)  => timingAxilWriteSlave,   -- [out]
         sAxiReadMasters(0)  => timingAxilReadMaster,   -- [in]
         sAxiReadSlaves(0)   => timingAxilReadSlave,    -- [out]
         mAxiWriteMasters    => locAxilWriteMasters,    -- [out]
         mAxiWriteSlaves     => locAxilWriteSlaves,     -- [in]
         mAxiReadMasters     => locAxilReadMasters,     -- [out]
         mAxiReadSlaves      => locAxilReadSlaves);     -- [in]

   U_EvrV2CoreTriggers_1 : entity lcls_timing_core.EvrV2CoreTriggers
      generic map (
         TPD_G           => TPD_G,
         NCHANNELS_G     => EVR_CHANNELS_G,
         NTRIGGERS_G     => EVR_TRIGGERS_G,
         TRIG_DEPTH_G    => EVR_TRIG_DEPTH_G,
         TRIG_PIPE_G     => EVR_TRIG_PIPE_G,
         COMMON_CLK_G    => true,
         EVR_CARD_G      => false,
         AXIL_BASEADDR_G => AXIL_XBAR_CONFIG_C(AXIL_EVR_C).baseAddr)
      port map (
         axilClk         => timingRxClk,                      -- [in]
         axilRst         => timingRxRst,                      -- [in]
         axilWriteMaster => locAxilWriteMasters(AXIL_EVR_C),  -- [in]
         axilWriteSlave  => locAxilWriteSlaves(AXIL_EVR_C),   -- [out]
         axilReadMaster  => locAxilReadMasters(AXIL_EVR_C),   -- [in]
         axilReadSlave   => locAxilReadSlaves(AXIL_EVR_C),    -- [out]
         evrClk          => timingRxClk,                      -- [in]
         evrRst          => timingRxRst,                      -- [in]
         evrBus          => timingBus,                        -- [in]
         trigOut         => evrTriggers,                      -- [out]
         evrModeSel      => '0');                             -- [in]

   GEN_TRIGGER_EVENT_BUFFERS : for i in EVR_TRIGGERS_G-1 downto 0 generate
      U_EvrTriggerEventBuffer_1 : entity l2si_core.EvrTriggerEventBuffer
         generic map (
            TPD_G                        => TPD_G,
            TRIGGER_INDEX_G              => i,
            EVENT_AXIS_CONFIG_G          => EVENT_AXIS_CONFIG_G,
            EVENT_CLK_IS_TIMING_RX_CLK_G => EVENT_CLK_IS_TIMING_RX_CLK_G)
         port map (
            timingRxClk     => timingRxClk,                         -- [in]
            timingRxRst     => timingRxRst,                         -- [in]
            axilReadMaster  => locAxilReadMasters(AXIL_TEB_C(i)),   -- [in]
            axilReadSlave   => locAxilReadSlaves(AXIL_TEB_C(i)),    -- [out]
            axilWriteMaster => locAxilWriteMasters(AXIL_TEB_C(i)),  -- [in]
            axilWriteSlave  => locAxilWriteSlaves(AXIL_TEB_C(i)),   -- [out]
            evrTriggers     => evrTriggers,                         -- [in]
            triggerData     => triggerData(i),                      -- [out]
            eventClk        => eventClk,                            -- [in]
            eventRst        => eventRst,                            -- [in]
            eventAxisMaster => eventAxisMasters(i),                 -- [out]
            eventAxisSlave  => eventAxisSlaves(i),                  -- [in]
            eventAxisCtrl   => eventAxisCtrl(i));                   -- [in]
   end generate GEN_TRIGGER_EVENT_BUFFERS;


end architecture rtl;
