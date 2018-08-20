-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrQuadAdcCore.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2018-07-26
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 Timing Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 Timing Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.NUMERIC_STD.all;

use work.StdRtlPkg.all;
use work.TimingExtnPkg.all;
use work.TimingPkg.all;
use work.QuadAdcPkg.all;
use work.EvrV2Pkg.all;
use work.XpmPkg.all;

entity QuadAdcEventV2Select is
  generic (
    TPD_G    : time    := 1 ns );
  port (
    -- EVR Ports
    evrClk              : in  sl;
    evrRst              : in  sl;
    config              : in  QuadAdcConfigType;
    evrBus              : in  TimingBusType;
    exptBus             : in  ExptBusType;
    strobe              : out sl;                -- validates following signals
    oneHz               : out sl;
    eventSel            : out sl;
    eventId             : out slv(191 downto 0);
    l1v                 : out sl;
    l1a                 : out sl;
    l1tag               : out slv( 4 downto 0) );
end QuadAdcEventV2Select;

architecture mapping of QuadAdcEventV2Select is

  type RegType is record
    strobe    : slv(2 downto 0);
    eventSel  : slv(2 downto 0);
    oneHz     : sl;
    lsb       : sl;
    eventId   : slv(191 downto 0);
    l1v       : sl;
    l1a       : sl;
    l1tag     : slv(4 downto 0);
    msg       : TimingMessageType;
    pword     : XpmPartitionDataType;
  end record;

  constant REG_INIT_C : RegType := (
    strobe    => (others=>'0'),
    eventSel  => (others=>'0'),
    oneHz     => '0',
    lsb       => '0',
    eventId   => (others=>'0'),
    l1v       => '0',
    l1a       => '0',
    l1tag     => (others=>'0'),
    msg       => TIMING_MESSAGE_INIT_C,
    pword     => XPM_PARTITION_DATA_INIT_C );

  signal r    : RegType := REG_INIT_C;
  signal rin  : RegType;

  signal evrConfig : EvrV2ChannelConfig := EVRV2_CHANNEL_CONFIG_INIT_C;

  signal ieventSel  : sl;
  
  constant XPMV7 : boolean := true;
  
begin

  strobe   <= r.strobe(0);
  eventSel <= ieventSel;
  oneHz    <= r.oneHz;
  eventId  <= r.eventId;
  l1v      <= r.l1v;
  l1a      <= r.l1a;
  l1tag    <= r.l1tag;

  evrConfig.enabled <= config.acqEnable;
  evrConfig.rateSel <= config.rateSel;
  evrConfig.destSel <= config.destSel;

  U_EventSelV2 : entity work.EvrV2EventSelect
    generic map ( TPD_G         => TPD_G )
    port map    ( clk           => evrClk,
                  rst           => evrRst,
                  config        => evrConfig,
                  strobeIn      => r.strobe(2),
                  dataIn        => r.msg,
                  exptIn        => exptBus,
                  selectOut     => ieventSel );

  comb: process ( r, evrRst, config, evrBus, exptBus, ieventSel ) is
    variable v : RegType;
    variable i : integer;
    variable q : slv(47 downto 0);
  begin
    v := r;

    q          := exptBus.message.partitionWord(conv_integer(config.partition));

    v.l1v      := '0';
    v.oneHz    := '0';
    v.strobe   := evrBus.strobe & r.strobe(2 downto 1);
    
    if evrBus.strobe='1' then
      v.msg       := evrBus.message;
      v.pword     := toPartitionWord(q);
      v.eventId :=  q(47 downto 16) &
                    toSlv(0,16) & q(15 downto 0) &
                    evrBus.message.timeStamp &
                    evrBus.message.pulseId;
    end if;

    -- Must delay l1v until after trigger(eventSel) arrives through adc clk domain
    v.eventSel := ieventSel & r.eventSel(r.eventSel'left downto 1);
    if r.eventSel(0)='1' then
      if config.rateSel(12 downto 11)="11" then
        v.l1v     := r.pword.l1e;
        v.l1a     := r.pword.l1a;
        v.l1tag   := r.pword.l1tag;
      else
        v.l1v     := '1';
        v.l1a     := '1';
        v.l1tag   := r.pword.l1tag;
      end if;
      
      if r.msg.pulseId(32)/=r.lsb then
        v.oneHz := '1';
        v.lsb   := not r.lsb;
      end if;
    end if;
    
    if evrRst='1' then
      v := REG_INIT_C;
    end if;

    rin <= v;
  end process comb;

  seq: process ( evrClk ) is
  begin
    if rising_edge(evrClk) then
      r <= rin;
    end if;
  end process seq;

end mapping;
