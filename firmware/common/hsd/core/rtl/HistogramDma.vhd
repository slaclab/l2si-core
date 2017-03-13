-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : HistogramDma.vhd
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
use work.AxiStreamPkg.all;
use work.QuadAdcPkg.all;

entity HistogramDma is
  generic (
    TPD_G           : time    := 1 ns;
    STREAM_WIDTH_G  : integer := 256;
    INPUT_DEPTH_G   : integer := 4;
    OUTPUT_DEPTH_G  : integer := 4 );
  port (
    clk              : in  sl;
    rst              : in  sl;
    valid            : in  sl;
    push             : in  sl;
    data             : in  slv(INPUT_DEPTH_G-1 downto 0);
    master           : out AxiStreamMasterType;
    slave            : in  AxiStreamSlaveType );
end HistogramDma;

architecture mapping of HistogramDma is

  constant DATA_WIDTH_G    : integer := 32;
  
  type StateType is (IDLE_S, READ_S, WRITE_S, DUMPHDR_S, DUMPDATA_S);
  
  type RegType is record
    state  : StateType;
    value  : slv(INPUT_DEPTH_G-1 downto 0);
    addra  : slv(OUTPUT_DEPTH_G-1 downto 0);
    addrb  : slv(OUTPUT_DEPTH_G-1 downto 0);
    en     : sl;
    wea    : sl;
    din    : slv(DATA_WIDTH_G-1 downto 0);
    master : AxiStreamMasterType;
  end record;
  constant REG_INIT_C : RegType := (
    state          => IDLE_S,
    value          => (others=>'0'),
    addra          => (others=>'0'),
    addrb          => (others=>'0'),
    en             => '0',
    wea            => '0',
    din            => (others=>'0'),
    master         => AXI_STREAM_MASTER_INIT_C );

  constant END_ADDR : slv(OUTPUT_DEPTH_G-1 downto 0) := (others=>'1');
  
  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal dout : slv(DATA_WIDTH_G-1 downto 0);

begin  -- mapping

  master <= r.master;

  U_RAM : entity work.SimpleDualPortRam
    generic map ( DATA_WIDTH_G => DATA_WIDTH_G,
                  ADDR_WIDTH_G => OUTPUT_DEPTH_G )
    port map ( clka   => clk,
               ena    => r.en,
               wea    => r.wea,
               addra  => r.addra,
               dina   => r.din,
               clkb   => clk,
               enb    => r.en,
               addrb  => r.addrb,
               doutb  => dout );
  
  process (clk)
  begin  -- process
    if rising_edge(clk) then
      r <= rin;
    end if;
  end process;

  process (r,rst,valid,push,data,dout,slave) is
    variable v : RegType;
  begin  -- process
    v  := r;

    v.din := (others=>'0');
    v.wea := '0';
    
    if slave.tReady='1' then
      v.master.tValid := '0';
    end if;

    v.master.tKeep := genTKeep(4);

    if data>r.value then
      v.value := data;
    end if;
    
    case r.state is
      when IDLE_S =>
        if push='1' then
          v.addra := (others=>'0');
          v.addrb := (others=>'0');
          v.en    := '1';
          if v.master.tValid='0' then
            v.master.tValid := '1';
            v.master.tLast  := '0';
            v.master.tData(31 downto 0)  := x"00000002";
            v.master.tData(OUTPUT_DEPTH_G) := '1';
            v.state := DUMPHDR_S;
          end if;
        elsif valid='1' then
          v.addrb := r.value(r.value'left downto INPUT_DEPTH_G-OUTPUT_DEPTH_G);
          v.value := (others=>'0');
          v.en    := '1';
          v.state := READ_S;
        else
          v.en     := '0';
        end if;
      when READ_S =>
        v.state := WRITE_S;
      when WRITE_S =>
        v.addra := r.addrb;
        v.din   := dout+1;
        v.wea   := '1';
        v.state := IDLE_S;
      when DUMPHDR_S =>
        if v.master.tValid='0' then
          v.master.tValid := '1';
          v.master.tData(31 downto 0)  := x"0000" & QUAD_ADC_DIAG_TAG;
          v.addra  := r.addrb;
          v.addrb  := r.addrb+1;
          v.wea    := '1';
          v.state  := DUMPDATA_S;
        end if;
      when DUMPDATA_S =>
        if v.master.tValid='0' then
          v.master.tValid := '1';
          v.master.tData(31 downto 0) := dout;
          v.addra  := r.addrb;
          v.addrb  := r.addrb+1;
          v.wea    := '1';
          if r.addrb=END_ADDR then
            v.master.tLast := '1';
            v.state        := IDLE_S;
          end if;
        end if;
      when others => NULL;
    end case;

    if rst='1' then
      v := REG_INIT_C;
    end if;
    
    rin <= v;
  end process;

end mapping;
