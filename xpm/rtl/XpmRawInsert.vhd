-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Raw insertion flag management
--
-- Manage the raw insertion flag for all readout groups
--
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
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;


library l2si_core;
use l2si_core.XpmPkg.all;
use l2si_core.XpmExtensionPkg.all;

entity XpmRawInsert is
   generic (
     TPD_G   : time    := 1 ns
     );
   port (
      clk       : in  sl;
      rst       : in  sl;
      config    : in  XpmConfigType;
      start     : in  sl;
      shift     : in  sl;
      data_in   : in  Slv48Array(XPM_PARTITIONS_C-1 downto 0);
      data_out  : out Slv48Array(XPM_PARTITIONS_C-1 downto 0) );
end XpmRawInsert;

architecture rtl of XpmRawInsert is

  type StateType is (IDLE_S,CALC_S,ASSERT_S,READ1_S,WRITE_S,CLEAR_S,READ2_S);

  type RegType is record
    rog       : integer range 0 to XPM_PARTITIONS_C-1;
    index     : slv(7 downto 0);
    rawCoinc  : Slv8Array(XPM_PARTITIONS_C-1 downto 0);
    rawGroups : Slv8Array(XPM_PARTITIONS_C-1 downto 0);
    rawValid  : slv(XPM_PARTITIONS_C-1 downto 0);
    rawValue  : slv(XPM_PARTITIONS_C-1 downto 0);
    ramAddr   : slv(7 downto 0);
    ramWrEn   : sl;
    ramWrData : slv(XPM_PARTITIONS_C*2-1 downto 0);
    ramValue  : slv(XPM_PARTITIONS_C-1 downto 0);
    ramValid  : slv(XPM_PARTITIONS_C-1 downto 0);
    state     : StateType;
    data_out  : Slv48Array(XPM_PARTITIONS_C-1 downto 0);
    rawCount  : Slv20Array(XPM_PARTITIONS_C-1 downto 0);
    clearData : slv(15 downto 0);
  end record;
  constant REG_INIT_C : RegType := (
    rog       => 0,
    index     => (others=>'0'),
    rawCoinc  => (others=>(others=>'0')),
    rawGroups => (others=>(others=>'0')),
    rawValid  => (others=>'0'),
    rawValue  => (others=>'0'),
    ramAddr   => (others=>'0'),
    ramWrEn   => '0',
    ramWrData => (others=>'0'),
    ramValue  => (others=>'0'),
    ramValid  => (others=>'0'),
    state     => IDLE_S,
    data_out  => (others=>toSlv(XPM_TRANSITION_DATA_INIT_C)),
    rawCount  => (others=>(others=>'1')),
    clearData => (others=>'0') );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ramValid  : slv(XPM_PARTITIONS_C-1 downto 0);
   signal ramValue  : slv(XPM_PARTITIONS_C-1 downto 0);
   signal ramRdData : slv(XPM_PARTITIONS_C*2-1 downto 0);
  
