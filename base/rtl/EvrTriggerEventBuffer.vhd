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

entity EvrTriggerEventBuffer is

   generic (
      TPD_G                          : time                := 1 ns;
      EVENT_AXIS_CONFIG_G            : AxiStreamConfigType := EVENT_AXIS_CONFIG_C;
      TRIGGER_CLK_IS_TIMING_RX_CLK_G : boolean             := false;
      EVENT_CLK_IS_TIMING_RX_CLK_G   : boolean             := false);
   port (
      timingRxClk : in sl;
      timingRxRst : in sl;

      -- AXI Lite bus for configuration and status
      -- This needs to be sync'd to timingRxClk
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;

      -- Timing Bus
      timingBus : in TimingBusType;

      -- Trigger output
      triggerClk  : in  sl;
      triggerRst  : in  sl;
      triggerData : out TriggerEventDataType;

      -- Event/Transition output
      eventClk           : in  sl;
      eventRst           : in  sl;
      eventTimingMessage : out TimingMessageType;
      eventAxisMaster    : out AxiStreamMasterType;
      eventAxisSlave     : in  AxiStreamSlaveType;
      eventAxisCtrl      : in  AxiStreamCtrlType);

end entity EvrTriggerEventBuffer;

architecture rtl of EvrTriggerEventBuffer is

   constant FIFO_ADDR_WIDTH_C : integer := 5;

   type RegType is record
      enable          : sl;
      fifoPauseThresh : slv(FIFO_ADDR_WIDTH_C-1 downto 0);
      triggerDelay    : slv(31 downto 0);
      overflow        : sl;
      fifoRst         : sl;
      triggerCount    : slv(31 downto 0);
      resetCounters   : sl;

      fifoAxisMaster : AxiStreamMasterType;

      -- outputs
      triggerData    : XpmEventDataType;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;

      -- debug
      partitionV     : integer;
      eventData      : XpmEventDataType;
      transitionData : XpmTransitionDataType;
      tmpEventData   : XpmEventDataType;
      eventHeader    : EventHeaderType;
      streamValid    : sl;


   end record RegType;

   constant REG_INIT_C : RegType := (
      enable          => '0',
      partition       => (others => '0'),
      fifoPauseThresh => toslv(16, FIFO_ADDR_WIDTH_C),
      triggerDelay    => toSlv(42, 32),
      overflow        => '0',
      fifoRst         => '0',

      transitionCount => (others => '0'),
      validCount      => (others => '0'),
      triggerCount    => (others => '0'),
      l0Count         => (others => '0'),
      l1AcceptCount   => (others => '0'),
      l1RejectCount   => (others => '0'),
      resetCounters   => '0',

      fbTimer         => (others => '0'),
      fbTimerOverflow => '0',
      fbTimerActive   => '0',
      fbTimerToTrig   => (others => '0'),
      pauseToTrig     => (others => '0'),
      notPauseToTrig  => (others => '1'),
      pause           => '0',

      fifoAxisMaster => axiStreamMasterInit(EVENT_AXIS_CONFIG_C),
      -- outputs     =>
      triggerData    => XPM_EVENT_DATA_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,

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

   signal triggerDataSlv          : slv(47 downto 0);
   signal delayedTriggerDataSlv   : slv(47 downto 0);
   signal delayedTriggerDataValid : sl;
   signal syncTriggerDataValid    : sl;
   signal syncTriggerDataSlv      : slv(47 downto 0);

   signal eventAxisCtrlPauseSync : sl;

begin

   U_EvrV2CoreTriggers_1: entity work.EvrV2CoreTriggers
      generic map (
         TPD_G           => TPD_G,
         NCHANNELS_G     => NCHANNELS_G,
         NTRIGGERS_G     => NTRIGGERS_G,
         TRIG_DEPTH_G    => TRIG_DEPTH_G,
         TRIG_PIPE_G     => TRIG_PIPE_G,
         COMMON_CLK_G    => COMMON_CLK_G,
         EVR_CARD_G      => EVR_CARD_G,
         AXIL_BASEADDR_G => AXIL_BASEADDR_G)
      port map (
         axilClk         => axilClk,          -- [in]
         axilRst         => axilRst,          -- [in]
         axilWriteMaster => axilWriteMaster,  -- [in]
         axilWriteSlave  => axilWriteSlave,   -- [out]
         axilReadMaster  => axilReadMaster,   -- [in]
         axilReadSlave   => axilReadSlave,    -- [out]
         evrClk          => evrClk,           -- [in]
         evrRst          => evrRst,           -- [in]
         evrBus          => evrBus,           -- [in]
         trigOut         => trigOut,          -- [out]
         evrModeSel      => evrModeSel);      -- [in]

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


   comb : process (alignedTimingMessage, alignedTimingStrobe, alignedXpmMessage, axilReadMaster,
                   axilWriteMaster, eventAxisCtrlPauseSync, fifoAxisCtrl, fifoWrCnt,
                   promptTimingStrobe, promptXpmMessage, r, timingRxRst) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      v := r;

      v.partitionV := conv_integer(r.partition);

      v.fifoRst := '0';

      v.fifoAxisMaster.tValid := '0';


      --------------------------------------------
      -- Trigger output logic
      -- Watch for and decode triggers on prompt interface
      -- Output on triggerData interface
      --------------------------------------------
      v.triggerData := XPM_EVENT_DATA_INIT_C;
      if (promptTimingStrobe = '1' and promptXpmMessage.valid = '1' and r.enable = '1') then
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
      if (alignedTimingStrobe = '1' and alignedXpmMessage.valid = '1') then
         -- Decode event data from configured partitionWord
         -- Decode as both event and transition and use the .valid field to determine which one to use
         v.eventData      := toXpmEventDataType(alignedXpmMessage.partitionWord(v.partitionV));
         v.transitionData := toXpmTransitionDataType(alignedXpmMessage.partitionWord(v.partitionV));

         -- Pass on events with l0Accept
         -- Pass on transitions
         v.streamValid := (v.eventData.valid and v.eventData.l0Accept) or v.transitionData.valid;

         -- Don't pass data through when disabled
         if (r.enable = '0') then
            v.streamValid := '0';
         end if;

         -- Create the EventHeader from timing and event data
         v.eventHeader.pulseId     := alignedTimingMessage.pulseId;
         v.eventHeader.timeStamp   := alignedTimingMessage.timeStamp;
         v.eventHeader.count       := v.eventData.count;
         v.eventHeader.triggerInfo := alignedXpmMessage.partitionWord(v.partitionV)(15 downto 0);
         v.eventHeader.partitions  := (others => '0');
         for i in 0 to 7 loop
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
         -- Note that this logic is active even when the r.enable register = 0.
         if (v.transitionData.valid = '1' and v.transitionData.header = MSG_CLEAR_FIFO_C) then
            v.overflow              := '0';
            v.fifoRst               := '1';
            v.fifoAxisMaster.tValid := '0';
         end if;


         if (r.enable = '1') then
            v.validCount := r.validCount + 1;
         end if;

      end if;

      -- Latch FIFO overflow if seen
      if (fifoAxisCtrl.overflow = '1') then
         v.overflow := '1';
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

      v.resetCounters := '0';           -- Pulsed for 1 cycle
      if (r.resetCounters = '1') then
         v.l0Count        := (others => '0');
         v.l1AcceptCount  := (others => '0');
         v.l1RejectCount  := (others => '0');
         v.validCount     := (others => '0');
         v.triggerCount   := (others => '0');
         v.pauseToTrig    := (others => '0');
         v.notPauseToTrig := (others => '1');
      end if;

      --------------------------------------------
      -- Axi lite interface
      --------------------------------------------
      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      axiSlaveRegister(axilEp, x"00", 0, v.enable);
      axiSlaveRegister(axilEp, x"04", 0, v.partition);
      axiSlaveRegister(axilEp, X"08", 0, v.fifoPauseThresh);
      axiSlaveRegister(axilEp, X"0C", 0, v.triggerDelay);
      axiSlaveRegisterR(axilEp, x"10", 0, r.overflow);
      axiSlaveRegisterR(axilEp, X"10", 1, r.pause);
      axiSlaveRegisterR(axilEp, X"10", 2, fifoAxisCtrl.overflow);
      axiSlaveRegisterR(axilEp, X"10", 3, fifoAxisCtrl.pause);
      axiSlaveRegisterR(axilEp, X"10", 4, fifoWrCnt);
      axiSlaveRegisterR(axilEp, x"14", 0, r.l0Count);
      axiSlaveRegisterR(axilEp, x"18", 0, r.l1AcceptCount);
      axiSlaveRegisterR(axilEp, x"1C", 0, r.l1RejectCount);
      axiSlaveRegisterR(axilEp, X"20", 0, r.transitionCount);
      axiSlaveRegisterR(axilEp, X"24", 0, r.validCount);
      axiSlaveRegisterR(axilEp, X"28", 0, r.triggerCount);
      axiSlaveRegisterR(axilEp, X"2C", 0, alignedXpmMessage.partitionAddr);
      axiSlaveRegisterR(axilEp, X"30", 0, alignedXpmMessage.partitionWord(0));
      axiSlaveRegisterR(axilEp, X"38", 0, r.pauseToTrig);
      axiSlaveRegisterR(axilEp, X"3C", 0, r.notPauseToTrig);
      axiSlaveRegister(axilEp, X"40", 0, v.resetCounters);

      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      if (timingRxRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      -- outputs
      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;
      partition      <= r.partition;
      overflow       <= r.overflow;
      pause          <= r.pause;

   end process comb;

   seq : process (timingRxClk) is
   begin
      if (rising_edge(timingRxClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -----------------------------------------------
   -- Delay triggerData according to AXI-Lite register
   -----------------------------------------------
   triggerDataSlv <= toSlv(r.triggerData);
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
         delay       => r.triggerDelay,            -- [in]
         inputData   => triggerDataSlv,            -- [in]
         inputValid  => r.triggerData.valid,       -- [in]
         outputData  => delayedTriggerDataSlv,     -- [out]
         outputValid => delayedTriggerDataValid);  -- [out]

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

      U_SynchronizerClearReadout : entity surf.SynchronizerOneShot
         generic map (
            TPD_G => TPD_G)
         port map (
            clk     => eventClk,
            dataIn  => r.fifoRst,
            dataOut => clearReadout);
   end generate TRIGGER_SYNC_GEN;

   NO_TRIGGER_SYNC_GEN : if (TRIGGER_CLK_IS_TIMING_RX_CLK_G) generate
      triggerData <= toXpmEventDataType(delayedTriggerDataSlv, delayedTriggerDataValid);
   end generate NO_TRIGGER_SYNC_GEN;

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
         sAxisClk        => timingRxClk,        -- [in]
         sAxisRst        => r.fifoRst,          -- [in]
         sAxisMaster     => r.fifoAxisMaster,   -- [in]
         sAxisSlave      => fifoAxisSlave,      -- [out]
         sAxisCtrl       => fifoAxisCtrl,       -- [out]
         fifoPauseThresh => r.fifoPauseThresh,  -- [in]
         fifoWrCnt       => fifoWrCnt,          -- [out]
         mAxisClk        => eventClk,           -- [in]
         mAxisRst        => eventRst,           -- [in]
         mAxisMaster     => eventAxisMaster,    -- [out]
         mAxisSlave      => eventAxisSlave);    -- [in]

   -----------------------------------------------
   -- Buffer TimingMessage that corresponds to each event placed in event fifo
   -----------------------------------------------
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
         rst    => r.fifoRst,                -- [in]
         wr_clk => timingRxClk,              -- [in]
         wr_en  => r.fifoAxisMaster.tValid,  -- [in]
         din    => alignedTimingMessageSlv,  -- [in]
         rd_clk => eventClk,                 -- [in]
         rd_en  => eventAxisSlave.tReady,    -- [in] -- This is probably wrong
         dout   => eventTimingMessageSlv);   -- [out]
   eventTimingMessage <= toTimingMessageType(eventTimingMessageSlv);

end architecture rtl;

