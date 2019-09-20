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

use work.StdRtlPkg.all;

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
      alignedTimingHeader  : in  TimingHeaderType;
      alignedExperimentBus : in  ExperimentMessageType;
      almostFull           : out sl;
      overflow             : out sl;

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

   type RegType is record
      enable         : sl;
      enableCache    : sl;
      partition      : slv(2 downto 0);
      overflow       : sl;
      fifoRst        : sl;
      messageDelay   : slv8Array(1 downto 0);
      fifoAxisMaster : AxiStreamMasterType;

      -- outputs
      triggerData    : ExperimentEventDataType;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;

   end record RegType;

   signal fifoAxisSlave : AxiStreamSlaveType;
   signal fifoAxisCtrl  : AxiStreamCtrlType;

begin

   U_AxiStreamFifoV2_1 : entity work.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => 1,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => true,
         BRAM_EN_G           => true,
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 5,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 16,
         SLAVE_AXI_CONFIG_G  => EVENT_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => EVENT_AXIS_CONFIG_C)
      port map (
         sAxisClk    => timingClk,         -- [in]
         sAxisRst    => r.fifoRst,         -- [in]
         sAxisMaster => r.fifoAxisMaster,  -- [in]
         sAxisSlave  => fifoAxisSlave,     -- [out]
         sAxisCtrl   => fifoAxisCtrl,      -- [out]
         fifoWrCnt   => fifoWrCnt,         -- [out]
         mAxisClk    => eventClk,          -- [in]
         mAxisRst    => eventRst,          -- [in]
         mAxisMaster => eventAxisMaster,   -- [out]
         mAxisSlave  => eventAxisSlave);   -- [in]

   almostFull <= fifoAxisCtrl.pause;

   comb : process (all) is
      variable v              : RegType;
      variable partition      : integer;
      variable eventData      : ExperimentEventDataType;
      variable transitionData : ExperimentTransitionDataType;
      variable tmpEventData   : ExperimentEventDataType;
      variable eventHeader    : EventHeaderType;
   begin
      v := r;

      partition := conv_integer(r.partition);
      
      v.fifoRst := '0';

      -- Check if data is accepted
      if (fifoAxisSlave.tReady = '1') then
         v.fifoAxisMaster.tValid := '0';
      end if;

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
         eventData      := toExperimentEventDataType(alignedExperimentMessage.partitionWord(r.partition));
         transitionData := toExperimentTransitionDataType(alignedExperimentMessage.partitionWord(r.partition));

         -- Pass on events with l0Accept
         -- Pass on transitions 
         streamValid := (eventData.valid = '1' and eventData.l0Accept = '1') or transitionData.valid = '1';

         -- Don't pass data through when disabled
         if (r.enable = '0' or r.cacheenable = '0') then
            streamValid := '0';
         end if;

         -- Latch time since last event
         if (eventData.valid = '1') then
            v.messageDelay(1) := r.messageDelay(0);
         end if;

         -- Create the EventHeader from timing and event data
         eventHeader.pulseId = alignedTimingHeader.pulseId;
         eventHeader.timeStamp   := alignedTimingHeader.timeStamp;
         eventHeader.count       := eventData.count;
         eventHeader.payload     := eventData.payload;
         eventHeader.triggerInfo := alignedExperimentMessage.partitionWord(r.partition)(15 downto 0);  -- Fix this uglyness later
         eventHeader.partitions  := (others => '0');
         for i in 0 to 7 loop
            tmpEventData              := toExperimentEventDataType(alignedExperimentMessage.partitionWord(i));
            eventHeader.partitions(i) := tmpEventData.l0Accept or not tmpEventData.valid;
         end loop;

         -- Place the EventHeader into an AXI-Stream transaction
         if (streamValid = '1') then
            if (v.fifoAxisMaster.tValid = '0') then
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
         if (streamValid = '1' and v.eventData.valid = '1') then
            if(v.eventData.l0Accept = '1') then
               v.l0Count := r.l0Count + 1;
            end if;

            if (v.eventData.l1Expect = '1') then
               if (v.eventData.l1Accept = '1') then
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
      axiSlaveRegister(axilEp, x"00", 1, v.cacheenable);
      axiSlaveRegister(axilEp, x"04", 0, v.partition);
      axiSlaveRegisterR(axilEp, x"08", 0, r.overflow);
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

