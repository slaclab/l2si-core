-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Public interface and decode functions for XPM messages on the
-- Timing Extension Bus.
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

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

library l2si_core;
use l2si_core.XpmPkg.all;

package XpmExtensionPkg is

   constant XPM_STREAM_ID_C     : integer := 1;
   constant XPM_MESSAGE_BITS_C  : integer := 32 + 8 * 48;
   constant XPM_MESSAGE_WORDS_C : integer := XPM_MESSAGE_BITS_C / 16;

   type XpmMessageType is record
      valid         : sl;
      partitionAddr : slv(XPM_PARTITION_ADDR_LENGTH_C-1 downto 0);
      partitionWord : Slv48Array(0 to XPM_PARTITIONS_C-1);
   end record;

   constant XPM_MESSAGE_INIT_C : XpmMessageType := (
      valid         => '0',
      partitionAddr => (others => '1'),
      partitionWord => (others => x"800080008000"));
   type XpmMessageArray is array (integer range<>) of XpmMessageType;

   -- Convert TimingExtensionMessage (512-bit slv) to XpmMessage
   function toXpmMessageType (timing : TimingExtensionMessageType) return XpmMessageType;

   -----------------------------------------------
   -- Xpm Event Decode
   -- Decoded from 48-bit Xpm Partition Words
   -----------------------------------------------
   type XpmEventDataType is record
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

   constant XPM_EVENT_DATA_INIT_C : XpmEventDataType := (
      valid    => '0',
      l0Accept => '0',
      l0Tag    => (others => '0'),
      l0Reject => '0',
      l1Expect => '0',
      l1Accept => '0',
      l1Tag    => (others => '0'),
      count    => (others => '0'),
      payload  => (others => '0'));

   type XpmEventDataArray is array (natural range <>) of XpmEventDataType;

   function toSlv (xpmEvent                  : XpmEventDataType) return slv;
   function toXpmEventDataType(partitionWord : slv(47 downto 0)) return XpmEventDataType;
   function toXpmEventDataType(partitionWord : slv(47 downto 0); valid : sl) return XpmEventDataType;   

   type XpmTransitionDataType is record
      valid   : sl;
      l0Tag   : slv(4 downto 0);
      header  : slv(7 downto 0);
      count   : slv(23 downto 0);
      payload : slv(7 downto 0);
   end record;

   constant XPM_TRANSITION_DATA_INIT_C : XpmTransitionDataType := (
      valid   => '0',
      l0Tag   => (others => '0'),
      header  => (others => '0'),
      count   => (others => '0'),
      payload => (others => '0'));

   --  Clear event buffers (transition data header)
   constant MSG_CLEAR_FIFO_C  : slv(7 downto 0) := toSlv(0, 8);
   --  Communicate delay of pword
   constant MSG_DELAY_PWORD_C : slv(7 downto 0) := toSlv(1, 8);  -- Not used!!

   function toSlv (xpmTransition                  : XpmTransitionDataType) return slv;
   function toXpmTransitionDataType(partitionWord : slv(47 downto 0)) return XpmTransitionDataType;

   -----------------------------------------------
   -- Decode broadcasts on partitionAddr
   -----------------------------------------------
   constant XPM_BROADCAST_PDELAY_C : slv(3 downto 0) := X"E";
   constant XPM_BROADCAST_XADDR_C  : slv(3 downto 0) := X"F";

   type XpmBroadcastType is record
      btype : slv(3 downto 0);
      index : integer;
      value : slv(6 downto 0);
   end record;

   function toXpmBroadcastType (partitionAddr : slv(31 downto 0)) return XpmBroadcastType;
   function toXpmPartitionAddress (broadcast  : XpmBroadcastType) return slv;


