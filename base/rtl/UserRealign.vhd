-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : UserRealign.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2019-09-18
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- This module produces a realigned timing header and expt bus.
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 DAQ Software'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 DAQ Software', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- surf
use work.StdRtlPkg.all;

-- l2si
use work.L2SiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity UserRealign is
   generic (
      TPD_G   : time    := 1 ns;
      WIDTH_G : integer := 1);
   port (
      rst               : in  sl;
      clk               : in  sl;
      delay             : in  slv(6 downto 0);
      timingHeader      : in  TimingHeaderType;
      userTiming        : in  slv(WIDTH_G-1 downto 0) := (others => '0');
      alignedUserTiming : out slv(WIDTH_G-1 downto 0));
end UserRealign;

architecture rtl of UserRealign is

   type RegType is record
      rden   : sl;
      rdaddr : slv(6 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      rden   => '0',
      rdaddr => (others => '0'));

   signal r    : RegType := REG_INIT_C;
   signal r_in : RegType;

begin

   U_Ram : entity work.SimpleDualPortRam
      generic map (
         DATA_WIDTH_G => WIDTH_G,
         ADDR_WIDTH_G => 7)
      port map (
         clka  => clk,
         ena   => '1',
         wea   => timingHeader.strobe,
         addra => timingHeader.pulseId(6 downto 0),
         dina  => userTimingI,
         clkb  => clk,
         rstb  => rst,
         enb   => r.rden,
         addrb => r.rdaddr,
         doutb => alignedUserTiming);

   comb : process(r, rst, timingHeader, delay) is
      variable v : RegType;
   begin
      v := r;

      v.rden := '0';

      if timingHeader.strobe = '1' then
         v.rden   := '1';
         v.rdaddr := timingHeader.pulseId(6 downto 0) + delay;
      end if;

      if rst = '1' then
         v := REG_INIT_C;
      end if;

      r_in <= v;
   end process;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= r_in;
      end if;
   end process;

end rtl;
