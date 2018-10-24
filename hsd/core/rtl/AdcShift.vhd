-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AdcShift.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2016-12-16
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:  Presamples data.  DIVIDE_C must be an integer factor of SAMPLES.
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 Timing Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 Timing Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.NUMERIC_STD.all;

use work.StdRtlPkg.all;
use work.QuadAdcPkg.all;

entity AdcShift is
  port (
    clk        :  in  sl;
    rst        :  in  sl;
    shift      :  in  slv(2 downto 0);
    din        :  in  slv(7 downto 0);
    dout       :  out slv(7 downto 0) );
end AdcShift;

architecture mapping of AdcShift is

  type RegType is record
    dataIn    : slv(7 downto 0);
    dataOut   : slv(7 downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    dataIn    => (others=>'0'),
    dataOut   => (others=>'0') );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

begin

  dout <= r.dataOut;
  
  process (r, rst, din, shift)
    variable v : RegType;
    variable d : slv(15 downto 0);
    variable i : integer;
  begin  -- process
    v := r;

    d := din & r.dataIn;
    i := conv_integer(shift);
    v.dataOut := d(i+7 downto i);
    v.dataIn  := d(15 downto 8);

    if rst='1' then
      v := REG_INIT_C;
    end if;
    
    rin <= v;
  end process;

  process (clk)
  begin  -- process
    if rising_edge(clk) then
      r <= rin;
    end if;
  end process;

end mapping;
