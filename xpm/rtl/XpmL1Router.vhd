-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: XpmL1Router
--
-- Note: Common-to-XpmApp interface defined here (see URL below)
--       https://confluence.slac.stanford.edu/x/rLyMCw
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

library l2si_core;
use l2si_core.XpmPkg.all;

--
--  Still need to route l1 feedback upstream when we are not mastering the partition
--
entity XpmL1Router is
   generic (
      TPD_G       : time    := 1 ns;
      NUM_LINKS_G : integer := 1);
   port (
      clk            : in  sl;
      rst            : in  sl;
      l1FeedbacksIn  : in  XpmL1FeedbackArray(NUM_LINKS_G-1 downto 0);
      l1InAcks       : out slv (NUM_LINKS_G-1 downto 0);
      l1FeedbacksOut : out XpmL1FeedbackArray(XPM_PARTITIONS_C downto 0);
      l1OutAcks      : in  slv (XPM_PARTITIONS_C downto 0));
end XpmL1Router;

architecture top_level_app of XpmL1Router is

   type ReqArray is array (natural range<>) of slv(NUM_LINKS_G-1 downto 0);
   signal req : ReqArray(XPM_PARTITIONS_C-1 downto 0);

   type SelArray is array (natural range<>) of slv(bitSize(NUM_LINKS_G-1)-1 downto 0);
   signal sel : SelArray(XPM_PARTITIONS_C-1 downto 0);

   signal valid : slv(XPM_PARTITIONS_C-1 downto 0);
begin

   comb : process (l1FeedbacksIn, l1OutAcks, sel, valid) is
      variable vreq : ReqArray(req'range);
   begin
      vreq := (others => (others => '0'));
      for i in 0 to NUM_LINKS_G-1 loop
         vreq(conv_integer(l1FeedbacksIn(i).partition))(i) := l1FeedbacksIn(i).valid;
      end loop;

      l1InAcks <= (others => '0');

      for i in 0 to XPM_PARTITIONS_C-1 loop
         l1FeedbacksOut(i) <= l1FeedbacksIn(conv_integer(sel(i)));
         if valid(i) = '1' then
            l1InAcks(conv_integer(sel(i))) <= l1OutAcks(i);
         else
            l1FeedbacksOut(i).valid <= '0';
         end if;
      end loop;

      -- Complete implementation
      req <= vreq;

      l1FeedbacksOut(XPM_PARTITIONS_C) <= XPM_L1_FEEDBACK_INIT_C;

   end process comb;

   GEN_PARTITION : for i in 0 to XPM_PARTITIONS_C-1 generate
      U_Arbiter : entity surf.Arbiter
         generic map (
            TPD_G      => TPD_G,
            REQ_SIZE_G => NUM_LINKS_G)
         port map (
            clk      => clk,
            rst      => rst,
            req      => req(i),
            selected => sel(i),
            valid    => valid(i),
            ack      => open);
   end generate;

end top_level_app;
