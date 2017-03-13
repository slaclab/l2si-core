
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package Version is

constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := x"00000009"; -- MAKE_VERSION

constant BUILD_STAMP_C : string := "QuadAdcFmc: Vivado v2016.2 (x86_64) Built Sat Mar 11 19:27:35 PST 2017 by weaver";

end Version;

-------------------------------------------------------------------------------
-- Revision History:
--
-- 09/26/2016 (0x00000000): PCIe interface with Timing
-- 09/26/2016 (0x00000001): Add DataSimulator + DMA
-- 10/16/2016 (0x00000002): Add DataSimulator + DMA + Full data width
-- 10/22/2016 (0x00000003): Add DataSimulator + DMA:dynamic sized + sample prescale
-- 11/03/2016 (0x00000004): Integrate FMC126
-- 12/14/2016 (0x00000005): Version for CXI beam test.  Beam synchronous but
-- s/w correction needed.  Prescale broken.
-- 12/14/2016 (0x00000006): Prescale fixed. Removed 8to10 gearbox.
-- 03/03/2017 (0x00000007): Test pattern moved to proper clock domain.
-- 03/11/2017 (0x00000008): Push trigIn into header for analysis
-- 03/12/2017 (0x00000009): Migration to git
--
-------------------------------------------------------------------------------

