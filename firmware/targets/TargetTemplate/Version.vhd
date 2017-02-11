------------------------------------------------------------------------------
-- This file is part of 'LCLS2 AMC Carrier Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 AMC Carrier Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package Version is

   constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := x"00000001";  -- MAKE_VERSION

   constant BUILD_STAMP_C : string := "TargetTemplate: Vivado v2016.4 (x86_64) Built Fri Feb 10 18:05:16 PST 2017 by ruckman";

end Version;

-------------------------------------------------------------------------------
-- Revision History:
--
-- 02/02/2017 (0x00000001): Initial Build
--
-------------------------------------------------------------------------------

