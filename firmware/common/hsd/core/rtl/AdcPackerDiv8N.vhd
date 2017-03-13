-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AdcPackerDiv8N.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2016-12-14
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
use work.QuadAdcPkg.all;

entity AdcPackerDiv8N is
  port (
    clk        :  in sl;
    rst        :  in sl;
    start      :  in sl;
    config     :  in QuadAdcConfigType;
    din        :  in Slv11Array( 7 downto 0);
    wren       : out slv       (15 downto 0);
    dout       : out Slv11Array(15 downto 0);
    last       : out sl );
end AdcPackerDiv8N;

architecture mapping of AdcPackerDiv8N is

  type RegType is record
    running   : sl;
    nwrite    : slv(config.samples'left-4 downto 0);
    count     : slv(config.samples'range);
    idx       : slv(3 downto 0);
    wrData    : Slv11Array(15 downto 0);
    wrEn      : slv       (15 downto 0);
    wrLast    : sl;
  end record;

  constant REG_INIT_C : RegType := (
    running   => '0',
    nwrite    => (others=>'0'),
    count     => (others=>'0'),
    idx       => (others=>'0'),
    wrData    => (others=>(others=>'0')),
    wrEn      => (others=>'0'),
    wrLast    => '0' );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

begin

  wren <= r.wrEn;
  dout <= r.wrData;
  last <= r.wrLast;
  
  process (r, rst, config, start, din)
    variable v     : RegType;
    variable i,j   : integer range 0 to 15;
  begin  -- process
    v := r;

    v.wrEn   := (others=>'0');
    v.wrLast := '0';
    
    if r.running='1' then
      if (r.count=toSlv(0,r.count'length)) then
        j := conv_integer(r.idx);
        if din(0)(10)='0' then
          v.wrData(j) := din(0);
        elsif din(0)(9)='0' then
          v.wrData(j) := "00000000000";
        else
          v.wrData(j) := "10000000000";
        end if;
        
        v.wrEn  (j)     := '1';
        v.idx           := r.idx+1;
        v.count         := toSlv((conv_integer(config.prescale)-1)/8,r.count'length);
      else
        v.count         := r.count-1;
      end if;
      
      if v.wrEn(15)='1' then
        if r.nwrite=1 then
          v.wrLast  := '1';
          v.running := '0';
        else
          v.nwrite := r.nwrite-1;
        end if;
      end if;
    end if;

    if start='1' then
      v.running := '1';
      v.idx     := (others=>'0');
      v.nwrite  := config.samples(config.samples'left downto 4);
      v.count   := (others=>'0');
    end if;
   
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
