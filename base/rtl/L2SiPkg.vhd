-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Provides constants, types and conversion functions to
-- facilitate use of L2Si components.
-------------------------------------------------------------------------------
-- This file is part of 'L2Si-core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'L2Si-core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- surf

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

-- lcls-timing-core

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

-- L2si

library l2si_core;
use l2si_core.XpmExtensionPkg.all;

package L2SiPkg is


   subtype TriggerEventDataType is XpmEventDataType;
   subtype TriggerEventDataArray is XpmEventDataArray;   

   subtype TriggerL1FeedbackType is XpmL1FeedbackType;
   subtype TriggerL1FeedbackArray is XpmL1FeedbackArray;   
   constant TRIGGER_L1_FEEDBACK_INIT_C : TriggerL1FeedbackType := XPM_L1_FEEDBACK_INIT_C;   
   
   ----------------------------------------------------
   -- Event and Timing Header interface
   ----------------------------------------------------
   constant EVENT_HEADER_VERSION_C : slv(7 downto 0) := toSlv(0, 8);
   constant L1A_INFO_C             : slv(6 downto 0) := toSlv(12, 7);

   type EventHeaderType is record
      pulseId     : slv(63 downto 0);   -- timingMessage.pulseId
      timeStamp   : slv(63 downto 0);   -- timingMessage.timestmp
      version     : slv(7 downto 0);    -- EVENT_HEADER_VERSION_C
      partitions  : slv(7 downto 0);    -- active partions
      payload     : slv(7 downto 0);    -- event payload
      count       : slv(23 downto 0);   -- event count
      triggerInfo : slv(15 downto 0);   -- event trigger info

   end record;

   type EventHeaderArray is array(natural range <>) of EventHeaderType;

   constant EVENT_HEADER_INIT_C : EventHeaderType := (
      pulseId     => (others => '0'),
      timeStamp   => (others => '0'),
      version     => EVENT_HEADER_VERSION_C,
      partitions  => (others => '0'),
      payload     => (others => '0'),
      count       => (others => '0'),
      triggerInfo => (others => '0'));


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



end package L2SiPkg;

package body L2SiPkg is

   --------------------------------------------------------
   -- Timing Header decode
   --------------------------------------------------------
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


end package body L2SiPkg;
