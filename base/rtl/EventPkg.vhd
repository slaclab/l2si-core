-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EventPkg.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-03-25
-- Last update: 2019-09-17
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
use work.TimingPkg.all;

package EventPkg is


   ------------------------------------------------
   -- Partition Data
   -- Convert Partiton words to event
   ------------------------------------------------
   
   
end package EventPkg;

package body EventPkg is

   function toTimingHeader(v : TimingBusType) return TimingHeaderType is
     variable result : TimingHeaderType;
   begin
     result.strobe    := v.strobe;
     result.pulseId   := v.message.pulseId;
     result.timeStamp := v.message.timeStamp;
     return result;
   end function;
   
   function toSlv(v : EventHeaderType) return slv is
     variable vector : slv(191 downto 0) := (others=>'0');
     variable i      : integer := 0;
   begin
     assignSlv(i, vector, v.pulseId(55 downto 0));
     if v.l1t(15) = '1' then
       assignSlv(i, vector, L1A_INFO_C);
     else
       assignSlv(i, vector, v.l1t(12 downto 6)); 
     end if;
     assignSlv(i, vector, v.damaged   );
     assignSlv(i, vector, v.timeStamp );
     assignSlv(i, vector, v.partitions);
     assignSlv(i, vector, v.l1t       );
     assignSlv(i, vector, v.count     );
     assignSlv(i, vector, v.version   );
     return vector;
   end function;

   
end package body EventPkg;
