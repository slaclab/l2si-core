-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : XpmMini.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2019-03-13
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
--use work.AmcCarrierPkg.all;
use work.XpmPkg.all;
use work.XpmBasePkg.all;

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

  type StateType is (INIT_S, PADDR_S, EWORD_S, EOS_S);
  type RegType is record
    full       : LinkFullArray (NPartitions-1 downto 0);
    fullfb     : slv           (NPartitions-1 downto 0);
    l1input    : LinkL1InpArray(NPartitions-1 downto 0);
    fiducial   : sl;
    source     : sl;
    paddr      : slv(PADDR_LEN-1 downto 0); -- platform address
    bcastr     : slv(PADDR_LEN-1 downto 0); -- received Xpm Broadcast
    bcastf     : slv(PADDR_LEN-1 downto 0); -- Xpm Broadcast to forward
    streams    : TimingSerialArray(NSTREAMS_C-1 downto 0);
    advance    : slv              (NSTREAMS_C-1 downto 0);
    state      : StateType;
    aword      : integer range 0 to paddr'left/16;
    eword      : integer range 0 to (NTagBytes+1)/2;
    ipart      : integer range 0 to 2*NPartitions-1;
    bcastCount : integer range 0 to 8;
  end record;
  constant REG_INIT_C : RegType := (
    full       => (others=>(others=>'0')),
    fullfb     => (others=>'0'),
    l1input    => (others=>(others=>XPM_L1_INPUT_INIT_C)),
    fiducial   => '0',
    source     => '1',
    paddr      => (others=>'1'),
    bcastr     => (others=>'1'),
    bcastf     => (others=>'1'),
    streams    => (others=>TIMING_SERIAL_INIT_C),
    advance    => (others=>'0'),
    state      => INIT_S,
    aword      => 0,
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
  signal dsFull         : FullArray   (NDsLinks-1 downto 0);
  signal dsRxRcvs       : Slv32Array  (NDsLinks-1 downto 0);
  signal dsId           : Slv32Array  (NDsLinks-1 downto 0);
  signal bpRxLinkFullS  : Slv16Array        (NBpLinks-1 downto 0);
  
  --  Serialized data to sensor links
  signal txData         : slv(15 downto 0);
  signal txDataK        : slv( 1 downto 0);

  signal streams   : TimingSerialArray(NSTREAMS_C-1 downto 0);
  signal streamIds : Slv4Array        (NSTREAMS_C-1 downto 0) := (x"1",x"2",x"0");
  signal r_streamIds : Slv4Array      (NSTREAMS_C-1 downto 0) := (x"1",x"2",x"0");
  signal advance   : slv              (NSTREAMS_C-1 downto 0);
  signal pdepth      : Slv8Array (NPartitions-1 downto 0);
  signal expWord     : Slv48Array(NPartitions-1 downto 0);
  signal fullfb      : slv       (NPartitions-1 downto 0);
  signal stream0_data: slv(15 downto 0);
  
begin

  linkstatp: process (bpStatus, dsLinkStatus, dsRxRcvs, isXpm, dsId) is
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

  U_SyncPaddr : entity work.SynchronizerVector
    generic map ( WIDTH_G => status.paddr'length )
    port map ( clk     => regclk,
               dataIn  => r.paddr,
               dataOut => status.paddr );
  
  U_FullFb : entity work.SynchronizerVector
    generic map ( WIDTH_G => fullfb'length )
    port map ( clk     => timingFbClk,
               dataIn  => r.fullfb,
               dataOut => fullfb );
  
  GEN_DSLINK: for i in 0 to NDsLinks-1 generate
    U_TxLink : entity work.XpmTxLink
      generic map ( ADDR => i, STREAMS_G => 3 )
      port map ( clk             => timingClk,
                 rst             => timingRst,
                 config          => config.dsLink(i),
                 isXpm           => isXpm(i),
                 streams         => r.streams,
                 streamIds       => r_streamIds,
                 paddr           => r.bcastf,
                 advance_i       => r.advance,
                 fiducial        => r.fiducial,
                 txData          => dsTx (i).data,
                 txDataK         => dsTx (i).dataK );
    U_RxLink : entity work.XpmRxLink
      port map ( clk             => timingClk,
                 rst             => timingRst,
                 config          => config.dsLink(i),
                 rxData          => dsRx     (i).data,
                 rxDataK         => dsRx     (i).dataK,
                 rxErr           => dsRxErr  (i).dspErr,
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
  
  U_Master : entity work.XpmAppMaster
    generic map ( NDsLinks   => NDsLinks )
    port map ( regclk        => regclk,
               update        => update,
               config        => partitionConfig,
               status        => partitionStatus,
               timingClk     => timingClk,
               timingRst     => timingRst,
               streams       => timingStream.streams,
               streamIds     => timingStream.streamIds,
               advance       => timingStream.advance,
               fiducial      => timingStream.fiducial,
               full          => r.full          (0),
               l1Input       => r.l1input       (0),
               result        => expWord         (0) );

  U_SyncDelay : entity work.SynchronizerVector
      generic map ( WIDTH_G => 8 )
      port map ( clk     => timingClk,
                 dataIn  => partitionConfig.pipeline.depth_fids,
                 dataOut => pdepth(i) );
  end generate;

  comb : process ( r, timingRst, dsFull, l1Input,
                   timingStream, streams, advance,
                   expWord, pdepth ) is
    variable v    : RegType;
    variable tidx : integer;
    constant pd   : XpmBroadcastType := PDELAY;
  begin
    v := r;
    v.streams := streams;
    v.streams(0).ready := '1';
    v.streams(1).ready := '1';
    v.streams(2).ready := '1';
    v.advance    := advance;
    v.fiducial   := timingStream.fiducial;
    
    if (advance(0)='0' and r.advance(0)='1') then
      v.streams(0).ready := '0';
    end if;
    
    case r.state is
      when INIT_S =>
        v.aword := 0;
        if (advance(0)='0' and r.advance(0)='1') then
          v.advance(2)      := '1';
          v.streams(2).data := r.bcastf(15 downto 0);
          v.aword           := r.aword+1;
          v.state           := PADDR_S;
        end if;
      when PADDR_S =>
        v.advance(2)      := '1';
        v.streams(2).data := r.bcastf(r.aword*16+15 downto r.aword*16);
        if (r.aword=r.bcastf'left/16) then
          v.ipart := 0;
          v.eword := 0;
          v.state := EWORD_S;
        else
          v.aword := r.aword+1;
        end if;
      when EWORD_S =>
        v.eword      := r.eword+1;
        v.advance(2) := '1';
        v.streams(2).data := expWord(r.ipart)(r.eword*16+15 downto r.eword*16);
        if (r.eword=(NTagBytes+1)/2) then
          if (r.ipart=NPartitions-1) then
            v.state := EOS_S;
          else
            v.ipart := r.ipart+1;
            v.eword := 0;
          end if;
        end if;
      when EOS_S =>
        v.streams(2).ready := '0';
        v.bcastf := r.bcastr;
        tidx := toIndex(r.bcastr);
        -- master of all : compose the word
        if r.bcastCount = 8 then
          v.bcastf := r.paddr;
          v.bcastCount := 0;
        else
          v.bcastf := toPaddr(pd,r.bcastCount,pdepth(r.bcastCount));
          v.bcastCount := r.bcastCount + 1;
        end if;
        v.aword := 0;
        v.state := INIT_S;
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
  end process;

  seq : process ( timingClk) is
  begin
    if rising_edge(timingClk) then
      r <= rin;
    end if;
  end process;
  
end top_level_app;
