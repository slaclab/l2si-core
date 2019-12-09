-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: XpmApp's Top Level
-- 
-- Note: Common-to-XpmApp interface defined here (see URL below)
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
use surf.AxiStreamPkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

library l2si_core;
use l2si_core.XpmPkg.all;
use l2si_core.XpmExtensionPkg.all;
use l2si_core.XpmMiniPkg.all;

library unisim;
use unisim.vcomponents.all;

entity XpmApp is
   generic (
      TPD_G           : time             := 1 ns;
      NUM_DS_LINKS_G  : integer          := 7;
      NUM_BP_LINKS_G  : integer          := 14;
      AXIL_BASEADDR_G : slv(31 downto 0) := (others => '0'));
   port (
      -----------------------
      -- XpmApp Ports --
      -----------------------
      regclk          : in  sl;
      regrst          : in  sl;
      update          : in  slv(XPM_PARTITIONS_C-1 downto 0);
      config          : in  XpmConfigType;
      status          : out XpmStatusType;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      obAppMaster     : out AxiStreamMasterType;
      obAppSlave      : in  AxiStreamSlaveType;
      groupLinkClear  : out slv (XPM_PARTITIONS_C-1 downto 0);
      -- AMC's DS Ports
      dsLinkStatus    : in  XpmLinkStatusArray(NUM_DS_LINKS_G-1 downto 0);
      dsRxData        : in  Slv16Array (NUM_DS_LINKS_G-1 downto 0);
      dsRxDataK       : in  Slv2Array (NUM_DS_LINKS_G-1 downto 0);
      dsTxData        : out Slv16Array (NUM_DS_LINKS_G-1 downto 0);
      dsTxDataK       : out Slv2Array (NUM_DS_LINKS_G-1 downto 0);
      dsRxErr         : in  slv (NUM_DS_LINKS_G-1 downto 0);
      dsRxClk         : in  slv (NUM_DS_LINKS_G-1 downto 0);
      dsRxRst         : in  slv (NUM_DS_LINKS_G-1 downto 0);
      --  BP DS Ports
      bpTxData        : out slv(15 downto 0);
      bpTxDataK       : out slv(1 downto 0);
      bpStatus        : in  XpmBpLinkStatusArray(NUM_BP_LINKS_G downto 0);
      bpRxLinkFull    : in  Slv16Array (NUM_BP_LINKS_G-1 downto 0);
      -- Timing Interface (timingClk domain) 
      timingClk       : in  sl;
      timingRst       : in  sl;
--      timingIn          : in  TimingRxType;
      timingStream    : in  XpmMiniStreamType;
      timingFbClk     : in  sl;
      timingFbRst     : in  sl;
      timingFbId      : in  slv(31 downto 0);
      timingFb        : out TimingPhyType);
end XpmApp;

