-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: XpmMini's Top Level
-- 
-- Note: Common-to-XpmMini interface defined here (see URL below)
--       https://confluence.slac.stanford.edu/x/rLyMCw
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 DAQ Software'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 DAQ Software', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

library l2si_core;
use l2si_core.XpmPkg.all;
use l2si_core.XpmExtensionPkg.all;
use l2si_core.XpmMiniPkg.all;

library unisim;
use unisim.vcomponents.all;

entity XpmMini is
   generic (
      TPD_G          : time    := 1 ns;
      NUM_DS_LINKS_G : integer := 1;
      NUM_BP_LINKS_G : integer := 1);
   port (
      -----------------------
      -- XpmMini Ports --
      -----------------------
      regclk       : in  sl;
      regrst       : in  sl;
      update       : in  sl;
      config       : in  XpmMiniConfigType;
      status       : out XpmMiniStatusType;
      -- DS Ports
      dsRxClk      : in  slv (NUM_DS_LINKS_G-1 downto 0);
      dsRxRst      : in  slv (NUM_DS_LINKS_G-1 downto 0);
      dsRx         : in  TimingRxArray (NUM_DS_LINKS_G-1 downto 0);
      dsTx         : out TimingPhyArray (NUM_DS_LINKS_G-1 downto 0);
      -- Timing Interface (timingClk domain) 
      timingClk    : in  sl;
      timingRst    : in  sl;
      timingStream : in  XpmMiniStreamType);
end XpmMini;

architecture top_level_app of XpmMini is

   type LinkFullArray is array (natural range<>) of slv(26 downto 0);
   type LinkL1InpArray is array (natural range<>) of XpmL1FeedbackArray(NUM_DS_LINKS_G-1 downto 0);

   type StateType is (INIT_S, PADDR_S, EWORD_S, EOS_S);
   type RegType is record
      full       : LinkFullArray (XPM_PARTITIONS_C-1 downto 0);
      l1feedback : LinkL1InpArray(XPM_PARTITIONS_C-1 downto 0);
      fiducial   : sl;
      source     : sl;
      paddr      : slv(XPM_PARTITION_ADDR_LENGTH_C-1 downto 0);  -- platform address
      bcastr     : slv(XPM_PARTITION_ADDR_LENGTH_C-1 downto 0);  -- received Xpm Broadcast
      bcastf     : slv(XPM_PARTITION_ADDR_LENGTH_C-1 downto 0);  -- Xpm Broadcast to forward
      streams    : TimingSerialArray(NSTREAMS_C-1 downto 0);
      advance    : slv (NSTREAMS_C-1 downto 0);
      state      : StateType;
      aword      : integer range 0 to (XPM_PARTITION_ADDR_LENGTH_C-1)/16;
      eword      : integer range 0 to (XPM_NUM_TAG_BYTES_C+1)/2;
      ipart      : integer range 0 to 2*XPM_PARTITIONS_C-1;
      bcastCount : integer range 0 to 8;
   end record;
   constant REG_INIT_C : RegType := (
      full       => (others => (others => '0')),
      l1feedback => (others => (others => XPM_L1_FEEDBACK_INIT_C)),
      fiducial   => '0',
      source     => '1',
      paddr      => (others => '1'),
      bcastr     => (others => '1'),
      bcastf     => (others => '1'),
      streams    => (others => TIMING_SERIAL_INIT_C),
      advance    => (others => '0'),
      state      => INIT_S,
      aword      => 0,
      eword      => 0,
      ipart      => 0,
      bcastCount => 0);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal partitionConfig : XpmPartitionConfigType;
   signal partitionStatus : XpmPartitionStatusType;

   --  feedback data from sensor links
   type L1FeedbackArray is array (natural range<>) of XpmL1FeedbackArray(XPM_PARTITIONS_C-1 downto 0);
   type FullArray is array (natural range<>) of slv (XPM_PARTITIONS_C-1 downto 0);

   signal l1Feedback    : L1FeedbackArray(NUM_DS_LINKS_G-1 downto 0);
   signal isXpm         : slv (NUM_DS_LINKS_G-1 downto 0);
   signal rxErr         : slv (NUM_DS_LINKS_G-1 downto 0);
   signal dsFull        : FullArray (NUM_DS_LINKS_G-1 downto 0);
   signal dsRxRcvs      : Slv32Array (NUM_DS_LINKS_G-1 downto 0);
   signal dsId          : Slv32Array (NUM_DS_LINKS_G-1 downto 0);
   signal bpRxLinkFullS : Slv16Array (NUM_BP_LINKS_G-1 downto 0);
   signal linkConfig    : XpmLinkConfigArray(NUM_DS_LINKS_G-1 downto 0);

   signal r_streamIds  : Slv4Array (NSTREAMS_C-1 downto 0)       := (x"1", x"2", x"0");
   signal pdepth       : Slv8Array (XPM_PARTITIONS_C-1 downto 0) := (others => (others => '0'));
   signal expWord      : Slv48Array(XPM_PARTITIONS_C-1 downto 0) := (others => (others => '0'));

