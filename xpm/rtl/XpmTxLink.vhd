-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : XpmTxLink.vhd
-- Author     : Matt Weaver
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-12-14
-- Last update: 2019-06-01
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
use work.TimingExtnPkg.all;
use work.TimingPkg.all;
use work.XpmPkg.all;

entity XpmTxLink is
   generic (
      ADDR      : integer := 0;
      STREAMS_G : integer := 2;
      DEBUG_G   : boolean := false );
   port (
      clk              : in  sl;
      rst              : in  sl;
      config           : in  XpmLinkConfigType;
      isXpm            : in  sl;
      streams          : in  TimingSerialArray(STREAMS_G-1 downto 0);
      streamIds        : in  Slv4Array        (STREAMS_G-1 downto 0);
      paddr            : in  slv(PADDR_LEN-1 downto 0);
      advance_i        : in  slv              (STREAMS_G-1 downto 0);
      fiducial         : in  sl;
      txData           : out slv(15 downto 0);
      txDataK          : out slv( 1 downto 0) );
end XpmTxLink;

architecture rtl of XpmTxLink is

  constant PBITS : integer := log2(NPartitions-1);
                              
  type RegType is record
    fiducial  : slv(2 downto 0);
    txDelay   : slv(config.txDelay'range);
    efifoV    : sl;
    efifoWr   : slv(paddr'length/16-1 downto 0);
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

  signal fstreams    : TimingSerialArray(STREAMS_G-1 downto 0);
  signal tfifoStream : TimingSerialArray(STREAMS_G-1 downto 0) := (others=>TIMING_SERIAL_INIT_C);
  signal tfifoWr     : slv              (STREAMS_G-1 downto 0) := (others=>'0');
  signal advance     : slv              (STREAMS_G-1 downto 0);
  signal fifoRst     : slv              (STREAMS_G-1 downto 0) := (others=>'0');
  signal fiducialDelayed : slv          (STREAMS_G-1 downto 0) := (others=>'0');
  signal efifoWr   : sl;
  signal efifoFull : sl;
  signal efifoDin  : slv(15 downto 0);
  signal efifoV    : sl;
  signal utxDelay  : slv(config.txDelay'range);
  signal itxData   : slv(15 downto 0);
  signal itxDataK  : slv( 1 downto 0);
  
  component ila_0
    port ( clk    : in sl;
           probe0 : in slv(255 downto 0) );
  end component;

begin

  GEN_DEBUG : if DEBUG_G generate
    U_ILA : ila_0
      port map ( clk                   => clk,
                 probe0( 15 downto  0) => itxData,
                 probe0( 17 downto 16) => itxDataK,
                 probe0( 18 )          => tfifoWr(0),
                 probe0( 19 )          => tfifoWr(1),
                 probe0( 20 )          => fiducial,
                 probe0( 22 downto 21) => advance_i(1 downto 0),
                 probe0( 24 downto 23) => advance  (1 downto 0),
                 probe0( 25 )          => fifoRst(0),
                 probe0( 26 )          => streams(0).ready,
                 probe0( 27 )          => streams(1).ready,
                 probe0( 28 )          => fstreams(0).ready,
                 probe0( 29 )          => fstreams(1).ready,
                 probe0( 32 downto 30) => r.fiducial,
                 probe0( 33 )          => r.efifoV,
                 probe0( 35 downto 34) => r.efifoWr,
                 probe0( 36 )          => fifoRst(1),
                 probe0( 38 downto 37) => r.eadvance,
                 probe0( 39 )          => '0',
                 probe0( 40 )          => efifoWr,
                 probe0( 41 )          => efifoFull,
                 probe0( 57 downto 42) => efifoDin,
                 probe0( 58 )          => efifoV,
                 probe0( 59 )          => fiducialDelayed(0),
                 probe0( 60 )          => fiducialDelayed(1),
                 probe0( 76 downto 61 )=> streams (0).data,
                 probe0( 92 downto 77 )=> fstreams(0).data,
                 probe0(255 downto 93) => (others=>'0') );
  end generate;

  txData  <= itxData;
  txDataK <= itxDataK;
  
  U_Serializer : entity work.TimingSerializer
     generic map ( STREAMS_C => STREAMS_G )
     port map ( clk       => clk,
                rst       => rst,
                fiducial  => r.fiducial(0),
                streams   => fstreams,
                streamIds => streamIds,
                advance   => advance,
                data      => itxData,
                dataK     => itxDataK );

  U_ScTimingFifo : entity work.FifoSync
    generic map ( FWFT_EN_G => true )
    port map ( clk     => clk,
               rst     => fifoRst (0),
               wr_en   => tfifoWr (0),
               din     => tfifoStream(0).data,
               rd_en   => advance (0),
               dout    => fstreams(0).data,
               valid   => fstreams(0).ready );
  fstreams(0).last   <= '1';
  fstreams(0).offset <= (others=>'0');
  
  U_CuTimingFifo : entity work.FifoSync
    generic map ( FWFT_EN_G => true )
    port map ( clk     => clk,
               rst     => fifoRst (1),
               wr_en   => tfifoWr (1),
               din     => tfifoStream(1).data,
               rd_en   => advance (1),
               dout    => fstreams(1).data,
               valid   => fstreams(1).ready );
  fstreams(1).last   <= '1';
  fstreams(1).offset <= (others=>'0');
  
  U_ExptFifo : entity work.FifoSync
    generic map ( FWFT_EN_G => true )
    port map ( clk     => clk,
               rst     => rst,
               wr_en   => efifoWr,
               din     => efifoDin,
               rd_en   => advance (2),
               dout    => fstreams(2).data,
               valid   => efifoV,
               full    => efifoFull );

  efifoWr            <= ((advance_i(2) and r.eadvance(0)) or uOr(r.efifoWr)) and not efifoFull;
  efifoDin           <= streams(2).data     when (advance_i(2)='1') else
                        r.paddr(15 downto 0);
                        
  fstreams(2).ready  <= efifoV;
  fstreams(2).last   <= '1';
  fstreams(2).offset <= (others=>'0');

  U_ScDelay : entity work.XpmSerialDelay
     generic map ( DELAY_WIDTH_G => config.txDelay'length,
                   NWORDS_G => TIMING_MESSAGE_WORDS_C,
                   FDEPTH_G => 100 )
     port map ( clk        => clk,
                rst        => rst,
                delay      => r.txDelay,
                delayRst   => config.txDelayRst,
                fiducial_i => fiducial,
                advance_i  => advance_i      (0),
                stream_i   => streams        (0),
                reset_o    => fifoRst        (0),
                fiducial_o => fiducialDelayed(0),
                advance_o  => tfifoWr        (0),
                stream_o   => tfifoStream    (0),
                overflow_o => open );

  U_CuDelay : entity work.XpmSerialDelay
     generic map ( DELAY_WIDTH_G => config.txDelay'length,
                   NWORDS_G => TIMING_EXTN_WORDS_C(1),
                   FDEPTH_G => 100 )
     port map ( clk        => clk,
                rst        => rst,
                delay      => r.txDelay,
                delayRst   => config.txDelayRst,
                fiducial_i => fiducial,
                advance_i  => advance_i      (1),
                stream_i   => streams        (1),
                reset_o    => fifoRst        (1),
                fiducial_o => fiducialDelayed(1),
                advance_o  => tfifoWr        (1),
                stream_o   => tfifoStream    (1),
                overflow_o => open );

  U_SyncDelay : entity work.SynchronizerVector
    generic map ( WIDTH_G => config.txDelay'length )
    port map ( clk     => clk,
               dataIn  => config.txDelay,
               dataOut => utxDelay );
  
  comb: process (r, rst, isXpm, utxDelay, fiducialDelayed, efifoV, advance_i, paddr, streams, fstreams ) is
     variable v : RegType;
   begin
     v := r;

     v.fiducial := fiducialDelayed(0) & r.fiducial(2 downto 1);
     v.efifoV   := efifoV;
     v.efifoWr  := (r.efifoV and not efifoV) & r.efifoWr(r.efifoWr'left downto 1);
     v.eadvance := advance_i(2) & r.eadvance(r.eadvance'left downto 1);
     if (r.efifoV='1' and efifoV='0') then
       if toXpmBroadcastType(paddr)=XADDR then
         v.paddr  := paddr(paddr'left-4 downto 0) & toSlv(ADDR,4);
       else
         v.paddr  := paddr;
       end if;
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