begin

  data_out <= r.data_out;
  
  --
  --  When a readout group is ready to generate an L0 trigger,
  --  check if the raw data retention flag was set by a prior
  --  readout group (smaller L0Delay).
  --  When a readout group sets the raw data retention flag,
  --  write it into RAM at its L0Delay offset.
  --
  U_RAM : entity surf.SimpleDualPortRam
    generic map (
      DATA_WIDTH_G => XPM_PARTITIONS_C*2,
      ADDR_WIDTH_G => 8
      )
    port map (
      -- Port A
      clka    => clk,
      ena     => rin.ramWrEn,
      wea     => rin.ramWrEn,
      addra   => rin.ramAddr,
      dina    => rin.ramWrData,
      -- Port B
      clkb    => clk,
      rstb    => rst,
      addrb   => rin.ramAddr,
      doutb   => ramRdData );
  
  ramValid    <= ramRdData(2*XPM_PARTITIONS_C-1 downto XPM_PARTITIONS_C);
  ramValue    <= ramRdData(XPM_PARTITIONS_C-1 downto 0);
  
  comb : process( r, rst, config, start, shift, data_in, ramValid, ramValue ) is
    variable v : RegType;
    variable event : XpmEventDataType;
    variable trans : XpmTransitionDataType;
  begin
    v := r;

    v.ramWrEn := '0';

    v.rawValid := (others=>'0');
    v.rawValue := (others=>'0');
    
    case r.state is
      when IDLE_S =>
        -- Calculate what each group would do without intervention
        -- and use that result in the next phase
        if start = '1' then -- fiducial
          for i in 0 to XPM_PARTITIONS_C-1 loop
            -- Check for L0Accept
            event := toXpmEventDataType(data_in(i));
            if event.valid = '1' and event.l0Accept = '1' then
              v.rawValid(i) := '1';
              if r.rawCount(i) = 0 then
                v.rawValue(i) := '1';
              end if;
            end if;
          end loop;
          v.state := CALC_S;
        end if;
      when CALC_S =>
        for i in 0 to XPM_PARTITIONS_C-1 loop
          -- Default is to count down
          if config.partition(i).l0Select.enabled='1' and r.rawCount(i) /= 0 then
            v.rawCount(i) := r.rawCount(i)-1;
          end if;
          -- Check for L0Accept
          event := toXpmEventDataType(data_in(i));
          if event.valid = '1' and event.l0Accept = '1' then
            -- Slower group set the flag
            if r.ramValid(i) = '1' then
              event.l0Raw := r.ramValue(i);
              if r.ramValue(i) = '1' then
                v.rawCount(i) := config.partition(i).l0Select.rawPeriod-1;
              end if;
            -- A coincident group set the flag
            elsif (r.rawValue and r.rawGroups(i))/=0 then
              event.l0Raw := '1';
              v.ramValue(i) := '1';
              v.ramValid(i) := '1';
              v.rawCount(i) := config.partition(i).l0Select.rawPeriod-1;
            -- No flag set
            else
              event.l0Raw := '0';
              v.ramValue(i) := '0';
              v.ramValid(i) := '1';
            end if;
            v.data_out(i) := toSlv(event);
          else
            v.data_out(i) := data_in(i);
            trans := toXpmTransitionDataType(data_in(i));
            --  Reset the counter on transition
            if trans.valid = '1' and trans.header(7 downto 0) = MSG_CLEAR_FIFO_C then
              v.rawCount(i) := (others=>'0');
            end if; 
          end if;
        end loop;
        v.state := ASSERT_S;
      when ASSERT_S =>
        if shift = '1' then  -- transmission complete
          v.rog     := 0;
          v.ramAddr := r.index + config.partition(v.rog).pipeline.depth_fids;
          v.state   := READ1_S;
        end if;
      when READ1_S =>
        v.ramWrEn   := '1';
        v.ramWrData := ramValid & ramValue;
        v.ramWrData(r.rog+XPM_PARTITIONS_C) := r.ramValid(r.rog);
        v.ramWrData(r.rog)                  := r.ramValue(r.rog);
        v.state     := WRITE_S;
      when WRITE_S =>
        if r.rog=XPM_PARTITIONS_C-1 then
          v.rog     := 0;
          v.index   := r.index-1;
          --  Clear old entry
          v.ramAddr := r.index + toSlv(128,8);
          v.ramWrEn := '1';
          v.ramWrData := (others=>'0');
          v.state   := CLEAR_S;
        else
          v.rog     := r.rog+1;
          v.ramAddr := r.index + config.partition(v.rog).pipeline.depth_fids;
          v.state   := READ1_S;
        end if;
      when CLEAR_S =>
          v.clearData := ramValid & ramValue;
          v.ramAddr := v.index + config.partition(v.rog).pipeline.depth_fids;
          v.state   := READ2_S;
      when READ2_S =>
        v.ramValid(r.rog) := '0';
        v.ramValue(r.rog) := '0';
        if (ramValid and config.partition(r.rog).l0Select.groups) /= 0 then
          v.ramValue(r.rog) := uOr(ramValue and config.partition(r.rog).l0Select.groups);
          v.ramValid(r.rog) := '1';
        end if;
        if r.rog = XPM_PARTITIONS_C-1 then
          v.state   := IDLE_S;
        else
          v.rog     := r.rog+1;
          v.ramAddr := r.index + config.partition(v.rog).pipeline.depth_fids;
        end if;
      when others => null;
    end case;

    -- Intermediate calculation for coincident group determination
    for i in 0 to XPM_PARTITIONS_C-1 loop
      v.rawCoinc(i) := (others=>'0');
      for j in 0 to XPM_PARTITIONS_C-1 loop
        if i = j then
          v.rawCoinc(i)(j) := '1';
        elsif (config.partition(i).pipeline.depth_fids = config.partition(j).pipeline.depth_fids) then
          v.rawCoinc(i)(j) := '1';
        end if;
      end loop;
      v.rawGroups(i) := config.partition(i).l0Select.groups and r.rawCoinc(i);
    end loop;
    
    if rst = '1' then
      v := REG_INIT_C;
    end if;

    rin <= v;
    
  end process comb;
  
   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
end rtl;