begin

   linkstatp : process (dsRxRcvs, isXpm, dsId) is
      variable linkStat : XpmLinkStatusType;
   begin
      for i in 0 to NUM_DS_LINKS_G-1 loop
         linkStat           := XPM_LINK_STATUS_INIT_C;
         linkStat.rxRcvCnts := dsRxRcvs(i);
         linkStat.rxIsXpm   := isXpm (i);
         linkStat.rxId      := dsId (i);
         status.dsLink(i)   <= linkStat;
      end loop;
   end process;

   GEN_DSLINK : for i in 0 to NUM_DS_LINKS_G-1 generate
      linkConfig(i).enable     <= config.dsLink(i).enable;
      linkConfig(i).loopback   <= config.dsLink(i).loopback;
      linkConfig(i).txReset    <= config.dsLink(i).txReset;
      linkConfig(i).rxReset    <= config.dsLink(i).rxReset;
      linkConfig(i).txPllReset <= config.dsLink(i).txPllReset;
      linkConfig(i).rxPllReset <= config.dsLink(i).rxPllReset;
      linkConfig(i).txDelayRst <= config.dsLink(i).txReset;
      linkConfig(i).txDelay    <= (others => '0');
      linkConfig(i).groupMask  <= toSlv(1, XPM_PARTITIONS_C);
      linkConfig(i).trigsrc    <= (others => '0');

      U_TxLink : entity l2si_core.XpmTxLink
         generic map (
            TPD_G     => TPD_G,
            ADDR_G    => i,
            STREAMS_G => 3)
         port map (
            clk       => timingClk,
            rst       => timingRst,
            config    => linkConfig(i),
            isXpm     => isXpm(i),
            streams   => r.streams,
            streamIds => r_streamIds,
            paddr     => r.bcastf,
            advance_i => r.advance,
            fiducial  => r.fiducial,
            txData    => dsTx(i).data,
            txDataK   => dsTx(i).dataK);

      dsTx(i).control <= TIMING_PHY_CONTROL_INIT_C;
      rxErr(i)        <= '0' when (dsRx(i).dspErr = "00" and dsRx(i).decErr = "00") else '1';

      U_RxLink : entity l2si_core.XpmRxLink
         generic map (
            TPD_G => TPD_G)
         port map (
            clk        => timingClk,
            rst        => timingRst,
            config     => linkConfig(i),
            rxData     => dsRx(i).data,
            rxDataK    => dsRx(i).dataK,
            rxErr      => rxErr(i),
            rxClk      => dsRxClk(i),
            rxRst      => dsRxRst(i),
            isXpm      => isXpm(i),
            id         => dsId(i),
            rxRcvs     => dsRxRcvs(i),
            full       => dsFull(i),
            l1Feedback => l1Feedback(i));
   end generate GEN_DSLINK;

   --  Form the full partition configuration
   partitionConfig.master   <= '1';
   partitionConfig.l0Select <= config.partition.l0Select;
   partitionConfig.l1Select <= XPM_L1_SELECT_CONFIG_INIT_C;
   partitionConfig.analysis <= XPM_ANALYSIS_CONFIG_INIT_C;
   partitionConfig.l0Tag    <= XPM_L0_TAG_CONFIG_INIT_C;
   partitionConfig.pipeline <= config.partition.pipeline;
   partitionConfig.inhibit  <= XPM_PART_INH_CONFIG_INIT_C;
   partitionConfig.message  <= config.partition.message;

   status.partition.l0Select <= partitionStatus.l0Select;

   U_Master : entity l2si_core.XpmAppMaster
      generic map (
         TPD_G          => TPD_G,
         NUM_DS_LINKS_G => NUM_DS_LINKS_G)
      port map (
         regclk     => regclk,
         update     => update,
         config     => partitionConfig,
         status     => partitionStatus,
         timingClk  => timingClk,
         timingRst  => timingRst,
         streams    => timingStream.streams,
         advance    => timingStream.advance,
         fiducial   => timingStream.fiducial,
         full       => r.full(0),
         l1Feedback => r.l1feedback(0),
         result     => expWord(0));

   U_SyncDelay : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 8)
      port map (
         clk     => timingClk,
         dataIn  => partitionConfig.pipeline.depth_fids,
         dataOut => pdepth(0));

   pdepth(7) <= pdepth(0);
   pdepth(6) <= pdepth(0);
   pdepth(5) <= pdepth(0);   
   pdepth(4) <= pdepth(0);
   pdepth(3) <= pdepth(0);
   pdepth(2) <= pdepth(0);
   pdepth(1) <= pdepth(0);

   comb : process (dsFull, expWord, l1Feedback, pdepth, r, timingRst, timingStream) is
      variable v    : RegType;
      variable tidx : integer;
