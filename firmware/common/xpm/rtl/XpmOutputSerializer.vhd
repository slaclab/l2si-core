-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : XpmOutputSerializer.vhd
-- Author     : Matt Weaver
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-12-14
-- Last update: 2016-09-03
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Firmware Target's Top Level
-- 
-- Note: Common-to-Application interface defined here (see URL below)
--       https://confluence.slac.stanford.edu/x/rLyMCw
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
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.TimingPkg.all;
use work.XpmPkg.all;

entity XpmOutputSerializer is
  port (
    clk              : in  sl;
    rst              : in  sl;
    fiducial         : in  sl;
    addrStrobe       : out sl;
    partStrobe       : out sl;
    partIndex        : out slv( 2 downto 0);
    l0Accept         : in  slv       (NPartitions-1 downto 0);
    l0Tag            : in  Slv8Array (NPartitions-1 downto 0);
    l1Out            : in  slv       (NPartitions-1 downto 0);
    l1Accept         : in  slv       (NPartitions-1 downto 0);
    l1Tag            : in  Slv8Array (NPartitions-1 downto 0);
    analysisTag      : in  Slv32Array(NPartitions-1 downto 0);
    advance          : in  sl;
    stream           : out TimingSerialType;
    streamId         : out slv(3 downto 0) );
end XpmOutputSerializer;

architecture rtl of XpmOutputSerializer is
  
  type PState is (IDLE_S, PTRIG_S, PANA_S);
  type RegType is
  record
    state        : PState;
    ready        : sl;
    index        : integer;
    addrStrobe   : sl;
  end record;
  
  constant REG_INIT_C : RegType := (
    state        => IDLE_S,
    ready        => '0',
    index        => 0,
    addrStrobe   => '0');
  
  signal r         : RegType := REG_INIT_C;
  signal rin       : RegType;
  signal i         : integer;
  
begin
  
  i             <= r.index;
  streamId      <= EXPT_STREAM_ID;
  stream.ready  <= r.ready;
  stream.data   <= toSlvT(l0Accept(i), l0Tag(i), l1Out(i),
                          l1Accept(i), l1Tag(i)) when r.state=PTRIG_S else
                   analysisTag(i)(15 downto 0) when r.state=PANA_S else
                   x"ffff";
  
  stream.offset <= (others=>'0');
  stream.last   <= '1';
  
  addrStrobe    <= r.addrStrobe;
  partStrobe    <= '1' when (advance='1' and (r.state=IDLE_S or r.state=PANA_S)) else '0';
  partIndex     <= toSlv(rin.index,3);
  
  comb: process (r, advance) is
    variable v : RegType;
  begin
    v := r;
    v.ready := '1';
    v.addrStrobe := '0';
    
    case (r.state) is
      when IDLE_S =>
        v.index   := 0;
        if (advance='1') then
          v.addrStrobe := '1';
          v.state   := PTRIG_S;
        end if;
      when PTRIG_S =>
        v.state   := PANA_S;
      when PANA_S =>
        if (r.index /= 7) then
          v.index   := r.index+1;
          v.state   := PTRIG_S;
        else
          v.ready   := '0';
          v.state   := IDLE_S;
        end if;
      when others => null;
    end case;
    
    rin <= v;
  end process comb;
  
  seq: process (clk) is
  begin
    if rising_edge(clk) then
      r <= rin;
    end if;
  end process seq;
end rtl;
