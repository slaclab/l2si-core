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

entity TriggerEventManager is
   generic (
      TPD_G                          : time                 := 1 ns;
      EN_LCLS_I_TIMING_G             : boolean              := false;
      EN_LCLS_II_TIMING_G            : boolean              := true;
      EN_LCLS_II_INHIBIT_COUNTS_G    : boolean              := false;
      NUM_DETECTORS_G                : integer range 1 to 8 := 8;
      AXIL_BASE_ADDR_G               : slv(31 downto 0)     := (others => '0');
      EVENT_AXIS_CONFIG_G            : AxiStreamConfigType  := EVENT_AXIS_CONFIG_C;
      AXIL_CLK_IS_TIMING_RX_CLK_G    : boolean              := false;
      L1_CLK_IS_TIMING_TX_CLK_G      : boolean              := false;
      TRIGGER_CLK_IS_TIMING_RX_CLK_G : boolean              := false;
      EVENT_CLK_IS_TIMING_RX_CLK_G   : boolean              := false;
      TRIGGER_PIPELINE_DEPTH_G       : integer              := 0);
   port (
      -- Timing Rx interface
      timingRxClk : in sl;
      timingRxRst : in sl;

      timingBus  : in TimingBusType;
      timingMode : in sl;

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
      eventClk                 : in  sl;
      eventRst                 : in  sl;
      eventTimingMessagesValid : out slv(NUM_DETECTORS_G-1 downto 0);
      eventTimingMessages      : out TimingMessageArray(NUM_DETECTORS_G-1 downto 0);
      eventTimingMessagesRd    : in  slv(NUM_DETECTORS_G-1 downto 0) := (others => '1');
      eventInhibitCountsValid  : out slv(NUM_DETECTORS_G-1 downto 0);
      eventInhibitCounts       : out TriggerInhibitCountsArray(NUM_DETECTORS_G-1 downto 0);
      eventInhibitCountsRd     : in  slv(NUM_DETECTORS_G-1 downto 0) := (others => '1');
      eventAxisMasters         : out AxiStreamMasterArray(NUM_DETECTORS_G-1 downto 0);
      eventAxisSlaves          : in  AxiStreamSlaveArray(NUM_DETECTORS_G-1 downto 0);
      eventAxisCtrl            : in  AxiStreamCtrlArray(NUM_DETECTORS_G-1 downto 0);
      clearReadout             : out slv(NUM_DETECTORS_G-1 downto 0);

      -- AXI-Lite
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);

end entity TriggerEventManager;

