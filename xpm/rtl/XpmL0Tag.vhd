-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Level-0 timestamp cache
--
-- This module caches the event timestamp information (XpmAcceptFrameType) for each
-- accepted Level-0 trigger and generates an associated index 'push_tag' for
-- use in downstream link Level-1 trigger communications.  The event timestamp
-- information is later retrieved by the 'pop' signal and 'pop_tag'.
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

entity XpmL0Tag is
   generic (
      TPD_G       : time    := 1 ns;
      TAG_WIDTH_G : integer := 32);
   port (
      clk       : in  sl;
      rst       : in  sl;
      config    : in  XpmL0TagConfigType;
      clear     : in  sl;
      timingBus : in  TimingBusType;
      push      : in  sl;
      skip      : in  sl;
      push_tag  : out slv(TAG_WIDTH_G-1 downto 0);
      pop       : in  sl;
      pop_tag   : in  slv(7 downto 0);
      pop_frame : out XpmAcceptFrameType);
end XpmL0Tag;

architecture rtl of XpmL0Tag is
   type RegType is record
      tag : slv(TAG_WIDTH_G-1 downto 0);
   end record;
   constant REG_INIT_C : RegType := (
      tag => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal uclear : sl;
begin
   push_tag  <= r.tag;
   pop_frame <= XPM_ACCEPT_FRAME_INIT_C;

   U_SYNC : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 1)
      port map (
         clk        => clk,
         dataIn(0)  => clear,
         dataOut(0) => uclear);

   comb : process (push, r, skip, uclear) is
      variable v : RegType;
   begin
      v := r;
      if (push = '1' or skip = '1') then
         v.tag := r.tag+1;
      end if;

      if (uclear = '1') then
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
