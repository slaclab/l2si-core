-------------------------------------------------------------------------------
-- Title      : CuTiming interface package
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Defines constants and functions for decoding CuTiming messages
-- on the Timing Extension bus.
-------------------------------------------------------------------------------
-- This file is part of L2Si. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of L2Si, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

package CuTimingPkg is

   constant CU_TIMING_STREAM_ID_C : integer := 2;
   
   constant CU_TIMING_BITS_C : integer := 256+64+80;
   constant CU_TIMING_WORDS_C : integer := CU_TIMING_BITS_C / 16;

   -- Cu Accelerator Timing System
   type CuTimingType is record
      valid      : sl;
      epicsTime  : slv(63 downto 0);
      eventCodes : slv(255 downto 0);
      bsaInit    : slv(19 downto 0);
      bsaActive  : slv(19 downto 0);
      bsaAvgDone : slv(19 downto 0);
      bsaDone    : slv(19 downto 0);
   end record;

   constant CU_TIMING_INIT_C : CuTimingType := (
      valid      => '0',
      epicsTime  => (others => '0'),
      eventCodes => (others => '0'),
      bsaInit    => (others => '0'),
      bsaActive  => (others => '0'),
      bsaAvgDone => (others => '0'),
      bsaDone    => (others => '0'));

   function toSlv(message          : CuTimingType) return slv;
   function toCuTimingType (vector : slv(CU_TIMING_BITS_C-1 downto 0)) return CuTimingType;


end package CuTimingPkg;

package body CuTimingPkg is

   function toSlv(message : CuTimingType) return slv
   is
      variable vector : slv(CU_TIMING_BITS_C-1 downto 0) := (others => '0');
      variable i      : integer                          := 0;
   begin
--      assignSlv(i, vector, message.valid);
      assignSlv(i, vector, message.epicsTime);
      assignSlv(i, vector, message.eventCodes);
      assignSlv(i, vector, message.bsaInit);
      assignSlv(i, vector, message.bsaActive);
      assignSlv(i, vector, message.bsaAvgDone);
      assignSlv(i, vector, message.bsaDone);
      return vector;
   end function;

   function toCuTimingType (vector : slv(CU_TIMING_BITS_C-1 downto 0)) return CuTimingType
   is
      variable message : CuTimingType;
      variable i       : integer := 0;
   begin
--      assignRecord(i, vector, message.valid);
      assignRecord(i, vector, message.epicsTime);
      assignRecord(i, vector, message.eventCodes);
      assignRecord(i, vector, message.bsaInit);
      assignRecord(i, vector, message.bsaActive);
      assignRecord(i, vector, message.bsaAvgDone);
      assignRecord(i, vector, message.bsaDone);
      return message;
   end function;


end package body CuTimingPkg;
