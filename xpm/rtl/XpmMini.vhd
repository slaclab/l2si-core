-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : XpmMini.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2020-01-15
-- Platform   : 
-- Standard   : VHDL'93/02
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

use work.StdRtlPkg.all;
use work.TimingExtnPkg.all;
use work.TimingPkg.all;
use work.AxiLitePkg.all;
use work.XpmPkg.all;
use work.XpmMiniPkg.all;

library unisim;
use unisim.vcomponents.all;

entity XpmMini is
   generic ( NDsLinks : integer := 1 );
   port (
      -----------------------
      -- XpmMini Ports --
      -----------------------
      regclk            : in  sl;
      regrst            : in  sl;
      update            : in  sl;
      config            : in  XpmMiniConfigType;
      status            : out XpmMiniStatusType;
      -- DS Ports
      dsRxClk           : in  slv               (NDsLinks-1 downto 0);
      dsRxRst           : in  slv               (NDsLinks-1 downto 0);
      dsRx              : in  TimingRxArray     (NDsLinks-1 downto 0);
      dsTx              : out TimingPhyArray    (NDsLinks-1 downto 0);
      -- Timing Interface (timingClk domain) 
      timingClk         : in  sl;
      timingRst         : in  sl;
      timingStream      : in  XpmStreamType );
end XpmMini;

architecture top_level_app of XpmMini is

  type LinkFullArray  is array (natural range<>) of slv(26 downto 0);
  type LinkL1InpArray is array (natural range<>) of XpmL1InputArray(NDsLinks-1 downto 0);

  type StateType is (IDLE_S, INIT_S, SLAVE_S, PADDR_S, EWORD_S, EOS_S);
  type RegType is record
    full       : LinkFullArray (NPartitions-1 downto 0);
    l1input    : LinkL1InpArray(NPartitions-1 downto 0);
    fiducial   : slv(3 downto 0);
    paddr      : slv(PADDR_LEN-1 downto 0); -- platform address
    paddrStrobe: sl;
    bcastr     : slv(PADDR_LEN-1 downto 0); -- received Xpm Broadcast
    bcastf     : slv(PADDR_LEN-1 downto 0); -- Xpm Broadcast to forward
    streamReset: sl;
    advance    : sl;
    stream     : TimingSerialType;
    state      : StateType;
    eword      : integer range 0 to (NTagBytes+1)/2;
    ipart      : integer range 0 to 2*NPartitions-1;
    bcastCount : integer range 0 to 8;
  end record;
  constant REG_INIT_C : RegType := (
    full       => (others=>(others=>'0')),
    l1input    => (others=>(others=>XPM_L1_INPUT_INIT_C)),
    fiducial   => (others=>'0'),
    paddr      => (others=>'1'),
    paddrStrobe=> '0',
    bcastr     => (others=>'1'),
    bcastf     => (others=>'1'),
    streamReset=> '1',
    advance    => '0',
    stream     => TIMING_SERIAL_INIT_C,
    state      => IDLE_S,
    eword      => 0,
    ipart      => 0,
    bcastCount => 0 );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;
  
  signal partitionConfig : XpmPartitionConfigType;
  signal partitionStatus : XpmPartitionStatusType;
  
  --  input data from sensor links
  type L1InputArray is array (natural range<>) of XpmL1InputArray(NPartitions-1 downto 0);
  type FullArray    is array (natural range<>) of slv            (NPartitions-1 downto 0);

  signal l1Input        : L1InputArray(NDsLinks-1 downto 0);
  signal isXpm          : slv         (NDsLinks-1 downto 0);
  signal rxErr          : slv         (NDsLinks-1 downto 0);
  signal dsFull         : FullArray   (NDsLinks-1 downto 0);
  signal dsRxRcvs       : Slv32Array  (NDsLinks-1 downto 0);
  signal dsId           : Slv32Array  (NDsLinks-1 downto 0);
  signal linkConfig     : XpmLinkConfigArray(NDsLinks-1 downto 0);
  
  signal fstreams             : TimingSerialArray(NSTREAMS_C-1 downto 0) := (others=>TIMING_SERIAL_INIT_C);
  signal ostreams             : TimingSerialArray(NSTREAMS_C-1 downto 0) := (others=>TIMING_SERIAL_INIT_C);
  signal timingStream_advance : slv              (NSTREAMS_C-1 downto 0) := (others=>'0');
  signal streamIds   : Slv4Array        (NSTREAMS_C-1 downto 0) := (x"1",x"2",x"0");
  signal advance     : slv              (NSTREAMS_C-1 downto 0);
  signal pdepth      : Slv8Array (NPartitions-1 downto 0) := (others=>x"00");
  signal expWord     : Slv48Array(NPartitions-1 downto 0) := (others=>toSlv(XPM_PARTITION_DATA_INIT_C));

