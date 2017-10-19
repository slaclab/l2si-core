-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EventPkg.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-03-25
-- Last update: 2017-10-12
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Programmable configuration and status fields
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 XPM Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 XPM Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

package EventPkg is

   type TimingHeaderType is record
      strobe    : sl;
      pulseId   : slv(63 downto 0);
      timeStamp : slv(63 downto 0);
   end record;
   constant TIMING_HEADER_INIT_C : TimingHeaderType := (
      strobe    => '0',
      pulseId   => (others=>'0'),
      timeStamp => (others=>'0') );

   type EventHeaderType is record
     timeStamp  : slv(63 downto 0);
     pulseId    : slv(63 downto 0);
     evttag     : slv(63 downto 0);
   end record;

   constant EVENT_HEADER_INIT_C : EventHeaderType := (
     timeStamp  => (others=>'0'),
     pulseId    => (others=>'0'),
     evttag     => (others=>'0') );

   type EventHeaderArray is array(natural range<>) of EventHeaderType;
   
   function toSlv(v : EventHeaderType) return slv;

end package EventPkg;

package body EventPkg is

   function toSlv(v : EventHeaderType) return slv is
     variable vector : slv(191 downto 0) := (others=>'0');
     variable i      : integer := 0;
   begin
     assignSlv(i, vector, v.pulseId);
     assignSlv(i, vector, v.timeStamp);
     assignSlv(i, vector, v.evttag);
     return vector;
   end function;

end package body EventPkg;
