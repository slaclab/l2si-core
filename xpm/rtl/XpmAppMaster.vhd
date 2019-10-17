-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : XpmAppMaster.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2019-10-17
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.TimingPkg.all;

use work.XpmPkg.all;
use work.XpmExtensionPkg.all;
use work.CuTimingPkg.all;

library unisim;
use unisim.vcomponents.all;

entity XpmAppMaster is
   generic (
      TPD_G               : time                := 1 ns;
      DEBUG_G             : boolean             := false;
      NDsLinks            : integer             := 14 );
   port (
      -----------------------
      -- XpmAppMaster Ports --
      -----------------------
      regclk            : in  sl;
      update            : in  sl;
      config            : in  XpmPartitionConfigType;
      status            : out XpmPartitionStatusType;
      -- Timing Interface (timingClk domain) 
      timingClk         : in  sl;
      timingRst         : in  sl;
      --
      streams           : in  TimingSerialArray(2 downto 0);
      streamIds         : in  Slv4Array        (2 downto 0) := (x"2",x"1",x"0");
      advance           : in  slv              (2 downto 0);
      fiducial          : in  sl;
      full              : in  slv              (26 downto 0);
      l1Feedback           : in  XpmL1FeedbackArray  (NDsLinks-1 downto 0) := (others=>XPM_L1_FEEDBACK_INIT_C);
      result            : out slv              (47 downto 0) );
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
    result     => (others=>'0'),
    latch      => '0',
    insertMsg  => '0',
    strobeMsg  => '0',
    partStrobe => '0',
    timingBus  => TIMING_BUS_INIT_C,
    cuTiming   => CU_TIMING_INIT_C,
    cuTimingV  => '0' );

  signal r : RegType := REG_INIT_C;
  signal rin : RegType;

  signal msgConfig      : XpmPartMsgConfigType;
  signal messageDin     : slv(msgConfig.hdr'length+msgConfig.payload'length-1 downto 0);
  signal messageDout    : slv(msgConfig.hdr'length+msgConfig.payload'length-1 downto 0);
  signal msgWr          : sl;
  signal msgRdCount     : slv(3 downto 0);
  
  --  feedback data from sensor links
  --  L0 inhibit decision
  signal l0Reset        : sl;
  signal inhibit        : sl;

  --  L0 trigger output
  signal l0Accept       : sl;
  signal l0Reject       : sl;
  signal l0Tag          : slv(8*NTagBytes-1 downto 0);
  --  L1 trigger output
  signal l1Out          : sl;
  signal l1Accept       : sl;
  signal l1AcceptTag    : slv(7 downto 0);
  signal l1AcceptFrame  : XpmAcceptFrameType;
  --  Analysis tag (key)
--  signal analysisTag    : slv(8*NTagBytes-1 downto 0);
  
  signal frame         : slv(16*TIMING_MESSAGE_WORDS_C-1 downto 0);
  signal timingBus_strobe : sl;
  signal timingBus_valid  : sl;
  signal delayOverflow : sl;

  signal cuRx_frame         : slv(CU_TIMING_BITS_C-1 downto 0);
  signal cuRx_strobe        : sl;
  signal cuRx_valid         : sl;
  signal cuRx_delayOverflow : sl;

  component ila_0
    port ( clk : in  sl;
           probe0 : in slv(255 downto 0) );
  end component;

