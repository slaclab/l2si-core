-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : XpmApp.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2019-12-17
-- Platform   : 
-- Standard   : VHDL'93/02
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

use work.StdRtlPkg.all;
use work.TimingExtnPkg.all;
use work.TimingPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
--use work.AmcCarrierPkg.all;
use work.XpmPkg.all;
use work.XpmMiniPkg.all;

library unisim;
use unisim.vcomponents.all;

entity XpmApp is
   generic (
      TPD_G               : time                := 1 ns;
      NDsLinks            : integer             := 7;
      NBpLinks            : integer             := 14;
      AXIL_BASEADDR_G     : slv(31 downto 0)    := (others=>'0') );
   port (
      -----------------------
      -- XpmApp Ports --
      -----------------------
      regclk            : in  sl;
      regrst            : in  sl;
      update            : in  slv(NPartitions-1 downto 0);
      config            : in  XpmConfigType;
      status            : out XpmStatusType;
      axilReadMaster    : in  AxiLiteReadMasterType;
      axilReadSlave     : out AxiLiteReadSlaveType;
      axilWriteMaster   : in  AxiLiteWriteMasterType;
      axilWriteSlave    : out AxiLiteWriteSlaveType;
      obAppMaster       : out AxiStreamMasterType;
      obAppSlave        : in  AxiStreamSlaveType;
      groupLinkClear    : out slv               (NPartitions-1 downto 0);
      -- AMC's DS Ports
      dsLinkStatus      : in  XpmLinkStatusArray(NDsLinks-1 downto 0);
      dsRxData          : in  Slv16Array        (NDsLinks-1 downto 0);
      dsRxDataK         : in  Slv2Array         (NDsLinks-1 downto 0);
      dsTxData          : out Slv16Array        (NDsLinks-1 downto 0);
      dsTxDataK         : out Slv2Array         (NDsLinks-1 downto 0);
      dsRxErr           : in  slv               (NDsLinks-1 downto 0);
      dsRxClk           : in  slv               (NDsLinks-1 downto 0);
      dsRxRst           : in  slv               (NDsLinks-1 downto 0);
      --  BP DS Ports
      bpTxData          : out slv(15 downto 0);
      bpTxDataK         : out slv( 1 downto 0);
      bpStatus          : in  XpmBpLinkStatusArray(NBpLinks   downto 0);
      bpRxLinkFull      : in  Slv16Array          (NBpLinks-1 downto 0);
      -- Timing Interface (timingClk domain) 
      timingClk         : in  sl;
      timingRst         : in  sl;
--      timingIn          : in  TimingRxType;
      timingStream      : in  XpmStreamType;
      timingFbClk       : in  sl;
      timingFbRst       : in  sl;
      timingFbId        : in  slv(31 downto 0);
      timingFb          : out TimingPhyType );
end XpmApp;

