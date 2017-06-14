-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DtiQuadPllArray.vhd
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

entity DtiQuadPllArray is
   generic (
      TPD_G             : time            := 1 ns;
      REF_CLK_FREQ_G    : real            := 156.25E+6;  -- Support 156.25MHz or 312.5MHz   
      QPLL_REFCLK_SEL_G : slv(2 downto 0) := "001");
   port (
      -- MGT Clock Port (156.25 MHz or 312.5 MHz)
      amcClkP       : in  slv         (1 downto 0);
      amcClkN       : in  slv         (1 downto 0);
      amcRst        : in  Slv2Array   (1 downto 0);
      amcQuad       : out AmcQuadArray(1 downto 0) );
end DtiQuadPllArray;

architecture mapping of DtiQuadPllArray is

  constant DIV_C : slv(2 downto 0) := ite((REF_CLK_FREQ_G = 156.25E+6), "000", "001");

  signal amcRefClk     : slv(1 downto 0);
  signal amcRefClkCopy : slv(1 downto 0);
  signal amcCoreClk    : slv(1 downto 0);
  
begin

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

    GEN_TENGIGCLK : for i in 0 to 1 generate

      amcQuad(j)(i).amcClk <= amcCoreClk(j);

      GthUltraScaleQuadPll_Inst : entity work.GthUltraScaleQuadPll
        generic map (
          -- Simulation Parameters
          TPD_G               => TPD_G,
          SIM_RESET_SPEEDUP_G => "FALSE",
          SIM_VERSION_G       => 2,
          -- QPLL Configuration Parameters
          QPLL_CFG0_G         => (others => x"301C"),
          QPLL_CFG1_G         => (others => x"0018"),
          QPLL_CFG1_G3_G      => (others => x"0018"),
          QPLL_CFG2_G         => (others => x"0048"),
          QPLL_CFG2_G3_G      => (others => x"0048"),
          QPLL_CFG3_G         => (others => x"0120"),
          QPLL_CFG4_G         => (others => x"0009"),
          QPLL_CP_G           => (others => "0000011111"),
          QPLL_CP_G3_G        => (others => "1111111111"),
          QPLL_FBDIV_G        => (others => 66),
          QPLL_FBDIV_G3_G     => (others => 80),
          QPLL_INIT_CFG0_G    => (others => x"0000"),
          QPLL_INIT_CFG1_G    => (others => x"00"),
          QPLL_LOCK_CFG_G     => (others => x"25E8"),
          QPLL_LOCK_CFG_G3_G  => (others => x"25E8"),
          QPLL_LPF_G          => (others => "1111111111"),
          QPLL_LPF_G3_G       => (others => "0000010101"),
          QPLL_REFCLK_DIV_G   => (others => 1),
          QPLL_SDM_CFG0_G     => (others => x"0000"),
          QPLL_SDM_CFG1_G     => (others => x"0000"),
          QPLL_SDM_CFG2_G     => (others => x"0000"),
          -- Clock Selects
          QPLL_REFCLK_SEL_G   => (others => "001"))
        port map (
          qPllRefClk(0)     => amcRefClk(j),
          qPllRefClk(1)     => '0',
          qPllOutClk(0)     => amcQuad(j)(i).qplloutclk,
          qPllOutClk(1)     => open,
          qPllOutRefClk(0)  => amcQuad(j)(i).qplloutrefclk,
          qPllOutRefClk(1)  => open,
          qPllLock(0)       => amcQuad(j)(i).qplllock,
          qPllLock(1)       => open,
          qPllLockDetClk(0) => '0',   -- IP Core ties this to GND (see note below) 
          qPllLockDetClk(1) => '0',   -- IP Core ties this to GND (see note below) 
          qPllPowerDown(0)  => '0',
          qPllPowerDown(1)  => '1',
          qPllReset(0)      => amcRst(j)(i),
          qPllReset(1)      => '1'); 

    end generate;
  end generate;

end mapping;
