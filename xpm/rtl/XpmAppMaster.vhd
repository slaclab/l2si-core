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


library surf;
use surf.StdRtlPkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;


library l2si_core;
use l2si_core.XpmPkg.all;
use l2si_core.XpmExtensionPkg.all;
use l2si_core.CuTimingPkg.all;

library unisim;
use unisim.vcomponents.all;

entity XpmAppMaster is
   generic (
      TPD_G          : time    := 1 ns;
      DEBUG_G        : boolean := false;
      NUM_DS_LINKS_G : integer := 14);
   port (
      -----------------------
      -- XpmAppMaster Ports --
      -----------------------
      regclk     : in  sl;
      update     : in  sl;
      config     : in  XpmPartitionConfigType;
      status     : out XpmPartitionStatusType;
      -- Timing Interface (timingClk domain) 
      timingClk  : in  sl;
      timingRst  : in  sl;
      --
      streams    : in  TimingSerialArray(2 downto 0);
      streamIds  : in  Slv4Array (2 downto 0) := (x"2", x"1", x"0");
      advance    : in  slv (2 downto 0);
      fiducial   : in  sl;
      pause      : in  slv (26 downto 0);
      overflow   : in  slv(26 downto 0);
      l1Feedback : in  XpmL1FeedbackType      := XPM_L1_FEEDBACK_INIT_C;
      l1Ack      : out sl;
      result     : out slv (47 downto 0));
end XpmAppMaster;