architecture top_level_app of XpmApp is

   type LinkFullArray is array (natural range<>) of slv(26 downto 0);
   type LinkL1InpArray is array (natural range<>) of XpmL1FeedbackArray(NUM_DS_LINKS_G-1 downto 0);

   type StateType is (INIT_S, PADDR_S, EWORD_S, EOS_S);
   type RegType is record
      full           : LinkFullArray (XPM_PARTITIONS_C-1 downto 0);
      fullfb         : slv (XPM_PARTITIONS_C-1 downto 0);
      l1feedback     : LinkL1InpArray(XPM_PARTITIONS_C-1 downto 0);
      fiducial       : sl;
      source         : sl;
      paddr          : slv(XPM_PARTITION_ADDR_LENGTH_C-1 downto 0);  -- platform address
      bcastr         : slv(XPM_PARTITION_ADDR_LENGTH_C-1 downto 0);  -- received Xpm Broadcast
      bcastf         : slv(XPM_PARTITION_ADDR_LENGTH_C-1 downto 0);  -- Xpm Broadcast to forward
      streams        : TimingSerialArray(NSTREAMS_C-1 downto 0);
      advance        : slv (NSTREAMS_C-1 downto 0);
      state          : StateType;
      aword          : integer range 0 to paddr'left/16;
      eword          : integer range 0 to (XPM_NUM_TAG_BYTES_C+1)/2;
      ipart          : integer range 0 to XPM_PARTITIONS_C-1;
      bcastCount     : integer range 0 to 8;
      msg            : slv(XPM_PARTITION_WORD_LENGTH_C-1 downto 0);
      msgComplete    : sl;
      msgGroup       : integer range 0 to XPM_PARTITIONS_C-1;
      groupLinkClear : slv(XPM_PARTITIONS_C-1 downto 0);
   end record;
   constant REG_INIT_C : RegType := (
      full           => (others => (others => '0')),
      fullfb         => (others => '0'),
      l1feedback     => (others => (others => XPM_L1_FEEDBACK_INIT_C)),
      fiducial       => '0',
      source         => '1',
      paddr          => (others => '1'),
      bcastr         => (others => '1'),
      bcastf         => (others => '1'),
      streams        => (others => TIMING_SERIAL_INIT_C),
      advance        => (others => '0'),
      state          => INIT_S,
      aword          => 0,
      eword          => 0,
      ipart          => 0,
      bcastCount     => 0,
      msg            => (others => '0'),
      msgComplete    => '0',
      msgGroup       => 0,
      groupLinkClear => (others => '0')
      );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;


   --  feedback data from sensor links
   type L1FeedbackArray is array (natural range<>) of XpmL1FeedbackArray(XPM_PARTITIONS_C-1 downto 0);
   type FullArray is array (natural range<>) of slv (XPM_PARTITIONS_C-1 downto 0);

   signal l1Feedback    : L1FeedbackArray(NUM_DS_LINKS_G-1 downto 0);
   signal isXpm         : slv (NUM_DS_LINKS_G-1 downto 0);
   signal dsFull        : FullArray (NUM_DS_LINKS_G-1 downto 0);
   signal dsRxRcvs      : Slv32Array (NUM_DS_LINKS_G-1 downto 0);
   signal dsId          : Slv32Array (NUM_DS_LINKS_G-1 downto 0);
   signal bpRxLinkFullS : Slv16Array (NUM_BP_LINKS_G-1 downto 0);

   --  Serialized data to sensor links
   signal txData  : slv(15 downto 0);
   signal txDataK : slv(1 downto 0);

   signal streams      : TimingSerialArray(NSTREAMS_C-1 downto 0);
   signal streamIds    : Slv4Array (NSTREAMS_C-1 downto 0) := (x"1", x"2", x"0");
   signal r_streamIds  : Slv4Array (NSTREAMS_C-1 downto 0) := (x"1", x"2", x"0");
   signal advance      : slv (NSTREAMS_C-1 downto 0);
   signal pmaster      : slv (XPM_PARTITIONS_C-1 downto 0);
   signal pdepthI      : Slv8Array (XPM_PARTITIONS_C-1 downto 0);
   signal pdepth       : Slv8Array (XPM_PARTITIONS_C-1 downto 0);
   signal expWord      : Slv48Array(XPM_PARTITIONS_C-1 downto 0);
   signal fullfb       : slv (XPM_PARTITIONS_C-1 downto 0);
   signal stream0_data : slv(15 downto 0);
   signal paddr        : slv (XPM_PARTITION_ADDR_LENGTH_C-1 downto 0);
