-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : XpmAppMaster.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2017-07-19
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
--use work.AmcCarrierPkg.all;
use work.XpmPkg.all;

library unisim;
use unisim.vcomponents.all;

entity XpmAppMaster is
   generic (
      TPD_G               : time                := 1 ns;
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
      streams           : in  TimingSerialArray(1 downto 0);
      streamIds         : in  Slv4Array        (1 downto 0) := (x"1",x"0");
      advance           : in  slv              (1 downto 0);
      fiducial          : in  sl;
      sof               : in  sl;
      eof               : in  sl;
      crcErr            : in  sl;
      full              : in  slv              (31 downto 0);
      l1Input           : in  XpmL1InputArray  (NDsLinks-1 downto 0) := (others=>XPM_L1_INPUT_INIT_C);
      result            : out slv              (47 downto 0) );
end XpmAppMaster;

architecture rtl of XpmAppMaster is

  type RegType is record
    result     : slv(result'range);
    latch      : sl;
    insertMsg  : sl;
    partStrobe : sl;
    timingBus  : TimingBusType;
  end record;
  constant REG_INIT_C : RegType := (
    result     => (others=>'0'),
    latch      => '0',
    insertMsg  => '0',
    partStrobe => '0',
    timingBus  => TIMING_BUS_INIT_C );

  signal r : RegType := REG_INIT_C;
  signal rin : RegType;

  signal msgConfig      : XpmPartMsgConfigType;
  
  --  input data from sensor links
  --  L0 inhibit decision
  signal inhibit        : sl;
  signal presult        : XpmPartitionDataType;
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
  
  constant DEBUG_C : boolean := true;
  
  component ila_1x256x1024
    port ( clk : in  sl;
           probe0 : in slv(255 downto 0) );
  end component;

begin

  --GEN_ILA: if DEBUG_C generate
  --  U_ILA : ila_1x256x1024
  --    port map ( clk      => timingClk,
  --               probe0( 31 downto   0) => analysisTag(0),
  --               probe0( 47 downto  32) => streams(1).data,
  --               probe0( 48 )           => advance(1),
  --               probe0( 49 )           => l0Accept(0),
  --               probe0( 50 )           => partStrobe(0),
  --               probe0( 51 )           => addrStrobe,
  --               probe0( 52 )           => timingBus.strobe,
  --               probe0( 60 downto 53 ) => l0Tag(0),
  --               probe0( 68 downto 61 ) => l1AcceptTag(0),
  --               probe0(255 downto 69 ) => (others=>'0'));
  --end generate;

  result <= r.result;
  status.l1Select <= XPM_L1_SELECT_STATUS_INIT_C;
  
  U_TimingDelay : entity work.TimingSerialDelay
    generic map ( NWORDS_G => TIMING_MESSAGE_WORDS_C,
                  FDEPTH_G => 100 )
    port map ( clk            => timingClk,
               rst            => timingRst,
               delay          => config.pipeline.depth,
               fiducial_i     => fiducial,
               advance_i      => advance(0),
               stream_i       => streams(0),
               frame_o        => frame,
               strobe_o       => timingBus_strobe,
               valid_o        => timingBus_valid,
               overflow_o     => delayOverflow );

  U_Inhibit : entity work.XpmInhibit
    port map ( regclk         => regclk,
               update         => update,
               clear          => config.l0Select.reset,
               config         => config.inhibit,
               status         => status.inhibit,
               --
               clk            => timingClk,
               rst            => timingRst,
               full           => full,
               fiducial       => fiducial,
               l0Accept       => l0Accept,
               l1Accept       => l1Accept,
               rejecc         => l0Reject,
               inhibit        => inhibit );
  
  U_L0Select : entity work.XpmL0Select
    port map ( clk            => timingClk,
               rst            => timingRst,
               config         => config.l0Select,
               timingBus      => r.timingBus,
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
               enabled        => config.l0Select.enabled,
               timingBus      => r.timingBus,
               push           => l0Accept,
               push_tag       => l0Tag,
               pop            => l1Accept,
               pop_tag        => l1AcceptTag,
               pop_frame      => l1AcceptFrame );

  --U_L1Select : entity work.XpmL1Select
  --  port map ( clk            => timingClk,
  --             rst            => timingRst,
  --             config         => config.l1Select,
  --             links          => l1Input,
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

  U_SyncMsgPayload : entity work.SynchronizerVector
    generic map ( WIDTH_G => config.message.payload'length )
    port map ( clk     => timingClk,
               dataIn  => config.message.payload,
               dataOut => msgConfig.payload );
  U_SyncMsgHeader : entity work.SynchronizerVector
    generic map ( WIDTH_G => config.message.hdr'length )
    port map ( clk     => timingClk,
               dataIn  => config.message.hdr,
               dataOut => msgConfig.hdr );
  U_SyncMsgInsert : entity work.RstSync
    port map ( clk       => timingClk,
               asyncRst  => config.message.insert,
               syncRst   => msgConfig.insert );
  --
  --  Unimplemented L1 trigger
  --
  l1Accept <= l0Accept;
  presult.l0a    <= l0Accept;
  presult.l1a    <= l0Accept;
  presult.l1e    <= l0Accept;
  presult.l0tag  <= l0Tag(presult.l0tag'range);
  presult.l1tag  <= l0Tag(presult.l1tag'range);
--  presult.anatag <= analysisTag;
  presult.anatag <= l0Tag(presult.anatag'range);
  
  comb : process ( r, timingRst, frame, timingBus_strobe, timingBus_valid, msgConfig,
                   presult ) is
    variable v     : RegType;
    variable pword : XpmPartitionDataType;
  begin
    v := r;

    v.partStrobe := r.timingBus.strobe;
    v.latch      := r.partStrobe;

    if msgConfig.insert = '1' then
      v.insertMsg := '1';
    end if;
    
    if r.latch='1' then
      if r.insertMsg = '1' then
        v.insertMsg := '0';
        v.result    := msgConfig.payload & '0' & msgConfig.hdr;
      else
        v.result    := toSlv(presult);
      end if;
    end if;
    
    if timingBus_strobe='1' then
      v.timingBus.message := ToTimingMessageType(frame);
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