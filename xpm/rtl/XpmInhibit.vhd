-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Level-0 trigger inhibit aggregation
--
-- Assert 'inhibit' as logical OR of link 'pause' status for all enabled
-- links ('config').
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


library surf;
use surf.StdRtlPkg.all;

library l2si_core;
use l2si_core.XpmPkg.all;

entity XpmInhibit is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- register clock domain
      regclk     : in  sl;
      update     : in  sl;
      clear      : in  sl;                    -- clear statistics
      config     : in  XpmPartInhConfigType;  -- programmable parameters
      status     : out XpmInhibitStatusType;  -- statistics
      --  timing clock domain
      clk        : in  sl;
      rst        : in  sl;
      pause      : in  slv(27 downto 0);      -- status from downstream links
      fiducial   : in  sl;
      l0Accept   : in  sl;
      l1Accept   : in  sl;
      rejecc     : in  sl;                    -- L0 rejected due to inhibit
      inhibit    : out sl;                    -- trigger inhibit status
      inhibitMsg : out sl);                   -- message inhibit status
end XpmInhibit;

architecture rtl of XpmInhibit is

   type RegType is record
      status : XpmInhibitStatusType;
   end record;
   constant REG_INIT_C : RegType := (
      status => XPM_INHIBIT_STATUS_INIT_C);

   signal r    : RegType := REG_INIT_C;
   signal r_in : RegType;

   signal proginhb : slv(config.setup'range);
   signal pauseb   : slv(27 downto 0);
   signal inhSrc   : slv(31 downto 0);
   signal dtSrc    : slv(31 downto 0);
   signal evcounts : SlVectorArray(31 downto 0, 31 downto 0);
   signal tmcounts : SlVectorArray(31 downto 0, 31 downto 0);

begin
   status     <= r.status;
   inhibit    <= uOr(pauseb) or uOr(proginhb);
   inhibitMsg <= uOr(pauseb(26 downto 0)) or uOr(proginhb);

   inhSrc <= (proginhb & pauseb) when rejecc = '1' else
             (others => '0');

   dtSrc <= (proginhb & pauseb) when fiducial = '1' else
            (others => '0');

   pauseb <= pause;

   U_Status : entity surf.SyncStatusVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 32)
      port map (
         statusIn     => inhSrc,
         cntRstIn     => clear,
         rollOverEnIn => (others => '1'),
         cntOut       => evcounts,
         wrClk        => clk,
         rdClk        => regclk);

   U_DtStatus : entity surf.SyncStatusVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 32)
      port map (
         statusIn     => dtSrc,
         cntRstIn     => clear,
         rollOverEnIn => (others => '1'),
         cntOut       => tmcounts,
         wrClk        => clk,
         rdClk        => regclk);

   GEN_L0INH : for i in config.setup'range generate
      U_L0INH : entity l2si_core.XpmTrigInhibit
         generic map (
            TPD_G => TPD_G)
         port map (
            rst      => rst,
            clk      => clk,
            config   => config.setup(i),
            fiducial => fiducial,
            trig     => l0Accept,
            inhibit  => proginhb (i));
   end generate;

   process (evcounts, r, tmcounts) is
      variable v : RegType;
   begin
      v := r;

      for i in 0 to 31 loop
         v.status.evcounts(i) := muxSlVectorArray(evcounts, i);
         v.status.tmcounts(i) := muxSlVectorArray(tmcounts, i);
      end loop;

      r_in <= v;
   end process;

   process (regclk) is
   begin
      if rising_edge(regclk) then
         r <= r_in after TPD_G;
      end if;
   end process;

end rtl;
