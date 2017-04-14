-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DtiUsApp.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2017-03-31
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: DtiApp's Top Level
-- 
-- Note: Common-to-DtiApp interface defined here (see URL below)
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
use work.TimingPkg.all;
use work.DtiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity DtiUsApp is
   generic (
      TPD_G               : time                := 1 ns );
   port (
     sysClk          : in  sl;
     sysRst          : in  sl;
     config          : in  DtiUsLinkConfigType;
     status          : out DtiUsLinkStatusType;
     --
     ctlClk          : in  sl;
     ctlRxMaster     : in  AxiStreamMasterType;
     ctlRxSlave      : out AxiStreamSlaveType;
     ctlTxMaster     : out AxiStreamMasterType;
     ctlTxSlave      : in  AxiStreamSlaveType;
     --
     timingClk       : in  sl;
     timingRst       : in  sl;
     trigger         : in  DtiAppTriggerType;
     --
     ibClk           : in  sl;
     ibMaster        : in  AxiStreamMasterType;
     ibSlave         : out AxiStreamSlaveType;
     --
     obClk           : in  sl;
     obMaster        : out AxiStreamMasterType;
     obSlave         : in  AxiStreamSlaveType;
end DtiUsApp;

architecture top_level_app of DtiUsApp is

  type LinkFullArray  is array (natural range<>) of slv(NDsLinks-1 downto 0);
    
  type StateType is (INIT_S, PADDR_S, EWORD_S, EOS_S);
  type RegType is record
  end record;
  constant REG_INIT_C : RegType := (
  );
  
  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;
  
  --  Serialized data to sensor links
  
  constant DEBUG_C : boolean := true;
  
begin

  -- Partition handling
  U_P : entity work.DtiPartition
    port map ( sysclk     => sysclk,
               config     => config,
               timingClk  => timingClk,
               timingBus  => timingIn,
               exptBus    => exptIn,
               full       => linkFull,
               l0Trig     => l0Trig,     -- L0 trigger, tag, and pulseId
               l1Trig     => l1Trig,     -- L1 trigger, tag, and decision
               message    => message );  -- Partition control messagee
               
  -- Us link handling
  GEN_U : for i in 0 to NDtiUsLinks-1 generate

    l0TrigIn (i) <= l0Trig (conv_integer(dtiConfig.usLinkCfg(i).partition));
    l1TrigIn (i) <= l1Trig (conv_integer(dtiConfig.usLinkCfg(i).partition));
    messageIn(i) <= message(conv_integer(dtiConfig.usLinkCfg(i).partition));

    U_U : entity work.DtiUsLink
      port map ( sysClk      => sysclk,
                 config      => dtiConfig.usLinkCfg(i),
                 ctlClk      => ethClk,
                 ctlRxMaster => ethRxMasters(i),
                 ctlRxSlave  => ethRxSlaves (i),
                 ctlTxMaster => ethTxMasters(i),
                 ctlTxSlave  => ethTxSlaves (i),
                 ibClk       => ibClk    (i),
                 ibMaster    => ibMasters(i),
                 ibSlave     => ibSlaves (i),
                 obClk       => obClk    (i),
                 obMaster    => obMasters(i),
                 obSlave     => obSlaves (i),
                 l0Trig      => l0Trig,
                 l1Trig      => l1Trig,
                 message     => message );
  end generate;
               
  -- Ds link handling

  
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

  linkstatp: process (linkStatus, isDti) is
    variable linkStat : DtiLinkStatusType;
  begin
    for i in 0 to NDSLinks-1 loop
      linkStat         := linkStatus(i);
      linkStat.rxIsDti := isDti(i);
      status.dsLink(i) <= linkStat;
    end loop;
  end process;
  
  U_SyncPaddr : entity work.SynchronizerVector
    generic map ( WIDTH_G => status.paddr'length )
    port map ( clk     => sysclk,
               dataIn  => r.paddr,
               dataOut => status.paddr );
  
  U_TimingFb : entity work.DtiTimingFb
    port map ( clk        => timingFbClk,
               rst        => timingFbRst,
               l1input    => (others=>XPM_L1_INPUT_INIT_C),
               full       => (others=>'0'),
               phy        => timingFb );
               
  GEN_DSLINK: for i in 0 to NDSLinks-1 generate
    U_TxLink : entity work.DtiTxLink
      generic map ( ADDR => i )
      port map ( clk             => timingClk,
                 rst             => timingRst,
                 config          => config.dsLink(i),
                 isDti           => isDti(i),
                 streams         => r.streams,
                 streamIds       => streamIds,
                 paddr           => r.paddr,
                 advance_i       => r.advance,
                 fiducial        => r.fiducial,
                 sof             => sof,
                 eof             => eof,
                 crcErr          => crcErr,
                 txData          => dsTxData (i),
                 txDataK         => dsTxDataK(i) );
    U_RxLink : entity work.DtiRxLink
      port map ( clk             => timingClk,
                 rst             => timingRst,
                 config          => config.dsLink(i),
                 rxData          => dsRxData (i),
                 rxDataK         => dsRxDataK(i),
                 rxErr           => dsRxErr  (i),
                 rxClk           => dsRxClk  (i),
                 rxRst           => dsRxRst  (i),
                 isDti           => isDti    (i),
                 full            => full     (i),
                 l1Input         => l1Input  (i) );
    U_SyncLinkConfig : entity work.SynchronizerVector
      generic map( WIDTH_G => config.dsLink(0).partition'length )
      port map ( clk     => timingClk,
                 dataIn  => config.dsLink(i).partition,
                 dataOut => partition(i) );
  end generate GEN_DSLINK;

  U_Deserializer : entity work.TimingDeserializer
    generic map ( STREAMS_C => 2 )
    port map ( clk       => timingClk,
               rst       => timingRst,
               fiducial  => fiducial,
               streams   => streams,
               streamIds => streamIds,
               advance   => advance,
               data      => timingIn,
               sof       => sof,
               eof       => eof,
               crcErr    => crcErr );

  GEN_PART : for i in 0 to NPartitions-1 generate

    U_Master : entity work.DtiAppMaster
      port map ( regclk        => sysclk,
                 update        => update          (i),
                 config        => config.partition(i),
                 status        => status.partition(i),
                 timingClk     => timingClk,
                 timingRst     => timingRst,
                 streams       => streams,
                 streamIds     => streamIds,
                 advance       => advance,
                 fiducial      => fiducial,
                 sof           => sof,
                 eof           => eof,
                 crcErr        => crcErr,
                 full          => r.full          (i),
                 l1Input       => r.l1input       (i),
                 l0Acc         => l0Accept        (i),
                 l1Acc         => l1Accept        (i),
                 result        => expWord         (i) );

    U_SyncMaster : entity work.Synchronizer
      port map ( clk     => timingClk,
                 dataIn  => config.partition(i).l0Select.enabled,
                 dataOut => pmaster(i) );
  end generate;

  comb : process ( r, timingRst, full, l1Input, fiducial, advance, expWord, streams, pmaster, partition ) is
    variable v : RegType;
  begin
    v := r;
    v.streams    := streams;
    v.streams(0).ready := '1';
    v.streams(1).ready := '1';
    v.advance    := advance;
    v.fiducial   := fiducial;
    v.l0Accept   := (others=>'0');
    v.l1Accept   := (others=>'0');
    
    --  test if we are the top of the hierarchy
    if streams(1).ready='1' then
      v.source        := '0';
    else
      v.paddr         := (others=>'1');
      v.source        := '1';
    end if;

    if (advance(0)='0' and r.advance(0)='1') then
      v.streams(0).ready := '0';
    end if;
    
    case r.state is
      when INIT_S =>
        v.aword := 0;
        if (r.source='0' and advance(1)='1') then
          if (r.taddr'length>16) then
            v.taddr := v.streams(1).data & r.taddr(r.paddr'left downto r.paddr'left-15);
          else
            v.taddr := v.streams(1).data;
          end if;
          v.state := PADDR_S;
        elsif (r.source='1' and advance(0)='0' and r.advance(0)='1') then
          v.advance(1)      := '1';
          v.streams(1).data := r.paddr(15 downto 0);
          v.aword           := r.aword+1;
          v.state           := PADDR_S;
        end if;
      when PADDR_S =>
        if r.source='1' then
          v.advance(1)      := '1';
          v.streams(1).data := r.paddr(r.aword*16+15 downto r.aword*16);
        else
          if (r.taddr'length>16) then
            v.taddr := v.streams(1).data & r.taddr(r.paddr'left downto r.paddr'left-15);
          else
            v.taddr := v.streams(1).data;
          end if;
        end if;
        if (r.aword=r.paddr'left/16) then
          v.ipart := 0;
          v.eword := 0;
          v.state := EWORD_S;
        else
          v.aword := r.aword+1;
        end if;
      when EWORD_S =>
        v.eword := r.eword+1;
        if r.source='1' then
          v.advance(1)      := '1';
          v.streams(1).data := expWord(r.ipart)(r.eword*16+15 downto r.eword*16);
        end if;
        if r.eword=0 then
          for i in 0 to NDSLinks-1 loop
            if (partition(i)=toSlv(r.ipart,4)) then
              v.l0Accept(i) := v.streams(1).data(0);
              v.l1Accept(i) := v.streams(1).data(9);
            end if;
          end loop;
        end if;
        if (r.eword=(NTagBytes+1)/2) then
          if (r.ipart=NPartitions-1) then
            v.state := EOS_S;
          else
            v.ipart := r.ipart+1;
            v.eword := 0;
          end if;
        end if;
      when EOS_S =>
        v.streams(1).ready := '0';
        v.paddr := r.taddr;
        v.aword := 0;
        v.state := INIT_S;
      when others => NULL;
    end case;

    for i in 0 to NPartitions-1 loop
      for j in 0 to NDSLinks-1 loop
        v.full   (i)(j) := full   (j)(i);
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
