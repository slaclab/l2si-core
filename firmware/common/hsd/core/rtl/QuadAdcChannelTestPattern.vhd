-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadAdcChannelTestPattern.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2017-03-13
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
--   Consider having two data formats: one for multi-channels over a certain
--   length and one for single channel any length or multi-channel under a
--   certain length.  The first would be interleaved allowing minimal buffering.
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

entity QuadAdcChannelTestPattern is
  generic (
    CHANNEL_C : integer range 0 to 7 );
  port (
    clk        :  in sl;
    rst        :  in sl;
    data       : out Slv11Array(7 downto 0) );
end QuadAdcChannelTestPattern;

architecture mapping of QuadAdcChannelTestPattern is

  type RegType is record
    count    : integer range 0 to 255;
    data     : Slv11Array(7 downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    count    => 0,
    data     => (others=>(others=>'0')) );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

begin  -- mapping

  data <= r.data;

  process (r, rst)
    variable v   : RegType;
  begin  -- process
    v := r;

    for i in 0 to 7 loop
      v.data(i)(10 downto 8) := toSlv(CHANNEL_C,3);
      v.data(i)( 7 downto 0) := toSlv(r.count+i,8);
    end loop;
    v.count := r.count+8;
    
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