architecture rtl of XpmAppMaster is

   type RegType is record
      result     : slv(result'range);
      latch      : sl;
      insertMsg  : sl;
      strobeMsg  : sl;
      partStrobe : sl;
      timingBus  : TimingBusType;
      cuTiming   : CuTimingType;
      cuTimingV  : sl;
   end record;
   constant REG_INIT_C : RegType := (
      result     => toSlv(XPM_TRANSITION_DATA_INIT_C),
      latch      => '0',
      insertMsg  => '0',
      strobeMsg  => '0',
      partStrobe => '0',
      timingBus  => TIMING_BUS_INIT_C,
      cuTiming   => CU_TIMING_INIT_C,
      cuTimingV  => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal msgConfig    : XpmPartMsgConfigType;
   signal msgConfigInt : XpmPartMsgConfigType;
   signal msgRdCount : slv(3 downto 0);

   --  feedback data from sensor links
   --  L0 inhibit decision
   signal l0Reset       : sl;
   signal inhibit       : sl;
   --  L0 trigger output
   signal l0Accept      : sl;
   signal l0Reject      : sl;
   signal l0Tag         : slv(8*XPM_NUM_TAG_BYTES_C-1 downto 0);
   --  L1 trigger output
   signal l1Out         : sl;
   signal l1Accept      : sl;
   signal l1AcceptTag   : slv(7 downto 0);
   signal l1AcceptFrame : XpmAcceptFrameType;
   --  Analysis tag (key)
--  signal analysisTag    : slv(8*XPM_NUM_TAG_BYTES_C-1 downto 0);

   signal frame            : slv(16*TIMING_MESSAGE_WORDS_C-1 downto 0);
   signal timingBus_strobe : sl;
   signal timingBus_valid  : sl;
   signal delayOverflow    : sl;

   signal cuRx_frame         : slv(CU_TIMING_BITS_C-1 downto 0);
   signal cuRx_strobe        : sl;
   signal cuRx_valid         : sl;
   signal cuRx_delayOverflow : sl;

   signal depth_clks_20 : slv(19 downto 0);
   signal depth_fids_7  : slv( 6 downto 0);

   signal pauseOrOverflow : slv(26 downto 0);

   component ila_0
      port (clk    : in sl;
            probe0 : in slv(255 downto 0));
   end component;

begin

   GEN_ILA : if DEBUG_G generate
      U_ILA : ila_0
         port map (
            clk                   => timingClk,
            probe0(0)             => l0Accept,
            probe0(1)             => timingBus_strobe,
            probe0(2)             => fiducial,
            probe0(3)             => timingBus_valid,
            probe0(4)             => config.message.insert,
            probe0(5)             => '0',
            probe0(6)             => r.insertMsg,
            probe0(7)             => r.strobeMsg,
            probe0(15 downto 8)   => l0Tag (7 downto 0),
            probe0(19 downto 16)  => msgRdCount,
            probe0(255 downto 20) => (others => '0'));
   end generate;

   result          <= r.result;
   status.l1Select <= XPM_L1_SELECT_STATUS_INIT_C;

   depth_clks_20 <= resize(config.pipeline.depth_clks, 20);
   U_TimingDelay : entity lcls_timing_core.TimingSerialDelay
      generic map (
         TPD_G    => TPD_G,
         NWORDS_G => TIMING_MESSAGE_WORDS_C,
         FDEPTH_G => 100)
      port map (
         clk        => timingClk,
         rst        => l0Reset,
         delay      => depth_clks_20,
         fiducial_i => fiducial,
         advance_i  => advance(0),
         stream_i   => streams(0),
         frame_o    => frame,
         strobe_o   => timingBus_strobe,
         valid_o    => timingBus_valid,
         overflow_o => delayOverflow);

   U_CuRx : entity lcls_timing_core.TimingSerialDelay
      generic map (
         TPD_G    => TPD_G,
         NWORDS_G => CU_TIMING_WORDS_C,
         FDEPTH_G => 100)
      port map (
         clk        => timingClk,
         rst        => l0Reset,
         delay      => depth_clks_20,
         fiducial_i => fiducial,
         advance_i  => advance(1),
         stream_i   => streams(1),
         frame_o    => cuRx_frame,
         strobe_o   => cuRx_strobe,
         valid_o    => cuRx_valid,
         overflow_o => cuRx_delayOverflow);

   pauseOrOverflow <= pause or overflow;
   U_Inhibit : entity l2si_core.XpmInhibit
      generic map (
         TPD_G => TPD_G)
      port map (
         regclk             => regclk,
         update             => update,
         clear              => config.l0Select.reset,
         config             => config.inhibit,
         status             => status.inhibit,
         --
         clk                => timingClk,
         rst                => timingRst,
         pause(26 downto 0) => pauseOrOverflow,
         pause(27)          => r.insertMsg,
         fiducial           => fiducial,
         l0Accept           => l0Accept,
         l1Accept           => l1Accept,
         rejecc             => l0Reject,
         inhibit            => inhibit);

   U_L0Select : entity l2si_core.XpmL0Select
      generic map (
         TPD_G   => TPD_G,
         DEBUG_G => DEBUG_G)
      port map (
         clk       => timingClk,
         rst       => timingRst,
         config    => config.l0Select,
         timingBus => r.timingBus,
         cuTiming  => r.cuTiming,
         cuTimingV => r.cuTimingV,
         inhibit   => inhibit,
         strobe    => r.partStrobe,
         accept    => l0Accept,
         rejecc    => l0Reject,
         status    => status.l0Select);

   U_L0Tag : entity l2si_core.XpmL0Tag
      generic map (
         TPD_G       => TPD_G,
         TAG_WIDTH_G => l0Tag'length)
      port map (
         clk       => timingClk,
         rst       => timingRst,
         config    => config.l0Tag,
         clear     => config.l0Select.reset,
         timingBus => r.timingBus,
         push      => l0Accept,         -- allocate a tag for a trigger
         skip      => r.strobeMsg,      -- allocate a tag for a message
         push_tag  => l0Tag,
         pop       => l1Accept,
         pop_tag   => l1AcceptTag,
         pop_frame => l1AcceptFrame);

   --U_L1Select : entity l2si_core.XpmL1Select
   --  port map ( clk            => timingClk,
   --             rst            => timingRst,
   --             config         => config.l1Select,
   --             links          => l1Feedback,
   --             enable         => l1Out,
   --             --accept         => l1Accept,
   --             --tag            => l1AcceptTag );
   --             accept         => open,
   --             tag            => open );
   l1Ack <= '1';
   l1AcceptTag <= (others=>'0');
   
   --U_AnalysisTag : entity l2si_core.XpmAnalysisTag
   --  port map ( wrclk          => regclk,
   --             config         => config.analysis,
   --             rdclk          => timingClk,
   --             rden           => l1Accept,
   --             rddone         => r.partStrobe,
   --             rdvalid        => status.anaRd,
   --             tag            => analysisTag );
   status.anaRd    <= (others=>'0');

   U_SyncMsgPayload : entity surf.FifoAsync
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => config.message.header'length,
         ADDR_WIDTH_G => 4,
         FWFT_EN_G    => true)
      port map (
         rst           => timingRst,
         wr_clk        => regClk,
         wr_en         => config.message.insert,
         din           => config.message.header,
         --
         rd_clk        => timingClk,
         rd_en         => fiducial,
         rd_data_count => msgRdCount,
         valid         => msgConfigInt.insert,
         dout          => msgConfigInt.header);

   depth_fids_7 <= resize(config.pipeline.depth_fids, 7);

   U_MsgDelay : entity surf.SlvDelay
      generic map (
         TPD_G        => TPD_G,
         SRL_EN_G     => true,
         DELAY_G      => 128,
         REG_OUTPUT_G => false,
         WIDTH_G      => 9 )
      port map (
         clk              => timingClk,                 -- [in]
         en               => fiducial,                  -- [in]
         delay            => depth_fids_7,
         din (7 downto 0) => msgConfigInt.header,
         din (8)          => msgConfigInt.insert,
         dout(7 downto 0) => msgConfig.header,
         dout(8)          => msgConfig.insert );

   U_SyncReset : entity surf.RstSync
      generic map (
         TPD_G => TPD_G)
      port map (
         clk      => timingClk,
         asyncRst => config.l0Select.reset,
         syncRst  => l0Reset);
   --
   --  Unimplemented L1 trigger
   --
   l1Accept <= l0Accept;

   comb : process (r, timingRst, frame, cuRx_frame, cuRx_valid,
                   timingBus_strobe, timingBus_valid, msgConfig,
                   l0Tag, l0Accept, l0Reject) is
      variable v     : RegType;
      variable pword : XpmEventDataType      := XPM_EVENT_DATA_INIT_C;
      variable msg   : XpmTransitionDataType := XPM_TRANSITION_DATA_INIT_C;
   begin
      v := r;

      v.partStrobe := r.timingBus.strobe;
      v.latch      := r.partStrobe;
      v.strobeMsg  := '0';

      if msgConfig.insert = '1' and r.timingBus.strobe = '1' then
         v.insertMsg := '1';
      end if;

      if r.latch = '1' then
         if r.insertMsg = '1' then
            v.insertMsg := '0';
            v.strobeMsg := '1';
            msg.valid   := '1';
            msg.l0tag   := l0Tag(msg.l0tag'range);
            msg.header  := msgConfig.header(6 downto 0);
            msg.count   := l0Tag(msg.count'range);
            v.result    := toSlv(msg);
         else
            pword.valid    := '1';
            pword.l0Accept := l0Accept;
            pword.l0Reject := l0Reject;
            pword.l1Accept := l0Accept;
            pword.l1Expect := l0Accept;
            pword.l0tag    := l0Tag(pword.l0tag'range);
            pword.l1tag    := l0Tag(pword.l1tag'range);
            pword.count    := l0Tag(pword.count'range);
            v.result       := toSlv(pword);
         end if;
      end if;

      if timingBus_strobe = '1' then
         v.timingBus.message := ToTimingMessageType(frame);
         v.cuTiming          := ToCuTimingType (cuRx_frame);
         v.cuTimingV         := cuRx_valid;
      end if;
      v.timingBus.strobe := timingBus_strobe;
      v.timingBus.valid  := timingBus_valid;

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
   end process seq;

end rtl;
