-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Level-1 trigger select
--
-- Select events for sensor readout based upon event information from fast sensor
-- feedback links.  Each link carries the tag (from XpmL0Tag) for the event and
-- its bits, if any, of feedback information.  The programmable 'config' indicates
-- the set of required bits for a decision and the accept condition(s).  The 'enable'
-- output strobes when a decision for 'tag' is made, and 'accept' indicates the
-- decision.
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

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

library l2si_core;
use l2si_core.XpmPkg.all;

entity XpmL1Select is
   generic (
      TPD_G          : time    := 1 ns;
      NUM_DS_LINKS_G : integer := 7);
   port (
      regclk : in  sl;
      regrst : in  sl;
      config : in  XpmL1SelectConfigType;
      --
      clk    : in  sl;
      rst    : in  sl;
      links  : in  XpmL1InputArray(NUM_DS_LINKS_G-1 downto 0);
      linkrd : out slv(NUM_DS_LINKS_G-1 downto 0);
      enable : out sl;
      accept : out sl;
      tag    : out slv(4 downto 0));
end XpmL1Select;

architecture rtl of XpmL1Select is

   type TrigConfigType is record
      trigmask : slv (15 downto 0);
      trigword : Slv9Array(15 downto 0);
   end record;

   constant TRIG_CONFIG_INIT_C : TrigConfigType := (
      trigmask => (others => '0'),
      trigword => (others => (others => '0')));

   type TrigStatusType is record
      trigsrc : Slv16Array(31 downto 0);
   end record;

   constant TRIG_STATUS_INIT_C : TrigStatusType := (
      trigsrc => (others => (others => '0')));

   type TrigPushType is record
      valid : sl;
      tag   : slv(4 downto 0);
   end record;

   constant TRIG_PUSH_INIT_C : TrigPushType := (
      valid => '0',
      tag   => (others => '0'));

   type RegType is record
      config : TrigConfigType(XPM_NUM_L1_TRIGGERS_C-1 downto 0);
      status : TrigStatusType(XPM_NUM_L1_TRIGGERS_C-1 downto 0);
      push   : TrigPushType;
      rd_en  : slv(NUM_DS_LINKS_G-1 downto 0);
      enable : sl;
   end record;

   constant REG_INIT_C : RegType := (
      config => (others => TRIG_CONFIG_INIT_C),
      status => (others => TRIG_STATUS_INIT_C),
      push   => TRIG_PUSH_INIT_C,
      rd_en  => (others => '0'),
      enable => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal uconfig : XpmL1SelectConfigType;

begin
   enable <= '0';
   accept <= '0';

   linkrd <= r.rd_en;

   GEN_RAM : for i in 0 to XPM_NUM_L1_TRIGGERS_C-1 generate
      U_CLEAR : entity surf.RstSync
         generic map (
            TPD_G => TPD_G)
         port map (
            clk      => clk,
            asyncRst => config.clear(i),
            syncRst  => uconfig.clear(i));

      U_L1TAG : entity surf.FifoSync
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => 5,
            ADDR_WIDTH_G => 4,
            FWFT_EN_G    => true)
         port map (
            rst   => uconfig.clear(i),
            clk   => clk,
            wr_en => r.push(i).valid,
            rd_en => r.push(i).rd,
            din   => r.push(i).tag,
            dout  => dout_tag(i));
   end generate;

   U_ENABLE : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => config.enable'length)
      port map (
         clk     => clk,
         dataIn  => config.enable,
         dataOut => uconfig.enable);

   U_TRIGSRC : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => config.trigsrc'length)
      port map (
         clk     => clk,
         dataIn  => config.trigsrc,
         dataOut => uconfig.trigsrc);

   U_TRIGWORD : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => config.trigword'length)
      port map (
         clk     => clk,
         dataIn  => config.trigword,
         dataOut => uconfig.trigword);

   U_TRIGWR : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => config.trigwr'length)
      port map (
         clk     => clk,
         dataIn  => config.trigwr,
         dataOut => uconfig.trigwr);

   comb : process (links, r, uconfig) is
      variable v    : RegType;
      variable s    : integer;
      variable push : sl;
   begin
      v := r;

      v.rd_en := (others => '0');

      for i in 0 to XPM_NUM_L1_TRIGGERS_C-1 loop

         v.push(i) := TRIG_PUSH_INIT_C;

         if uconfig.clear(i) = '1' then
            v.config(i).trigmask := (others => '0');
            v.config(i).trigword := (others => (others => '0'));
         elsif uconfig.trigwr(i) = '1' then
            s                       := conv_integer(uconfig.trigsrc);
            v.config(i).trigmask(s) := '1';
            v.config(i).trigword(s) := uconfig.trigword;
            for j in 0 to 31 loop
               v.status(i).trigsrc(j)(s) := '1';
            end loop;
         end if;

         if uconfig.enable(i) = '1' then
            for j in 0 to NUM_DS_LINKS_G-1 loop
               if links(j).valid = '1' then
                  s                                                  := conv_integer(links(j).trigsrc);
                  v.status(i).trigsrc(conv_integer(links(j).tag))(s) := '0';
                  v.rden(j)                                          := '1';
               end if;
            end loop;

            s    := 0;
            push := '0';
            for j in 0 to 31 loop
               if (r.status(i).trigsrc(j) = toSlv(0, 16)) then
                  s    := j;
                  push := '1';
               end if;
            end loop;
            if push = '1' then
               v.push.valid(i)         := '1';
               v.push.tag (i)          := toSlv(s, 5);
               v.status (i).trigsrc(s) := r.config(i).trigmask;
            end if;
         end if;
      end loop;

      rin <= v;
   end process;

   seq : process(clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process;

end rtl;