architecture top_level_app of XpmApp is

  type LinkFullArray  is array (natural range<>) of slv(26 downto 0);
  type LinkL1InpArray is array (natural range<>) of XpmL1InputArray(NDsLinks-1 downto 0);

  type StateType is (IDLE_S, INIT_S, SLAVE_S, PADDR_S, EWORD_S, EOS_S);
  type RegType is record
    full       : LinkFullArray (NPartitions-1 downto 0);
    fullfb     : slv           (NPartitions-1 downto 0);
    l1input    : LinkL1InpArray(NPartitions-1 downto 0);
    fiducial   : slv(3 downto 0);
    source     : sl;
    paddr      : slv(PADDR_LEN-1 downto 0); -- platform address
    paddrStrobe: sl;
    bcastr     : slv(PADDR_LEN-1 downto 0); -- received Xpm Broadcast
    bcastf     : slv(PADDR_LEN-1 downto 0); -- Xpm Broadcast to forward
    streamReset: sl;
    advance    : sl;
    stream     : TimingSerialType;
    state      : StateType;
    eword      : integer range 0 to (NTagBytes+1)/2;
    ipart      : integer range 0 to NPartitions-1;
    bcastCount : integer range 0 to 8;
    msg        : slv(PWORD_LEN-1 downto 0);
    msgComplete : sl;
    msgGroup    : integer range 0 to NPartitions-1;
    groupLinkClear : slv(NPartitions-1 downto 0);
  end record;
  constant REG_INIT_C : RegType := (
    full       => (others=>(others=>'0')),
    fullfb     => (others=>'0'),
    l1input    => (others=>(others=>XPM_L1_INPUT_INIT_C)),
    fiducial   => x"0",
    source     => '1',
    paddr      => (others=>'1'),
    paddrStrobe=> '0',
    bcastr     => (others=>'1'),
    bcastf     => (others=>'1'),
    streamReset=> '1',
    advance    => '1',
    stream     => TIMING_SERIAL_INIT_C,
    state      => IDLE_S,
    eword      => 0,
    ipart      => 0,
    bcastCount => 0,
    msg        => (others=>'0'),
    msgComplete=> '0',
    msgGroup   => 0,
    groupLinkClear => (others=>'0')
    );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;
  

  --  input data from sensor links
  type L1InputArray is array (natural range<>) of XpmL1InputArray(NPartitions-1 downto 0);
  type FullArray    is array (natural range<>) of slv            (NPartitions-1 downto 0);

  signal l1Input        : L1InputArray(NDsLinks-1 downto 0);
  signal isXpm          : slv         (NDsLinks-1 downto 0);
  signal dsFull         : FullArray   (NDsLinks-1 downto 0);
  signal dsRxRcvs       : Slv32Array  (NDsLinks-1 downto 0);
  signal dsId           : Slv32Array  (NDsLinks-1 downto 0);
  signal bpRxLinkFullS  : Slv16Array        (NBpLinks-1 downto 0);
  
  signal timingStream_streams : TimingSerialArray(NSTREAMS_C-1 downto 0);
  signal fstreams             : TimingSerialArray(NSTREAMS_C-1 downto 0);
  signal ostreams             : TimingSerialArray(NSTREAMS_C-1 downto 0);
  signal stream0_data: slv(15 downto 0);
  signal streamIds   : Slv4Array        (NSTREAMS_C-1 downto 0) := (x"1",x"2",x"0");
  signal advance     : slv              (NSTREAMS_C-1 downto 0);
  signal fadvance    : slv              (NSTREAMS_C-1 downto 0);
  signal pmaster     : slv       (NPartitions-1 downto 0);
  signal pdepthI     : Slv8Array (NPartitions-1 downto 0);
  signal pdepth      : Slv8Array (NPartitions-1 downto 0);
  signal expWord     : Slv48Array(NPartitions-1 downto 0);
  signal fullfb      : slv       (NPartitions-1 downto 0);
  signal paddr       : slv       (PADDR_LEN-1 downto 0);
