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
      TPD_G           : time                 := 1 ns;
      NUM_DETECTORS_G : integer range 1 to 8 := 8);
   port (
      clk                : in  sl;
      rst                : in  sl;
      pllReset           : in  sl                                    := '0';
      phyReset           : in  sl                                    := '0';
      id                 : in  slv(31 downto 0)                      := (others => '1');
      detectorPartitions : in  slv3Array(NUM_DETECTORS_G-1 downto 0) := (others => (others => '0'));
      full               : in  slv(NUM_DETECTORS_G-1 downto 0)       := (others => '0');
      overflow           : in  slv(NUM_DETECTORS_G-1 downto 0)       := (others => '0');
      l1Feedbacks        : in  XpmL1FeedbackArray(NUM_DETECTORS_G-1 downto 0);
      l1Acks             : out slv(NUM_DETECTORS_G-1 downto 0);
      phy                : out TimingPhyType);
end XpmTimingFb;

architecture rtl of XpmTimingFb is

   type StateType is (IDLE_S, PFULL_S, ID1_S, ID2_S, PDATA1_S, PDATA2_S, EOF_S);

   constant MAX_IDLE_C : slv(7 downto 0) := x"0F";

   type RegType is record
      ready        : sl;
      state        : StateType;
      idleCnt      : slv(MAX_IDLE_C'range);
      detector     : integer range 0 to NUM_DETECTORS_G-1;
      lastFull     : slv(XPM_PARTITIONS_C-1 downto 0);
      lastOverflow : slv(XPM_PARTITIONS_C-1 downto 0);
      l1Acks       : slv(NUM_DETECTORS_G-1 downto 0);
      txData       : slv(15 downto 0);
      txDataK      : slv(1 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      ready        => '0',
      state        => IDLE_S,
      idleCnt      => (others => '0'),
      detector     => 0,
      lastFull     => (others => '1'),
      lastOverflow => (others => '0'),
      l1Acks       => (others => '0'),
      txData       => (D_215_C & K_COM_C),
      txDataK      => "01");

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;


begin

   l1Acks                  <= r.l1Acks;
   phy.data                <= r.txData;
   phy.dataK               <= r.txDataK;
   phy.control.pllReset    <= pllReset;
   phy.control.reset       <= phyReset;
   phy.control.inhibit     <= '0';
   phy.control.polarity    <= '0';
   phy.control.bufferByRst <= '0';

   comb : process (detectorPartitions, full, id, l1Feedbacks, overflow, r, rst) is
      variable v                 : RegType;
      variable partitionFull     : slv(XPM_PARTITIONS_C-1 downto 0);
      variable partitionOverflow : slv(XPM_PARTITIONS_C-1 downto 0);

   begin
      v := r;

      v.txDataK := "01";
      v.l1Acks  := (others => '0');
      v.ready   := '0';

      -- Full and overflow arrive per DETECTOR
      -- reorganize them according to partition
      partitionFull     := (others => '0');
      partitionOverflow := (others => '0');

      for d in NUM_DETECTORS_G-1 downto 0 loop
         if (full(d) = '1') then
            partitionFull(conv_integer(detectorPartitions(d))) := '1';
         end if;

         if (overflow(d) = '1') then
            partitionOverflow(conv_integer(detectorPartitions(d))) := '1';
         end if;
      end loop;


      if (r.lastFull /= partitionFull) or (r.lastOverflow /= partitionOverflow) then
         v.ready := '1';
      end if;
      if (r.idleCnt = MAX_IDLE_C) then
         v.ready := '1';
      end if;
      for i in 0 to NUM_DETECTORS_G-1 loop
         if l1Feedbacks(i).valid = '1' then
            v.ready := '1';
         end if;
      end loop;

      case (r.state) is
         when IDLE_S =>
            v.idleCnt := r.idleCnt+1;
            if (r.ready = '1') then
               v.idleCnt := (others => '0');
               v.txData  := D_215_C & K_EOS_C;
               v.state   := PFULL_S;
            else
               v.txData := D_215_C & K_COM_C;
            end if;
         when PFULL_S =>
            v.txDataK             := "00";
            v.txData              := (others => '0');
            v.txData(7 downto 0)  := partitionFull;
            v.txData(15 downto 8) := partitionOverflow;
            v.lastFull            := partitionFull;
            v.lastOverflow        := partitionOverflow;
            v.state               := ID1_S;
         when ID1_S =>
            v.txDataK := "00";
            v.txData  := id(15 downto 0);
            v.state   := ID2_S;
         when ID2_S =>
            v.txDataK  := "00";
            v.txData   := id(31 downto 16);
            v.state    := EOF_S;
            v.detector := 0;
            v.state    := PDATA1_S;

         when PDATA1_S =>
            v.txDataK            := "00";
            v.txData             := (others => '0');
            v.txData(7 downto 4) := l1Feedbacks(r.detector).trigsrc;
            v.txData(3 downto 1) := detectorPartitions(r.detector);
            v.txData(0)          := l1Feedbacks(r.detector).valid;   -- Redundant
            v.state              := PDATA2_S;
         when PDATA2_S =>
            v.txDataK             := "00";
            v.txData              := (others => '0');
            v.txData(14)          := l1Feedbacks(r.detector).valid;
            v.txData(13 downto 5) := l1Feedbacks(r.detector).trigword;
            v.txData(4 downto 0)  := l1Feedbacks(r.detector).tag;
            v.l1Acks(r.detector)  := l1Feedbacks(r.detector).valid;  -- Ack the feedback message

            -- Done after iterating through all detectors
            if (r.detector = NUM_DETECTORS_G-1) then
               v.detector := 0;
               v.state    := EOF_S;
            else
               v.detector := r.detector + 1;
               v.state    := PDATA1_S;
            end if;

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
