-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 
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

entity XpmTimingFb is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk        : in  sl;
      rst        : in  sl;
      pllReset   : in  sl                               := '0';
      phyReset   : in  sl                               := '0';
      id         : in  slv(31 downto 0)                 := (others => '1');
      pause      : in  slv(XPM_PARTITIONS_C-1 downto 0) := (others => '0');
      overflow   : in  slv(XPM_PARTITIONS_C-1 downto 0) := (others => '0');
      l1Feedback : in  XpmL1FeedbackType                := XPM_L1_FEEDBACK_INIT_C;
      l1Ack      : out sl;
      phy        : out TimingPhyType);
end XpmTimingFb;

architecture rtl of XpmTimingFb is

   type StateType is (IDLE_S, PFULL_S, ID1_S, ID2_S, PDATA1_S, PDATA2_S, EOF_S);

   constant MAX_IDLE_C : slv(7 downto 0) := x"03";

   type RegType is record
      ready        : sl;
      state        : StateType;
      idleCnt      : slv(MAX_IDLE_C'range);
      lastPause    : slv(XPM_PARTITIONS_C-1 downto 0);
      lastOverflow : slv(XPM_PARTITIONS_C-1 downto 0);
      l1Feedback   : XpmL1FeedbackType;
      l1Ack        : sl;
      txData       : slv(15 downto 0);
      txDataK      : slv(1 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      ready        => '0',
      state        => IDLE_S,
      idleCnt      => (others => '0'),
      lastPause    => (others => '1'),
      lastOverflow => (others => '0'),
      l1Feedback   => XPM_L1_FEEDBACK_INIT_C,
      l1Ack        => '0',
      txData       => (D_215_C & K_COM_C),
      txDataK      => "01");

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;


begin

   l1Ack                   <= r.l1Ack;
   phy.data                <= r.txData;
   phy.dataK               <= r.txDataK;
   phy.control.pllReset    <= pllReset;
   phy.control.reset       <= phyReset;
   phy.control.inhibit     <= '0';
   phy.control.polarity    <= '0';
   phy.control.bufferByRst <= '0';

   comb : process (pause, id, l1Feedback, overflow, r, rst) is
      variable v : RegType;
   begin
      v := r;

      v.txDataK := "01";
      v.l1Ack   := '0';
      v.ready   := '0';

      if (r.lastPause /= pause) or (r.lastOverflow /= overflow) then
         v.ready := '1';
      end if;
      if (r.idleCnt = MAX_IDLE_C) then
         v.ready := '1';
      end if;
      if l1Feedback.valid = '1' then
         v.ready := '1';
      end if;

      case (r.state) is
         when IDLE_S =>
            v.idleCnt := r.idleCnt+1;
            if (r.ready = '1') then
               v.idleCnt := (others => '0');
               v.txData  := D_215_C & K_SOF_C;
               v.state   := ID1_S;
            else
               v.txData := D_215_C & K_COM_C;
            end if;
         when ID1_S =>
            v.txDataK := "00";
            v.txData  := id(15 downto 0);
            v.state   := ID2_S;
         when ID2_S =>
            v.txDataK := "00";
            v.txData  := id(31 downto 16);
            v.state   := PFULL_S;
         when PFULL_S =>
            v.txDataK             := "00";
            v.txData              := (others => '0');
            v.txData(7 downto 0)  := pause;
            v.txData(15 downto 8) := overflow;
            v.lastPause           := pause;
            v.lastOverflow        := overflow;
            if l1Feedback.valid = '1' then
               v.l1Feedback := l1Feedback;
               v.l1Ack      := '1';
               v.state      := PDATA1_S;
            else
               v.state := EOF_S;
            end if;
         when PDATA1_S =>
            v.txDataK := "00";
            v.txData  := resize(toSlv(r.l1Feedback), 16);
            v.state   := PDATA2_S;
         when PDATA2_S =>
            v.txDataK := "00";
            v.txData  := resize(toSlv(r.l1Feedback), 32)(15 downto 0);
            v.state   := PFULL_S;
         when EOF_S =>
            v.txData := D_215_C & K_EOF_C;
            v.state  := IDLE_S;
         when others => null;
      end case;

      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin;
      end if;
   end process seq;

end rtl;
