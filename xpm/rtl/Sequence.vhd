-------------------------------------------------------------------------------
-- Title      : Sequence
-------------------------------------------------------------------------------
-- File       : Sequence.vhd
-- Author     : Matt Weaver  <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-15
-- Last update: 2023-11-08
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Sequence engine for timing generator.
--
--  Sequencer instruction word bits:
--    (31:29)="010"  Fixed Rate Sync -- shifted down 1
--       (19:16)=marker_id
--       (11:0)=occurrence
--    (31:29)="011"  AC Rate Sync -- shifted down 1
--       (28:23)=timeslot_mask  -- shifted down 1
--       (19:16)=marker_id
--       (11:0)=occurrence
--    (31:29)="001"  Checkpoint/Notify -- shifted down 1
--    (31:29)="000"  Branch -- shifted down 1
--       (28:27)=counter
--       (24)=conditional  -- flipped polarity
--       (23:12)=test_value
--       (10:0)=address
--    (31:29)="100" Request
--       (15:0)  Value
--    (31:29)="101" Call/Return
--       (12)=return from call
--       (10:0)=address
--
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
use work.all;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library UNISIM;
use UNISIM.VCOMPONENTS.all;

library lcls_timing_core;
use lcls_timing_core.TPGPkg.all;

library surf;
use surf.StdRtlPkg.all;

entity Sequence is
   generic ( TPD_G       : time := 1 ns;
             MON_SUM_G   : boolean := true;  -- monCount is the sum of requests
             EN_NOTIFY_G : boolean := true;
             MON_WIDTH_G : integer range 1 to 32 := 20;
             MON_DEPTH_G : integer := 4;
             DEBUG       : boolean := false );
   port (
      -- Clock and reset
      clkA         : in  sl;
      rstA         : in  sl;
      wrEnA        : in  sl;
      indexA       : in  SeqAddrType;
      rdStepA      : out slv(31 downto 0);
      wrStepA      : in  slv(31 downto 0);
      clkB         : in  sl;
      rstB         : in  sl;
      rdEnB        : in  sl;
      waitB        : in  sl;
      acTS         : in  slv(2 downto 0);
      acRate       : in  slv(5 downto 0);
      fixedRate    : in  slv(9 downto 0);
      seqReset     : in  sl;
      startAddr    : in  SeqAddrType;
      seqState     : out SequencerState;
      seqNotify    : out SeqAddrType;
      seqNotifyWr  : out sl;
      seqNotifyAck : in  sl := '1';
      dataO        : out slv(16 downto 0);

      monReset : in  sl;
      monCount : out slv(127 downto 0)
      );
end Sequence;

-- Define architecture for top level module
architecture ISequence of Sequence is

   type SEQ_STATE is (SEQ_STOPPED, SEQ_LOAD, SEQ_TEST_BRANCH, SEQ_TEST_OCC, SEQ_STEP_WAIT, SEQ_STEP_LOAD);

   type RegType is
   record
      index      : slv(SEQADDRLEN-1 downto 0);
      delaycount : slv(15 downto 0);
      count      : Slv12Array(3 downto 0);
      data       : slv(16 downto 0);
      counter    : slv(11 downto 0);
      counterI   : integer range 0 to 3;
      jump       : sl;
      notify     : sl;
      notifyaddr : slv(SEQADDRLEN-1 downto 0);
      returnaddr : slv(SEQADDRLEN-1 downto 0); -- a one-deep stack
      state      : SEQ_STATE;
      monCount   : Slv32Array(MON_DEPTH_G-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      index      => (others => '0'),
      delaycount => (others => '0'),
      count      => (others => (others => '0')),
      data       => (others => '0'),
      counter    => (others => '0'),
      counterI   => 0,
      jump       => '0',
      notify     => '0',
      notifyaddr => (others => '0'),
      returnaddr => (others => '0'),
      state      => SEQ_STOPPED,
      monCount   => (others=>(others => '0')));

   signal rdStepB : slv(31 downto 0);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal istate : slv(2 downto 0);
   signal icount : slv(1 downto 0);

   signal monResetS : sl;

   component ila_0
     port ( clk    : in  sl;
            probe0 : in slv(255 downto 0) );
   end component;
