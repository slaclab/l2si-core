-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : HsdDivClk.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2018-05-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:  
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

entity HsdDivClk is
  generic ( DIV_G : integer := 100 );
  port ( ClkIn   :  in sl;
         RstIn   :  in sl;
         Sync    :  in sl;
         ClkOut  : out slv(1 downto 0);
         Locked  : out sl );
end HsdDivClk;

architecture mapping of HsdDivClk is

  type RegType is record
    state     : sl;
    locked    : sl;
    count     : slv(7 downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    state     => '1',
    locked    => '0',
    count     => (others=>'0') );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

begin

  ClkOut <= r.state & r.state;
  Locked <= r.locked;
  
  process (r, RstIn, Sync)
    variable v     : RegType;
  begin  -- process
    v := r;

    if r.count = DIV_G-1 then
      v.state := not r.state;
      v.count := (others=>'0');
    else
      v.count  := r.count+1;
    end if;
   
    if RstIn='1' or Sync='1' then
      v := REG_INIT_C;
    end if;

    if Sync='1' then
      v.locked := '1';
    end if;
    
    rin <= v;
  end process;

  process (ClkIn)
  begin  -- process
    if rising_edge(ClkIn) then
      r <= rin;
    end if;
  end process;

end mapping;
