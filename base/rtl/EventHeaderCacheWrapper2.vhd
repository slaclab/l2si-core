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
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- surf
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;

-- lcls-timing-core
use work.TimingPkg.all;

-- l2si
use work.L2SiPkg.all;



entity EventHeaderCacheWrapper2 is

   generic (
      TPD_G           : time                 := 1 ns;
      NUM_DETECTORS_G : integer range 1 to 8 := 8);

   port (
      -- Timing Rx interface
      timingRxClk : in sl;
      timingRxRst : in sl;
      timingBus   : in TimingBusType;

      -- Timing Tx Feedback
      timingTxClk : in  sl;
      timingTxRst : in  sl;
      timingPhy   : out TimingPhyType;

      -- Triggers 
      triggerClk : in  sl;
      triggerRst : in  sl;
      triggers   : out ExperimentEventDataArray(NUM_DETECTORS_G-1 downto 0);

      -- L1 trigger feedback
      l1Clk       : in  sl;
      l1Rst       : in  sl;
      l1Feedbacks : in  ExperimentL1FeedbackArray(NUM_DETECTORS_G-1 downto 0);
      l1Acks      : out slv(NUM_DETECTORS_G-1 downto 0);

      -- Output Streams and triggers
      eventClk           : in  sl;
      eventRst           : in  sl;
      eventTimingMessage : out TimingMessageArray(NUM_DETECTORS_G-1 downto 0);
      eventAxisMasters   : out AxiStreamMasterArray(NUM_DETECTORS_G-1 downto 0);
      eventAxisSlaves    : in  AxiStreamSlaveArray(NUM_DETECTORS_G-1 downto 0);
      eventAxisCtrl      : in  AxiStreamCtrlArray(NUM_DETECTORS_G-1 downto 0);

      -- AXI-Lite
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);

end entity EventHeaderCacheWrapper2;

architecture rtl of EventHeaderCacheWrapper2 is

   -----------------------------------------------
   -- SLV conversion functions for synchronization
   -----------------------------------------------
   constant FB_SYNC_VECTOR_BITS_C : integer := 32 + (3 * NUM_DETECTORS_G) + (2 * NUM_DETECTORS_G) - 1 downto 0);
   function toSlv (
      xpmId              : slv(31 downto 0);
      detectorPartitions : slv3Array(NUM_DETECTORS_G-1 downto 0);
      full               : slv(NUM_DETECTORS_G-1 downto 0);
      overflow           : slv(NUM_DETECTORS_G-1 downto 0))
      return slv is

      variable vector : slv(FB_SYNC_VECTOR_BITS_C-1 downto 0) := (others => '0');
      variable i      : integer                               := 0;
   begin
      assignSlv(i, vector, xpmId);
      for j in 0 to NUM_DETECTORS_G-1 loop
         assignSlv(i, vector, detectorPartitions(j));
      end loop;
      assignSlv(i, vector, full);
      assignSlv(i, vector, overflow);
      return vector;
   end function;

   procedure fromSlv (
      vector             : in  slv(FB_SYNC_VECTOR_BITS_C-1 downto 0);
      xpmId              : out slv(31 downto 0);
      detectorPartitions : out slv3Array(NUM_DETECTORS_G-1 downto 0);
      full               : out slv(NUM_DETECTORS_G-1 downto 0);
      overflow           : out slv(NUM_DETECTORS_G-1 downto 0)) is
      variable i : integer := 0;
   begin
      assignRecord(i, vector, xpmId);
      for j in 0 to NUM_DETECTORS_G-1 loop
         assignRecord(i, vector, detectorPartitions(j));
      end loop;
      assignRecord(i, vector, full);
      assignRecord(i, vector, overflow);
   end procedure fromSlv;