begin

   GEN_DEBUG: if DEBUG generate
     istate <= "000" when r.state=SEQ_STOPPED else
               "001" when r.state=SEQ_LOAD else
               "010" when r.state=SEQ_TEST_BRANCH else
               "011" when r.state=SEQ_TEST_OCC else
               "100" when r.state=SEQ_STEP_WAIT else
               "101";
     icount <= toSlv(r.counterI,2);
     U_ILA : ila_0
       port map ( clk                    => clkB,
                  probe0( 31 downto   0) => rdStepB,
                  probe0( 39 downto  32) => r.count(0)(7 downto 0),
                  probe0( 47 downto  40) => r.count(1)(7 downto 0),
                  probe0( 55 downto  48) => r.count(2)(7 downto 0),
                  probe0( 63 downto  56) => r.count(3)(7 downto 0),
                  probe0( 79 downto  64) => r.data(15 downto 0),
                  probe0( 95 downto  80) => r.delaycount,
                  probe0(103 downto  96) => r.counter(7 downto 0),
                  probe0(106 downto 104) => istate,
                  probe0(108 downto 107) => icount,
                  probe0(118 downto 109) => fixedRate,
                  probe0(119)            => seqReset,
                  probe0(120)            => rdEnB,
                  probe0(255 downto 121) => (others=>'0') );
   end generate GEN_DEBUG;

   dataO          <= r.data;
   seqState.index <= SeqAddrType(r.index);
   GEN_COUNT : for i in r.count'range generate
     seqState.count(i) <= r.count(i)(7 downto 0);
   end generate;
   seqNotifyWr    <= r.notify;
   seqNotify      <= SeqAddrType(r.notifyaddr);

   GEN_MONCOUNT : for i in 0 to MON_DEPTH_G-1 generate
     monCount(i*32+MON_WIDTH_G-1 downto i*32) <= r.monCount(i)(MON_WIDTH_G-1 downto 0);
   end generate;

   U_Ram : entity surf.DualPortRam
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 32,
         ADDR_WIDTH_G => 11,
         MODE_G       => "read-first")
      port map (
         clka  => clkA,
         ena   => '1',
         wea   => wrEnA,
         rsta  => rstA,
         addra => slv(indexA),
         dina  => wrStepA,
         douta => rdStepA,
         clkb  => clkB,
         enb   => '1',
         rstb  => rstB,
         addrb => rin.index,
         doutb => rdStepB);

   U_MonReset : entity surf.RstSync
     port map (
       clk      => clkB,
       asyncRst => monReset,
       syncRst  => monResetS );

   process (r, seqReset, rdStepB, fixedRate, acRate, acTS, rdEnB, waitB, startAddr, seqNotifyAck, monResetS)
      variable v : RegType;
      variable rateI, acTSI : integer;
   begin  -- process

      v := r;

      v.jump := '0';

      if seqNotifyAck = '1' then
         v.notify := '0';
      end if;

      case r.state is
         when SEQ_STOPPED => null;
         when SEQ_LOAD =>
            v.counterI := conv_integer(rdStepB(28 downto 27));
            v.counter  := r.count(v.counterI);
            if (v.counter = rdStepB(23 downto 12)) then
               v.jump := '1';
            end if;
            v.state := SEQ_TEST_BRANCH;
         when SEQ_TEST_BRANCH =>
            case rdStepB(31 downto 29) is
               when "000" =>                                     -- Branch
                  if rdStepB(24) = '0' then                      -- unconditional
                     v.index := rdStepB(v.index'range);
                  elsif (r.jump = '1') then
                     v.index             := r.index+1;
                     v.count(r.counterI) := (others => '0');
                  else
                     v.index             := rdStepB(v.index'range);
                     v.count(r.counterI) := r.count(r.counterI)+1;
                  end if;
                  v.state := SEQ_LOAD;
               when "001" =>                                     -- Notify
                  v.index      := r.index+1;
                  if EN_NOTIFY_G then
                    v.notify     := '1';
                    v.notifyaddr := r.index;
                  end if;
                  v.state      := SEQ_LOAD;
               when "100" =>                                    -- Request
                  if MON_SUM_G then
                     v.monCount(0)   := r.monCount(0)+1;
                  else
                     for i in 0 to MON_DEPTH_G-1 loop
                        if rdStepB(i) = '1' then
                           v.monCount(i) := r.monCount(i)+1;
                        end if;
                     end loop;
                  end if;
                  v.index      := r.index+1;
                  v.data       := '1' & rdStepB(15 downto 0);
                  v.state      := SEQ_LOAD;
                when "101" =>                                    -- Call/Return
                  if rdStepB(12) = '1' then  -- return
                     v.index := r.returnaddr;
                     v.returnaddr := (others=>'0');  -- some stack safety
                  else
                     v.index := rdStepB(v.index'range);
                     v.returnaddr := r.index+1;
                  end if;
                  v.state      := SEQ_LOAD;
               when others =>                                   -- Sync
                  v.state := SEQ_TEST_OCC;
            end case;
         when SEQ_TEST_OCC =>                                   -- Sync
            if rdStepB(11 downto 0) = r.delaycount then
               v.state := SEQ_STEP_LOAD;
            else
               v.state := SEQ_STEP_WAIT;
            end if;
         when SEQ_STEP_WAIT =>                                  -- Sync
            if waitB = '1' then
               rateI := conv_integer(rdStepB(19 downto 16));
               acTSI := conv_integer(acTS);
               if rdStepB(29) = '0' then                        -- FixedRate
                  if (rateI<fixedRate'length and fixedRate(rateI) = '1') then
                     v.delaycount := r.delaycount+1;
                  end if;
               elsif (rdStepB(22+acTSI) = '1') then  -- 28:23
                  if (rateI<acRate'length and acRate(rateI) = '1') then
                     v.delaycount := r.delaycount+1;
                  end if;
               end if;
               v.state := SEQ_TEST_OCC;
            end if;
         when SEQ_STEP_LOAD =>
            v.index      := r.index+1;
            v.delaycount := (others => '0');
            v.state      := SEQ_LOAD;
      end case;

      if rdEnB = '1' then
         v.data := (others => '0');
      end if;

      if monResetS = '1' then
         v.monCount := (others=>(others => '0'));
      end if;

      -- from any state
      if seqReset = '1' and rdEnB = '1' then
         v.index      := slv(startAddr);
         v.delaycount := (others => '0');
         v.count      := (others => (others => '0'));
         v.state      := SEQ_LOAD;
      end if;

      rin <= v;

   end process;

   process (clkB)
   begin  -- process
      if rising_edge(clkB) then
         r <= rin after TPD_G;
      end if;
   end process;

end ISequence;
