-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
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

entity TriggerEventBuffer is

   generic (
      TPD_G                          : time                := 1 ns;
      TRIGGER_INDEX_G                : integer             := 0;
      EN_LCLS_I_TIMING_G             : boolean             := false;
      EN_LCLS_II_TIMING_G            : boolean             := true;
      EN_LCLS_II_INHIBIT_COUNTS_G    : boolean             := false;
      EVENT_AXIS_CONFIG_G            : AxiStreamConfigType := EVENT_AXIS_CONFIG_C;
      AXIL_CLK_IS_TIMING_RX_CLK_G    : boolean             := false;
      TRIGGER_CLK_IS_TIMING_RX_CLK_G : boolean             := false;
      EVENT_CLK_IS_TIMING_RX_CLK_G   : boolean             := false);
   port (
      timingRxClk : in sl;
      timingRxRst : in sl;

      -- AXI Lite bus for configuration and status
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;

      -- EVR triggers for LCLS-I timing
      timingMode  : in sl;
      evrTriggers : in TimingTrigType;

      -- Prompt header and event bus
      promptTimingStrobe  : in sl;
      promptTimingMessage : in TimingMessageType;
      promptXpmMessage    : in XpmMessageType;

      -- Aligned header and event bus
      alignedTimingStrobe  : in sl;
      alignedTimingMessage : in TimingMessageType;
      alignedXpmMessage    : in XpmMessageType;

      -- Feedback
      partition : out slv(2 downto 0);
      pause     : out sl;
      overflow  : out sl;

      -- Trigger output
      triggerClk  : in  sl;
      triggerRst  : in  sl;
      triggerData : out TriggerEventDataType;


      -- Event/Transition output
      eventClk                : in  sl;
      eventRst                : in  sl;
      eventTimingMessageValid : out sl;
      eventTimingMessage      : out TimingMessageType;
      eventTimingMessageRd    : in  sl := '1';
      eventInhibitCountsValid : out sl;
      eventInhibitCounts      : out TriggerInhibitCountsType;
      eventInhibitCountsRd    : in  sl := '1';
      eventAxisMaster         : out AxiStreamMasterType;
      eventAxisSlave          : in  AxiStreamSlaveType;
      eventAxisCtrl           : in  AxiStreamCtrlType;
      clearReadout            : out sl);

end entity TriggerEventBuffer;