end package XpmExtensionPkg;
package body XpmExtensionPkg is

   function toXpmMessageType (timing : TimingExtensionMessageType) return XpmMessageType
   is
      variable xpm  : XpmMessageType;
      variable i    : integer := 0;
      variable data : slv(XPM_MESSAGE_BITS_C-1 downto 0);
   begin
      data      := timing.data(511 downto 512-XPM_MESSAGE_BITS_C);
      xpm.valid := timing.valid;
      assignRecord(i, data, xpm.partitionAddr);
      for j in 0 to XPM_PARTITIONS_C-1 loop
         assignRecord(i, data, xpm.partitionWord(j));
      end loop;
      return xpm;
   end function;



   function toSlv (xpmEvent : XpmEventDataType) return slv is
      variable vector : slv(47 downto 0) := (others => '0');
      variable i      : integer          := 0;
   begin
      assignSlv(i, vector, xpmEvent.l0Accept);
      assignSlv(i, vector, xpmEvent.l0Tag);
      assignSlv(i, vector, "0");
      assignSlv(i, vector, xpmEvent.l0Reject);
      assignSlv(i, vector, xpmEvent.l1Expect);
      assignSlv(i, vector, xpmEvent.l1Accept);
      assignSlv(i, vector, xpmEvent.l1Tag);
      assignSlv(i, vector, xpmEvent.valid);  -- valid 'EVENT' word
      assignSlv(i, vector, xpmEvent.count);
      assignSlv(i, vector, xpmEvent.payload);
      return vector;
   end function;

   function toXpmEventDataType(partitionWord : slv(47 downto 0)) return XpmEventDataType is
      variable xpmEvent : XpmEventDataType := XPM_EVENT_DATA_INIT_C;
      variable i        : integer          := 0;
      variable validV   : sl;
   begin
      assignRecord(i, partitionWord, xpmEvent.l0Accept);  -- 0
      assignRecord(i, partitionWord, xpmEvent.l0Tag);     -- 5:1
      i := i+1;                                           -- 6
      assignRecord(i, partitionWord, xpmEvent.l0Reject);  -- 7
      assignRecord(i, partitionWord, xpmEvent.l1Expect);  -- 8
      assignRecord(i, partitionWord, xpmEvent.l1Accept);  -- 9
      assignRecord(i, partitionWord, xpmEvent.l1Tag);     --14:10
      assignRecord(i, partitionWord, xpmEvent.valid);     -- 15
      assignRecord(i, partitionWord, xpmEvent.count);     -- 39:16
      assignRecord(i, partitionWord, xpmEvent.payload);   -- 47:40

      return xpmEvent;
   end function;

   function toXpmEventDataType(partitionWord : slv(47 downto 0); valid : sl) return XpmEventDataType is
      variable xpmEvent : XpmEventDataType := XPM_EVENT_DATA_INIT_C;
   begin
      xpmEvent := toXpmEventDataType(partitionWord);
      xpmEvent.valid := valid;
      return xpmEvent;
   end function;
   


   function toSlv (xpmTransition : XpmTransitionDataType) return slv is
      variable vector : slv(47 downto 0) := (others => '0');
      variable i      : integer          := 0;
   begin
      assignSlv(i, vector, "0");                       -- 0
      assignSlv(i, vector, xpmTransition.l0Tag);       -- 5:1
      assignSlv(i, vector, xpmTransition.header);      -- 13:6
      assignSlv(i, vector, "0");                       -- 14
      assignSlv(i, vector, not(xpmTransition.valid));  -- 15
      assignSlv(i, vector, xpmTransition.count);       -- 39:16
      assignSlv(i, vector, xpmTransition.payload);     -- 47:40
      return vector;
   end function;

   function toXpmTransitionDataType (partitionWord : slv(47 downto 0)) return XpmTransitionDataType is
      variable xpmTransition : XpmTransitionDataType := XPM_TRANSITION_DATA_INIT_C;
      variable i             : integer               := 0;
   begin
      i := i+1;
      assignRecord(i, partitionWord, xpmTransition.l0Tag);
      assignRecord(i, partitionWord, xpmTransition.header);
      i := i+1;

      assignRecord(i, partitionWord, xpmTransition.valid);
      xpmTransition.valid := not xpmTransition.valid;
      assignRecord(i, partitionWord, xpmTransition.count);
      assignRecord(i, partitionWord, xpmTransition.payload);
      return xpmTransition;
   end function;

   function toXpmBroadcastType (partitionAddr : slv(31 downto 0)) return XpmBroadcastType is
      variable i         : integer;
      variable broadcast : XpmBroadcastType;
      variable tmpIndex  : slv(2 downto 0);
   begin
      i               := 0;
      assignRecord(i, partitionAddr, broadcast.value);
      i               := 24;
      assignRecord(i, partitionAddr, tmpIndex);
      broadcast.index := conv_integer(tmpIndex);
      i               := 28;
      assignRecord(i, partitionAddr, broadcast.btype);
      return broadcast;
   end function;

   function toXpmPartitionAddress (broadcast : XpmBroadcastType) return slv is
      variable i             : integer;
      variable partitionAddr : slv(31 downto 0);
      variable indexTmp      : slv(2 downto 0);
   begin
      i             := 0;
      partitionAddr := (others => '0');
      assignSlv(i, partitionAddr, broadcast.value);
      i             := 24;
      indexTmp      := toSlv(broadcast.index, 3);
      assignSlv(i, partitionAddr, indexTmp);
      i             := 28;
      assignSlv(i, partitionAddr, broadcast.btype);
      return partitionAddr;
   end function;

end package body XpmExtensionPkg;
