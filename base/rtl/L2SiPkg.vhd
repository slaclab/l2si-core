-------------------------------------------------------------------------------
-- Title      : TimingPkg
-------------------------------------------------------------------------------
-- File       : TimingExtnPkg.vhd
-- Author     : Matt Weaver  <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2018-07-20
-- Last update: 2019-09-23
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 Timing Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 Timing Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- surf
use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

-- lcls-timing-core
use work.TimingPkg.all;

package L2SiPkg is

   ----------------------------------------------------
   -- Timing Extension Bus decode
   ----------------------------------------------------
   --  Experiment timing information (appended by downstream masters)   
   constant EXPERIMENT_STREAM_ID_C : integer := 1;

   constant EXPERIMENT_PARTITIONS_C            : integer := 8;
   constant EXPERIMENT_PARTITION_ADDR_LENGTH_C : integer := 32;
   constant EXPERIMENT_PARTITION_WORD_LENGTH_C : integer := 48;
   constant EXPERIMENT_MESSAGE_BITS_C          : integer := 32 + 8 * 48;

   type ExperimentMessageType is record
      valid         : sl;
      partitionAddr : slv(EXPERIMENT_PARTITION_ADDR_LENGTH_C downto 0);
      partitionWord : Slv48Array(0 to EXPERIMENT_PARTITIONS_C-1);
   end record;

   constant EXPERIMENT_MESSAGE_INIT_C : ExperimentMessageType := (
      valid         => '0',
      partitionAddr => (others => '1'),
      partitionWord => (others => x"800080008000"));
   type ExperimentMessageArray is array (integer range<>) of ExperimentMessageType;

--   function toSlv(message                   : ExperimentMessageType) return slv;
   --function toExperimentMessageType (vector : slv(EXPERIMENT_MESSAGE_BITS_C-1 downto 0)) return ExperimentMessageType;
   function toExperimentMessageType (timing : TimingExtensionMessageType) return ExperimentMessageType;

   ----------------------------------------------------
   -- Event and Timing Header interface
   ----------------------------------------------------
   type TimingHeaderType is record
      strobe    : sl;
      pulseId   : slv(63 downto 0);
      timeStamp : slv(63 downto 0);
   end record;

   constant TIMING_HEADER_INIT_C : TimingHeaderType := (
      strobe    => '0',
      pulseId   => (others => '0'),
      timeStamp => (others => '0'));

   function toTimingHeader(timingBus : TimingBusType) return TimingHeaderType;

   constant EVENT_HEADER_VERSION_C : slv(7 downto 0) := toSlv(0, 8);
   constant L1A_INFO_C             : slv(6 downto 0) := toSlv(12, 7);

   type EventHeaderType is record
      pulseId     : slv(63 downto 0);
      timeStamp   : slv(63 downto 0);
      count       : slv(23 downto 0);
      version     : slv(7 downto 0);
      partitions  : slv(15 downto 0);   -- readout groups
      triggerInfo : slv(15 downto 0);   -- L1 trigger lines
      payload     : slv(7 downto 0);    -- transition payload
   end record;

   type EventHeaderArray is array(natural range<>) of EventHeaderType;

   constant EVENT_HEADER_INIT_C : EventHeaderType := (
      pulseId     => (others => '0'),
      timeStamp   => (others => '0'),
      count       => (others => '0'),
      version     => EVENT_HEADER_VERSION_C,
      partitions  => (others => '0'),
      triggerInfo => (others => '0'),
      payload     => (others => '0'));

   constant EVENT_HEADER_BITS_C : integer := 192;

   function toSlv(eventHeader     : EventHeaderType) return slv;
   function toEventHeader (vector : slv) return EventHeaderType;

   constant EVENT_AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 24,              -- 192 bits
      TDEST_BITS_C  => 1,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_FIXED_C,
      TUSER_BITS_C  => 0,
      TUSER_MODE_C  => TUSER_NONE_C);

   -----------------------------------------------
   -- Experiment Event Decode
   -- Decoded from 48-bit Experiment Partition Words
   -----------------------------------------------
   type ExperimentEventDataType is record
      valid    : sl;
      l0Accept : sl;                    -- l0 accept
      l0Tag    : slv(4 downto 0);
      l0Reject : sl;                    -- l0 reject
      l1Expect : sl;                    -- l1 expexted
      l1Accept : sl;                    -- l1 accepted
      l1Tag    : slv(4 downto 0);
      count    : slv(23 downto 0);
      payload  : slv(7 downto 0);       -- Not used?
   end record;

   constant EXPERIMENT_EVENT_DATA_INIT_C : ExperimentEventDataType := (
      valid    => '0',
      l0Accept => '0',
      l0Tag    => (others => '0'),
      l0Reject => '0',
      l1Expect => '0',
      l1Accept => '0',
      l1Tag    => (others => '0'),
      count    => (others => '0'),
      payload  => (others => '0'));

   function toSlv (experimentEvent                  : ExperimentEventDataType) return slv;
   function toExperimentEventDataType(partitionWord : slv(47 downto 0)) return ExperimentEventDataType;

   type ExperimentTransitionDataType is record
      valid   : sl;
      l0Tag   : slv(4 downto 0);
      header  : slv(7 downto 0);
      count   : slv(23 downto 0);
      payload : slv(7 downto 0);
   end record;

   constant EXPERIMENT_TRANSITION_DATA_INIT_C : ExperimentTransitionDataType := (
      valid   => '0',
      l0Tag   => (others => '0'),
      header  => (others => '0'),
      count   => (others => '0'),
      payload => (others => '0'));

   --  Clear event header -> event data match fifos
   constant MSG_CLEAR_FIFO_C  : slv(7 downto 0) := toSlv(0,8);
   --  Communicate delay of pword
   constant MSG_DELAY_PWORD_C : slv(7 downto 0) := toSlv(1,8);
   

   function toSlv (experimentTransition                  : ExperimentTransitionDataType) return slv;
   function toExperimentTransitionDataType(partitionWord : slv(47 downto 0)) return ExperimentTransitionDataType;


   -----------------------------------------------
   -- partitionAddr gets decoded to look for delay commands
   -----------------------------------------------
   type ExperimentDelayType is record
      valid : sl;
      index : integer;
      value : slv(6 downto 0);
   end record ExperimentAddressDataType;

   function toExperimentDelayType (partitionAddr : slv(31 downto 0)) return ExperimentDelayType;

