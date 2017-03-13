-------------------------------------------------------------------------------
-- Title      : AXI PCIe Core
-------------------------------------------------------------------------------
-- File       : AxiPcieRegPkg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-02-12
-- Last update: 2016-11-20
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Package file for AXI PCIe Core
-------------------------------------------------------------------------------
-- This file is part of 'AxiPcieCore'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'AxiPcieCore', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

package AxiPcieRegPkg is
  
  constant VERSION_ADDR_C : slv(31 downto 0) := x"00000000";
  constant FLASH_ADDR_C   : slv(31 downto 0) := x"00008000";
  constant I2C_ADDR_C     : slv(31 downto 0) := x"00010000";
  constant DMA_ADDR_C     : slv(31 downto 0) := x"00020000";
  constant PHY_ADDR_C     : slv(31 downto 0) := x"00030000";
  constant TIM_ADDR_C     : slv(31 downto 0) := x"00040000";
  constant APP_ADDR_C     : slv(31 downto 0) := x"00080000";
   
end package AxiPcieRegPkg;