begin

  GEN_ILA: if DEBUG_G generate
    U_ILA : ila_0
      port map ( clk                    => timingClk,
                 probe0(  0 )           => l0Accept,
                 probe0(  1 )           => timingBus_strobe,
                 probe0(  2 )           => fiducial,
                 probe0(  3 )           => timingBus_valid,
                 probe0(  4 )           => config.message.insert,
                 probe0(  5 )           => msgWr,
                 probe0(  6 )           => r.insertMsg,
                 probe0(  7 )           => r.strobeMsg,
                 probe0( 15 downto 8 )  => l0Tag      (7 downto 0),
                 probe0( 19 downto 16 ) => msgRdCount,
                 probe0(255 downto 20 ) => (others=>'0'));
  end generate;

  result <= r.result;
  status.l1Select <= XPM_L1_SELECT_STATUS_INIT_C;
  
  U_TimingDelay : entity work.TimingSerialDelay
    generic map ( NWORDS_G => TIMING_MESSAGE_WORDS_C,
                  FDEPTH_G => 100 )
    port map ( clk            => timingClk,
               rst            => l0Reset,
               delay          => resize(config.pipeline.depth_clks,20),
               fiducial_i     => fiducial,
               advance_i      => advance(0),
               stream_i       => streams(0),
               frame_o        => frame,
               strobe_o       => timingBus_strobe,
               valid_o        => timingBus_valid,
               overflow_o     => delayOverflow );

  U_CuRx : entity work.TimingSerialDelay
    generic map ( NWORDS_G => CU_TIMING_WORDS_C,
                  FDEPTH_G => 100 )
    port map ( clk            => timingClk,
               rst            => l0Reset,
               delay          => resize(config.pipeline.depth_clks,20),
               fiducial_i     => fiducial,
               advance_i      => advance(1),
               stream_i       => streams(1),
               frame_o        => cuRx_frame,
               strobe_o       => cuRx_strobe,
               valid_o        => cuRx_valid,
               overflow_o     => cuRx_delayOverflow );

  U_Inhibit : entity work.XpmInhibit
    port map ( regclk         => regclk,
               update         => update,
               clear          => config.l0Select.reset,
               config         => config.inhibit,
               status         => status.inhibit,
               --
               clk            => timingClk,
               rst            => timingRst,
               full(26 downto 0) => full,
               full(27)          => r.insertMsg,
               fiducial       => fiducial,
               l0Accept       => l0Accept,
               l1Accept       => l1Accept,
               rejecc         => l0Reject,
               inhibit        => inhibit );
  
  U_L0Select : entity work.XpmL0Select
    generic map ( DEBUG_G => DEBUG_G )
    port map ( clk            => timingClk,
               rst            => timingRst,
               config         => config.l0Select,
               timingBus      => r.timingBus,
               cuTiming       => r.cuTiming,
               cuTimingV      => r.cuTimingV,
               inhibit        => inhibit,
               strobe         => r.partStrobe,
               accept         => l0Accept,
               rejecc         => l0Reject,
               status         => status.l0Select );

  U_L0Tag : entity work.XpmL0Tag
    generic map ( TAG_WIDTH_G => l0Tag'length )
    port map ( clk            => timingClk,
               rst            => timingRst,
               config         => config.l0Tag,
               clear          => config.l0Select.reset,
               timingBus      => r.timingBus,
               push           => l0Accept,     -- allocate a tag for a trigger
               skip           => r.strobeMsg,  -- allocate a tag for a message
               push_tag       => l0Tag,
               pop            => l1Accept,
               pop_tag        => l1AcceptTag,
               pop_frame      => l1AcceptFrame );

  --U_L1Select : entity work.XpmL1Select
  --  port map ( clk            => timingClk,
  --             rst            => timingRst,
  --             config         => config.l1Select,
  --             links          => l1Feedback,
  --             enable         => l1Out,
  --             --accept         => l1Accept,
  --             --tag            => l1AcceptTag );
  --             accept         => open,
  --             tag            => open );

  --U_AnalysisTag : entity work.XpmAnalysisTag
  --  port map ( wrclk          => regclk,
  --             config         => config.analysis,
  --             rdclk          => timingClk,
  --             rden           => l1Accept,
  --             rddone         => r.partStrobe,
  --             rdvalid        => status.anaRd,
  --             tag            => analysisTag );

  messageDin        <= config.message.payload & config.message.hdr;
  msgConfig.hdr     <= messageDout(config.message.hdr'range);
  msgConfig.payload <= messageDout(config.message.payload'left+config.message.hdr'length downto config.message.hdr'length);

  U_LatchMsg : entity work.SynchronizerOneShot
    port map ( clk     => regClk,
               dataIn  => config.message.insert,
               dataOut => msgWr );
  
  U_SyncMsgPayload : entity work.FifoAsync
    generic map ( DATA_WIDTH_G => messageDin'length,
                  ADDR_WIDTH_G => 4,
                  FWFT_EN_G    => true )
    port map ( rst     => timingRst,
               wr_clk  => regClk,
               wr_en   => msgWr,
               din     => messageDin,
               --
               rd_clk  => timingClk,
               rd_en   => r.strobeMsg,
               rd_data_count => msgRdCount,
               valid   => msgConfig.insert,
               dout    => messageDout );

  U_SyncReset : entity work.RstSync
    port map ( clk       => timingClk,
               asyncRst  => config.l0Select.reset,
               syncRst   => l0Reset );
  --
  --  Unimplemented L1 trigger
  --
  l1Accept <= l0Accept;

  comb : process ( r, timingRst, frame, cuRx_frame, cuRx_valid,
                   timingBus_strobe, timingBus_valid, msgConfig,
                   l0Tag, l0Accept, l0Reject ) is
    variable v     : RegType;
    variable pword : XpmEventDataType;
    variable msg   : XpmTransitionDataType;
  begin
    v := r;

    v.partStrobe := r.timingBus.strobe;
    v.latch      := r.partStrobe;
    v.strobeMsg  := '0';

    if msgConfig.insert = '1' and r.timingBus.strobe = '1' then
      v.insertMsg := '1';
    end if;

    if r.latch='1' then
      if r.insertMsg = '1' then
        v.insertMsg  := '0';
        v.strobeMsg  := '1';
        msg.l0tag    := l0Tag(msg.l0tag'range);
        msg.header      := msgConfig.hdr;
        msg.payload  := msgConfig.payload;
        msg.count   := l0Tag(msg.count'range);
        v.result     := toSlv(msg);
      else
        pword.l0Accept    := l0Accept;
        pword.l0Reject    := l0Reject;
        pword.l1Accept    := l0Accept;
        pword.l1Expect    := l0Accept;
        pword.l0tag  := l0Tag(pword.l0tag'range);
        pword.l1tag  := l0Tag(pword.l1tag'range);
        pword.count := l0Tag(pword.count'range);
        v.result     := toSlv(pword);
      end if;
    end if;
    
    if timingBus_strobe='1' then
      v.timingBus.message := ToTimingMessageType(frame);
      v.cuTiming          := ToCuTimingType     (cuRx_frame);
      v.cuTimingV         := cuRx_valid;
    end if;
    v.timingBus.strobe  := timingBus_strobe;
    v.timingBus.valid   := timingBus_valid;
    
    if timingRst='1' then
      v := REG_INIT_C;
    end if;

    rin <= v;
  end process;

  seq : process (timingClk) is
  begin
    if rising_edge(timingClk) then
      r <= rin;
    end if;
  end process seq;

end rtl;