--   function toTrigVector(message : ExperimentMessageType) return slv;

end package L2SiPkg;

package body L2SiPkg is

   --------------------------------------------------------
   -- Timing Extension Decode functions
   --------------------------------------------------------
--    function toSlv(message : ExperimentMessageType) return slv
--    is
--       variable vector : slv(EXPERIMENT_MESSAGE_BITS_C-1 downto 0) := (others => '0');
--       variable i : integer := 0;
--    begin
--       assignSlv(i, vector, message.partitionAddr);
--       for j in message.partitionWord'range loop
--          assignSlv(i, vector, message.partitionWord(j));
--       end loop;
--       return vector;
--    end function;

   function toExperimentMessageType (timing : TimingExtensionMessageType) return ExperimentMessageType
   is
      variable experiment : ExperimentMessageType;
      variable i          : integer := 0;
   begin
      experiment.valid := timing.valid;
      assignRecord(i, timing.data, experiment.partitionAddr);
      for j in 0 to EXPERIMENT_PARTITIONS_C-1 loop
         assignRecord(i, timing.data, experiment.partitionWord(j));
      end loop;
      return experiment;
   end function;


   --------------------------------------------------------
   -- Timing Header decode
   --------------------------------------------------------
   function toTimingHeader(timingBus : TimingBusType) return TimingHeaderType is
      variable result : TimingHeaderType;
   begin
      result.strobe    := timingBus.strobe;
      result.pulseId   := timingBus.message.pulseId;
      result.timeStamp := timingBus.message.timeStamp;
      return result;
   end function;

   function toSlv(eventHeader : EventHeaderType) return slv is
      variable vector : slv(191 downto 0) := (others => '0');
      variable i      : integer           := 0;
   begin
      assignSlv(i, vector, eventHeader.pulseId(55 downto 0));
      -- Steal the top 8 bits of puslseId
      -- It is redundant to have these triggerInfo bits here
      -- but software expects it this way
      assignSlv(i, vector, ite(eventHeader.triggerInfo(15) = '1', L1A_INFO_C, eventHeader.triggerInfo(12 downto 6)));
      i := i+1;
      assignSlv(i, vector, eventHeader.timeStamp);
      assignSlv(i, vector, eventHeader.partitions);
      assignSlv(i, vector, eventHeader.triggerInfo);
      assignSlv(i, vector, eventHeader.count);
      assignSlv(i, vector, eventHeader.version);
      return vector;
   end function;

   function toEventHeader (vector : slv) return EventHeaderType is
      variable eventHeader : EventHeaderType := EVENT_HEADER_INIT_C;
      variable i           : integer;
   begin
      assignRecord(i, vector, eventHeader.pulseId(55 downto 0));
      i := i+8;
      assignRecord(i, vector, eventHeader.timeStamp);
      assignRecord(i, vector, eventHeader.partitions);
      assignRecord(i, vector, eventHeader.triggerInfo);
      assignRecord(i, vector, eventHeader.count);
      assignRecord(i, vector, eventHeader.version);
      return eventHeader;
   end function;



   -- Figure out what to do with this