architecture rtl of TriggerEventBuffer is

   constant FIFO_ADDR_WIDTH_C : integer := 5;

   type RegType is record
      evrTrigLast     : sl;
      partition       : slv(2 downto 0);
      overflow        : sl;
      fifoRst         : sl;
      transitionCount : slv(31 downto 0);
      validCount      : slv(31 downto 0);
      triggerCount    : slv(31 downto 0);
      l0Count         : slv(31 downto 0);
      l1AcceptCount   : slv(31 downto 0);
      l1RejectCount   : slv(31 downto 0);

      fbTimer         : slv(11 downto 0);
      fbTimerOverflow : sl;
      fbTimerActive   : sl;
      fbTimerToTrig   : slv(11 downto 0);
      pauseToTrig     : slv(11 downto 0);
      notPauseToTrig  : slv(11 downto 0);
      pause           : sl;


      fifoAxisMaster : AxiStreamMasterType;
      msgFifoWr      : sl;
      inhFifoWr      : sl;

      l0Rejects      : slv       (XPM_PARTITIONS_C-1 downto 0);
      l0RejectCounts : XpmInhibitCountsType;

      -- outputs
      triggerData : XpmEventDataType;

      -- debug
      partitionV     : integer;
      eventData      : XpmEventDataType;
      transitionData : XpmTransitionDataType;
      tmpEventData   : XpmEventDataType;
      eventHeader    : EventHeaderType;
      streamValid    : sl;


   end record RegType;

   constant REG_INIT_C : RegType := (
      evrTrigLast => '0',
      partition   => (others => '0'),
      overflow    => '0',
      fifoRst     => '0',

      transitionCount => (others => '0'),
      validCount      => (others => '0'),
      triggerCount    => (others => '0'),
      l0Count         => (others => '0'),
      l1AcceptCount   => (others => '0'),
      l1RejectCount   => (others => '0'),

      fbTimer         => (others => '0'),
      fbTimerOverflow => '0',
      fbTimerActive   => '0',
      fbTimerToTrig   => (others => '0'),
      pauseToTrig     => (others => '0'),
      notPauseToTrig  => (others => '1'),
      pause           => '0',

      fifoAxisMaster => axiStreamMasterInit(EVENT_AXIS_CONFIG_C),
      msgFifoWr      => '0',
      inhFifoWr      => '0',

      l0Rejects      => (others=>'0'),
      l0RejectCounts => XPM_INHIBIT_COUNTS_INIT_C,

      -- outputs     =>
      triggerData => TRIGGER_EVENT_DATA_INIT_C,

      partitionV     => 0,
      eventData      => XPM_EVENT_DATA_INIT_C,
      transitionData => XPM_TRANSITION_DATA_INIT_C,
      tmpEventData   => XPM_EVENT_DATA_INIT_C,
      eventHeader    => EVENT_HEADER_INIT_C,
      streamValid    => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal fifoAxisSlave : AxiStreamSlaveType;
   signal fifoAxisCtrl  : AxiStreamCtrlType;
   signal fifoWrCnt     : slv(FIFO_ADDR_WIDTH_C-1 downto 0);

   signal alignedTimingMessageSlv : slv(TIMING_MESSAGE_BITS_NO_BSA_C-1 downto 0);
   signal eventTimingMessageSlv   : slv(TIMING_MESSAGE_BITS_NO_BSA_C-1 downto 0);

   signal triggerDataValid        : sl;
   signal triggerDataSlv          : slv(47 downto 0);
   signal xpmTriggerDataValid     : sl;
   signal xpmTriggerDataSlv       : slv(47 downto 0);
   signal delayedTriggerDataValid : sl;
   signal delayedTriggerDataSlv   : slv(47 downto 0);
   signal syncTriggerDataValid    : sl;
   signal syncTriggerDataSlv      : slv(47 downto 0);

   signal eventAxisCtrlPauseSync : sl;
   signal eventAxisRst           : sl;
   signal eventAxisRstSync       : sl;

   signal partitionReg    : slv(2 downto 0);
   signal triggerDelay    : slv(31 downto 0);
   signal triggerSource   : sl;
   signal fifoPauseThresh : slv(FIFO_ADDR_WIDTH_C-1 downto 0);
   signal resetCounters   : sl;
   signal fifoRstReg      : sl;
   signal fifoRst         : sl;
   signal enable          : sl;
   
   signal triggerInhibitCountsSlv : slv(XPM_INHIBIT_COUNTS_LEN_C-1 downto 0);
   signal eventInhibitCountsSlv   : slv(XPM_INHIBIT_COUNTS_LEN_C-1 downto 0);

begin

   -- Event AXIS bus pause is the application pause signal
   -- It needs to be synchronizer to timingRxClk
   U_Synchronizer_1 : entity surf.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => timingRxClk,              -- [in]
         rst     => timingRxRst,              -- [in]
         dataIn  => eventAxisCtrl.pause,      -- [in]
         dataOut => eventAxisCtrlPauseSync);  -- [out]


   comb : process (alignedTimingMessage, alignedTimingStrobe, alignedXpmMessage, enable,
                   eventAxisCtrlPauseSync, evrTriggers, fifoAxisCtrl, fifoRstReg, partitionReg,
                   promptTimingStrobe, promptXpmMessage, r, resetCounters, timingMode, timingRxRst,
                   triggerSource, xpmTriggerDataSlv, xpmTriggerDataValid) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
      variable eventData : XpmEventDataType;
   begin
      v := r;

      if ((EN_LCLS_I_TIMING_G and timingMode = '0') or
          (EN_LCLS_II_TIMING_G and timingMode = '1' and triggerSource = EVR_TRIGGER_SOURCE_C)) then

         -- EVR trigger logic
         -- Mislabled as "EVR", can come in LCLS-II timing
         v.fifoRst               := '0';
         v.fifoAxisMaster.tValid := '0';
         v.triggerData.valid     := '0';
         v.triggerData.l0Accept  := '0';
         v.triggerData.l1Expect  := '0';
         v.triggerData.l1Accept  := '0';
         v.evrTrigLast           := evrTriggers.trigPulse(TRIGGER_INDEX_G);

         if (evrTriggers.trigPulse(TRIGGER_INDEX_G) = '1' and r.evrTrigLast = '0' and enable = '1') then
            v.triggerCount                        := r.triggerCount + 1;
            v.fifoAxisMaster.tValid               := '1';
            v.fifoAxisMaster.tdata(63 downto 0)   := (others => '0');
            v.fifoAxisMaster.tdata(127 downto 64) := evrTriggers.timeStamp;
            v.fifoAxisMaster.tLast                := '1';

            v.triggerData.valid    := '1';
            v.triggerData.l0Accept := '1';
            v.triggerData.l1Expect := '1';
            v.triggerData.l1Accept := '1';
            v.triggerData.l0Tag    := v.triggerCount(4 downto 0);
            v.triggerData.count    := v.triggerCount(23 downto 0);

         end if;

         delayedTriggerDataSlv   <= toSlv(r.triggerData);
         delayedTriggerDataValid <= r.triggerData.valid and r.triggerData.l0Accept;

      elsif (EN_LCLS_II_TIMING_G and timingMode = '1' and triggerSource = XPM_TRIGGER_SOURCE_C) then

         -- LCLS-II XPM Trigger Buffer Logic
         v.partitionV            := conv_integer(r.partition);
         v.fifoRst               := '0';
         v.fifoAxisMaster.tValid := '0';
         v.msgFifoWr             := '0';

         --------------------------------------------
         -- Trigger output logic
         -- Watch for and decode triggers on prompt interface
         -- Output on triggerData interface
         --------------------------------------------
         v.triggerData := XPM_EVENT_DATA_INIT_C;
         if (promptTimingStrobe = '1' and promptXpmMessage.valid = '1' and enable = '1') then
            v.triggerData := toXpmEventDataType(promptXpmMessage.partitionWord(v.partitionV));
            if (v.triggerData.valid = '1' and v.triggerData.l0Accept = '1') then
               v.triggerCount := r.triggerCount + 1;
            end if;
         end if;

         --------------------------------------------
         -- Event/Transition logic
         -- Watch for events/transitions on aligned interface
         -- Place entries into FIFO
         --------------------------------------------
         v.streamValid := '0';
         v.msgFifoWr   := '0';
         v.inhFifoWr   := r.msgFifoWr;
         if (r.streamValid = '1' and r.transitionData.header/=toSlv(10,6)) then
           v.inhFifoWr := '1';
         end if;

         v.l0Rejects   := (others=>'0');
         if (alignedTimingStrobe = '1' and alignedXpmMessage.valid = '1') then
            -- Decode event data from configured partitionWord
            -- Decode as both event and transition and use the .valid field to determine which one to use
            v.eventData      := toXpmEventDataType(alignedXpmMessage.partitionWord(v.partitionV));
            v.transitionData := toXpmTransitionDataType(alignedXpmMessage.partitionWord(v.partitionV));
            for i in 0 to XPM_PARTITIONS_C-1 loop
               eventData     := toXpmEventDataType(alignedXpmMessage.partitionWord(i));
               if (eventData.valid = '1' and eventData.l0Reject = '1') then
                  v.l0Rejects(i) := '1';
               end if;
            end loop;

            -- Pass on events with l0Accept
            -- Pass on transitions
            v.streamValid := (v.eventData.valid and v.eventData.l0Accept) or v.transitionData.valid;
            v.msgFifoWr   := (v.eventData.valid and v.eventData.l0Accept);

            -- Don't pass data through when disabled
            if (enable = '0') then
               v.streamValid := '0';
               v.msgFifoWr   := '0';
            end if;

            -- Create the EventHeader from timing and event data
            v.eventHeader.pulseId     := alignedTimingMessage.pulseId;
            v.eventHeader.timeStamp   := alignedTimingMessage.timeStamp;
            v.eventHeader.count       := v.eventData.count;
            v.eventHeader.triggerInfo := alignedXpmMessage.partitionWord(v.partitionV)(15 downto 0);
            v.eventHeader.partitions  := (others => '0');
            for i in 0 to XPM_PARTITIONS_C-1 loop
               v.tmpEventData              := toXpmEventDataType(alignedXpmMessage.partitionWord(i));
               v.eventHeader.partitions(i) := v.tmpEventData.l0Accept or not v.tmpEventData.valid;
            end loop;

            -- Place the EventHeader into an AXI-Stream transaction
            if (v.streamValid = '1') then
               if (fifoAxisCtrl.overflow = '0') then
                  v.fifoAxisMaster.tValid                                := '1';
                  v.fifoAxisMaster.tdata(EVENT_HEADER_BITS_C-1 downto 0) := toSlv(v.eventHeader);
                  v.fifoAxisMaster.tDest(0)                              := v.transitionData.valid;
                  v.fifoAxisMaster.tLast                                 := '1';
               end if;
            end if;

            -- Special case - reset fifo, mask any tValid
            -- Note that this logic is active even when the enable register = 0.
            if (v.transitionData.valid = '1' and v.transitionData.header = MSG_CLEAR_FIFO_C) then
               v.overflow              := '0';
               v.fifoRst               := '1';
               v.fifoAxisMaster.tValid := '0';
            end if;


            if (enable = '1') then
               v.validCount := r.validCount + 1;
            end if;

         end if;


         -- Count stuff
         if (r.streamValid = '1') then
            if (r.eventData.valid = '1') then
               if (r.eventData.l0Accept = '1') then
                  v.l0Count := r.l0Count + 1;
               end if;

               if (r.eventData.l1Expect = '1') then
                  if (r.eventData.l1Accept = '1') then
                     v.l1AcceptCount := r.l1AcceptCount + 1;
                  else
                     v.l1RejectCount := r.l1RejectCount + 1;
                  end if;
               end if;
            end if;

            if (r.transitionData.valid = '1') then
               v.transitionCount := r.transitionCount + 1;
            end if;
         end if;

         if r.inhFifoWr = '1' then
            v.l0RejectCounts := XPM_INHIBIT_COUNTS_INIT_C;
         else
            for i in 0 to XPM_PARTITIONS_C-1 loop
               if r.l0Rejects(i) = '1' then
                 v.l0RejectCounts.inhibits(i) := r.l0RejectCounts.inhibits(i) + 1;
               end if;
            end loop;
         end if;

         -- Monitor time between pause assertion and trigger arrival
         v.fbTimer := r.fbTimer + 1;
         if uAnd(r.fbTimer) = '1' then
            v.fbTimerOverflow := '1';
         end if;
         v.pause := fifoAxisCtrl.pause or eventAxisCtrlPauseSync;
         if v.pause /= r.pause then
            v.fbTimer         := (others => '0');
            v.fbTimerOverflow := '0';
            v.fbTimerActive   := r.fbTimerOverflow;
            if (r.pause = '1' and r.fbTimerActive = '1' and r.fbTimerToTrig > r.pauseToTrig) then
               v.pauseToTrig := r.fbTimerToTrig;
            end if;
         elsif (r.triggerData.valid = '1' and r.triggerData.l0Accept = '1') then
            if r.pause = '1' then
               v.fbTimerToTrig := r.fbTimer;
            elsif (r.fbTimerActive = '1' and r.fbTimerOverflow = '0' and r.fbTimer < r.notPauseToTrig) then
               v.notPauseToTrig := r.fbTimer;
            end if;
         end if;

         delayedTriggerDataSlv   <= xpmTriggerDataSlv;
         delayedTriggerDataValid <= xpmTriggerDataValid;
      else
         delayedTriggerDataSlv <= (others => '0');
         delayedTriggerDataValid <= '0';
      end if;  -- LCLS-II XPM logic

      -- Latch FIFO overflow if seen
      if (fifoAxisCtrl.overflow = '1') then
         v.overflow := '1';
      end if;

      if (resetCounters = '1') then
         v.l0Count        := (others => '0');
         v.l1AcceptCount  := (others => '0');
         v.l1RejectCount  := (others => '0');
         v.validCount     := (others => '0');
         v.triggerCount   := (others => '0');
         v.pauseToTrig    := (others => '0');
         v.notPauseToTrig := (others => '1');
      end if;

      v.partition := partitionReg;

      if (timingRxRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      -- outputs
      fifoRst <= r.fifoRst or fifoRstReg;

      partition <= r.partition;
      overflow  <= r.overflow;
      pause     <= r.pause;

   end process comb;

   seq : process (timingRxClk) is
   begin
      if (rising_edge(timingRxClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_TriggerEventBufferReg : entity l2si_core.TriggerEventBufferReg
      generic map (
         TPD_G               => TPD_G,
         COMMON_CLK_G        => AXIL_CLK_IS_TIMING_RX_CLK_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_C,
         EN_LCLS_I_TIMING_G  => EN_LCLS_I_TIMING_G,
         EN_LCLS_II_TIMING_G => EN_LCLS_II_TIMING_G)
      port map (
         timingRxClk       => timingRxClk,
         timingRxRst       => timingRxRst,
         overflow          => r.overflow,
         fifoAxisCtrl      => fifoAxisCtrl,
         fifoWrCnt         => fifoWrCnt,
         timingMode        => timingMode,
         triggerCount      => r.triggerCount,
         pause             => r.pause,
         l0Count           => r.l0Count,
         l1AcceptCount     => r.l1AcceptCount,
         l1RejectCount     => r.l1RejectCount,
         transitionCount   => r.transitionCount,
         validCount        => r.validCount,
         alignedXpmMessage => alignedXpmMessage,
         pauseToTrig       => r.pauseToTrig,
         notPauseToTrig    => r.notPauseToTrig,
         enable            => enable,
         fifoRst           => fifoRstReg,
         resetCounters     => resetCounters,
         partition         => partitionReg,
         triggerDelay      => triggerDelay,
         triggerSource     => triggerSource,
         fifoPauseThresh   => fifoPauseThresh,
         -- AXI Lite bus for configuration and status
         axilClk           => axilClk,
         axilRst           => axilRst,
         axilReadMaster    => axilReadMaster,
         axilReadSlave     => axilReadSlave,
         axilWriteMaster   => axilWriteMaster,
         axilWriteSlave    => axilWriteSlave);

   -----------------------------------------------
   -- Delay triggerData according to AXI-Lite register
   -----------------------------------------------
   triggerDataSlv   <= toSlv(r.triggerData);
   triggerDataValid <= r.triggerData.valid and r.triggerData.l0Accept;
   U_SlvDelayFifo_1 : entity surf.SlvDelayFifo
      generic map (
         TPD_G              => TPD_G,
         DATA_WIDTH_G       => 48,
         DELAY_BITS_G       => 32,
         FIFO_ADDR_WIDTH_G  => FIFO_ADDR_WIDTH_C,
         FIFO_MEMORY_TYPE_G => "block")
      port map (
         clk         => timingRxClk,               -- [in]
         rst         => timingRxRst,               -- [in]
         delay       => triggerDelay,              -- [in]
         inputData   => triggerDataSlv,            -- [in]
         inputValid  => triggerDataValid,          -- [in]
         outputData  => xpmTriggerDataSlv,     -- [out]
         outputValid => xpmTriggerDataValid);  -- [out]

   -----------------------------------------------
   -- Synchronize trigger data to trigger clock
   -----------------------------------------------
   TRIGGER_SYNC_GEN : if (not TRIGGER_CLK_IS_TIMING_RX_CLK_G) generate
      U_SynchronizerFifo_1 : entity surf.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            COMMON_CLK_G => false,
            DATA_WIDTH_G => 48)
         port map (
            rst    => timingRxRst,              -- [in]
            wr_clk => timingRxClk,              -- [in]
            wr_en  => delayedTriggerDataValid,  -- [in]
            din    => delayedTriggerDataSlv,    -- [in]
            rd_clk => triggerClk,               -- [in]
            rd_en  => syncTriggerDataValid,     -- [in]
            valid  => syncTriggerDataValid,     -- [out]
            dout   => syncTriggerDataSlv);      -- [out]
      triggerData <= toXpmEventDataType(syncTriggerDataSlv, syncTriggerDataValid);

   end generate TRIGGER_SYNC_GEN;

   NO_TRIGGER_SYNC_GEN : if (TRIGGER_CLK_IS_TIMING_RX_CLK_G) generate
      triggerData <= toXpmEventDataType(delayedTriggerDataSlv, delayedTriggerDataValid);
   end generate NO_TRIGGER_SYNC_GEN;

   U_SynchronizerClearReadout : entity surf.SynchronizerOneShot
     generic map (
       TPD_G => TPD_G)
     port map (
       clk     => eventClk,
       dataIn  => fifoRst,
       dataOut => clearReadout);

   eventAxisRst <= eventRst or fifoRst;
   
   U_EventAxisRst : entity surf.RstSync
     port map (
       clk       => eventClk,
       asyncRst  => eventAxisRst,
       syncRst   => eventAxisRstSync );
   
   -----------------------------------------------
   -- Buffer event data in a fifo
   -----------------------------------------------
   U_AxiStreamFifoV2_1 : entity surf.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => 1,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => false,
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => EVENT_CLK_IS_TIMING_RX_CLK_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_C,
         FIFO_FIXED_THRESH_G => false,
         FIFO_PAUSE_THRESH_G => 16,
         SLAVE_AXI_CONFIG_G  => EVENT_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => EVENT_AXIS_CONFIG_G)
      port map (
         sAxisClk        => timingRxClk,       -- [in]
         sAxisRst        => fifoRst,           -- [in]
         sAxisMaster     => r.fifoAxisMaster,  -- [in]
         sAxisSlave      => fifoAxisSlave,     -- [out]
         sAxisCtrl       => fifoAxisCtrl,      -- [out]
         fifoPauseThresh => fifoPauseThresh,   -- [in]
         fifoWrCnt       => fifoWrCnt,         -- [out]
         mAxisClk        => eventClk,          -- [in]
         mAxisRst        => eventAxisRstSync,  -- [in]
         mAxisMaster     => eventAxisMaster,   -- [out]
         mAxisSlave      => eventAxisSlave);   -- [in]

   -----------------------------------------------
   -- Buffer TimingMessage that corresponds to each event placed in event fifo
   -----------------------------------------------
   GEN_EVENT_TIMING_MESSAGE : if (EN_LCLS_II_TIMING_G) generate
      alignedTimingMessageSlv <= toSlvNoBsa(alignedTimingMessage);
      U_Fifo_1 : entity surf.Fifo
         generic map (
            TPD_G           => TPD_G,
            GEN_SYNC_FIFO_G => EVENT_CLK_IS_TIMING_RX_CLK_G,
            MEMORY_TYPE_G   => "block",
            FWFT_EN_G       => true,
            PIPE_STAGES_G   => 1,               -- make sure this lines up right with event fifo
            DATA_WIDTH_G    => TIMING_MESSAGE_BITS_NO_BSA_C,
            ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_C)
         port map (
            rst    => fifoRst,                  -- [in]
            wr_clk => timingRxClk,              -- [in]
            wr_en  => r.msgFifoWr,              -- [in]
            din    => alignedTimingMessageSlv,  -- [in]
            rd_clk => eventClk,                 -- [in]
            rd_en  => eventTimingMessageRd,     -- [in]
            valid  => eventTimingMessageValid,  -- [out]
            dout   => eventTimingMessageSlv);   -- [out]
      eventTimingMessage <= toTimingMessageType(eventTimingMessageSlv);
   end generate GEN_EVENT_TIMING_MESSAGE;

   GEN_INHIBIT_COUNTS : if (EN_LCLS_II_INHIBIT_COUNTS_G) generate
      triggerInhibitCountsSlv <= toSlv(r.l0RejectCounts);
      U_Fifo_2 : entity surf.Fifo
         generic map (
            TPD_G           => TPD_G,
            GEN_SYNC_FIFO_G => EVENT_CLK_IS_TIMING_RX_CLK_G,
            MEMORY_TYPE_G   => "block",
            FWFT_EN_G       => true,
            PIPE_STAGES_G   => 1,               -- make sure this lines up right with event fifo
            DATA_WIDTH_G    => eventInhibitCountsSlv'length,
            ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_C)
         port map (
            rst    => fifoRst,                  -- [in]
            wr_clk => timingRxClk,              -- [in]
            wr_en  => r.inhFifoWr,              -- [in]
            din    => triggerInhibitCountsSlv,  -- [in]
            rd_clk => eventClk,                 -- [in]
            rd_en  => eventInhibitCountsRd,     -- [in]
            valid  => eventInhibitCountsValid,  -- [out]
            dout   => eventInhibitCountsSlv);   -- [out]
      eventInhibitCounts <= toXpmInhibitCountsType(eventInhibitCountsSlv);
end generate GEN_INHIBIT_COUNTS;

end architecture rtl;

