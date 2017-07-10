-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DtiHeaderCache.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2017-07-08
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
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

use work.StdRtlPkg.all;
use work.ArbiterPkg.all;
use work.TimingPkg.all;
use work.XpmPkg.all;
use work.DtiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity DtiHeaderCache is
   generic (
      TPD_G               : time                := 1 ns );
   port (
     rst             : in  sl;
     --  Cache Input
     wrclk           : in  sl;
     enable          : in  sl;
     timingBus       : in  TimingBusType;
     exptBus         : in  ExptBusType;
     partition       : in  slv(2 downto 0);
     l0delay         : in  slv(7 downto 0);
     pdata           : out XpmPartitionDataType;
     pdataV          : out sl;
     cntL0           : out slv(19 downto 0);
     cntL1A          : out slv(19 downto 0);
     cntL1R          : out slv(19 downto 0);
     --  Cache Output
     rdclk           : in  sl;
     entag           : in  sl;
     l0tag           : in  slv(4 downto 0);
     advance         : in  sl;
     hdrOut          : out DtiEventHeaderType );
end DtiHeaderCache;

architecture rtl of DtiHeaderCache is

  type WrRegType is record
    rden   : sl;
    wren   : sl;
    rdaddr : slv(7 downto 0);
    pword  : XpmPartitionDataType;
    pwordV : sl;
    cntL0  : slv(19 downto 0);
    cntL1A : slv(19 downto 0);
    cntL1R : slv(19 downto 0);
  end record;

  constant WR_REG_INIT_C : WrRegType := (
    rden   => '0',
    wren   => '0',
    rdaddr => (others=>'0'),
    pword  => XPM_PARTITION_DATA_INIT_C,
    pwordV => '0',
    cntL0  => (others=>'0'),
    cntL1A => (others=>'0'),
    cntL1R => (others=>'0') );

  signal wr    : WrRegType := WR_REG_INIT_C;
  signal wr_in : WrRegType;
  
  signal wrrst, rdrst : sl;
  signal entagw, entagr : sl;
  signal daddr        : slv(  4 downto 0);
  signal doutf        : slv(  4 downto 0);
  signal dout         : slv(127 downto 0);
  signal doutb        : slv(159 downto 0);
  signal il1a         : sl;
  signal sdelay       : slv(l0delay'range);
  signal spartition   : slv(partition'range);

begin

  pdata            <= wr.pword;
  pdataV           <= wr.pwordV;
  cntL0            <= wr.cntL0;
  cntL1A           <= wr.cntL1A;
  cntL1R           <= wr.cntL1R;
  
  hdrOut.timeStamp <= doutb( 63 downto   0);
  hdrOut.pulseId   <= doutb(127 downto  64);
  hdrOut.evttag    <= doutb(159 downto 128);
    
  daddr <= l0tag when entagr='1' else
           doutf;

  il1a  <= wr.pword.l1e and wr.pword.l1a and wr.pwordV;
  
  U_RstIn  : entity work.RstSync
    port map ( clk      => wrclk,
               asyncRst => rst,
               syncRst  => wrrst );
  
  U_RstOut  : entity work.RstSync
    port map ( clk      => rdclk,
               asyncRst => rst,
               syncRst  => rdrst );

  U_EntagW : entity work.Synchronizer
    port map ( clk      => rdclk,
               dataIn   => entag,
               dataOut  => entagr );
  
  U_EntagR : entity work.Synchronizer
    port map ( clk      => wrclk,
               dataIn   => entag,
               dataOut  => entagw );
  
  U_SyncD : entity work.SynchronizerVector
    generic map ( WIDTH_G => l0delay'length )
    port map ( clk     => wrclk,
               dataIn  => l0delay,
               dataOut => sdelay );

  U_SyncP : entity work.SynchronizerVector
    generic map ( WIDTH_G => partition'length )
    port map ( clk     => wrclk,
               dataIn  => partition,
               dataOut => spartition );

  U_HdrRam : entity work.SimpleDualPortRam
    generic map ( DATA_WIDTH_G => 128,
                  ADDR_WIDTH_G => 8 )
    port map ( clka   => wrclk,
               ena    => '1',
               wea    => timingBus.strobe,
               addra  => timingBus.message.pulseId(7 downto 0),
               dina(127 downto 64) => timingBus.message.pulseId,
               dina( 63 downto  0) => timingBus.message.timeStamp,
               clkb   => wrclk,
               enb    => wr.rden,
               addrb  => wr.rdaddr,
               doutb  => dout );

  U_TagRam : entity work.SimpleDualPortRam
    generic map ( DATA_WIDTH_G => 160,
                  ADDR_WIDTH_G => 5 )
    port map ( clka   => wrclk,
               ena    => '1',
               wea    => wr.wren,
               addra  => wr.pword.l0tag,
               dina(127 downto   0) => dout,
               dina(159 downto 128) => wr.pword.anatag,
               clkb   => rdclk,
               enb    => '1',
               addrb  => daddr,
               doutb  => doutb );

  U_TagFifo : entity work.FifoAsync
    generic map ( ADDR_WIDTH_G => 4,
                  DATA_WIDTH_G => 5,
                  FWFT_EN_G    => true )
    port map ( rst       => rst,
               wr_clk    => wrclk,
               wr_en     => il1a,
               din       => wr.pword.l1tag,
               rd_clk    => rdclk,
               rd_en     => advance,
               dout      => doutf );

  comb : process( wr, wrrst, timingBus, exptBus, sdelay, spartition, enable ) is
    variable v  : WrRegType;
    variable ip : integer;
  begin
    v := wr;

    v.rden      := '0';
    v.wren      := '0';
    v.pwordV    := '0';
    
    ip := conv_integer(spartition);
    
    if timingBus.strobe = '1' then
      v.rden   := '1';
      v.rdaddr := timingBus.message.pulseId(7 downto 0) - sdelay;
      v.pword  := toPartitionWord(exptBus.message.partitionWord(ip));
      v.pwordV := enable;
    end if;

    if wr.rden = '1' then
      v.wren  := wr.pword.l0a;
    end if;
    
    if wrrst = '1' then
      v := WR_REG_INIT_C;
    end if;

    if wr.pwordV = '1' then
      if wr.pword.l0a = '1' then
        v.cntL0 := wr.cntL0 + 1;
      end if;

      if wr.pword.l1e = '1' then
        if wr.pword.l1a = '1' then
          v.cntL1A := wr.cntL1A + 1;
        else
          v.cntL1R := wr.cntL1R + 1;
        end if;
      end if;
    end if;
    
    wr_in <= v;
  end process;
  
  seq : process (wrclk) is
  begin
    if rising_edge(wrclk) then
      wr <= wr_in;
    end if;
  end process;
  
end rtl;
