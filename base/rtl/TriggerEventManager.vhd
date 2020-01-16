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

entity TriggerEventManager is

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

      -- Timing Tx Feedback
      timingTxClk : in  sl;
      timingTxRst : in  sl;
      timingTxPhy : out TimingPhyType;

      -- Triggers 
      triggerClk  : in  sl;
      triggerRst  : in  sl;
      triggerData : out TriggerEventDataArray(NUM_DETECTORS_G-1 downto 0);

      -- L1 trigger feedback
      l1Clk       : in  sl                                                 := '0';
      l1Rst       : in  sl                                                 := '0';
      l1Feedbacks : in  TriggerL1FeedbackArray(NUM_DETECTORS_G-1 downto 0) := (others => TRIGGER_L1_FEEDBACK_INIT_C);
      l1Acks      : out slv(NUM_DETECTORS_G-1 downto 0);

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

end entity TriggerEventManager;

architecture rtl of TriggerEventManager is

   constant AXIL_MASTERS_C : integer                              := 9;
   constant AXIL_ALIGNER_C : integer                              := 0;
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

   -- Trigger message
   signal xpmMessage : XpmMessageType;

   -- Aligner outputs
   signal xpmId                : slv(31 downto 0);
   signal alignedTimingStrobe  : sl;
   signal alignedTimingMessage : TimingMessageType;
   signal alignedXpmMessage    : XpmMessageType;

   -- Event header cache outputs
   signal detectorPartitions : slv3array(NUM_DETECTORS_G-1 downto 0);
   signal full               : slv(NUM_DETECTORS_G-1 downto 0) := (others => '0');
   signal overflow           : slv(NUM_DETECTORS_G-1 downto 0) := (others => '0');


   -----------------------------------------------
   -- SLV conversion constnants, functions and signals for synchronization
   -----------------------------------------------
   constant FB_SYNC_VECTOR_BITS_C : integer := 32 + (3 * NUM_DETECTORS_G) + (2 * NUM_DETECTORS_G);

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
      signal vector             : in  slv(FB_SYNC_VECTOR_BITS_C-1 downto 0);
      signal xpmId              : out slv(31 downto 0);
      signal detectorPartitions : out slv3Array(NUM_DETECTORS_G-1 downto 0);
      signal full               : out slv(NUM_DETECTORS_G-1 downto 0);
      signal overflow           : out slv(NUM_DETECTORS_G-1 downto 0)) is
      variable i           : integer := 0;
      variable xpmIdTmp    : slv(31 downto 0);
      variable dpTmp       : slv3array(NUM_DETECTORS_G-1 downto 0);
      variable fullTmp     : slv(NUM_DETECTORS_G-1 downto 0);
      variable overflowTmp : slv(NUM_DETECTORS_G-1 downto 0);
   begin
      assignRecord(i, vector, xpmIdTmp);
      for j in 0 to NUM_DETECTORS_G-1 loop
         assignRecord(i, vector, dpTmp(j));
      end loop;
      assignRecord(i, vector, fullTmp);
      assignRecord(i, vector, overflowTmp);

      xpmId              <= xpmIdTmp;
      detectorPartitions <= dpTmp;
      full               <= fullTmp;
      overflow           <= overflowTmp;
   end procedure fromSlv;

   signal timingRxtoTimingTxSyncSlvIn  : slv(FB_SYNC_VECTOR_BITS_C-1 downto 0);
   signal timingRxtoTimingTxSyncSlvOut : slv(FB_SYNC_VECTOR_BITS_C-1 downto 0);

   signal xpmIdSync              : slv(31 downto 0);
   signal detectorPartitionsSync : slv3array(NUM_DETECTORS_G-1 downto 0);
   signal fullSync               : slv(NUM_DETECTORS_G-1 downto 0);
   signal overflowSync           : slv(NUM_DETECTORS_G-1 downto 0);

   signal l1FeedbacksSync : XpmL1FeedbackArray(NUM_DETECTORS_G-1 downto 0);
   signal l1AcksTx        : slv(NUM_DETECTORS_G-1 downto 0);


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

   -- Grab and decode the Xpm message from the timing extension bus
   xpmMessage <= toXpmMessageType(timingBus.extension(XPM_STREAM_ID_C));

   -- Align timing message and xpm partition words according to PDELAY broadcasts on xpm bus
   U_XpmMessageAligner_1 : entity l2si_core.XpmMessageAligner
      generic map (
         TPD_G      => TPD_G,
         TF_DELAY_G => 100)
      port map (
         clk                  => timingRxClk,                          -- [in]
         rst                  => timingRxRst,                          -- [in]
         axilReadMaster       => locAxilReadMasters(AXIL_ALIGNER_C),   -- [in]
         axilReadSlave        => locAxilReadSlaves(AXIL_ALIGNER_C),    -- [out]
         axilWriteMaster      => locAxilWriteMasters(AXIL_ALIGNER_C),  -- [in]
         axilWriteSlave       => locAxilWriteSlaves(AXIL_ALIGNER_C),   -- [out]
         xpmId                => xpmId,                                -- [out]
         promptTimingStrobe   => timingBus.strobe,                     -- [in]
         promptTimingMessage  => timingBus.message,                    -- [in]
         promptXpmMessage     => xpmMessage,                           -- [in]
         alignedTimingStrobe  => alignedTimingStrobe,                  -- [out]
         alignedTimingMessage => alignedTimingMessage,                 -- [out]
         alignedXpmMessage    => alignedXpmMessage);                   -- [out]


   GEN_DETECTORS : for i in NUM_DETECTORS_G-1 downto 0 generate
      U_TriggerEventBuffer_1 : entity l2si_core.TriggerEventBuffer
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
            full                 => full(i),                             -- [out]
            overflow             => overflow(i),                         -- [out]
            triggerClk           => triggerClk,                          -- [in]
            triggerRst           => triggerRst,                          -- [in]
            triggerData          => triggerData(i),                      -- [out]
            eventClk             => eventClk,                            -- [in]
            eventRst             => eventRst,                            -- [in]
            eventTimingMessage   => eventTimingMessages(i),              -- [out]
            eventAxisMaster      => eventAxisMasters(i),                 -- [out]
            eventAxisSlave       => eventAxisSlaves(i),                  -- [in]
            eventAxisCtrl        => eventAxisCtrl(i));                   -- [in]
   end generate GEN_DETECTORS;


   -----------------------------------------------
   -- Send almost full and overflow data back upstream
   -----------------------------------------------
   -- Synchronize to transmit clock
   timingRxToTimingTxSyncSlvIn <= toSlv(xpmId, detectorPartitions, full, overflow);
   U_SynchronizerFifo_xpmId : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => false,
         DATA_WIDTH_G => FB_SYNC_VECTOR_BITS_C)
      port map (
         rst    => timingRxRst,                    -- [in]
         wr_clk => timingRxClk,                    -- [in]
         din    => timingRxToTimingTxSyncSlvIn,    -- [in]
         rd_clk => timingTxClk,                    -- [in]
         dout   => timingRxToTimingTxSyncSlvOut);  -- [out]

   conv_slv : process (timingRxToTimingTxSyncSlvOut) is
   begin
      fromSlv(timingRxToTimingTxSyncSlvOut, xpmIdSync, detectorPartitionsSync, fullSync, overflowSync);
   end process conv_slv;

   -----------------------------------------------
   -- Synchronize l1Feedbacks from l1Clk to timingTxClk
   -----------------------------------------------
   l1_sync_gen : for i in 0 to NUM_DETECTORS_G-1 generate
      U_Synchronizer_1 : entity surf.Synchronizer
         generic map (
            TPD_G         => TPD_G,
            BYPASS_SYNC_G => L1_CLK_IS_TIMING_TX_CLK_G,
            STAGES_G      => 3)
         port map (
            clk     => timingTxClk,                -- [in]
            rst     => timingTxRst,                -- [in]
            dataIn  => l1Feedbacks(i).valid,       -- [in]
            dataOut => l1FeedbacksSync(i).valid);  -- [out]

      U_SynchronizerVector : entity surf.SynchronizerVector
         generic map (
            TPD_G         => TPD_G,
            BYPASS_SYNC_G => L1_CLK_IS_TIMING_TX_CLK_G,
            STAGES_G      => 2,
            WIDTH_G       => 18)
         port map (
            clk                  => timingTxClk,              -- [in]
            rst                  => timingTxRst,              -- [in]
            dataIn(3 downto 0)   => l1Feedbacks(i).trigsrc,   -- [in]
            dataIn(8 downto 4)   => l1Feedbacks(i).tag,       -- [in]
            dataIn(17 downto 9)  => l1Feedbacks(i).trigword,  -- [in]                                                            -- 
            dataOut(3 downto 0)  => l1FeedbacksSync(i).trigsrc,    -- [out]
            dataOut(8 downto 4)  => l1FeedbacksSync(i).tag,   -- [out]
            dataOut(17 downto 9) => l1FeedbacksSync(i).trigword);  -- [out]
   end generate l1_sync_gen;  --

   -- Sync l1Acks from timingTxClk to l1Clk
   U_SynchronizerVector_1 : entity surf.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => L1_CLK_IS_TIMING_TX_CLK_G,
         WIDTH_G       => NUM_DETECTORS_G)
      port map (
         clk     => l1Clk,              -- [in]
         rst     => l1Rst,              -- [in]
         dataIn  => l1AcksTx,           -- [in]
         dataOut => l1Acks);            -- [out]

   -- Create upstream message
   U_XpmTimingFb_1 : entity l2si_core.XpmTimingFb
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
         phy                => timingTxPhy);            -- [out]


end architecture rtl;