begin

  linkstatp: process (dsRxRcvs, isXpm, dsId) is
    variable linkStat : XpmLinkStatusType;
  begin
    for i in 0 to NDsLinks-1 loop
      linkStat           := XPM_LINK_STATUS_INIT_C;
      linkStat.rxRcvCnts := dsRxRcvs(i);
      linkStat.rxIsXpm   := isXpm   (i);
      linkStat.rxId      := dsId    (i);
      status.dsLink(i)   <= linkStat;
    end loop;
  end process;

  GEN_DSLINK: for i in 0 to NDsLinks-1 generate
    linkConfig(i).enable     <= config.dsLink(i).enable;
    linkConfig(i).loopback   <= config.dsLink(i).loopback;
    linkConfig(i).txReset    <= config.dsLink(i).txReset;
    linkConfig(i).rxReset    <= config.dsLink(i).rxReset;
    linkConfig(i).txPllReset <= config.dsLink(i).txPllReset;
    linkConfig(i).rxPllReset <= config.dsLink(i).rxPllReset;
    linkConfig(i).txDelayRst <= config.dsLink(i).txReset;
    linkConfig(i).txDelay    <= (others=>'0');
    linkConfig(i).rxTimeOut  <= toSlv(100,9);
    linkConfig(i).groupMask  <= toSlv(1,NPartitions);
    linkConfig(i).trigsrc    <= (others=>'0');
      
    U_TxLink : entity work.XpmTxLink
      generic map ( ADDR => i, STREAMS_G => 3 )
      port map ( clk             => timingClk,
                 rst             => timingRst,
                 streams         => ostreams,
                 streamIds       => streamIds,
                 paddr           => r.paddr,
                 paddrStrobe     => r.paddrStrobe,
                 fiducial        => r.fiducial(0),
                 advance_o       => advance,
                 txData          => dsTx (i).data,
                 txDataK         => dsTx (i).dataK );

    dsTx(i).control <= TIMING_PHY_CONTROL_INIT_C;
    rxErr(i) <= '0' when (dsRx(i).dspErr="00" and dsRx(i).decErr="00") else '1';
    
    U_RxLink : entity work.XpmRxLink
      port map ( clk             => timingClk,
                 rst             => timingRst,
                 config          => linkConfig(i),
                 rxData          => dsRx     (i).data,
                 rxDataK         => dsRx     (i).dataK,
                 rxErr           => rxErr    (i),
                 rxClk           => dsRxClk  (i),
                 rxRst           => dsRxRst  (i),
                 isXpm           => isXpm    (i),
                 id              => dsId     (i),
                 rxRcvs          => dsRxRcvs (i),
                 full            => dsFull   (i),
                 l1Input         => l1Input  (i) );
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

  GEN_STR : for i in 0 to 0 generate
    U_FIFO : entity work.FifoSync
      generic map ( ADDR_WIDTH_G => 4,
                    DATA_WIDTH_G => 16,
                    FWFT_EN_G    => true )
      port map ( clk     => timingClk,
                 rst     => rin.streamReset,
                 wr_en   => timingStream_advance(i),
                 din     => timingStream.streams(i).data,
                 rd_en   => advance (i),
                 dout    => fstreams(i).data,
                 valid   => fstreams(i).ready,
                 full    => open );
    timingStream_advance(i) <= rin.advance;
    fstreams(i).offset <= timingStream.streams(i).offset;
    fstreams(i).last   <= timingStream.streams(i).last;
  end generate;

  U_Master : entity work.XpmAppMaster
    generic map ( NDsLinks   => NDsLinks )
    port map ( regclk        => regclk,
               update        => update,
               config        => partitionConfig,
               status        => partitionStatus,
               timingClk     => timingClk,
               timingRst     => timingRst,
               streams       => timingStream.streams,
               streamIds     => streamIds,
               advance       => timingStream_advance,
               fiducial      => timingStream.fiducial,
               full          => r.full          (0),
               l1Input       => r.l1input       (0),
               result        => expWord         (0) );

  U_SyncDelay : entity work.SynchronizerVector
      generic map ( WIDTH_G => 8 )
      port map ( clk     => timingClk,
                 dataIn  => partitionConfig.pipeline.depth_fids,
                 dataOut => pdepth(0) );

  comb : process ( r, timingRst, dsFull, l1Input,
                   timingStream, fstreams, advance,
                   expWord, pdepth ) is
    variable v    : RegType;
    variable tidx : integer;
    constant pd   : XpmBroadcastType := PDELAY;
  begin
    v            := r;
    v.fiducial   := timingStream.fiducial & r.fiducial(r.fiducial'left downto 1);

    -- advance not driven for XpmMini; mock it up
    if v.fiducial(r.fiducial'left downto r.fiducial'left-2)=0 then
      v.advance  := timingStream.streams(0).ready;
    else
      v.advance  := '0';
    end if;
    
    case r.state is
      when IDLE_S =>
        v.streamReset  := '1';
        if timingStream.fiducial = '1' then
          v.stream.ready := '1';
          v.streamReset  := '0';
          v.state        := INIT_S;
        end if;
       when INIT_S =>
        v.stream.data := r.bcastf(15 downto 0);
        if advance(2) = '1' then
          v.paddrStrobe := '0';
          v.stream.data := r.bcastf(31 downto 16);
          v.ipart       := 0;
          v.eword       := 0;
          v.state       := EWORD_S;
        end if;
      when EWORD_S =>
        v.stream.data := expWord(r.ipart)(r.eword*16+15 downto r.eword*16);

        if (r.eword=(NTagBytes+1)/2) then
          v.eword := 0;
          if (r.ipart=NPartitions-1) then
            v.state := EOS_S;
          else
            v.ipart := r.ipart+1;
          end if;
        else
          v.eword := r.eword+1;
        end if;
      when EOS_S =>
        v.stream.ready  := '0';
        v.bcastf := r.bcastr;
        tidx := toIndex(r.bcastr);
        -- master of all : compose the word
        if r.bcastCount = 8 then
          v.bcastf := r.paddr;
          v.bcastCount := 0;
          v.paddrStrobe := '1';
        else
          v.bcastf := toPaddr(pd,r.bcastCount,pdepth(r.bcastCount));
          v.bcastCount := r.bcastCount + 1;
        end if;
        v.state := IDLE_S;
      when others => NULL;
    end case;

    for i in 0 to NPartitions-1 loop
      for j in 0 to NDsLinks-1 loop
        v.full   (i)(j) := dsFull (j)(i);
        v.l1input(i)(j) := l1Input(j)(i);
      end loop;
    end loop;

    if timingRst='1' then
      v := REG_INIT_C;
    end if;
    
    rin <= v;

    ostreams           <= fstreams;
    ostreams(2)        <= r.stream;
    ostreams(2).offset <= toSlv(0,7);
    ostreams(2).last   <= '1';

  end process;

  seq : process ( timingClk) is
  begin
    if rising_edge(timingClk) then
      r <= rin;
    end if;
  end process;
  
end top_level_app;