begin

   -----------------------------------------------
   -- Synchronize AXI-Lite bus to timingRxClk
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
         mAxiClk         => timingRxClk,            -- [in]
         mAxiClkRst      => timingRxRst,            -- [in]
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

   -- Grab and decode the Experiment message from the timing extension bus
   experimentMessage <= toExperimentMessageType(timingBus.extension(EXPERIMENT_STREAM_ID_C));

   -- Align timing message and experiment partition words according to PDELAY broadcasts on experiment bus
   U_EventRealign_1 : entity work.EventRealign
      generic map (
         TPD_G      => TPD_G,
         TF_DELAY_G => TF_DELAY_G)
      port map (
         clk                      => timingRxClk,                          -- [in]
         rst                      => timingRxRst,                          -- [in]
         axilReadMaster           => locAxilReadMasters(AXIL_REALIGN_C),   -- [in]
         axilReadSlave            => locAxilReadSlaves(AXIL_REALIGN_C),    -- [out]
         axilWriteMaster          => locAxilWriteMasters(AXIL_REALIGN_C),  -- [in]
         axilWriteSlave           => locAxilWriteSlaves(AXIL_REALIGN_C),   -- [out]
         xpmId                    => xpmId,                                -- [out]
         promptTimingStrobe       => timingBus.strobe,                     -- [in]
         promptTimingMessage      => timingBus.message,                    -- [in]
         promptExperimentMessage  => experimentMessage,                    -- [in]
         alignedTimingStrobe      => alignedTimingStrobe,                  -- [out]
         alignedTimingMessage     => alignedTimingMessage,                 -- [out]
         alignedExperimentMessage => alignedExperimentMessage);            -- [out]


   GEN_DETECTORS : for i in NUM_DETECTORS_G-1 downto 0 generate
      U_EventHeaderCache2_1 : entity work.EventHeaderCache2
         generic map (
            TPD_G => TPD_G)
         port map (
            timingRxClk              => timingRxClk,               -- [in]
            timingRxRst              => timingRxRst,               -- [in]
            axilReadMaster           => locAxilReadMasters(i),     -- [in]
            axilReadSlave            => locAxilReadSlaves(i),      -- [out]
            axilWriteMaster          => locAxilWriteMasters(i),    -- [in]
            axilWriteSlave           => locAxilWriteSlaves(i),     -- [out]
            promptTimingStrobe       => timingBus.strobe,          -- [in]            
            promptTimingMessage      => timingBus.message,         -- [in]
            promptExperimentMessage  => experimentMessage,         -- [in]
            alignedTimingstrobe      => alignedTimingStrobe,       -- [in]
            alignedTimingMessage     => alignedTimingMessage       -- [in]
            alignedExperimentMessage => alignedExperimentMessage,  -- [in]
            detectorPartitions       => detectorPartitions(i)      -- [out]
            full                     => full(i),                   -- [out]
            overflow                 => overflow(i),               -- [out]
            triggerClk               => triggerClk,                -- [in]
            triggerRst               => triggerRst,                -- [in]
            triggerData              => triggerData,               -- [out]
            eventClk                 => eventClk,                  -- [in]
            eventRst                 => eventRst,                  -- [in]
            eventAxisMaster          => eventAxisMaster(i),        -- [out]
            eventAxisSlave           => eventAxisSlave(i),         -- [in]
            eventAxisCtrl            => eventAxisCtrl(i));         -- [in]
   end generate GEN_DETECTORS;


   -----------------------------------------------
   -- Send almost full and overflow data back upstream
   -----------------------------------------------
   -- Synchronize to transmit clock
   -- Use 1 wide Synchronizer Fifo
   -- It's nice to keep everything aligned
   timingRxToTimingTxSyncSlvIn <= toSlv(xpmId, detectorPartitions, full, overflow);
   U_SynchronizerFifo_xpmId : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => false,
--         BRAM_EN_G     => BRAM_EN_G,
         DATA_WIDTH_G => FB_SYNC_VECTOR_BITS_C)
      port map (
         rst    => timingRxRst,                    -- [in]
         wr_clk => timingRxClk,                    -- [in]
         din    => timingRxToTimingTxSyncSlvIn,    -- [in]
         rd_clk => timingTxClk,                    -- [in]
         dout   => timingRxToTimingTxSyncSlvOut);  -- [out]

   conv_slv : process () is
   begin
      fromSlv(timingRxToTimingTxSyncSlvOut, xpmIdSync, detectorPartitionsSync, fullSync, overflowSync);
   end process conv_slv;

   l1_sync_gen : for i in 0 to NUM_DETECTORS_G-1 generate
      U_Synchronizer_1 : entity work.Synchronizer
         generic map (
            TPD_G    => TPD_G,
            STAGES_G => 3)
         port map (
            clk     => timingTxClk,                -- [in]
            rst     => timingTxRst,                -- [in]
            dataIn  => l1Feedbacks(i).valid,       -- [in]
            dataOut => l1FeedbacksSync(i).valid);  -- [out]

      U_SynchronizerVector : entity work.SynchronizerVector
         generic map (
            TPD_G        => TPD_G,
            COMMON_CLK_G => false,
            STAGES_G     => 2,
            DATA_WIDTH_G => 17)
         port map (
            clk                 => timingTxClk,                   -- [in]
            rst                 => timingTxRst,                   -- [in]
            dataIn(3 downto 0)  => l1Feedbacks(i).trigsrc,        -- [in]
            dataIn(8 downto 4)  => l1Feedbacks(i).tag,            -- [in]
            dataIn(17 downto 9) => l1Feedbacks(i).trigword,       -- [in]                                                            -- 
            dout(3 downto 0)    => l1FeedbacksSync(i).trigsrc,    -- [out]
            dout(8 downto 4)    => l1FeedbacksSync(i).tag,        -- [out]
            dout(17 downto 9)   => l1FeedbacksSync(i).trigword);  -- [out]

   end generate l1_sync_gen;  --


   -- Sync l1Acks from timingTxClk to l1Clk
   U_SynchronizerVector_1 : entity work.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => BYPASS_SYNC_G,
         WIDTH_G       => NUM_DETECTORS_G)
      port map (
         clk     => l1Clk,              -- [in]
         rst     => l1Rst,              -- [in]
         dataIn  => l1AcksTx,           -- [in]
         dataOut => l1Acks);            -- [out]

   -- Create upstream message
   U_XpmTimingFb_1 : entity work.XpmTimingFb
      generic map (
         TPD_G           => TPD_G,
         NUM_DETECTORS_G => NUM_DETECTORS_G)
      port map (
         clk                => timingTxClk,             -- [in]
         rst                => timingTxRst,             -- [in]
         id                 => xpmIdSync,               -- [in]
         detectorPartitions => detectorPartitionsSync,  -- [in]
         full               => fullSync,                -- [in]
         overflow           => overflowSync,            -- [in]
         l1Feedbacks        => l1FeedbacksSync,         -- [in]
         l1Acks             => l1AcksTx,                -- [out]
         phy                => timingPhy);              -- [out]


end architecture rtl;
