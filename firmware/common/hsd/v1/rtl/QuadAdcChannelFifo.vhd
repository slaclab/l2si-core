-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadAdcChannelFifo.vhd
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
use work.AxiStreamPkg.all;
use work.TimingPkg.all;
use work.QuadAdcPkg.all;

entity QuadAdcChannelFifo is
  generic ( FIFO_ADDR_WIDTH_C : integer := 10 );
  port (
    clk        :  in sl;
    rst        :  in sl;
    start      :  in sl;
    config     :  in QuadAdcConfigType;
    din        :  in Slv11Array(7 downto 0);
    rden       :  in sl;
    rddata     : out Slv11Array(15 downto 0);
    rdlast     : out sl;
    empty      : out sl;
    data_count : out slv(FIFO_ADDR_WIDTH_C-1 downto 0) );
end QuadAdcChannelFifo;

architecture mapping of QuadAdcChannelFifo is

  type RegType is record
    wsel      : integer range 0 to 3;
    wrEn      : slv       (15 downto 0);
    wrData    : Slv11Array(15 downto 0);
    wrLast    : sl;
    rdEn      : sl;
    rdData    : Slv11Array(15 downto 0);
    rdLast    : sl;
    empty     : sl;
  end record;

  constant REG_INIT_C : RegType := (
    wsel      => 0,
    wrEn      => (others=>'0'),
    wrData    => (others=>(others=>'0')),
    wrLast    => '0',
    rdEn      => '0',
    rdData    => (others=>(others=>'0')),
    rdLast    => '0',
    empty     => '1' );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  type PackArray is array(natural range<>) of Slv11Array(15 downto 0);
  signal astart  : slv       (3 downto 0);
  signal awren   : Slv16Array(3 downto 0);
  signal awrdata : PackArray (3 downto 0);
  signal awrlast : slv       (3 downto 0);
  
  signal dout_rd  : Slv11Array(15 downto 0);
  signal dout_last: sl;
  signal iempty   : sl;

begin  -- mapping

  empty  <= r.empty;
  rddata <= r.rdData;
  rdlast <= r.rdLast;

  GEN_FIFO : for i in 0 to 14 generate
    U_FIFO : entity work.FifoSync
      generic map ( DATA_WIDTH_G  => 11,
                    ADDR_WIDTH_G  => FIFO_ADDR_WIDTH_C )
      port map ( rst               => rst,
                 clk               => clk,
                 wr_en             => r.wrEn  (i),
                 din               => r.wrData(i),
                 rd_en             => rin.rdEn,
                 dout              => dout_rd(i),
                 data_count        => open,
                 empty             => open );
  end generate;
  GEN_FIFO_LAST : for i in 15 to 15 generate
    U_FIFO : entity work.FifoSync
      generic map ( DATA_WIDTH_G  => 12,
                    ADDR_WIDTH_G  => FIFO_ADDR_WIDTH_C )
      port map ( rst               => rst,
                 clk               => clk,
                 wr_en             => r.wrEn  (i),
                 din(10 downto 0)  => r.wrData(i),
                 din(11)           => r.wrLast,
                 rd_en             => rin.rdEn,
                 dout(10 downto 0) => dout_rd(i),
                 dout(11)          => dout_last,
                 data_count        => data_count,
                 empty             => iempty );
  end generate;


  U_Div1 : entity work.AdcPackerDivN
    generic map ( SAMPLES  => 8,
                  DIVIDE_C => 1 )
    port map ( clk      => clk,
               rst      => rst,
               start    => astart (0),
               config   => config,
               din      => din,
               wren     => awren  (0),
               dout     => awrdata(0),
               last     => awrlast(0) );
  
  U_Div2 : entity work.AdcPackerDivN
    generic map ( SAMPLES  => 8,
                  DIVIDE_C => 2 )
    port map ( clk      => clk,
               rst      => rst,
               start    => astart (1),
               config   => config,
               din      => din,
               wren     => awren  (1),
               dout     => awrdata(1),
               last     => awrlast(1) );
  
  U_Div4 : entity work.AdcPackerDivN
    generic map ( SAMPLES  => 8,
                  DIVIDE_C => 4 )
    port map ( clk      => clk,
               rst      => rst,
               start    => astart (2),
               config   => config,
               din      => din,
               wren     => awren  (2),
               dout     => awrdata(2),
               last     => awrlast(2) );
  
  U_Div8 : entity work.AdcPackerDiv8N
    port map ( clk      => clk,
               rst      => rst,
               start    => astart (3),
               config   => config,
               din      => din,
               wren     => awren  (3),
               dout     => awrdata(3),
               last     => awrlast(3) );
  
  process (r, start)
  begin
    astart <= (others=>'0');
    astart(r.wsel) <= start;
  end process;
  
  process (r, rst, config, awren, awrdata, awrlast, rden, iempty, dout_rd, dout_last)
    variable v     : RegType;
  begin  -- process
    v := r;

    if config.intlv=Q_ABCD then
      v.wsel     := 0;
    else
      if config.prescale < 2 then
        v.wsel := 0;
      elsif config.prescale < 4 then
        v.wsel := 1;
      elsif config.prescale < 8 then
        v.wsel := 2;
      else
        v.wsel := 3;
      end if;
    end if;

    v.wrEn   := awren  (r.wsel);
    v.wrData := awrdata(r.wsel);
    v.wrLast := awrlast(r.wsel);
    
    v.rdEn := '0';
    
    if r.empty='1' then
      if iempty='0' then
        v.rdEn  := '1';
        v.empty := '0';
      end if;
    elsif rden='1' then
      v.rdData := dout_rd;
      v.rdLast := dout_last;
      if iempty='0' then
        v.rdEn  := '1';
        v.empty := '0';
      else
        v.empty := '1';
      end if;
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