architecture rtl of TriggerEventManager is

   constant AXIL_MASTERS_C : integer                              := 10;
   constant AXIL_EVR_C     : integer                              := 0;
   constant AXIL_ALIGNER_C : integer                              := 1;
   constant AXIL_TEB_0_C   : integer                              := 2;
   constant AXIL_TEB_1_C   : integer                              := 3;
   constant AXIL_TEB_2_C   : integer                              := 4;
   constant AXIL_TEB_3_C   : integer                              := 5;
   constant AXIL_TEB_4_C   : integer                              := 6;
   constant AXIL_TEB_5_C   : integer                              := 7;
   constant AXIL_TEB_6_C   : integer                              := 8;
   constant AXIL_TEB_7_C   : integer                              := 9;
   constant AXIL_TEB_C     : IntegerArray(0 to NUM_DETECTORS_G-1) := list(2, NUM_DETECTORS_G, 1);

   constant AXIL_XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(0 to AXIL_MASTERS_C-1) := (
      AXIL_EVR_C      => (
         baseAddr     => AXIL_BASE_ADDR_G,
         addrBits     => 15,
         connectivity => x"FFFF"),
      AXIL_ALIGNER_C  => (
         baseAddr     => AXIL_BASE_ADDR_G + X"8000",
         addrBits     => 8,
         connectivity => X"FFFF"),
      AXIL_TEB_0_C    => (
         baseAddr     => AXIL_BASE_ADDR_G + X"9000",
         addrBits     => 8,
         connectivity => X"FFFF"),
      AXIL_TEB_1_C    => (
         baseAddr     => AXIL_BASE_ADDR_G + X"9100",
         addrBits     => 8,
         connectivity => X"FFFF"),
      AXIL_TEB_2_C    => (
         baseAddr     => AXIL_BASE_ADDR_G + X"9200",
         addrBits     => 8,
         connectivity => X"FFFF"),
      AXIL_TEB_3_C    => (
         baseAddr     => AXIL_BASE_ADDR_G + X"9300",
         addrBits     => 8,
         connectivity => X"FFFF"),
      AXIL_TEB_4_C    => (
         baseAddr     => AXIL_BASE_ADDR_G + X"9400",
         addrBits     => 8,
         connectivity => X"FFFF"),
      AXIL_TEB_5_C    => (
         baseAddr     => AXIL_BASE_ADDR_G + X"9500",
         addrBits     => 8,
         connectivity => X"FFFF"),
      AXIL_TEB_6_C    => (
         baseAddr     => AXIL_BASE_ADDR_G + X"9600",
         addrBits     => 8,
         connectivity => X"FFFF"),
      AXIL_TEB_7_C    => (
         baseAddr     => AXIL_BASE_ADDR_G + X"9700",
         addrBits     => 8,
         connectivity => X"FFFF"));

   -- Fanned out Axi bus
   signal locAxilReadMasters  : AxiLiteReadMasterArray(AXIL_MASTERS_C-1 downto 0);
   signal locAxilReadSlaves   : AxiLiteReadSlaveArray(AXIL_MASTERS_C-1 downto 0)  := (others => AXI_LITE_READ_SLAVE_EMPTY_DECERR_C);
   signal locAxilWriteMasters : AxiLiteWriteMasterArray(AXIL_MASTERS_C-1 downto 0);
   signal locAxilWriteSlaves  : AxiLiteWriteSlaveArray(AXIL_MASTERS_C-1 downto 0) := (others => AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);

   -- Trigger message
   signal xpmMessage  : XpmMessageType := XPM_MESSAGE_INIT_C;
   signal evrTriggers : TimingTrigType := TIMING_TRIG_INIT_C;

   -- Aligner outputs
   signal xpmId                : slv(31 downto 0)  := (others => '0');
   signal alignedTimingStrobe  : sl                := '0';
   signal alignedTimingMessage : TimingMessageType := TIMING_MESSAGE_INIT_C;
   signal alignedXpmMessage    : XpmMessageType    := XPM_MESSAGE_INIT_C;

   -- Event header cache outputs
   signal detectorPartitions : slv3array(NUM_DETECTORS_G-1 downto 0) := (others => (others => '0'));
   signal pause              : slv(NUM_DETECTORS_G-1 downto 0)       := (others => '0');
   signal overflow           : slv(NUM_DETECTORS_G-1 downto 0)       := (others => '0');


   -----------------------------------------------
   -- SLV conversion constnants, functions and signals for synchronization
   -----------------------------------------------
   constant FB_SYNC_VECTOR_BITS_C : integer := 32 + (3 * NUM_DETECTORS_G) + (2 * NUM_DETECTORS_G);

   function toSlv (
      xpmId              : slv(31 downto 0);
      detectorPartitions : slv3Array(NUM_DETECTORS_G-1 downto 0);
      pause              : slv(NUM_DETECTORS_G-1 downto 0);
      overflow           : slv(NUM_DETECTORS_G-1 downto 0))
      return slv is

      variable vector : slv(FB_SYNC_VECTOR_BITS_C-1 downto 0) := (others => '0');
      variable i      : integer                               := 0;
   begin
      assignSlv(i, vector, xpmId);
      for j in 0 to NUM_DETECTORS_G-1 loop
         assignSlv(i, vector, detectorPartitions(j));
      end loop;
      assignSlv(i, vector, pause);
      assignSlv(i, vector, overflow);
      return vector;
   end function;

   procedure fromSlv (
      signal vector             : in  slv(FB_SYNC_VECTOR_BITS_C-1 downto 0);
      signal xpmId              : out slv(31 downto 0);
      signal detectorPartitions : out slv3Array(NUM_DETECTORS_G-1 downto 0);
      signal pause              : out slv(NUM_DETECTORS_G-1 downto 0);
      signal overflow           : out slv(NUM_DETECTORS_G-1 downto 0)) is
      variable i           : integer := 0;
      variable xpmIdTmp    : slv(31 downto 0);
      variable dpTmp       : slv3array(NUM_DETECTORS_G-1 downto 0);
      variable pauseTmp    : slv(NUM_DETECTORS_G-1 downto 0);
      variable overflowTmp : slv(NUM_DETECTORS_G-1 downto 0);
   begin
      assignRecord(i, vector, xpmIdTmp);
      for j in 0 to NUM_DETECTORS_G-1 loop
         assignRecord(i, vector, dpTmp(j));
      end loop;
      assignRecord(i, vector, pauseTmp);
      assignRecord(i, vector, overflowTmp);

      xpmId              <= xpmIdTmp;
      detectorPartitions <= dpTmp;
      pause              <= pauseTmp;
      overflow           <= overflowTmp;
   end procedure fromSlv;

   signal timingRxtoTimingTxSyncSlvIn  : slv(FB_SYNC_VECTOR_BITS_C-1 downto 0);
   signal timingRxtoTimingTxSyncSlvOut : slv(FB_SYNC_VECTOR_BITS_C-1 downto 0);

   signal xpmIdSync              : slv(31 downto 0);
   signal detectorPartitionsSync : slv3array(NUM_DETECTORS_G-1 downto 0);
   signal pauseSync              : slv(NUM_DETECTORS_G-1 downto 0);
   signal overflowSync           : slv(NUM_DETECTORS_G-1 downto 0);

   signal partitionsPause    : slv(XPM_PARTITIONS_C-1 downto 0);
   signal partitionsOverflow : slv(XPM_PARTITIONS_C-1 downto 0);

   constant L1_AXI_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 4,
      TDEST_BITS_C  => 4,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 0,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   signal l1Masters    : AxiStreamMasterArray(NUM_DETECTORS_G-1 downto 0) := (others => axiStreamMasterInit(L1_AXI_CONFIG_C));
   signal l1Slaves     : AxiStreamSlaveArray (NUM_DETECTORS_G-1 downto 0);
   signal l1Master     : AxiStreamMasterType;
   signal l1MasterSync : AxiStreamMasterType;
   signal l1Slave      : AxiStreamSlaveType;
   signal l1SlaveSync  : AxiStreamSlaveType;
   signal l1Feedback   : XpmL1FeedbackType;

