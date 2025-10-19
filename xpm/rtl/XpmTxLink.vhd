-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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
-- This file is part of 'L2SI Core'. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'L2SI Core', including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

library l2si_core;
use l2si_core.XpmPkg.all;
use l2si_core.XpmExtensionPkg.all;

entity XpmTxLink is
   generic (
      TPD_G     : time    := 1 ns;
      ADDR_G    : integer := 0;
      STREAMS_G : integer := 2;
      DEBUG_G   : boolean := false);
   port (
      clk         : in  sl;
      rst         : in  sl;
      streams     : in  TimingSerialArray(STREAMS_G-1 downto 0);
      streamIds   : in  Slv4Array (STREAMS_G-1 downto 0);
      paddr       : in  slv(XPM_PARTITION_ADDR_LENGTH_C-1 downto 0);
      paddrStrobe : in  sl;
      fiducial    : in  sl;
      advance_o   : out slv (STREAMS_G-1 downto 0);
      txData      : out slv(15 downto 0);
      txDataK     : out slv(1 downto 0));
end XpmTxLink;

architecture rtl of XpmTxLink is

   constant PBITS : integer := log2(XPM_PARTITIONS_C-1);

   type RegType is record
      paddr  : slv(XPM_PARTITION_ADDR_LENGTH_C-1 downto 0);
      word   : slv(15 downto 0);
      strobe : sl;
   end record;

   constant REG_INIT_C : RegType := (
      paddr  => (others => '0'),
      word   => (others => '0'),
      strobe => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal fstreams : TimingSerialArray(STREAMS_G-1 downto 0);
   signal itxData  : slv(15 downto 0);
   signal itxDataK : slv(1 downto 0);
   signal advance  : slv(STREAMS_G-1 downto 0);

   component ila_0
      port (
         clk    : in sl;
         probe0 : in slv(255 downto 0));
   end component;

begin

   GEN_DEBUG : if DEBUG_G generate
      U_ILA : ila_0
         port map (
            clk                   => clk,
            probe0(15 downto 0)   => itxData,
            probe0(17 downto 16)  => itxDataK,
            probe0(255 downto 18) => (others => '0'));
   end generate;

   txData    <= itxData;
   txDataK   <= itxDataK;
   advance_o <= advance;

   streams_p : process (rin, streams) is
   begin
      fstreams         <= streams;
      fstreams(2).data <= rin.word;
   end process;

   U_Serializer : entity lcls_timing_core.TimingSerializer
      generic map (
         STREAMS_C => STREAMS_G)
      port map (
         clk       => clk,
         rst       => rst,
         fiducial  => fiducial,
         streams   => fstreams,
         streamIds => streamIds,
         advance   => advance,
         data      => itxData,
         dataK     => itxDataK);

   comb : process (advance, paddr, paddrStrobe, r, rst, streams) is
      variable v : RegType;
   begin
      v := r;

      v.paddr  := paddr(paddr'left-4 downto 0) & toSlv(ADDR_G, 4);
      v.strobe := paddrStrobe;
      if paddrStrobe = '1' then
         v.strobe := '1';
         v.word   := r.paddr(15 downto 0);
      elsif r.strobe = '1' and advance(2) = '1' then
         v.word   := r.paddr(31 downto 16);
         v.strobe := '0';
      else
         v.word := streams(2).data;
      end if;

      if rst = '1' then
         v := REG_INIT_C;
      end if;

      rin <= v;
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
