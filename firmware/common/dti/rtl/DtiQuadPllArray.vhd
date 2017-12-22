-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DtiQuadPllArray.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-08
-- Last update: 2017-11-15
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
      amcClkP       : in  sl;
      amcClkN       : in  sl;
      amcTxP        : out slv(6 downto 0);
      amcTxN        : out slv(6 downto 0);
      amcRxP        : in  slv(6 downto 0);
      amcRxN        : in  slv(6 downto 0);
      -- channel ports
      chanPllRst    : in  slv(6 downto 0);
      chanTxP       : in  slv(6 downto 0);
      chanTxN       : in  slv(6 downto 0);
      chanRxP       : out slv(6 downto 0);
      chanRxN       : out slv(6 downto 0);
      chanQuad      : out QuadArray(6 downto 0) );
end DtiQuadPllArray;

architecture mapping of DtiQuadPllArray is

  constant DIV_C : slv(2 downto 0) := ite((REF_CLK_FREQ_G = 156.25E+6), "000", "001");

  signal amcRefClk     : sl;
  signal amcRefClkCopy : sl;
  signal amcCoreClk    : sl;
  signal amcQuad       : QuadArray(1 downto 0);
  signal qplloutclk    : slv(1 downto 0);
  signal qplloutrefclk : slv(1 downto 0);
  signal qplllock      : slv(1 downto 0);
  signal qpllRst       : slv(1 downto 0);
  signal qpllRstI      : Slv4Array(1 downto 0) := (others=>x"0");
begin

    IBUFDS_GTE3_Inst : IBUFDS_GTE3
      generic map (
        REFCLK_EN_TX_PATH  => '0',
        REFCLK_HROW_CK_SEL => "00",    -- 2'b00: ODIV2 = O
        REFCLK_ICNTL_RX    => "00")
      port map (
        I     => amcClkP,
        IB    => amcClkN,
        CEB   => '0',
        ODIV2 => amcRefClkCopy,
        O     => amcRefClk);  

    BUFG_GT_Inst : BUFG_GT
      port map (
        I       => amcRefClkCopy,
        CE      => '1',
        CEMASK  => '1',
        CLR     => '0',
        CLRMASK => '1',
        DIV     => DIV_C,
        O       => amcCoreClk);

    GEN_TENGIGCLK : for i in 0 to 1 generate

      amcQuad(i).coreClk <= amcCoreClk;
      amcQuad(i).refClk  <= amcRefClk;
      
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
          qPllRefClk(0)     => amcRefClk,
          qPllRefClk(1)     => '0',
          qPllOutClk(0)     => amcQuad(i).qplloutclk,
          qPllOutClk(1)     => open,
          qPllOutRefClk(0)  => amcQuad(i).qplloutrefclk,
          qPllOutRefClk(1)  => open,
          qPllLock(0)       => amcQuad(i).qplllock,
          qPllLock(1)       => open,
          qPllLockDetClk(0) => '0',   -- IP Core ties this to GND (see note below) 
          qPllLockDetClk(1) => '0',   -- IP Core ties this to GND (see note below) 
          qPllPowerDown(0)  => '0',
          qPllPowerDown(1)  => '1',
          qPllReset(0)      => qpllRst(i),
          qPllReset(1)      => '1'); 

    end generate;
  --
  --  The AMC SFP channels are reordered - the mapping to MGT quads is non-trivial
  --    amcTx/Rx indexed by MGT
  --    iamcTx/Rx indexed by SFP
  --
  reorder_p : process (amcRxP,amcRxN,chanTxP,chanTxN,
                       amcCoreClk,amcRefClk,qpllRstI,chanPllRst,amcQuad) is
  begin
    qpllRst(0) <= uOr(qpllRstI(0));
    qpllRst(1) <= uOr(qpllRstI(1));
    for j in 0 to 3 loop
      amcTxP    (j)   <= chanTxP(j+2);
      amcTxN    (j)   <= chanTxN(j+2);
      chanRxP   (j+2) <= amcRxP(j);
      chanRxN   (j+2) <= amcRxN(j);
      qpllRstI(0)(j) <= chanPllRst(j+2);
      chanQuad  (j+2) <= amcQuad(0);
    end loop;
    for j in 4 to 5 loop
      amcTxP    (j)   <= chanTxP(j-4);
      amcTxN    (j)   <= chanTxN(j-4);
      chanRxP   (j-4) <= amcRxP(j);
      chanRxN   (j-4) <= amcRxN(j);
      qpllRstI(1)(j-4) <= chanPllRst(j-4);
      chanQuad  (j-4) <= amcQuad(1);
    end loop;
    for j in 6 to 6 loop
      amcTxP    (j) <= chanTxP(j);
      amcTxN    (j) <= chanTxN(j);
      chanRxP   (j) <= amcRxP(j);
      chanRxN   (j) <= amcRxN(j);
      qpllRstI(1)(j-4) <= chanPllRst(j-4);
      chanQuad  (j) <= amcQuad(1);
    end loop;
  end process;

end mapping;
