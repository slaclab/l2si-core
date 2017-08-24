-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadAdcChannelFifov2.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2017-08-23
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
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
--use work.TimingPkg.all;
use work.QuadAdcPkg.all;
use work.QuadAdcCompPkg.all;

entity FexGate is
  port (
    clk             :  in sl;
    rst             :  in sl;
    start           :  in sl;
    handle          :  in sl;
    fbegin          :  in slv(13 downto 0);
    flength         :  in slv(13 downto 0);
    lopen           : out sl;
    lhandle         : out sl;
    lclose          : out sl );
end FexGate;

architecture rtl of FexGate is
  type StateType is ( CLOSED_S, WAIT_S, OPEN_S );
  type L0StateType is record
    state  : StateType;
    count  : slv(13 downto 0);
    handle : sl;
  end record;
  constant L0STATE_INIT_C : L0StateType := (
    state  => CLOSED_S,
    count  => (others=>'0'),
    handle => '0' );
  type L0StateArray  is array(natural range<>) of L0StateType;

  type RegType is record
    count      : slv(13 downto 0);
    l0         : L0StateArray(15 downto 0);
    iclosed    : slv(3 downto 0);
    iwait      : slv(3 downto 0);
    iopen      : slv(3 downto 0);
    lopen      : sl;
    lclose     : sl;
    lhandle    : sl;
  end record;

  constant REG_INIT_C : RegType := (
    count      => (others=>'0'),
    l0         => (others=>L0STATE_INIT_C),
    iclosed    => (others=>'0'),
    iwait      => (others=>'0'),
    iopen      => (others=>'0'),
    lopen      => '0',
    lclose     => '0',
    lhandle    => '0' );
  
  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;

begin 

  process (r, rst, start, handle, fbegin, flength) is
    variable v  : RegType;
    variable i  : integer;
  begin
    v := r;
    v.lopen   := '0';
    v.lclose  := '0';
    v.lhandle := '0';

    v.count := r.count+1;
    
    -- Feature extraction window
    if start = '1' then
      i := conv_integer(r.iclosed);
      v.l0(i).state := WAIT_S;
      v.l0(i).count := r.count + fbegin + 1;
      v.l0(i).handle := handle;
      v.iclosed := r.iclosed+1;
    end if;

    i := conv_integer(r.iwait);
    if (r.l0(i).state = WAIT_S and
        r.l0(i).count = r.count) then
      v.lopen       := '1';
      v.lhandle     := r.l0(i).handle;
      v.l0(i).state := OPEN_S;
      v.l0(i).count := r.count + flength;
      v.iwait := r.iwait+1;
    end if;
    
    i := conv_integer(r.iopen);
    if (r.l0(i).state = OPEN_S and
        r.l0(i).count = r.count) then
      v.lclose      := '1';
      v.l0(i).state := CLOSED_S;
      v.iopen := r.iopen+1;
    end if;
    
    if rst='1' then
      v := REG_INIT_C;
    end if;
    
    r_in <= v;

    lopen   <= r.lopen;
    lclose  <= r.lclose;
    lhandle <= r.lhandle;
  end process;

  process (clk)
  begin  -- process
    if rising_edge(clk) then
      r <= r_in;
    end if;
  end process;

end rtl;
