-------------------------------------------------------------------------------
-- Title      : SyncDivider
-------------------------------------------------------------------------------
-- File       : SyncDivider.vhd
-- Author     : Matt Weaver  <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-15
-- Last update: 2019-02-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Generates a single clk pulse at a prescaled rate of sysClk.
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 Timing Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 Timing Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
LIBRARY ieee;
use work.all;
use work.StdRtlPkg.all;

USE ieee.std_logic_1164.ALL;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity SyncDivider is
   generic ( TPD_G    : time    := 1 ns; Width    : integer := 4 );
   port ( 
      -- Clock and reset
      sysClk             : in  std_logic;
      sync               : in  std_logic;  -- starts trigO on next clock
      enable             : in  std_logic;
      divisor            : in  std_logic_vector(Width-1 downto 0);
      trigO              : out std_logic
      );
end SyncDivider;

-- Define architecture for top level module
architecture SyncDivider of SyncDivider is 

  type RegType is record
    count    : slv(Width-1 downto 0);
    trig     : sl;
  end record;
  constant REG_INIT_C : RegType := (
    count    => (others=>'0'),
    trig     => '0');

  signal r    : RegType := REG_INIT_C;
  signal rin  : RegType;

begin

  trigO <= r.trig;
  
  comb: process (r, enable, sync, divisor) is
    variable v : RegType;
  begin
    v := r;

    v.trig := '0';
    
    if (enable='1') then
      if (r.count=divisor) then
        v.count := toSlv(1,Width);
        v.trig  := '1';
      elsif (sync='1') then
        v.count := divisor;
      else
        v.count := r.count+1;
      end if;
    end if;

    rin <= v;
  end process comb;

  seq: process (sysClk) is
  begin
     if rising_edge(sysClk) then
       r <= rin after TPD_G;
     end if;
  end process seq;

end SyncDivider;
