-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Sensor link deserializer
--
-- This module receives the sensor link data stream and extracts the readout
-- status and event feedback information, if any.  The readout status is expressed
-- by the 'pause' signal which is asserted either by the almost full status from
-- the link or the history of 'l0Accept' and 'l1Accept' signals with the given
-- link configuration limits 'config'.
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

library l2si_core;
use l2si_core.XpmPkg.all;
use l2si_core.XpmExtensionPkg.all;

entity XpmRxLink is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk        : in  sl;
      rst        : in  sl;
      config     : in  XpmLinkConfigType;
      pause      : out slv(XPM_PARTITIONS_C-1 downto 0);
      overflow   : out slv(XPM_PARTITIONS_C-1 downto 0);
      l1Feedback : out XpmL1FeedbackType;
      l1Ack      : in  sl := '0';

      rxClk   : in  sl;
      rxRst   : in  sl;
      rxData  : in  slv(15 downto 0);
      rxDataK : in  slv(1 downto 0);
      rxErr   : in  sl;
      isXpm   : out sl;
      id      : out slv(31 downto 0);
      rxRcvs  : out slv(31 downto 0));
end XpmRxLink;

architecture rtl of XpmRxLink is
   type RxStateType is (IDLE_S, PAUSE_S, ID1_S, ID2_S, PDATA1_S, PDATA2_S);

   constant L1_FB_SLV_LENGTH_C : integer := toSlv(XPM_L1_FEEDBACK_INIT_C)'length;

   signal l1FeedbackValid : sl;
   signal l1FeedbackSlv   : slv(L1_FB_SLV_LENGTH_C-1 downto 0);

   type RegType is record
      state     : RxStateType;
      partition : integer range 0 to XPM_PARTITIONS_C-1;
      isXpm     : sl;
      id        : slv(31 downto 0);
      rxRcvs    : slv(31 downto 0);
      pause     : slv(XPM_PARTITIONS_C-1 downto 0);
      overflow  : slv(XPM_PARTITIONS_C-1 downto 0);
      l1slv     : slv(31 downto 0);
      l1wr      : sl;
      strobe    : slv(XPM_PARTITIONS_C-1 downto 0);
      timeout   : slv(8 downto 0);
   end record;
   constant REG_INIT_C : RegType := (
      state     => IDLE_S,
      partition => 0,
      isXpm     => '0',
      id        => (others => '0'),
      rxRcvs    => (others => '0'),
      pause     => (others => '1'),
      overflow  => (others => '0'),
      l1slv     => (others => '0'),
      l1wr      => '0',
      strobe    => (others => '0'),
      timeout   => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal uconfig : XpmLinkConfigType := XPM_LINK_CONFIG_INIT_C;

begin

   isXpm  <= r.isXpm;
   id     <= r.id;
   rxRcvs <= r.rxRcvs;

   U_ASync : entity surf.FifoAsync
      generic map (
         TPD_G        => TPD_G,
         FWFT_EN_G    => true,
         DATA_WIDTH_G => L1_FB_SLV_LENGTH_C,
         ADDR_WIDTH_G => 4)
      port map (
         rst    => rxRst,
         wr_clk => rxClk,
         wr_en  => r.l1wr,
         din    => r.l1slv(L1_FB_SLV_LENGTH_C-1 downto 0),
         rd_clk => clk,
         rd_en  => l1Ack,
         valid  => l1FeedbackValid,
         dout   => l1FeedbackSlv);

   process (l1FeedbackSlv, l1FeedbackValid) is
   begin
      l1Feedback       <= toL1Feedback(l1FeedbackSlv);
      l1Feedback.valid <= l1FeedbackValid;
   end process;

   U_Enable : entity surf.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => rxClk,
         dataIn  => config.enable,
         dataOut => uconfig.enable);

   U_Pause : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         INIT_G  => toSlv(-1, XPM_PARTITIONS_C),
         WIDTH_G => XPM_PARTITIONS_C)
      port map (
         clk     => clk,
         dataIn  => r.pause,
         dataOut => pause);

   U_Overflow : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => XPM_PARTITIONS_C)
      port map (
         clk     => clk,
         dataIn  => r.overflow,
         dataOut => overflow);

   U_Partition : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => config.groupMask'length)
      port map (
         clk     => rxClk,
         dataIn  => config.groupMask,
         dataOut => uconfig.groupMask);

   U_TrigSrc : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => config.trigsrc'length)
      port map (
         clk     => rxClk,
         dataIn  => config.trigsrc,
         dataOut => uconfig.trigsrc);

   comb : process (r, rxData, rxDataK, rxErr, rxRst, uconfig) is
      variable v : RegType;
      variable p : integer range 0 to XPM_PARTITIONS_C-1;
   begin
      v         := r;
      v.strobe  := (others => '0');
      v.timeout := (others => '0');
      v.l1wr    := '0';

      v.isXpm := uAnd(r.id(31 downto 24));

      case (r.state) is
         when IDLE_S =>
            v.timeout := r.timeout+1;
            -- if (rxDataK = "01") then
            --    if (rxData = (D_215_C & K_SOF_C)) then
            if (rxDataK(0) = '1') then
               if (rxData(7 downto 0) = K_SOF_C) then
                  v.rxRcvs := r.rxRcvs+1;
                  v.state  := ID1_S;
               end if;
            end if;
         when ID1_S =>
            v.id(15 downto 0) := rxData;
            v.state           := ID2_S;
         when ID2_S =>
            v.id(31 downto 16) := rxData;
            v.state            := PAUSE_S;
         when PAUSE_S =>
            v.pause    := rxData( 7 downto 0);
            v.overflow := rxData(15 downto 8);
            v.state    := PDATA1_S;
         when PDATA1_S =>
            v.l1slv(15 downto 0) := rxData;
            v.state              := PDATA2_S;
         when PDATA2_S =>
            v.l1slv(31 downto 16) := rxData;
            if uconfig.groupMask(conv_integer(toL1Feedback(v.l1slv).partition)) = '1' then
               v.l1wr := '1';
            end if;
            v.state := PAUSE_S;
         when others => null;
      end case;

      -- EOF always returns to IDLE
      if (rxDataK = "01" and rxData = (D_215_C & K_EOF_C)) then
         v       := r;
         v.state := IDLE_S;
      end if;

      if (rxRst = '1' or rxErr = '1') then
         v          := REG_INIT_C;
      end if;

      if (uconfig.enable = '0') then
         v.pause    := (others => '0');
         v.overflow := (others => '0');
         v.l1wr     := '0';
      elsif (r.timeout = uconfig.rxTimeOut) then
         v.pause    := (others => '1');
         v.overflow := (others => '1');
         v.timeout  := (others => '0');
      end if;

      v.pause    := v.pause and uconfig.groupMask;
      v.overflow := v.overflow and uconfig.groupMask;

      rin <= v;
   end process comb;

   seq : process (rxClk) is
   begin
      if rising_edge(rxClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
