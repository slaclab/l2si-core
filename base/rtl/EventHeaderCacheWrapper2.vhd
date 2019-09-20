-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: I don't even know
-------------------------------------------------------------------------------
-- This file is part of L2SI. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of L2Si, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

entity EventHeaderCacheWrapper2 is

   generic (
      TPD_G           : time                 := 1 ns;
      NUM_DETECTORS_G : integer range 1 to 8 := 8);

   port (
      -- Timing Rx interface
      timingClk  : in sl;
      timingRst  : in sl;
      timingBus  : in TimingBusType;
      timingMode : in sl;
      userTiming : in slv(255 downto 0);  -- Extra timing bus bits to cache

      -- Output Streams and triggers
      eventClk         : in  sl;
      eventRst         : in  sl;
      eventAxisMasters : out AxiStreamMasterArray(NUM_DETECTORS_G-1 downto 0);
      eventAxisSlaves  : in  AxiStreamSlaveArray(NUM_DETECTORS_G-1 downto 0);
      eventAxisCtrl    : in  AxiStreamCtrlArray(NUM_DETECTORS_G-1 downto 0);

      triggerStrobes : out slv(NUM_DETECTORS_G-1 downto 0);

      -- Timing output
      timingPhy : out TimingPhyType;

      -- AXI-Lite
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);

end entity EventHeaderCacheWrapper2;

architecture rtl of EventHeaderCacheWrapper2 is

begin

   -----------------------------------------------
   -- Synchronize AXI-Lite bus to timingClk
   -----------------------------------------------
   U_AxiLiteAsync_1 : entity work.AxiLiteAsync
      generic map (
         TPD_G => TPD_G)
      port map (
         sAxiClk         => axilClk,                -- [in]
         sAxiClkRst      => axilClkRst,             -- [in]
         sAxiReadMaster  => axilReadMaster,         -- [in]
         sAxiReadSlave   => axilReadSlave,          -- [out]
         sAxiWriteMaster => axilWriteMaster,        -- [in]
         sAxiWriteSlave  => axilWriteSlave,         -- [out]
         mAxiClk         => timingClk,              -- [in]
         mAxiClkRst      => timingRst,              -- [in]
         mAxiReadMaster  => timingAxilReadMaster,   -- [out]
         mAxiReadSlave   => timingAxilReadSlave,    -- [in]
         mAxiWriteMaster => timingAxilWriteMaster,  -- [out]
         mAxiWriteSlave  => timingAxilWriteSlave);  -- [in]

   -----------------------------------------------
   -- Fan out AXI-Lite to each EventHeaderCache
   -----------------------------------------------
   U_AxiLiteCrossbar_1 : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => AXIL_XBAR_CONFIG_C)
      port map (
         axiClk              => timingClk,              -- [in]
         axiClkRst           => timingRst,              -- [in]
         sAxiWriteMasters(0) => timingAxilWriteMaster,  -- [in]
         sAxiWriteSlaves(0)  => timingAxilWriteSlave,   -- [out]
         sAxiReadMasters(0)  => timingAxilReadMaster,   -- [in]
         sAxiReadSlaves(0)   => timingAxilReadSlave,    -- [out]
         mAxiWriteMasters    => locAxilWriteMasters,    -- [out]
         mAxiWriteSlaves     => locAxilWriteSlaves,     -- [in]
         mAxiReadMasters     => locAxilReadMasters,     -- [out]
         mAxiReadSlaves      => locAxilReadSlaves);     -- [in]

   -- Grab strobe, pulseId and timestamp from timing bus
   timingHeader <= toTimingHeader(timingBus);

   -- Grab and decode the Experiment message from the timing extension bus
   experimentMessage <= toExperimentMessageType(timingBus.extension(EXPERIMENT_STREAM_ID_C));

   -- Align timing header and exptBus partition words according to PDELAY broadcasts on exptBus
   U_Realign : entity work.EventRealign
      generic map (
         TPD_G => TPD_G)
      port map (
         clk                      => timingClk,
         rst                      => timingRst,
         promptTimingHeader       => timingHeader,
         promptExperimentMessage  => experimentMessage,
         alignedTimingHeader      => alignedTimingHeader,
         alignedExperimentMessage => alignedExperimentMessage,
         partitionDelays          => partitionDelays);

   GEN_DETECTORS : for i in NUM_DETECTORS_G-1 downto 0 generate

      -- Align user timing data
      -- This needs to push down into EventHeaderCache because that's where the
      -- partition number configuration will be stored
--       U_UserRealign_1: entity work.UserRealign
--          generic map (
--             TPD_G   => TPD_G,
--             WIDTH_G => WIDTH_G)
--          port map (
--             rst               => rst,                 -- [in]
--             clk               => clk,                 -- [in]
--             delay             => ,               -- [in]
--             timingHeader      => timingHeader,        -- [in]
--             userTiming        => userTiming,          -- [in]
--             alignedUserTiming => alignedUserTiming);  -- [out]

      U_EventHeaderCache2_1 : entity work.EventHeaderCache2
         generic map (
            TPD_G => TPD_G)
         port map (
            timingClk               => timingClk,                -- [in]
            timingRst               => timingRst,                -- [in]
            axilReadMaster          => locAxilReadMasters(i),    -- [in]
            axilReadSlave           => locAxilReadSlaves(i),     -- [out]
            axilWriteMaster         => locAxilWriteMasters(i),   -- [in]
            axilWriteSlave          => locAxilWriteSlaves(i),    -- [out]
            promptTimingHeader      => promptTimingHeader,       -- [in]
            promptExperimentMessage => promptExperimentMessage,  -- [in]
            alignedTimingHeader     => alignedTimingHeader,      -- [in]
            alignedExperimentBus    => alignedExperimentBus,     -- [in]
            almostFull              => almostFull(i),            -- [out]
            overflow                => overflow(i),              -- [out]
            triggerData             => triggerData,              -- [out]
            eventClk                => eventClk,                 -- [in]
            eventRst                => eventRst,                 -- [in]
            eventAxisMaster         => eventAxisMaster(i),       -- [out]
            eventAxisSlave          => eventAxisSlave(i),        -- [in]
            eventAxisCtrl           => eventAxisCtrl(i));        -- [in]

      -- Create an EventHeaderCache Trigger delay unit for each detector


   end generate GEN_DETECTORS;

end architecture rtl;