begin

  linkstatp: process (bpStatus, dsLinkStatus, dsRxRcvs, isXpm, dsId) is
    variable linkStat : XpmLinkStatusType;
  begin
    for i in 0 to NDsLinks-1 loop
      linkStat           := dsLinkStatus(i);
      linkStat.rxRcvCnts := dsRxRcvs(i);
      linkStat.rxIsXpm   := isXpm   (i);
      linkStat.rxId      := dsId    (i);
      status.dsLink(i)   <= linkStat;
    end loop;
    status.bpLink <= bpStatus;
  end process;

  GEN_SYNCBP : for i in 0 to NBpLinks-1 generate
    U_SyncFull : entity work.SynchronizerVector
      generic map ( WIDTH_G => 16 )
      port map ( clk     => timingClk,
                 dataIn  => bpRxLinkFull(i),
                 dataOut => bpRxLinkFullS(i) );
  end generate;
  
  U_SyncPaddrRx : entity work.SynchronizerVector
    generic map ( WIDTH_G => status.paddr'length )
    port map ( clk     => regclk,
               dataIn  => r.paddr,
               dataOut => status.paddr );
  
  U_SyncPaddrTx : entity work.SynchronizerVector
    generic map ( WIDTH_G => config.paddr'length )
    port map ( clk     => timingClk,
               dataIn  => config.paddr,
               dataOut => paddr );
  
  U_FullFb : entity work.SynchronizerVector
    generic map ( WIDTH_G => fullfb'length )
    port map ( clk     => timingFbClk,
               dataIn  => r.fullfb,
               dataOut => fullfb );

  U_GroupClear : entity work.SynchronizerOneShotVector
    generic map ( WIDTH_G => NPartitions )
    port map ( clk        => regclk,
               dataIn     => r.groupLinkClear,
               dataOut    => groupLinkClear );
  
  U_TimingFb : entity work.XpmTimingFb
    port map ( clk        => timingFbClk,
               rst        => timingFbRst,
               id         => timingFbId,
               l1input    => (others=>XPM_L1_INPUT_INIT_C),
               full       => fullfb,
               phy        => timingFb );
  
  GEN_DSLINK: for i in 0 to NDsLinks-1 generate
    U_TxLink : entity work.XpmTxLink
      generic map ( ADDR => i, STREAMS_G => 3, DEBUG_G => (i<1) )
      port map ( clk             => timingClk,
                 rst             => timingRst,
                 streams         => ostreams,
                 streamIds       => streamIds,
                 paddr           => r.paddr,
                 paddrStrobe     => r.paddrStrobe,
                 fiducial        => r.fiducial(0),
                 advance_o       => open,
                 txData          => dsTxData (i),
                 txDataK         => dsTxDataK(i) );
    U_RxLink : entity work.XpmRxLink
      port map ( clk             => timingClk,
                 rst             => timingRst,
                 config          => config.dsLink(i),
                 rxData          => dsRxData (i),
                 rxDataK         => dsRxDataK(i),
                 rxErr           => dsRxErr  (i),
                 rxClk           => dsRxClk  (i),
                 rxRst           => dsRxRst  (i),
                 isXpm           => isXpm    (i),
                 id              => dsId     (i),
                 rxRcvs          => dsRxRcvs (i),
                 full            => dsFull   (i),
                 l1Input         => l1Input  (i) );
  end generate GEN_DSLINK;

  U_BpTx : entity work.XpmTxLink
    generic map ( ADDR      => 15,
                  STREAMS_G => 3,
                  DEBUG_G   => false )
    port map ( clk             => timingClk,
               rst             => timingRst,
               streams         => ostreams,
               streamIds       => streamIds,
               paddr           => r.paddr,
               paddrStrobe     => r.paddrStrobe,
               fiducial        => r.fiducial(0),
               advance_o       => advance,
               txData          => bpTxData ,
               txDataK         => bpTxDataK );

  --
  --  Let the local sequencer replace its part in the incoming stream
  --
  U_Seq : entity work.XpmSequence
    generic map ( AXIL_BASEADDR_G => AXIL_BASEADDR_G )
    port map ( axilClk         => regclk,
               axilRst         => regrst,
               axilReadMaster  => axilReadMaster ,
               axilReadSlave   => axilReadSlave  ,
               axilWriteMaster => axilWriteMaster,
               axilWriteSlave  => axilWriteSlave ,
               obAppMaster     => obAppMaster,
               obAppSlave      => obAppSlave,
               timingClk       => timingClk,
               timingRst       => timingRst,
--               fiducial        => timingStream.fiducial,
               timingAdvance   => timingStream.advance(0),
               timingDataIn    => timingStream.streams(0).data,
               timingDataOut   => stream0_data );

  streams_p : process (timingStream, stream0_data) is
  begin
    timingStream_streams         <= timingStream.streams;
    timingStream_streams(0).data <= stream0_data;
  end process;

  advance_p : process(advance, rin) is
  begin
    fadvance    <= advance;
    fadvance(2) <= rin.advance;
  end process;
  
  --
  --  Cache the incoming stream data, but only since the fiducial
  --
  GEN_STR : for i in 0 to NSTREAMS_C-1 generate
    U_FIFO : entity work.FifoSync
      generic map ( ADDR_WIDTH_G => 4,
                    DATA_WIDTH_G => 16,
                    FWFT_EN_G    => true )
      port map ( clk     => timingClk,
                 rst     => rin.streamReset,
                 wr_en   => timingStream.advance(i),
                 din     => timingStream_streams(i).data,
                 rd_en   => fadvance(i),
                 dout    => fstreams(i).data,
                 valid   => fstreams(i).ready,
                 full    => open );
    fstreams(i).offset <= timingStream.streams(i).offset;
    fstreams(i).last   <= timingStream.streams(i).last;
  end generate;
  
  GEN_PART : for i in 0 to NPartitions-1 generate
    --
    --  Get the result word (trigger/message) for each partition
    --
    U_Master : entity work.XpmAppMaster
      generic map ( NDsLinks   => NDsLinks,
                    DEBUG_G    => (i<1) )
      port map ( regclk        => regclk,
                 update        => update          (i),
                 config        => config.partition(i),
                 status        => status.partition(i),
                 timingClk     => timingClk,
                 timingRst     => timingRst,
                 streams       => timingStream_streams,
                 streamIds     => streamIds,
                 advance       => timingStream.advance,
                 fiducial      => timingStream.fiducial,
                 full          => r.full          (i),
                 l1Input       => r.l1input       (i),
                 result        => expWord         (i) );

    U_SyncMaster : entity work.Synchronizer
      port map ( clk     => timingClk,
                 dataIn  => config.partition(i).master,
                 dataOut => pmaster(i) );

    --
    --  Actual delay is 1 greater than configuration
    --
    pdepthI(i) <= config.partition(i).pipeline.depth_fids+1;

    U_SyncDelay : entity work.SynchronizerVector
      generic map ( WIDTH_G => 8 )
      port map ( clk     => timingClk,
                 dataIn  => pdepthI(i),
                 dataOut => pdepth(i) );
  end generate;

  --
  -- timingStream carries its own 'advance' signal as well as fiducial.
  -- 
  comb : process ( r, timingRst, dsFull, bpRxLinkFullS, l1Input,
                   timingStream, fstreams, advance,
                   expWord, pmaster, pdepth, paddr ) is
    variable v    : RegType;
    variable tidx : integer;
    variable mhdr : slv(7 downto 0);
    constant pd   : XpmBroadcastType := PDELAY;
  begin
    v             := r;
    v.advance     := advance (2);
    v.msgComplete := '0';
    v.fiducial    := timingStream.fiducial & r.fiducial(r.fiducial'left downto 1);
    
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
        if fstreams(2).ready = '1' then
          v.source      := '0';
          v.bcastr      := fstreams(2).data & r.bcastr(r.bcastr'left downto r.bcastr'left-15);
          v.advance     := '1';
          v.state       := SLAVE_S;
        elsif advance(2) = '1' then
          v.source      := '1';
          v.paddrStrobe := '0';
          v.stream.data := r.bcastf(31 downto 16);
          v.ipart       := 0;
          v.eword       := 0;
          v.state       := EWORD_S;
        end if;
      when SLAVE_S =>
        if advance(2) = '1' then
          v.paddrStrobe := '0';
          v.bcastr      := fstreams(2).data & r.bcastr(r.bcastr'left downto r.bcastr'left-15);
          v.stream.data := r.bcastf(31 downto 16);
          v.ipart       := 0;
          v.eword       := 0;
          v.state       := EWORD_S;
        end if;
      when EWORD_S =>
        if r.source='1' or pmaster(r.ipart)='1' then
          v.stream.data := expWord(r.ipart)(r.eword*16+15 downto r.eword*16);
        else
          v.stream.data := fstreams(2).data;
        end if;

        --  Collect the partition message to be forwarded,
        v.msg := v.stream.data & r.msg(r.msg'left downto 16);
        
        if (r.eword=(NTagBytes+1)/2) then
          v.msgComplete := '1';
          v.msgGroup    := r.ipart;
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
        if r.source='1' then
          -- master of all : compose the word
          if r.bcastCount = 8 then
            v.paddr  := paddr;
            v.bcastf := paddr;
            v.bcastCount := 0;
            v.paddrStrobe := '1';
          else
            v.bcastf := toPaddr(pd,r.bcastCount,pdepth(r.bcastCount));
            v.bcastCount := r.bcastCount + 1;
          end if;
        else
          case (toXpmBroadcastType(r.bcastr)) is
            when PDELAY =>
              if pmaster(tidx)='1' then
                -- master of this partition : compose the word
                v.bcastf := toPaddr(pd,tidx,pdepth(tidx));
              end if;
            when XADDR =>
              v.bcastf := paddr;
              v.paddr  := r.bcastr;
              v.paddrStrobe := '1';
            when others => null;
          end case;
        end if;
        v.state := IDLE_S;
      when others => NULL;
    end case;

    for i in 0 to NPartitions-1 loop
      for j in 0 to NDsLinks-1 loop
        v.full   (i)(j) := dsFull (j)(i);
        v.l1input(i)(j) := l1Input(j)(i);
      end loop;
      for j in 0 to NBpLinks-1 loop
        v.full   (i)(j+16) := bpRxLinkFullS(j)(i);
      end loop;
      if pmaster(i) = '0' and v.full(i)/=0 then
        v.fullfb(i) := '1';
      else
        v.fullfb(i) := '0';
      end if;
    end loop;

    v.groupLinkClear := (others=>'0');
    if r.msgComplete = '1' and r.msg(15) = '0' then
      mhdr := toPartitionMsg(r.msg).hdr;
      case (mhdr(7 downto 6)) is
        when "00"  => -- Transition
          NULL;
        when "01"  => -- Occurrence
          case (mhdr(5 downto 0)) is
            when "000000" => -- ClearReadout
              v.groupLinkClear(r.msgGroup) := '1';
            when others => NULL;
          end case;
        when "10"  => -- Marker
          NULL;
        when others=> -- Unknown
          NULL;
      end case;
    end if;
    
    if timingRst='1' then
      v := REG_INIT_C;
    end if;
    
    rin <= v;

    ostreams           <= fstreams;
    ostreams(2)        <= r.stream;
    ostreams(2).offset <= fstreams(2).offset;
    ostreams(2).last   <= fstreams(2).last;

  end process;

  seq : process ( timingClk) is
  begin
    if rising_edge(timingClk) then
      r <= rin;
    end if;
  end process;
  
end top_level_app;