--      constant pd   : XpmBroadcastType := PDELAY;
   begin
      v                  := r;
      v.streams          := timingStream.streams;
      --v.streams(0).ready := '1';
      v.streams(1).ready := '1';
      --v.streams(2).ready := '1';
      v.advance          := timingStream.advance;
      v.fiducial         := timingStream.fiducial;

      --if (timingStream.advance(0)='0' and r.advance(0)='1') then
      --  v.streams(0).ready := '0';
      --end if;

      case r.state is
         when INIT_S =>
            v.aword := 0;
            if (timingStream.advance(0) = '0' and r.advance(0) = '1') then
               v.advance(2)      := '1';
               v.streams(2).data := r.bcastf(15 downto 0);
               v.aword           := r.aword+1;
               v.state           := PADDR_S;
            end if;
         when PADDR_S =>
            v.advance(2)      := '1';
            v.streams(2).data := r.bcastf(r.aword*16+15 downto r.aword*16);
            if (r.aword = r.bcastf'left/16) then
               v.ipart := 0;
               v.eword := 0;
               v.state := EWORD_S;
            else
               v.aword := r.aword+1;
            end if;
         when EWORD_S =>
            v.eword           := r.eword+1;
            v.advance(2)      := '1';
            v.streams(2).data := expWord(r.ipart)(r.eword*16+15 downto r.eword*16);
            if (r.eword = (XPM_NUM_TAG_BYTES_C+1)/2) then
               if (r.ipart = XPM_PARTITIONS_C-1) then
                  v.state := EOS_S;
               else
                  v.ipart := r.ipart+1;
                  v.eword := 0;
               end if;
            end if;
         when EOS_S =>
            v.streams(2).ready := '0';
            v.bcastf           := r.bcastr;
            tidx               := toXpmBroadcastType(r.bcastr).index;
            -- master of all : compose the word
            if r.bcastCount = 8 then
               v.bcastf     := r.paddr;
               v.bcastCount := 0;
            else
               v.bcastf     := toXpmPartitionAddress((btype => XPM_BROADCAST_PDELAY_C, index => r.bcastCount, value => pdepth(r.bcastCount)(6 downto 0)));
               v.bcastCount := r.bcastCount + 1;
            end if;
            v.aword := 0;
            v.state := INIT_S;
         when others => null;
      end case;

      for i in 0 to XPM_PARTITIONS_C-1 loop
         for j in 0 to NUM_DS_LINKS_G-1 loop
            v.full (i)(j)      := dsFull (j)(i);
            v.l1feedback(i)(j) := l1Feedback(j)(i);
         end loop;
      end loop;

      if timingRst = '1' then
         v := REG_INIT_C;
      end if;

      rin <= v;
   end process;

   seq : process (timingClk) is
   begin
      if rising_edge(timingClk) then
         r <= rin after TPD_G;
      end if;
   end process;

end top_level_app;
