-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of L2SI. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of L2SI, including this file, may be
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
use l2si_core.XpmExtensionPkg.all;

entity TriggerEventBuffer is

   generic (
      TPD_G                          : time    := 1 ns;
      TRIGGER_CLK_IS_TIMING_RX_CLK_G : boolean := false;
      EVENT_CLK_IS_TIMING_RX_CLK_G   : boolean := false);
   port (
      timingRxClk : in sl;
      timingRxRst : in sl;

      -- AXI Lite bus for configuration and status
      -- This needs to be sync'd to timingRxClk
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;


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
      full      : out sl;
      overflow  : out sl;

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

end entity TriggerEventBuffer;

architecture rtl of TriggerEventBuffer is

   constant FIFO_ADDR_WIDTH_C : integer := 5;

   type RegType is record
      enable            : sl;
      enableEventBuffer : sl;
      partition         : slv(2 downto 0);
      fifoPauseThresh   : slv(FIFO_ADDR_WIDTH_C-1 downto 0);
      triggerDelay      : slv(31 downto 0);
      overflow          : sl;
      fifoRst           : sl;
      messageDelay      : slv8Array(1 downto 0);
      l0Count           : slv(31 downto 0);
      l1AcceptCount     : slv(31 downto 0);
      l1RejectCount     : slv(31 downto 0);

      fifoAxisMaster : AxiStreamMasterType;

      -- outputs
      triggerData    : XpmEventDataType;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;

   end record RegType;

   constant REG_INIT_C : RegType := (
      enable            => '0',
      enableEventBuffer => '0',
      partition         => (others => '0'),
      fifoPauseThresh   => toslv(16, FIFO_ADDR_WIDTH_C),
      triggerDelay      => toSlv(42, 32),
      overflow          => '0',
      fifoRst           => '0',
      messageDelay      => (others => (others => '0')),
      l0Count           => (others => '0'),
      l1AcceptCount     => (others => '0'),
      l1RejectCount     => (others => '0'),

      fifoAxisMaster => axiStreamMasterInit(EVENT_AXIS_CONFIG_C),
      -- outputs     =>
      triggerData    => XPM_EVENT_DATA_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal fifoAxisSlave : AxiStreamSlaveType;
   signal fifoAxisCtrl  : AxiStreamCtrlType;
   signal fifoWrCnt     : slv(FIFO_ADDR_WIDTH_C-1 downto 0);

   signal alignedTimingMessageSlv : slv(TIMING_MESSAGE_BITS_NO_BSA_C-1 downto 0);
   signal eventTimingMessageSlv   : slv(TIMING_MESSAGE_BITS_NO_BSA_C-1 downto 0);

   signal triggerDataSlv          : slv(47 downto 0);
   signal delayedTriggerDataSlv   : slv(47 downto 0);
   signal delayedTriggerDataValid : sl;
   signal syncTriggerDataValid    : sl;
   signal syncTriggerDataSlv      : slv(47 downto 0);

begin


   comb : process (alignedXpmMessage, alignedTimingMessage, alignedTimingStrobe,
                   axilReadMaster, axilWriteMaster, fifoAxisCtrl,
                   promptXpmMessage, promptTimingStrobe, r, timingRxRst) is
      variable v              : RegType;
      variable axilEp         : AxiLiteEndpointType;
      variable partitionV     : integer;
      variable eventData      : XpmEventDataType;
      variable transitionData : XpmTransitionDataType;
      variable tmpEventData   : XpmEventDataType;
      variable eventHeader    : EventHeaderType;
      variable streamValid    : sl;
   begin
      v := r;

      partitionV := conv_integer(r.partition);

      v.fifoRst := '0';

      v.fifoAxisMaster.tValid := '0';

      --------------------------------------------
      -- Trigger output logic
      -- Watch for and decode triggers on prompt interface
      -- Output on triggerData interface
      --------------------------------------------
      v.triggerData.valid := '0';
      if (promptTimingStrobe = '1' and promptXpmMessage.valid = '1') then
         v.triggerData := toXpmEventDataType(promptXpmMessage.partitionWord(partitionV));

         -- Count time since last event
         v.messageDelay(0) := r.messageDelay(0) + 1;
         if (v.triggerData.valid = '1') then
            v.messageDelay(0) := (others => '0');
         end if;

         -- Gate output valid if disabled by configuration
         if (r.enable = '0') then
            v.triggerData.valid := '0';
         end if;
      end if;

      --------------------------------------------
      -- Event/Transition logic
      -- Watch for events/transitions on aligned interface
      -- Place entries into FIFO
      --------------------------------------------
      if (alignedTimingStrobe = '1' and alignedXpmMessage.valid = '1') then
         -- Decode event data from configured partitionWord
         -- Decode as both event and transition and use the .valid field to determine which one to use
         eventData      := toXpmEventDataType(alignedXpmMessage.partitionWord(partitionV));
         transitionData := toXpmTransitionDataType(alignedXpmMessage.partitionWord(partitionV));

         -- Pass on events with l0Accept
         -- Pass on transitions
         streamValid := (eventData.valid and eventData.l0Accept) or transitionData.valid;

         -- Don't pass data through when disabled
         if (r.enable = '0' or r.enableEventBuffer = '0') then
            streamValid := '0';
         end if;

         -- Latch delay between prompt and aligned (should match the configured delay)
         if (eventData.valid = '1') then
            v.messageDelay(1) := r.messageDelay(0);
         end if;

         -- Create the EventHeader from timing and event data
         eventHeader.pulseId     := alignedTimingMessage.pulseId;
         eventHeader.timeStamp   := alignedTimingMessage.timeStamp;
         eventHeader.count       := eventData.count;
         eventHeader.payload     := eventData.payload;
         eventHeader.triggerInfo := alignedXpmMessage.partitionWord(partitionV)(15 downto 0);  -- Fix this uglyness later
         eventHeader.partitions  := (others => '0');
         for i in 0 to 7 loop
            tmpEventData              := toXpmEventDataType(alignedXpmMessage.partitionWord(i));
            eventHeader.partitions(i) := tmpEventData.l0Accept or not tmpEventData.valid;
         end loop;

         -- Place the EventHeader into an AXI-Stream transaction
         if (streamValid = '1') then
            if (fifoAxisCtrl.pause = '0') then
               v.fifoAxisMaster.tValid                                := '1';
               v.fifoAxisMaster.tdata(EVENT_HEADER_BITS_C-1 downto 0) := toSlv(eventHeader);
               v.fifoAxisMaster.tDest(0)                              := transitionData.valid;
               v.fifoAxisMaster.tLast                                 := '1';
            else
               v.overflow := '1';
            end if;
         end if;

         -- Special case - reset fifo, mask any tValid
         if (transitionData.valid = '1' and transitionData.header = MSG_CLEAR_FIFO_C) then
            v.overflow              := '0';
            v.fifoRst               := '1';
            v.fifoAxisMaster.tValid := '0';
         end if;

         -- Count stuff
         -- Could maybe do this with registered data?
         if (streamValid = '1' and eventData.valid = '1') then
            if(eventData.l0Accept = '1') then
               v.l0Count := r.l0Count + 1;
            end if;

            if (eventData.l1Expect = '1') then
               if (eventData.l1Accept = '1') then
                  v.l1AcceptCount := r.l1AcceptCount + 1;
               else
                  v.l1RejectCount := r.l1RejectCount + 1;
               end if;
            end if;
         end if;

      end if;


      --------------------------------------------
      -- Axi lite interface
      --------------------------------------------
      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      axiSlaveRegister(axilEp, x"00", 0, v.enable);
      axiSlaveRegister(axilEp, x"00", 1, v.enableEventBuffer);
      axiSlaveRegister(axilEp, x"04", 0, v.partition);
      axiSlaveRegisterR(axilEp, x"08", 0, r.overflow);
      axiSlaveRegisterR(axilEp, X"08", 1, fifoAxisCtrl.pause);
      axiSlaveRegister(axilEp, X"08", 16, v.fifoPauseThresh);
      axiSlaveRegisterR(axilEp, x"0C", 0, r.messageDelay(1));
      axiSlaveRegisterR(axilEp, x"10", 0, r.l0Count);
      axiSlaveRegisterR(axilEp, x"14", 0, r.l1AcceptCount);
      axiSlaveRegisterR(axilEp, x"1C", 0, r.l1RejectCount);
      axiSlaveRegister(axilEp, X"20", 0, v.triggerDelay);

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
         MASTER_AXI_CONFIG_G => EVENT_AXIS_CONFIG_C)
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

   full <= fifoAxisCtrl.pause or eventAxisCtrl.pause;

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

