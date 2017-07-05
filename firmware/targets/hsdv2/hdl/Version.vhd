
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package Version is

constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := x"00000000"; -- MAKE_VERSION

constant BUILD_STAMP_C : string := "QuadAdcFmc: Vivado v2016.2 (x86_64) Built Sat Mar 11 19:27:35 PST 2017 by weaver";

end Version;

-------------------------------------------------------------------------------
-- Revision History:
--
-- 09/26/2016 (0x00000000): PCIe interface with Timing
--
-------------------------------------------------------------------------------