begin

   linkstatp : process (bpStatus, dsLinkStatus, dsRxRcvs, isXpm, dsId) is
      variable linkStat : XpmLinkStatusType;
   begin
      for i in 0 to NUM_DS_LINKS_G-1 loop
         linkStat           := dsLinkStatus(i);
         linkStat.rxRcvCnts := dsRxRcvs(i);
         linkStat.rxIsXpm   := isXpm (i);
         linkStat.rxId      := dsId (i);
         status.dsLink(i)   <= linkStat;
      end loop;
      status.bpLink <= bpStatus;
   end process;

   GEN_SYNCBP : for i in 0 to NUM_BP_LINKS_G-1 generate
      U_SyncFull : entity surf.SynchronizerVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 16)
         port map (
            clk     => timingClk,
            dataIn  => bpRxLinkFull(i),
            dataOut => bpRxLinkFullS(i));
   end generate;

   U_SyncPaddrRx : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => status.paddr'length)
      port map (
         clk     => regclk,
         dataIn  => r.paddr,
         dataOut => status.paddr);

   U_SyncPaddrTx : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => config.paddr'length)
      port map (
         clk     => timingClk,
         dataIn  => config.paddr,
         dataOut => paddr);

   U_FullFb : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => fullfb'length)
      port map (
         clk     => timingFbClk,
         dataIn  => r.fullfb,
         dataOut => fullfb);

   U_GroupClear : entity surf.SynchronizerOneShotVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => XPM_PARTITIONS_C)
      port map (
         clk     => regclk,
         dataIn  => r.groupLinkClear,
         dataOut => groupLinkClear);

   U_TimingFb : entity l2si_core.XpmTimingFb
      port map (
         clk                => timingFbClk,
         rst                => timingFbRst,
         id                 => timingFbId,
         detectorPartitions => (others => (others => '0')),
         full               => fullfb,
         l1feedbacks        => (others => XPM_L1_FEEDBACK_INIT_C),
         phy                => timingFb);

   GEN_DSLINK : for i in 0 to NUM_DS_LINKS_G-1 generate
      U_TxLink : entity l2si_core.XpmTxLink
         generic map (
            TPD_G     => TPD_G,
            ADDR_G    => i,
            STREAMS_G => 3,
            DEBUG_G   => false)
         port map (
            clk       => timingClk,
            rst       => timingRst,
            config    => config.dsLink(i),
            isXpm     => isXpm(i),
            streams   => r.streams,
            streamIds => r_streamIds,
            paddr     => r.bcastf,
            advance_i => r.advance,
            fiducial  => r.fiducial,
            txData    => dsTxData (i),
            txDataK   => dsTxDataK(i));

      U_RxLink : entity l2si_core.XpmRxLink
         generic map (
            TPD_G => TPD_G)
         port map (
            clk        => timingClk,
            rst        => timingRst,
            config     => config.dsLink(i),
            full       => dsFull (i),
            overflow   => open,
            l1Feedback => l1Feedback (i);
            rxClk      => dsRxClk (i),
            rxRst      => dsRxRst (i),
            rxData     => dsRxData (i),
            rxDataK    => dsRxDataK(i),
            rxErr      => dsRxErr (i),
            isXpm      => isXpm (i),
            id         => dsId (i),
            rxRcvs     => dsRxRcvs (i));
   end generate GEN_DSLINK;

   U_BpTx : entity l2si_core.XpmTxLink
      generic map (
         TPD_G     => TPD_G,
         ADDR_G    => 15,
         STREAMS_G => 3,
         DEBUG_G   => false)
      port map (
         clk       => timingClk,
         rst       => timingRst,
         config    => config.bpLink(0),
         isXpm     => '1',
         streams   => r.streams,
         streamIds => r_streamIds,
         paddr     => r.bcastf,
         advance_i => r.advance,
         fiducial  => r.fiducial,
         txData    => bpTxData,
         txDataK   => bpTxDataK);

   --U_Deserializer : entity lcls_timing_core.TimingDeserializer
   --  generic map (
   -- TPD_G => TPD_G,
   --    STREAMS_C => 3,
   --                DEBUG_G   => true )
   --  port map ( clk       => timingClk,
   --             rst       => timingRst,
   --             fiducial  => fiducial,
   --             streams   => streams,
   --             streamIds => streamIds,
   --             advance   => advance,
   --             data      => timingIn,
   --             sof       => sof,
   --             eof       => eof,
   --             crcErr    => crcErr );

   U_Seq : entity l2si_core.XpmSequence
      generic map (
         TPD_G           => TPD_G,
         AXIL_BASEADDR_G => AXIL_BASEADDR_G)
      port map (
         axilClk         => regclk,
         axilRst         => regrst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         obAppMaster     => obAppMaster,
         obAppSlave      => obAppSlave,
         timingClk       => timingClk,
         timingRst       => timingRst,
--               fiducial        => timingStream.fiducial,
         timingAdvance   => timingStream.advance(0),
         timingDataIn    => timingStream.streams(0).data,
         timingDataOut   => stream0_data);

   streams_p : process (timingStream, stream0_data) is
   begin
      streams         <= timingStream.streams;
      streams(0).data <= stream0_data;
      advance         <= timingStream.advance;
   end process;

   GEN_PART : for i in 0 to XPM_PARTITIONS_C-1 generate

      U_Master : entity l2si_core.XpmAppMaster
         generic map (
            TPD_G          => TPD_G,
            NUM_DS_LINKS_G => NUM_DS_LINKS_G,
            DEBUG_G        => (i < 1))
         port map (
            regclk     => regclk,
            update     => update (i),
            config     => config.partition(i),
            status     => status.partition(i),
            timingClk  => timingClk,
            timingRst  => timingRst,
            streams    => streams,
            streamIds  => streamIds,
            advance    => advance,
            fiducial   => timingStream.fiducial,
            full       => r.full (i),
            l1Feedback => r.l1feedback (i),
            result     => expWord (i));

      U_SyncMaster : entity surf.Synchronizer
         generic map(
            TPD_G => TPD_G)
         port map (
            clk     => timingClk,
            dataIn  => config.partition(i).master,
            dataOut => pmaster(i));

      --
      --  Actual delay is 1 greater than configuration
      --
      pdepthI(i) <= config.partition(i).pipeline.depth_fids+1;

      U_SyncDelay : entity surf.SynchronizerVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 8)
         port map (
            clk     => timingClk,
            dataIn  => pdepthI(i),
            dataOut => pdepth(i));
   end generate;

   comb : process (r, timingRst, dsFull, bpRxLinkFullS, l1Feedback,
                   timingStream, streams, advance,
                   expWord, pmaster, pdepth, paddr) is
      variable v         : RegType;
      variable tidx      : integer;
      variable mhdr      : slv(7 downto 0);
      variable broadcast : XpmBroadcastType;
   begin
      v                  := r;
      v.streams          := streams;
      v.streams(0).ready := '1';
      v.streams(1).ready := '1';
      v.streams(2).ready := '1';
      v.advance          := advance;
      v.fiducial         := timingStream.fiducial;
      v.msgComplete      := '0';

      --  test if we are the top of the hierarchy
      if streams(2).ready = '1' then
         v.source := '0';
      end if;

      if (advance(0) = '0' and r.advance(0) = '1') then
         v.streams(0).ready := '0';
      end if;

      case r.state is
         when INIT_S =>
            v.aword := 0;
            if (r.source = '0' and advance(2) = '1') then
               v.bcastr := v.streams(2).data & r.bcastr(r.bcastr'left downto r.bcastr'left-15);
               v.aword  := r.aword+1;
               v.state  := PADDR_S;
            elsif (r.source = '1' and advance(0) = '0' and r.advance(0) = '1') then
               v.advance(2)      := '1';
               v.streams(2).data := r.bcastf(15 downto 0);
               v.aword           := r.aword+1;
               v.state           := PADDR_S;
            end if;
         when PADDR_S =>
            if r.source = '1' then
               v.advance(2)      := '1';
               v.streams(2).data := r.bcastf(r.aword*16+15 downto r.aword*16);
            else
               v.bcastr := v.streams(2).data & r.bcastr(r.bcastr'left downto r.bcastr'left-15);
            end if;
            if (r.aword = r.bcastf'left/16) then
               v.ipart := 0;
               v.eword := 0;
               v.state := EWORD_S;
            else
               v.aword := r.aword+1;
            end if;
         when EWORD_S =>
            v.eword      := r.eword+1;
            v.advance(2) := '1';
            if r.source = '1' or pmaster(r.ipart) = '1' then
               v.streams(2).data := expWord(r.ipart)(r.eword*16+15 downto r.eword*16);
            end if;

            --  Collect the partition message to be forwarded,
            v.msg := v.streams(2).data & r.msg(r.msg'left downto 16);

            if (r.eword = (XPM_NUM_TAG_BYTES_C+1)/2) then
               v.msgComplete := '1';
               v.msgGroup    := r.ipart;
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
            if r.source = '1' then
               -- master of all : compose the word
               if r.bcastCount = 8 then
                  v.bcastf     := paddr;
                  v.bcastCount := 0;
               else
                  broadcast    := (btype => XPM_BROADCAST_PDELAY_C, index => r.bcastCount, value => pdepth(r.bcastCount)(6 downto 0));
                  v.bcastf     := toXpmPartitionAddress(broadcast);
                  v.bcastCount := r.bcastCount + 1;
               end if;
            else
               broadcast := toXpmBroadcastType(r.bcastr);
               case (broadcast.btype) is
                  when XPM_BROADCAST_PDELAY_C =>
                     if pmaster(tidx) = '1' then
                        -- master of this partition : compose the word
                        broadcast := (btype => XPM_BROADCAST_PDELAY_C, index => tidx, value => pdepth(tidx)(6 downto 0));
                        v.bcastf  := toXpmPartitionAddress(broadcast);
                     end if;
                  when XPM_BROADCAST_XADDR_C =>
                     v.bcastf := paddr;
                     v.paddr  := r.bcastr;
                  when others => null;
               end case;
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
         for j in 0 to NUM_BP_LINKS_G-1 loop
            v.full (i)(j+16) := bpRxLinkFullS(j)(i);
         end loop;
         if pmaster(i) = '0' and v.full(i) /= 0 then
            v.fullfb(i) := '1';
         else
            v.fullfb(i) := '0';
         end if;
      end loop;

      v.groupLinkClear := (others => '0');
      if r.msgComplete = '1' and r.msg(15) = '0' then
         mhdr := toXpmTransitionDataType(r.msg).header;
         case (mhdr(7 downto 6)) is
            when "00" =>                -- Transition
               null;
            when "01" =>                -- Occurrence
               case (mhdr(5 downto 0)) is
                  when "000000" =>      -- ClearReadout
                     v.groupLinkClear(r.msgGroup) := '1';
                  when others => null;
               end case;
            when "10" =>                -- Marker
               null;
            when others =>              -- Unknown
               null;
         end case;
      end if;

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
