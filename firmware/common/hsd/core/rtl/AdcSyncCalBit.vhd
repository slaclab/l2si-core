-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AdcSyncCalBit.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2017-03-13
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

entity AdcSyncCalBit is
  generic (
    SYNC_PERIOD_G : integer := 147;
    DEBUG_G       : boolean := false );
  port (
    -- AXI-Lite Interface
    syncClk             : in  sl;
    enable              : in  sl;
    sync                : in  slv(7 downto 0);
    match               : out sl );
end AdcSyncCalBit;

architecture mapping of AdcSyncCalBit is

  type MatchStateType is (SS_IDLE, SS_INIT, SS_WAIT, SS_TEST, SS_CALC);
  type RegType is record
    state : MatchStateType;
    last  : slv(2 downto 0);
    count : slv(bitSize(SYNC_PERIOD_G+8)-1 downto 0);
    match : sl;
  end record;
  constant REG_INIT_C : RegType := (
    state => SS_IDLE,
    last  => (others=>'0'),
    count => (others=>'0'),
    match => '0' );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal s : slv(2 downto 0);

begin

  match <= r.match;
  
  comb : process ( r, sync, enable ) is
    variable v  : RegType;
  begin
    v := r;

    case r.state is
      when SS_IDLE =>
        if enable='1' then
          v.state := SS_INIT;
        end if;
      when SS_INIT => 
        if sync/=toSlv(0,8) then
          for i in 7 downto 0 loop
            if sync(i)='1' then
              v.last := toSlv(i,3);
            end if;
          end loop;
          v.count := toSlv(8,r.count'length);
          v.match := '1';
          v.state := SS_WAIT;
        end if;
      when SS_WAIT =>
        v.count := r.count+8;
        if sync=toSlv(0,8) then
          v.state := SS_TEST;
        end if;
      when SS_TEST =>
        if sync/=toSlv(0,8) then
          for i in 7 downto 0 loop
            if sync(i)='1' then
              v.count := r.count + toSlv(i,r.count'length);
            end if;
          end loop;
          v.state := SS_CALC;
        else
          v.count := r.count+8;
        end if;
      when SS_CALC =>
        if r.count/=r.last+toSlv(SYNC_PERIOD_G,r.count'length) then
          v.match := '0';
        end if;
        v.last  := r.count(2 downto 0);
        v.count := toSlv(16,r.count'length);
        v.state := SS_WAIT;
      when others => NULL;
    end case;
    
    if enable='0' then
      v.state := SS_IDLE;
    end if;

    rin <= v;
  end process comb;
  
  seq: process ( syncClk ) is
  begin
    if rising_edge(syncClk) then
      r <= rin;
    end if;
  end process seq;

end mapping;
