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

-- surf

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;

-- lcls-timing-core

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

-- l2si

library l2si_core;
use l2si_core.L2SiPkg.all;
use l2si_core.XpmPkg.all;
use l2si_core.XpmExtensionPkg.all;

entity EvrTriggerEventManager is

   generic (
      TPD_G                          : time                 := 1 ns;
      NUM_DETECTORS_G                : integer range 1 to 8 := 8;
      AXIL_BASE_ADDR_G               : slv(31 downto 0)     := (others => '0');
      EVENT_AXIS_CONFIG_G            : AxiStreamConfigType  := EVENT_AXIS_CONFIG_C;
      L1_CLK_IS_TIMING_TX_CLK_G      : boolean              := false;
      TRIGGER_CLK_IS_TIMING_RX_CLK_G : boolean              := false;
      EVENT_CLK_IS_TIMING_RX_CLK_G   : boolean              := false);
   port (
      -- Timing Rx interface
      timingRxClk : in sl;
      timingRxRst : in sl;
      timingBus   : in TimingBusType;

      -- Triggers 
      triggerClk  : in  sl;
      triggerRst  : in  sl;
      triggerData : out TriggerEventDataArray(NUM_DETECTORS_G-1 downto 0);

      -- Output Streams
      eventClk            : in  sl;
      eventRst            : in  sl;
      eventTimingMessages : out TimingMessageArray(NUM_DETECTORS_G-1 downto 0);
      eventAxisMasters    : out AxiStreamMasterArray(NUM_DETECTORS_G-1 downto 0);
      eventAxisSlaves     : in  AxiStreamSlaveArray(NUM_DETECTORS_G-1 downto 0);
      eventAxisCtrl       : in  AxiStreamCtrlArray(NUM_DETECTORS_G-1 downto 0);

      -- AXI-Lite
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);

end entity EvrTriggerEventManager;

architecture rtl of EvrTriggerEventManager is

   constant AXIL_MASTERS_C : integer                              := 9;
   constant AXIL_TEB_C     : IntegerArray(0 to NUM_DETECTORS_G-1) := list(1, NUM_DETECTORS_G, 1);

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


   GEN_DETECTORS : for i in NUM_DETECTORS_G-1 downto 0 generate
      U_TriggerEventBuffer_1 : entity l2si_core.EvrTriggerEventBuffer
         generic map (
            TPD_G                          => TPD_G,
            EVENT_AXIS_CONFIG_G            => EVENT_AXIS_CONFIG_G,
            TRIGGER_CLK_IS_TIMING_RX_CLK_G => TRIGGER_CLK_IS_TIMING_RX_CLK_G,
            EVENT_CLK_IS_TIMING_RX_CLK_G   => EVENT_CLK_IS_TIMING_RX_CLK_G)
         port map (
            timingRxClk          => timingRxClk,                         -- [in]
            timingRxRst          => timingRxRst,                         -- [in]
            axilReadMaster       => locAxilReadMasters(AXIL_TEB_C(i)),   -- [in]
            axilReadSlave        => locAxilReadSlaves(AXIL_TEB_C(i)),    -- [out]
            axilWriteMaster      => locAxilWriteMasters(AXIL_TEB_C(i)),  -- [in]
            axilWriteSlave       => locAxilWriteSlaves(AXIL_TEB_C(i)),   -- [out]
            promptTimingStrobe   => timingBus.strobe,                    -- [in]            
            promptTimingMessage  => timingBus.message,                   -- [in]
            promptXpmMessage     => xpmMessage,                          -- [in]
            alignedTimingstrobe  => alignedTimingStrobe,                 -- [in]
            alignedTimingMessage => alignedTimingMessage,                -- [in]
            alignedXpmMessage    => alignedXpmMessage,                   -- [in]
            partition            => detectorPartitions(i),               -- [out]
            pause                => pause(i),                            -- [out]
            overflow             => overflow(i),                         -- [out]
            triggerClk           => triggerClk,                          -- [in]
            triggerRst           => triggerRst,                          -- [in]
            triggerData          => triggerData(i),                      -- [out]
            eventClk             => eventClk,                            -- [in]
            eventRst             => eventRst,                            -- [in]
            eventTimingMessage   => eventTimingMessages(i),              -- [out]
            eventAxisMaster      => eventAxisMasters(i),                 -- [out]
            eventAxisSlave       => eventAxisSlaves(i),                  -- [in]
            eventAxisCtrl        => eventAxisCtrl(i),                    -- [in]
            clearReadout         => clearReadout(i));                    -- [out]      
   end generate GEN_DETECTORS;



end architecture rtl;
