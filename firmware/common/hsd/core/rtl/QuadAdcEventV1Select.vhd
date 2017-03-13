-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrQuadAdcCore.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2017-03-13
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
use work.TimingPkg.all;

entity QuadAdcEventV1Select is
  generic (
    TPD_G    : time    := 1 ns );
  port (
    -- EVR Ports
    evrClk              : in  sl;
    evrRst              : in  sl;
    enabled             : in  sl;
    eventCode           : in  slv(7 downto 0);
    evrBus              : in  TimingBusType;
    strobe              : out sl;              -- validates following signals
    oneHz               : out sl;
    eventSel            : out sl;
    eventId             : out slv(95 downto 0) );
end QuadAdcEventV1Select;

architecture mapping of QuadAdcEventV1Select is

  type RegType is record
    eventSel  : sl;
    strobe    : sl;
    strobeO   : sl;
    oneHz     : sl;
    lsb       : sl;
    eventWord : slv(15 downto 0);
    eventId   : slv(95 downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    eventSel  => '0',
    strobe    => '0',
    strobeO   => '0',
    oneHz     => '0',
    lsb       => '0',
    eventWord => (others=>'0'),
    eventId   => (others=>'0') );

  signal r    : RegType := REG_INIT_C;
  signal rin  : RegType;

begin

  strobe   <= r.strobeO;
  oneHz    <= r.oneHz;
  eventSel <= r.eventSel;
  eventId  <= r.eventId;

  comb: process ( r, evrRst, enabled, eventCode, evrBus ) is
    variable v : RegType;
    variable i : integer;
  begin
    v := r;

    v.eventSel := '0';
    v.oneHz    := '0';
    v.strobe   := '0';
    v.strobeO  := r.strobe;
    
    if evrBus.strobe='1' then
      v.strobe    := '1';
      v.eventId   := evrBus.stream.pulseId & evrBus.stream.dbuff.epicsTime;
      i := conv_integer(eventCode(7 downto 4));
      v.eventWord := evrBus.stream.eventCodes(16*i+15 downto 16*i);
    end if;

    if r.strobe='1' then
      i := conv_integer(eventCode(3 downto 0));
      if (r.eventWord(i)='1' and enabled='1') then
        v.eventSel := '1';
      end if;
      if evrBus.stream.dbuff.epicsTime(0)/=r.lsb then
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
