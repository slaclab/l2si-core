-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DtiCPllArray.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-08
-- Last update: 2016-04-19
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Ethernet Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Ethernet Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.DtiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity DtiCPllArray is
   generic (
      TPD_G             : time            := 1 ns;
      REF_CLK_FREQ_G    : real            := 156.25E+6;  -- Support 156.25MHz or 312.5MHz   
      CPLL_REFCLK_SEL_G : slv(2 downto 0) := "001");
   port (
      -- MGT Clock Port (156.25 MHz or 312.5 MHz)
      amcClkP       : in  slv         (1 downto 0);
      amcClkN       : in  slv         (1 downto 0);
      coreClk       : out slv         (1 downto 0);
      gtRefClk      : out slv         (1 downto 0) );
end DtiCPllArray;

architecture mapping of DtiCPllArray is

  constant DIV_C : slv(2 downto 0) := ite((REF_CLK_FREQ_G = 156.25E+6), "000", "001");

  signal amcRefClk     : slv(1 downto 0);
  signal amcRefClkCopy : slv(1 downto 0);
  signal amcCoreClk    : slv(1 downto 0);
  
begin

  coreClk  <= amcCoreClk;
  gtRefClk <= amcRefClk;
  
  GEN_AMC : for j in 0 to 1 generate

    IBUFDS_GTE3_Inst : IBUFDS_GTE3
      generic map (
        REFCLK_EN_TX_PATH  => '0',
        REFCLK_HROW_CK_SEL => "00",    -- 2'b00: ODIV2 = O
        REFCLK_ICNTL_RX    => "00")
      port map (
        I     => amcClkP(j),
        IB    => amcClkN(j),
        CEB   => '0',
        ODIV2 => amcRefClkCopy(j),
        O     => amcRefClk(j));  

    BUFG_GT_Inst : BUFG_GT
      port map (
        I       => amcRefClkCopy(j),
        CE      => '1',
        CEMASK  => '1',
        CLR     => '0',
        CLRMASK => '1',
        DIV     => DIV_C,
        O       => amcCoreClk(j));

  end generate;

end mapping;