--    function toTrigVector(message : ExperimentMessageType) return slv is
--       variable vector : slv(EXPERIMENT_PARTITIONS_C-1 downto 0);
--       variable word   : XpmPartitionDataType;
--    begin
--       for i in 0 to EXPERIMENT_PARTITIONS_C-1 loop
--          word      := toPartitionWord(message.partitionWord(i));
--          vector(i) := word.l0a or not message.partitionWord(i)(15);
--       end loop;
--       return vector;
--    end function;


   function toSlv (experimentEvent : ExperimentEventDataType) return slv is
      variable vector : slv(47 downto 0) := (others => '0');
      variable i      : integer          := 0;
   begin
      assignSlv(i, vector, experimentEvent.l0Accept);
      assignSlv(i, vector, experimentEvent.l0Tag);
      assignSlv(i, vector, "0");
      assignSlv(i, vector, experimentEvent.l0Reject);
      assignSlv(i, vector, experimentEvent.l1Expect);
      assignSlv(i, vector, experimentEvent.l1Accept);
      assignSlv(i, vector, experimentEvent.l1Tag);
      assignSlv(i, vector, experimentEvent.valid);  -- valid 'EVENT' word
      assignSlv(i, vector, experimentEvent.count);
      assignSlv(i, vector, experimentEvent.payload);
      return vector;
   end function;

   function toExperimentEventDataType(partitionWord : slv(47 downto 0)) return ExperimentEventDataType is
      variable experimentEvent : ExperimentEventDataType := EXPERIMENT_EVENT_DATA_INIT_C;
      variable i               : integer                 := 0;
   begin
      assignRecord(i, partitionWord, experimentEvent.l0Accept);  -- 0
      assignRecord(i, partitionWord, experimentEvent.l0Tag);     -- 5:1
      i := i+1;                                           -- 6
      assignRecord(i, partitionWord, experimentEvent.l0Reject);  -- 7
      assignRecord(i, partitionWord, experimentEvent.l1Expect);  -- 8
      assignRecord(i, partitionWord, experimentEvent.l1Accept);  -- 9
      assignRecord(i, partitionWord, experimentEvent.l1Tag);     --14:10
      assignRecord(i, partitionWord, experimentEvent.valid);     -- 15
      assignRecord(i, partitionWord, experimentEvent.count);     -- 39:16
      assignRecord(i, partitionWord, experimentEvent.payload);   -- 47:40

      return experimentEvent;
   end function;


   function toSlv (experimentTransition : ExperimentTransitionDataType) return slv is
      variable vector : slv(47 downto 0) := (others => '0');
      variable i      : integer          := 0;
   begin
      assignSlv(i, vector, "0");                              -- 0
      assignSlv(i, vector, experimentTransition.l0Tag);       -- 5:1
      assignSlv(i, vector, experimentTransition.header);      -- 13:6
      assignSlv(i, vector, "0");                              -- 14
      assignSlv(i, vector, not(experimentTransition.valid));  -- 15
      assignSlv(i, vector, experimentTransition.count);       -- 39:16
      assignSlv(i, vector, experimentTransition.payload);     -- 47:40
      return vector;
   end function;

   function toExperimentTransitionDataType (partitionWord : slv(47 downto 0)) return ExperimentTransitionDataType is
      variable experimentTransition : ExperimentTransitionDataType := EXPERIMENT_TRANSITION_DATA_INIT_C;
      variable i                    : integer                      := 0;
   begin
      i := i+1;
      assignRecord(i, partitionWord, experimentTransition.l0Tag);
      assignRecord(i, partitionWord, experimentTransition.header);
      i := i+1;

      assignRecord(i, partitionWord, experimentTransition.valid);
      experimentTransition.valid := not experimentTransition.valid;
      assignRecord(i, partitionWord, experimentTransition.count);
      assignRecord(i, partitionWord, experimentTransition.payload);
      return experimentTransition;
   end function;


   function toExperimentDelayType (partitionAddr : slv(31 downto 0)) return ExperimentDelayType is
      variable v : ExperimentDelayType;
   begin
      v.valid := '0';
      v.index := 0;
      v.value := (others => '0');

      if (partitionAddr(31 downto 28) = X"E") then
         v.valid := '1';
         v.index := conv_integer(partitionAddr(26 downto 24));
         v.value := partitionAddr(6 downto 0);
      end if;
      return v;
   end function toExperimentDelayType;


end package body L2SiPkg;
