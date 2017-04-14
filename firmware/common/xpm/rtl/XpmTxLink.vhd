-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : XpmTxLink.vhd
-- Author     : Matt Weaver
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-12-14
-- Last update: 2017-02-21
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Sensor link serializer
--
-- Inserts the local link address (always) and the xpm partition data (if we
-- are the master of the partition) into the
-- outgoing data stream.  If the link is to a device, the timing stream
-- needs to be delayed to align with the xpm partition data.
-- The CRC needs to be recomputed.  Still need to force a bad CRC if the
-- incoming frame is corrupt.
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 XPM Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 XPM Core', including this file, 
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

entity XpmTxLink is
   generic (
      ADDR : integer := 0 );
   port (
      clk              : in  sl;
      rst              : in  sl;
      config           : in  XpmLinkConfigType;
      isXpm            : in  sl;
      streams          : in  TimingSerialArray(1 downto 0);
      streamIds        : in  Slv4Array        (1 downto 0) := (x"1",x"0");
      paddr            : in  slv(PADDR_LEN-1 downto 0);
      advance_i        : in  slv              (1 downto 0);
      fiducial         : in  sl;
      sof              : in  sl;
      eof              : in  sl;
      crcErr           : in  sl;
      txData           : out slv(15 downto 0);
      txDataK          : out slv( 1 downto 0) );
end XpmTxLink;

architecture rtl of XpmTxLink is

  constant PBITS : integer := log2(NPartitions-1);
                              
  type RegType is record
    fiducial  : slv(2 downto 0);
    txDelay   : slv(config.txDelay'range);
    efifoV    : sl;
    efifoWr   : slv(paddr'length/16 downto 0);
    eadvance  : slv(paddr'length/16-1 downto 0);
    paddr     : slv(paddr'range);
  end record;
  constant REG_INIT_C : RegType := (
    fiducial  => (others=>'0'),
    txDelay   => (others=>'0'),
    efifoV    => '1',
    efifoWr   => (others=>'0'),
    eadvance  => (others=>'0'),
    paddr     => (others=>'1') );
  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal fstreams  : TimingSerialArray(1 downto 0);
  signal tfifoStream : TimingSerialType;
  signal tfifoWr   : sl;
  signal efifoWr   : sl;
  signal efifoFull : sl;
  signal efifoDin  : slv(15 downto 0);
  signal efifoV    : sl;
  signal fiducialDelayed   : sl;
  signal advance   : slv(1 downto 0);
  signal utxDelay  : slv(config.txDelay'range);
  
begin

  U_Serializer : entity work.TimingSerializer
     generic map ( STREAMS_C => 2 )
     port map ( clk       => clk,
                rst       => rst,
                fiducial  => r.fiducial(0),
                streams   => fstreams,
                streamIds => streamIds,
                advance   => advance,
                data      => txData,
                dataK     => txDataK );

  U_TimingFifo : entity work.FifoSync
    generic map ( FWFT_EN_G => true )
    port map ( clk     => clk,
               rst     => rst,
               wr_en   => tfifoWr,
               din     => tfifoStream.data,
               rd_en   => advance(0),
               dout    => fstreams(0).data,
               valid   => fstreams(0).ready );
  fstreams(0).last   <= '1';
  fstreams(0).offset <= (others=>'0');
  
  U_ExptFifo : entity work.FifoSync
    generic map ( FWFT_EN_G => true )
    port map ( clk     => clk,
               rst     => rst,
               wr_en   => efifoWr,
               din     => efifoDin,
               rd_en   => advance(1),
               dout    => fstreams(1).data,
               valid   => efifoV,
               full    => efifoFull );

  efifoWr            <= ((advance_i(1) and r.eadvance(0)) or uOr(r.efifoWr)) and not efifoFull;
  efifoDin           <= streams(1).data     when (advance_i(1)='1') else
                        r.paddr(15 downto 0);
                        
  fstreams(1).ready  <= efifoV;
  fstreams(1).last   <= '1';
  fstreams(1).offset <= (others=>'0');

  U_Delay : entity work.XpmSerialDelay
     generic map ( DELAY_WIDTH_G => config.txDelay'length,
                   NWORDS_G => TIMING_MESSAGE_WORDS_C,
                   FDEPTH_G => 100 )
     port map ( clk        => clk,
                rst        => rst,
                delay      => r.txDelay,
                delayRst   => config.txDelayRst,
                fiducial_i => fiducial,
                advance_i  => advance_i(0),
                stream_i   => streams(0),
                fiducial_o => fiducialDelayed,
                advance_o  => tfifoWr,
                stream_o   => tfifoStream,
                overflow_o => open );

  U_SyncDelay : entity work.SynchronizerVector
    generic map ( WIDTH_G => config.txDelay'length )
    port map ( clk     => clk,
               dataIn  => config.txDelay,
               dataOut => utxDelay );
  
  comb: process (r, rst, isXpm, utxDelay, fiducialDelayed, efifoV, advance_i, paddr ) is
     variable v : RegType;
   begin
     v := r;

     v.fiducial := fiducialDelayed & r.fiducial(2 downto 1);
     v.efifoV   := efifoV;
     v.efifoWr  := (r.efifoV and not efifoV) & r.efifoWr(r.efifoWr'left downto 1);
     if paddr'length>16 then
       v.eadvance := advance_i(1) & r.eadvance(r.eadvance'left downto 1);
     else
       v.eadvance(0) := advance_i(1);
     end if;
     if (r.efifoV='1' and efifoV='0') then
       v.paddr  := paddr(paddr'left-4 downto 0) & toSlv(ADDR,4);
     else
       v.paddr  := x"0000" & r.paddr(r.paddr'left downto 16);
     end if;
     
     if isXpm='1' then
       v.txDelay := (others=>'0');
     else
       v.txDelay := utxDelay;
     end if;

     if rst='1' then
       v := REG_INIT_C;
     end if;
     
     rin <= v;
   end process comb;

   seq: process (clk) is
   begin
     if rising_edge(clk) then
       r <= rin;
     end if;
   end process seq;
end rtl;
