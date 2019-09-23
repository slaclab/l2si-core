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

-- surf
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;

-- lcls-timing-core
use work.TimingPkg.all;

-- l2si
use work.L2SiPkg.all;

entity EventHeaderCache2 is

   generic (
      TPD_G : time := 1 ns);

   port (
      timingClk : in sl;
      timingRst : in sl;

      -- AXI Lite bus for configuration and status
      -- This needs to be sync'd to timingClk
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;


      -- Prompt header and event bus
      promptTimingHeader      : in TimingHeaderType;
      promptExperimentMessage : in ExperimentMessageType;

      -- Aligned header and event bus
      alignedTimingHeader      : in  TimingHeaderType;
      alignedExperimentMessage : in  ExperimentMessageType;
      almostFull               : out sl;
      overflow                 : out sl;

      -- Trigger output
      triggerData : out ExperimentEventDataType;

      -- Event/Transition output
      eventClk        : in  sl;
      eventRst        : in  sl;
      eventAxisMaster : out AxiStreamMasterType;
      eventAxisSlave  : in  AxiStreamSlaveType;
      eventAxisCtrl   : in  AxiStreamCtrlType);

end entity EventHeaderCache2;

architecture rtl of EventHeaderCache2 is

   constant FIFO_ADDR_WIDTH_C : integer := 5;

   type RegType is record
      enable          : sl;
      enableCache     : sl;
      partition       : slv(2 downto 0);
      fifoPauseThresh : slv(FIFO_ADDR_WIDTH_C-1 downto 0);
      overflow        : sl;
      fifoRst         : sl;
      messageDelay    : slv8Array(1 downto 0);
      l0Count         : slv(31 downto 0);
      l1AcceptCount   : slv(31 downto 0);
      l1RejectCount   : slv(31 downto 0);

      fifoAxisMaster : AxiStreamMasterType;

      -- outputs
      triggerData    : ExperimentEventDataType;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;

   end record RegType;

   constant REG_INIT_C : RegType := (
      enable          => '0',
      enableCache     => '0',
      partition       => (others => '0'),
      fifoPauseThresh => (others => '0'),
      overflow        => '0',
      fifoRst         => '0',
      messageDelay    => (others => (others => '0')),
      l0Count         => (others => '0'),
      l1AcceptCount   => (others => '0'),
      l1RejectCount   => (others => '0'),

      fifoAxisMaster => axiStreamMasterInit(EVENT_AXIS_CONFIG_C),
      -- outputs     =>
      triggerData    => EXPERIMENT_EVENT_DATA_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal fifoAxisSlave : AxiStreamSlaveType;
   signal fifoAxisCtrl  : AxiStreamCtrlType;
   signal fifoWrCnt     : slv(FIFO_ADDR_WIDTH_C-1 downto 0);

begin

   U_AxiStreamFifoV2_1 : entity work.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => 1,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => false,
         BRAM_EN_G           => true,
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_C,
         FIFO_FIXED_THRESH_G => false,
         FIFO_PAUSE_THRESH_G => 16,
         SLAVE_AXI_CONFIG_G  => EVENT_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => EVENT_AXIS_CONFIG_C)
      port map (
         sAxisClk        => timingClk,          -- [in]
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

   almostFull <= fifoAxisCtrl.pause;

   comb : process (alignedTimingHeader, axilReadMaster, axilWriteMaster, fifoAxisCtrl,
                   fifoAxisSlave, promptExperimentMessage, promptTimingHeader, r, timingRst) is
      variable v              : RegType;
      variable axilEp         : AxiLiteEndpointType;
      variable partition      : integer;
      variable eventData      : ExperimentEventDataType;
      variable transitionData : ExperimentTransitionDataType;
      variable tmpEventData   : ExperimentEventDataType;
      variable eventHeader    : EventHeaderType;
      variable streamValid    : sl;
   begin
      v := r;

      partition := conv_integer(r.partition);

      v.fifoRst := '0';

      -- Check if data is accepted
--       if (fifoAxisSlave.tReady = '1') then
--          v.fifoAxisMaster.tValid := '0';
--       end if;

      -- Watch for and decode triggers on prompt interface
      -- Output on triggerData interface
      v.triggerData.valid := '0';
      if (promptTimingHeader.strobe = '1' and promptExperimentMessage.valid = '1') then
         v.triggerData := toExperimentEventDataType(promptExperimentMessage.partitionWord(partition));

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

      -- Watch for events/transitions on aligned interface
      -- Place entries into FIFO
      if (alignedTimingHeader.strobe = '1' and alignedExperimentMessage.valid = '1') then
         -- Decode event data from configured partitionWord
         -- Decode as both event and transition and use the .valid field to determine which one to use
         eventData      := toExperimentEventDataType(alignedExperimentMessage.partitionWord(partition));
         transitionData := toExperimentTransitionDataType(alignedExperimentMessage.partitionWord(partition));

         -- Pass on events with l0Accept
         -- Pass on transitions
         streamValid := (eventData.valid and eventData.l0Accept) or transitionData.valid;

         -- Don't pass data through when disabled
         if (r.enable = '0' or r.enableCache = '0') then
            streamValid := '0';
         end if;

         -- Latch time since last event
         if (eventData.valid = '1') then
            v.messageDelay(1) := r.messageDelay(0);
         end if;

         -- Create the EventHeader from timing and event data
         eventHeader.pulseId     := alignedTimingHeader.pulseId;
         eventHeader.timeStamp   := alignedTimingHeader.timeStamp;
         eventHeader.count       := eventData.count;
         eventHeader.payload     := eventData.payload;
         eventHeader.triggerInfo := alignedExperimentMessage.partitionWord(partition)(15 downto 0);  -- Fix this uglyness later
         eventHeader.partitions  := (others => '0');
         for i in 0 to 7 loop
            tmpEventData              := toExperimentEventDataType(alignedExperimentMessage.partitionWord(i));
            eventHeader.partitions(i) := tmpEventData.l0Accept or not tmpEventData.valid;
         end loop;

         -- Place the EventHeader into an AXI-Stream transaction
         if (streamValid = '1') then
            if (fifoAxisCtrl.pause = '0') then
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
      axiSlaveRegister(axilEp, x"00", 1, v.enableCache);
      axiSlaveRegister(axilEp, x"04", 0, v.partition);
      axiSlaveRegisterR(axilEp, x"08", 0, r.overflow);
      axiSlaveRegisterR(axilEp, X"08", 1, fifoAxisCtrl.pause);
      axiSlaveRegister(axilEp, X"08", 16, v.fifoPauseThresh);
      axiSlaveRegisterR(axilEp, x"0C", 0, r.messageDelay(1));
      axiSlaveRegisterR(axilEp, x"10", 0, r.l0Count);
      axiSlaveRegisterR(axilEp, x"14", 0, r.l1AcceptCount);
      axiSlaveRegisterR(axilEp, x"1C", 0, r.l1RejectCount);

      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      if (timingRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;
      triggerData    <= r.triggerData;
      overflow       <= r.overflow;


   end process comb;

   seq : process (timingClk) is
   begin
      if (rising_edge(timingClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;



end architecture rtl;

