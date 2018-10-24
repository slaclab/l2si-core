-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadAdcTrigger.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2018-06-27
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-- Independent channel setup.  Simplified to make reasonable interface
-- for feature extraction algorithms.
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

entity QuadAdcTrigger is
  generic ( NCHAN_C : integer := 1 );
  port ( clk       : in  sl;
         rst       : in  sl;
         trigIn    : in  slv(7 downto 0);
         afullIn   : in  slv(NCHAN_C-1 downto 0);
         config    : in  QuadAdcConfigType;
         l1in      : in  sl;
         l1ina     : in  sl;
         --
         afullOut  : out sl;
         afullCnt  : out slv(31 downto 0);
         ql1in     : out sl;
         ql1ina    : out sl;
         shift     : out slv(2 downto 0);
         clear     : out sl;
         start     : out sl;
         trig      : out Slv8Array(1 downto 0) );
end QuadAdcTrigger;

architecture mapping of QuadAdcTrigger is
  type SyncStateType is (S_SHIFT_S, S_WAIT_S);

  constant TMO_VAL_C : integer := 4095;
  
  type RegType is record
    afull    : sl;
    afullcnt : slv(31 downto 0);
    clear    : sl;
    start    : sl;
    syncState: SyncStateType;
    adcShift : slv(2 downto 0);
    trigd1   : slv(7 downto 0);
    trigd2   : slv(7 downto 0);
    trig     : slv(7 downto 0);
    l1in     : slv(4 downto 0);
    l1ina    : slv(4 downto 0);
    tmo      : integer range 0 to TMO_VAL_C;
  end record;

  constant REG_INIT_C : RegType := (
    afull     => '0',
    afullcnt  => (others=>'0'),
    clear     => '1',
    start     => '0',
    syncState => S_SHIFT_S,
    adcShift  => (others=>'0'),
    trigd1    => (others=>'0'),
    trigd2    => (others=>'0'),
    trig      => (others=>'0'),
    l1in      => (others=>'0'),
    l1ina     => (others=>'0'),
    tmo       => TMO_VAL_C );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

begin

  afullOut  <= r.afull;
  afullCnt  <= r.afullcnt;
  ql1in     <= r.l1in (0);
  ql1ina    <= r.l1ina(0);
  shift     <= r.adcShift;
  clear     <= r.clear;
  start     <= r.start;
  trig(0)   <= r.trig;
  trig(1)   <= r.trigd2;

  process (r, rst, trigIn, afullIn, config,
           l1in, l1ina) is
    variable v   : RegType;
    variable tshift : integer;
  begin  -- process
    v := r;

    v.trigd1  := trigIn;
    case config.trigShift(1 downto 0) is
      when "00" => v.trigd2 := r.trigd1;
      when "01" => v.trigd2 := trigIn(0 downto 0) & r.trigd1(7 downto 1);
      when "10" => v.trigd2 := trigIn(1 downto 0) & r.trigd1(7 downto 2);
      when "11" => v.trigd2 := trigIn(2 downto 0) & r.trigd1(7 downto 3);
      when others => null;
    end case;
    v.trig   := r.trigd2;
    
    v.afull        := uOr(afullIn);
    if r.afull='1' then
      v.afullcnt := r.afullcnt+1;
    end if;
    
    v.l1in    := l1in  & r.l1in (r.l1in 'left downto 1);
    v.l1ina   := l1ina & r.l1ina(r.l1ina'left downto 1);
    

    v.clear := not config.acqEnable;
    
    v.start := '0';
    case (r.syncState) is
      when S_SHIFT_S =>
        if r.trigd2/=toSlv(0,8) then
          v.start := config.acqEnable;
          if r.trigd2(3 downto 0)/=0 then
            v.adcShift := toSlv(0,3);
          else
            v.adcShift := toSlv(4,3);
          end if;
         
          v.syncState := S_WAIT_S;
        end if;
      when S_WAIT_S =>
        if r.trigd2=toSlv(0,8) then
          v.syncState := S_SHIFT_S;
        end if;
      when others => NULL;
    end case;

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
