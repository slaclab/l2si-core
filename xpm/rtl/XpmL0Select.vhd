-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Level-0 trigger select
-- 
-- Select events for sensor integration based upon timing frame information
-- and programmed selection parameters.
--
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
use l2si_core.CuTimingPkg.all;

entity XpmL0Select is
   generic (
      TPD_G   : time    := 1 ns;
      DEBUG_G : boolean := false);
   port (
      clk       : in  sl;
      rst       : in  sl;
      -- programmed event selection criteria
      config    : in  XpmL0SelectConfigType;
      -- current pulse timing information
      timingBus : in  TimingBusType;
      cuTiming  : in  CuTimingType;
      cuTimingV : in  sl;
      -- state of the deadtime assertion
      inhibit   : in  sl;
      -- strobe cycle when decision needs to be made
      strobe    : in  sl;
      -- event selection decision
      accept    : out sl;
      rejecc    : out sl;
      -- monitoring statistics
      status    : out XpmL0SelectStatusType);
end XpmL0Select;

architecture rtl of XpmL0Select is
   type RegType is record
      strobeRdy : sl;
      accept    : sl;
      rejecc    : sl;
      seqWord   : slv(15 downto 0);
      evtWord   : slv(15 downto 0);
      status    : XpmL0SelectStatusType;
   end record;
   constant REG_INIT_C : RegType := (
      strobeRdy => '0',
      accept    => '0',
      rejecc    => '0',
      seqWord   => (others => '0'),
      evtWord   => (others => '0'),
      status    => XPM_L0_SELECT_STATUS_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal uconfig : XpmL0SelectConfigType;

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
            probe0(0)             => timingBus.strobe,
            probe0(1)             => uconfig.enabled,
            probe0(2)             => strobe,
            probe0(3)             => inhibit,
            probe0(7 downto 4)    => r.status.enabled (3 downto 0),
            probe0(11 downto 8)   => r.status.inhibited(3 downto 0),
            probe0(15 downto 12)  => r.status.num (3 downto 0),
            probe0(19 downto 16)  => r.status.numInh (3 downto 0),
            probe0(20)            => uconfig.reset,
            probe0(21)            => r.accept,
            probe0(22)            => r.rejecc,
            probe0(255 downto 23) => (others => '0'));
   end generate;

   accept <= r.accept;
   rejecc <= r.rejecc;
   status <= r.status;

   U_SYNC : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 34)
      port map (
         clk                   => clk,
         dataIn(15 downto 0)   => config.rateSel,
         dataIn(31 downto 16)  => config.destSel,
         dataIn(32)            => config.reset,
         dataIn(33)            => config.enabled,
         dataOut(15 downto 0)  => uconfig.rateSel,
         dataOut(31 downto 16) => uconfig.destSel,
         dataOut(32)           => uconfig.reset,
         dataOut(33)           => uconfig.enabled);

   comb : process (r, inhibit, timingBus, cuTiming, cuTimingV, uconfig, strobe) is
      variable v        : RegType;
      variable m        : TimingMessageType;
      variable rateSel  : sl;
      variable destSel  : sl;
      variable controlI : integer;
      variable eventI   : integer;
   begin
      v := r;

      v.accept := '0';
      v.rejecc := '0';

      m := timingBus.message;           -- shorthand

      controlI := conv_integer(uconfig.rateSel(13 downto 8));
      if (controlI < m.control'length) then
         v.seqWord := m.control(controlI);
      else
         v.seqWord := (others => '0');
      end if;

      eventI    := conv_integer(uconfig.rateSel(12 downto 8));
      v.evtWord := cuTiming.eventCodes(eventI*16+15 downto eventI*16);

      if (timingBus.strobe = '1') then
         v.strobeRdy := '1';
   end if;

   if (strobe = '1' and r.strobeRdy = '1') then
      v.strobeRdy := '0';
      -- calculate rateSel
      case uconfig.rateSel(15 downto 14) is
         when "00" => rateSel := m.fixedRates(conv_integer(uconfig.rateSel(3 downto 0)));
         when "01" =>
            if (uconfig.rateSel(conv_integer(m.acTimeSlot)+3-1) = '0') then
               rateSel := '0';
            else
               rateSel := m.acRates(conv_integer(uconfig.rateSel(2 downto 0)));
            end if;
         when "10"   => rateSel := r.seqWord(conv_integer(uconfig.rateSel(3 downto 0)));
         when "11"   => rateSel := r.evtWord(conv_integer(uconfig.rateSel(3 downto 0)));
         when others => rateSel := '0';
      end case;
      -- calculate destSel
      if (uconfig.destSel(15) = '1' or
          ((uconfig.destSel(conv_integer(m.beamRequest(7 downto 4))) = '1') and
           (m.beamRequest(0) = '1'))) then
         destSel := '1';
      else
         destSel := '0';
      end if;
      if uconfig.enabled = '1' then
         v.status.enabled := r.status.enabled+1;
         if (inhibit = '1') then
            v.status.inhibited := r.status.inhibited+1;
         end if;
         if (rateSel = '1' and destSel = '1') then
            v.status.num := r.status.num+1;
            if (inhibit = '1') then
               v.rejecc        := '1';
               v.status.numInh := r.status.numInh+1;
            else
               v.accept        := '1';
               v.status.numAcc := r.status.numAcc+1;
            end if;
         end if;
      end if;
   end if;

   if (uconfig.reset = '1') then
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
