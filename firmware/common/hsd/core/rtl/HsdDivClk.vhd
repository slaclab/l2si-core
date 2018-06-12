-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : HsdDivClk.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2018-06-03
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
  generic ( DIV_G  : integer := 100;
            HALF_G : boolean := false );
  port ( ClkIn   :  in sl;
         RstIn   :  in sl;
         Sync    :  in sl;
         ClkOut  : out slv(1 downto 0);
         Locked  : out sl );
end HsdDivClk;

architecture mapping of HsdDivClk is

  constant CWIDTH_C : integer := bitSize(DIV_G-1);
    
  type RegType is record
    sync      : slv(1 downto 0);
    state     : sl;
    locked    : sl;
    count     : slv(CWIDTH_C-1 downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    sync      => (others=>'1'),
    state     => '1',
    locked    => '0',
    count     => (others=>'0') );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal Clk, Rst, bLocked : sl;
  
  component ila_0
    port ( clk   : in sl;
           probe0 : in slv(255 downto 0) );
  end component;

  constant DEBUG_C : boolean := false;
  
begin

  GEN_DEBUG : if DEBUG_C generate
    U_ILA : ila_0
      port map ( clk       => Clk,
                 probe0(0) => Rst,
                 probe0(1) => Sync,
                 probe0(2) => r.state,
                 probe0(3) => r.locked,
                 probe0(4) => bLocked,
                 probe0(12 downto 5) => resize(r.count,8),
                 probe0(255 downto 13) => (others=>'0') );
  end generate;

  GEN_CLKx2 : if HALF_G generate
    U_MMCM : entity work.ClockManagerUltrascale
      generic map ( INPUT_BUFG_G     => false,
                    NUM_CLOCKS_G     => 1,
                    CLKIN_PERIOD_G   => 5.4,
                    CLKFBOUT_MULT_G  => 6,
                    CLKOUT0_DIVIDE_G => 3 )
      port map ( clkIn     => ClkIn,
                 rstIn     => RstIn,
                 clkOut(0) => Clk,
                 rstOut(0) => Rst,
                 locked    => bLocked );
  end generate;

  NOGEN_CLK : if not HALF_G generate
    Clk     <= ClkIn;
    Rst     <= RstIn;
    bLocked <= '1';
  end generate;
  
  ClkOut <= r.state & r.state;
  Locked <= r.locked;
  
  process (r, Rst, Sync, bLocked)
    variable v     : RegType;
  begin  -- process
    v := r;

    if r.count = DIV_G-1 then
      v.state := not r.state;
      v.count := (others=>'0');
    else
      v.count  := r.count+1;
    end if;

    if r.sync="01" then
      v := REG_INIT_C;
      v.locked := bLocked;
    end if;

    v.sync := r.sync(0) & Sync;
    
    rin <= v;
  end process;

  process (Clk)
  begin  -- process
    if rising_edge(Clk) then
      r <= rin;
    end if;
  end process;

end mapping;
