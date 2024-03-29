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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;

library l2si_core;
use l2si_core.XpmPkg.all;

entity XpmTrigInhibit is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk      : in  sl;
      rst      : in  sl;
      config   : in  XpmInhibitConfigType;  -- programmable parameters
      fiducial : in  sl;
      trig     : in  sl;
      inhibit  : out sl);                   -- trigger inhibit status
end XpmTrigInhibit;

architecture rtl of XpmTrigInhibit is

   type RegType is record
      count  : slv(config.interval'range);
      target : slv(config.interval'range);
      rd_cnt : sl;
      pause   : sl;
   end record;
   constant REG_INIT_C : RegType := (
      count  => (others => '0'),
      target => (others => '0'),
      rd_cnt => '0',
      pause   => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal uconfig   : XpmInhibitConfigType;
   signal dout_cnt  : slv(config.interval'range);
   signal dcount    : slv(config.limit'range);
   signal valid_cnt : sl;
   signal fiforst   : sl;

begin

   inhibit <= r.pause;
   fiforst <= rst or not uconfig.enable;

   U_Interval : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => config.interval'length)
      port map (
         clk     => clk,
         dataIn  => config.interval,
         dataOut => uconfig.interval);

   U_Limit : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => config.limit'length)
      port map (
         clk     => clk,
         dataIn  => config.limit,
         dataOut => uconfig.limit);

   U_Enable : entity surf.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => clk,
         dataIn  => config.enable,
         dataOut => uconfig.enable);

   U_FIFO : entity surf.FifoSync
      generic map (
         TPD_G        => TPD_G,
         FWFT_EN_G    => true,
         DATA_WIDTH_G => config.interval'length,
         ADDR_WIDTH_G => config.limit'length)
      port map (
         rst        => fiforst,
         clk        => clk,
         wr_en      => trig,
         rd_en      => r.rd_cnt,
         din        => r.target,
         dout       => dout_cnt,
         data_count => dcount,
         valid      => valid_cnt);

   comb : process (dcount, dout_cnt, fiducial, r, rst, uconfig, valid_cnt) is
      variable v      : RegType;
      variable ncount : slv(dcount'range);
   begin
      v        := r;
      v.rd_cnt := '0';

      if fiducial = '1' then
         v.count  := r.count+1;
         v.target := r.count+uconfig.interval;
         --  latch the fifo status
         if (valid_cnt = '1' and dcount = uconfig.limit) then
            v.pause := '1';
         else
            v.pause := '0';
         end if;
      end if;

      if (valid_cnt = '1' and dout_cnt = r.count) then
         v.rd_cnt := fiducial;
      end if;

      if rst = '1' or uconfig.enable = '0' then
         v := REG_INIT_C;
      end if;

      rin <= v;
   end process;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process;


end rtl;