begin

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
         axiClk              => axilClk,              -- [in]
         axiClkRst           => axilRst,              -- [in]
         sAxiWriteMasters(0) => axilWriteMaster,      -- [in]
         sAxiWriteSlaves(0)  => axilWriteSlave,       -- [out]
         sAxiReadMasters(0)  => axilReadMaster,       -- [in]
         sAxiReadSlaves(0)   => axilReadSlave,        -- [out]
         mAxiWriteMasters    => locAxilWriteMasters,  -- [out]
         mAxiWriteSlaves     => locAxilWriteSlaves,   -- [in]
         mAxiReadMasters     => locAxilReadMasters,   -- [out]
         mAxiReadSlaves      => locAxilReadSlaves);   -- [in]

   -------------------------------------------------------------------------------------------------
   -- LCLS-I timing uses EvrV2CoreTrigers to decode triggers from the EVR timing stream
   -- LCLS-II timing uses EvrV2CoreTrigers to decode triggers from the LCLS-II timing stream
   -------------------------------------------------------------------------------------------------
   U_EvrV2CoreTriggers_1 : entity lcls_timing_core.EvrV2CoreTriggers
      generic map (
         TPD_G           => TPD_G,
         NCHANNELS_G     => NUM_DETECTORS_G,
         NTRIGGERS_G     => NUM_DETECTORS_G,
         TRIG_DEPTH_G    => 28,
         TRIG_PIPE_G     => TRIGGER_PIPELINE_DEPTH_G,
         COMMON_CLK_G    => AXIL_CLK_IS_TIMING_RX_CLK_G,
         EVR_CARD_G      => false,
         AXIL_BASEADDR_G => AXIL_XBAR_CONFIG_C(AXIL_EVR_C).baseAddr)
      port map (
         axilClk         => axilClk,                          -- [in]
         axilRst         => axilRst,                          -- [in]
         axilWriteMaster => locAxilWriteMasters(AXIL_EVR_C),  -- [in]
         axilWriteSlave  => locAxilWriteSlaves(AXIL_EVR_C),   -- [out]
         axilReadMaster  => locAxilReadMasters(AXIL_EVR_C),   -- [in]
         axilReadSlave   => locAxilReadSlaves(AXIL_EVR_C),    -- [out]
         evrClk          => timingRxClk,                      -- [in]
         evrRst          => timingRxRst,                      -- [in]
         evrBus          => timingBus,                        -- [in]
         trigOut         => evrTriggers,                      -- [out]
         evrModeSel      => timingMode);                      -- [in]

   -------------------------------------------------------------------------------------------------
   -- LCLS-II uses the XPM extension stream
   -------------------------------------------------------------------------------------------------
   -- Grab and decode the Xpm message from the timing extension bus
   xpmMessage <= toXpmMessageType(timingBus.extension(XPM_STREAM_ID_C));

   -- Align timing message and xpm partition words according to PDELAY broadcasts on xpm bus
   XPM_ALIGN_GEN : if (EN_LCLS_II_TIMING_G) generate
      U_XpmMessageAligner_1 : entity l2si_core.XpmMessageAligner
         generic map (
            TPD_G        => TPD_G,
            COMMON_CLK_G => AXIL_CLK_IS_TIMING_RX_CLK_G,
            TF_DELAY_G   => 100)
         port map (
            timingRxClk          => timingRxClk,                          -- [in]
            timingRxRst          => timingRxRst,                          -- [in]
            axilClk              => axilClk,                              -- [in]
            axilRst              => axilRst,                              -- [in]
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
   end generate;

   -------------------------------------------------------------------------------------------------
   -- TriggerEventBuffers create a stream of EventHeader message for each trigger/detector
   -------------------------------------------------------------------------------------------------
   GEN_DETECTORS : for i in NUM_DETECTORS_G-1 downto 0 generate
      U_TriggerEventBuffer_1 : entity l2si_core.TriggerEventBuffer
         generic map (
            TPD_G                          => TPD_G,
            TRIGGER_INDEX_G                => i,
            EN_LCLS_I_TIMING_G             => EN_LCLS_I_TIMING_G,
            EN_LCLS_II_TIMING_G            => EN_LCLS_II_TIMING_G,
            EN_LCLS_II_INHIBIT_COUNTS_G    => EN_LCLS_II_INHIBIT_COUNTS_G,
            EVENT_AXIS_CONFIG_G            => EVENT_AXIS_CONFIG_G,
            AXIL_CLK_IS_TIMING_RX_CLK_G    => AXIL_CLK_IS_TIMING_RX_CLK_G,
            TRIGGER_CLK_IS_TIMING_RX_CLK_G => TRIGGER_CLK_IS_TIMING_RX_CLK_G,
            EVENT_CLK_IS_TIMING_RX_CLK_G   => EVENT_CLK_IS_TIMING_RX_CLK_G)
         port map (
            timingRxClk             => timingRxClk,                         -- [in]
            timingRxRst             => timingRxRst,                         -- [in]
            axilClk                 => axilClk,                             -- [in]
            axilRst                 => axilRst,                             -- [in]
            axilReadMaster          => locAxilReadMasters(AXIL_TEB_C(i)),   -- [in]
            axilReadSlave           => locAxilReadSlaves(AXIL_TEB_C(i)),    -- [out]
            axilWriteMaster         => locAxilWriteMasters(AXIL_TEB_C(i)),  -- [in]
            axilWriteSlave          => locAxilWriteSlaves(AXIL_TEB_C(i)),   -- [out]
            timingMode              => timingMode,                          -- [in]
            evrTriggers             => evrTriggers,                         -- [out]
            promptTimingStrobe      => timingBus.strobe,                    -- [in]
            promptTimingMessage     => timingBus.message,                   -- [in]
            promptXpmMessage        => xpmMessage,                          -- [in]
            alignedTimingstrobe     => alignedTimingStrobe,                 -- [in]
            alignedTimingMessage    => alignedTimingMessage,                -- [in]
            alignedXpmMessage       => alignedXpmMessage,                   -- [in]
            partition               => detectorPartitions(i),               -- [out]
            pause                   => pause(i),                            -- [out]
            overflow                => overflow(i),                         -- [out]
            triggerClk              => triggerClk,                          -- [in]
            triggerRst              => triggerRst,                          -- [in]
            triggerData             => triggerData(i),                      -- [out]
            eventClk                => eventClk,                            -- [in]
            eventRst                => eventRst,                            -- [in]
            eventTimingMessageValid => eventTimingMessagesValid(i),         -- [out]
            eventTimingMessage      => eventTimingMessages(i),              -- [out]
            eventTimingMessageRd    => eventTimingMessagesRd(i),            -- [in]
            eventInhibitCountsValid => eventInhibitCountsValid(i),          -- [out]
            eventInhibitCounts      => eventInhibitCounts(i),               -- [out]
            eventInhibitCountsRd    => eventInhibitCountsRd(i),             -- [in]
            eventAxisMaster         => eventAxisMasters(i),                 -- [out]
            eventAxisSlave          => eventAxisSlaves(i),                  -- [in]
            eventAxisCtrl           => eventAxisCtrl(i),                    -- [in]
            clearReadout            => clearReadout(i));                    -- [out]
   end generate GEN_DETECTORS;


   GEN_XPM_FB : if (EN_LCLS_II_TIMING_G) generate
      -----------------------------------------------
      -- Send pause and overflow data back upstream if EN_LCLS_II_TIMING_G
      -----------------------------------------------
      -- Synchronize to transmit clock
      timingRxToTimingTxSyncSlvIn <= toSlv(xpmId, detectorPartitions, pause, overflow);
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
         fromSlv(timingRxToTimingTxSyncSlvOut, xpmIdSync, detectorPartitionsSync, pauseSync, overflowSync);
      end process conv_slv;

      ------------------------------------------------------------------
      -- Arbitrate and synchronize l1Feedbacks from l1Clk to timingTxClk
      ------------------------------------------------------------------

      l1_sync_gen : for i in 0 to NUM_DETECTORS_G-1 generate
         l1Masters(i).tData(toSlv(XPM_L1_FEEDBACK_INIT_C)'range) <= toSlv(l1Feedbacks(i));
         l1Masters(i).tValid                                     <= l1Feedbacks(i).valid;
         l1Masters(i).tLast                                      <= '1';
         l1Acks (i)                                              <= l1Slaves(i).tReady;
      end generate;

      U_L1_Mux : entity surf.AxiStreamMux
         generic map (
            TPD_G        => TPD_G,
            NUM_SLAVES_G => NUM_DETECTORS_G)
         port map (
            axisClk      => l1Clk,
            axisRst      => l1Rst,
            sAxisMasters => l1Masters,
            sAxisSlaves  => l1Slaves,
            mAxisMaster  => l1Master,
            mAxisSlave   => l1Slave);

      -- only crossing clock domains
      U_L1_Fifo : entity surf.AxiStreamFifoV2
         generic map (
            TPD_G               => TPD_G,
            GEN_SYNC_FIFO_G     => L1_CLK_IS_TIMING_TX_CLK_G,
            SLAVE_AXI_CONFIG_G  => L1_AXI_CONFIG_C,
            MASTER_AXI_CONFIG_G => L1_AXI_CONFIG_C)
         port map (
            sAxisClk    => l1Clk,
            sAxisRst    => l1Rst,
            sAxisMaster => l1Master,
            sAxisSlave  => l1Slave,
            mAxisClk    => timingTxClk,
            mAxisRst    => timingTxRst,
            mAxisMaster => l1MasterSync,
            mAxisSlave  => l1SlaveSync);

      partitions : process (detectorPartitionsSync, pauseSync, overflowSync) is
      begin
         partitionsPause    <= (others => '0');
         partitionsOverflow <= (others => '0');
         for i in 0 to NUM_DETECTORS_G-1 loop
            if pauseSync(i) = '1' then
               partitionsPause (conv_integer(detectorPartitionsSync(i))) <= '1';
            end if;
            if overflowSync(i) = '1' then
               partitionsOverflow(conv_integer(detectorPartitionsSync(i))) <= '1';
            end if;
         end loop;
      end process partitions;

      -- Create upstream message
      l1Feedback <= toL1Feedback(l1MasterSync.tData(21 downto 0));
      U_XpmTimingFb_1 : entity l2si_core.XpmTimingFb
         generic map (
            TPD_G => TPD_G)
         port map (
            clk        => timingTxClk,         -- [in]
            rst        => timingTxRst,         -- [in]
            id         => xpmIdSync,           -- [in]
            pause      => partitionsPause,     -- [in]
            overflow   => partitionsOverflow,  -- [in]
            l1Feedback => l1Feedback,          -- [in]
            l1Ack      => l1SlaveSync.tReady,  -- [out]
            phy        => timingTxPhy);        -- [out]

   end generate GEN_XPM_FB;

end architecture rtl;
