-------------------------------------------------------------------------------
-- File       : EventHeaderCacheWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 XPM Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'LCLS2 XPM Core', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.TimingPkg.all;
use work.TimingExtnPkg.all;
use work.EventPkg.all;
use work.TDetPkg.all;
use work.XpmPkg.all;
use work.SsiPkg.all;

entity EventHeaderCacheWrapper is
   generic (
      TPD_G              : time                := 1 ns;
      -- USER_AXIS_CONFIG_G : AxiStreamConfigType := TDET_AXIS_CONFIG_C;
      USER_AXIS_CONFIG_G : AxiStreamConfigType := ssiAxiStreamConfig(4);
      USER_TIMING_BITS_G : integer             := 1;
      PIPE_STAGES_G      : natural             := 0;
      NDET_G             : natural             := 1);
   port (
      -- Trigger Interface (rxClk domain)
      trigBus         : out TDetTrigArray (NDET_G-1 downto 0);
      -- Readout Interface (tdetClk domain)
      tdetClk         : in  sl;
      tdetRst         : in  sl := '0';
      tdetTiming      : in  TDetTimingArray (NDET_G-1 downto 0);
      tdetStatus      : out TDetStatusArray (NDET_G-1 downto 0);
      -- Event stream (tdetClk domain)
      tdetEventMaster : out AxiStreamMasterArray(NDET_G-1 downto 0);
      tdetEventSlave  : in  AxiStreamSlaveArray (NDET_G-1 downto 0);
      -- Transition stream (tdetClk domain)
      tdetTransMaster : out AxiStreamMasterArray(NDET_G-1 downto 0);
      tdetTransSlave  : in  AxiStreamSlaveArray (NDET_G-1 downto 0);
      -- LCLS RX Timing Interface (rxClk domain)
      rxClk           : in  sl;
      rxRst           : in  sl;
      timingBus       : in  TimingBusType;
      userTimingIn    : in  slv(USER_TIMING_BITS_G-1 downto 0) := (others=>'0');
      -- LCLS RX Timing Interface (txClk domain)
      txClk           : in  sl;
      txRst           : in  sl;
      timingPhy       : out TimingPhyType);
end EventHeaderCacheWrapper;

architecture mapping of EventHeaderCacheWrapper is

   signal timingHdr  : TimingHeaderType;  -- prompt
   signal triggerBus : ExptBusType;       -- prompt

   signal appTimingHdr : TimingHeaderType;  -- aligned
   signal appExptBus   : ExptBusType;       -- aligned
   signal appUserTiming: slv(USER_TIMING_BITS_G-1 downto 0); -- aligned
   
   signal pdata      : XpmPartitionDataArray(NDET_G-1 downto 0);
   signal pdataV     : slv                  (NDET_G-1 downto 0);
   signal spartition : Slv3Array            (NDET_G-1 downto 0);
   signal spdelay    : Slv7Array            (NDET_G-1 downto 0);

   signal pdelay  : Slv7Array(NPartitions-1 downto 0);
   signal fullOut : slv      (NPartitions-1 downto 0);
   signal aFull   : slv      (NPartitions-1 downto 0);

   signal tdetMaster : AxiStreamMasterArray (NDET_G-1 downto 0);
   signal tdetSlave  : AxiStreamSlaveArray (NDET_G-1 downto 0);

   signal tdetMasterResize : AxiStreamMasterArray (NDET_G-1 downto 0);
   signal tdetSlaveResize  : AxiStreamSlaveArray (NDET_G-1 downto 0);

   signal hdrOut    : EventHeaderArray (NDET_G-1 downto 0);
   signal hdrFull   : slv              (NDET_G-1 downto 0);
   signal hdrFullT  : slv              (NDET_G-1 downto 0);
   signal aFullRx   : slv              (NDET_G-1 downto 0);

   type DbgRegType is record
     evCount     : Slv8Array(3 downto 0);
     evCountDiff : slv(31 downto 0);
   end record;

   constant DBG_REG_INIT_C : DbgRegType := (
     evCount      => (others=>(others=>'0')),
     evCountDiff  => (others=>'0') );

   signal dr   : DbgRegType := DBG_REG_INIT_C;
   signal drin : DbgRegType;

   type RegType is record
     status          : TDetStatusArray(NDET_G-1 downto 0);
     spartition      : Slv3Array      (NDET_G-1 downto 0);
     afull           : slv            (NDET_G-1 downto 0);
     stable          : slv            (NDET_G-1 downto 0);
     cntOflow        : slv            (NDET_G-1 downto 0);
     cnts            : Slv12Array     (NDET_G-1 downto 0);
     cntsToTrig      : Slv12Array     (NDET_G-1 downto 0);
     cntsFullToTrig  : Slv12Array     (NDET_G-1 downto 0);
     cntsNFullToTrig : Slv12Array     (NDET_G-1 downto 0);
     dbg             : DbgRegType;
   end record;

   constant REG_INIT_C : RegType := (
     status          => (others=>TDET_STATUS_INIT_C),
     spartition      => (others=>(others=>'0')),
     afull           => (others=>'0'),
     stable          => (others=>'0'),
     cntOflow        => (others=>'0'),
     cnts            => (others=>(others=>'0')),
     cntsToTrig      => (others=>(others=>'0')),
     cntsFullToTrig  => (others=>(others=>'0')),
     cntsNFullToTrig => (others=>(others=>'1')),
     dbg             => DBG_REG_INIT_C );

   signal r    : RegType := REG_INIT_C;
   signal rin  : RegType;

   constant DEBUG_C : boolean := true;

   component ila_0
     port ( clk    : in sl;
            probe0 : in slv(255 downto 0) );
   end component;

   signal evCountTrig, evCountTrigRx : sl;
   signal cntWrFifo, cntRdFifo : Slv5Array(NDET_G-1 downto 0);

begin

   timingHdr          <= toTimingHeader (timingBus);
   triggerBus.message <= timingBus.extn.expt;
   triggerBus.valid   <= timingBus.extnValid;

   U_Realign : entity work.EventRealign
      generic map (
         TPD_G              => TPD_G)
      port map (
         clk         => rxClk,
         rst         => rxRst,
         timingI     => timingHdr,
         exptBusI    => triggerBus,
         timingO     => appTimingHdr,
         exptBusO    => appExptBus,
         delay       => pdelay);

   GEN_DET : for i in 0 to NDET_G-1 generate

     U_Realign : entity work.UserRealign
       generic map (
         WIDTH_G => USER_TIMING_BITS_G,
         TPD_G   => TPD_G)
       port map (
         clk         => rxClk,
         rst         => rxRst,
         delay       => spdelay(i),
         timingI     => timingHdr,
         userTimingI => userTimingIn,
         userTimingO => trigBus(i).user(USER_TIMING_BITS_G-1 downto 0) );
     
      trigBus(i).l0a   <= pdata (i).l0a;
      trigBus(i).l0tag <= pdata (i).l0tag;
      trigBus(i).valid <= pdataV(i);
      
      U_HeaderCache : entity work.EventHeaderCache
         generic map ( TPD_G => TPD_G,
                       ADDR_WIDTH_G => 5,
                       FULL_THRES_G => 24,
                       DEBUG_G => DEBUG_C )
         port map (
            rst            => rxRst,
            --  Cache Input
            wrclk          => rxClk,
            -- configuration
            enable         => tdetTiming(i).enable,
            partition      => tdetTiming(i).partition,
            -- event input
            timing_prompt  => timingHdr,
            expt_prompt    => triggerBus,
            timing_aligned => appTimingHdr,
            expt_aligned   => appExptBus,
            -- trigger output
            pdata          => pdata (i),
            pdataV         => pdataV(i),
            -- status
            aFull          => hdrFull(i),
            cntL0          => tdetStatus(i).cntL0,
            cntL1A         => tdetStatus(i).cntL1A,
            cntL1R         => tdetStatus(i).cntL1R,
            cntWrFifo      => cntWrFifo (i),
            rstFifo        => open,
            msgDelay       => tdetStatus(i).msgDelay,
            cntOflow       => tdetStatus(i).cntOflow,
            --  Cache Output
            rdclk          => tdetClk,
            advance        => tdetSlave (i).tReady,
            valid          => tdetMaster(i).tValid,
            pmsg           => tdetMaster(i).tDest(0),
            cntRdFifo      => cntRdFifo (i),
            hdrOut         => hdrOut (i));

      tdetStatus(i).cntWrFifo <= cntWrFifo(i);
      tdetStatus(i).cntRdFifo <= cntRdFifo(i);
     
      tdetMaster(i).tData(8*TDET_AXIS_CONFIG_C.TDATA_BYTES_C-1 downto 0) <= toSlv(hdrOut(i));
      tdetMaster(i).tLast                                                <= '1';
      tdetMaster(i).tKeep                                                <= genTKeep(TDET_AXIS_CONFIG_C);

      U_Resizer : entity work.AxiStreamResize
         generic map (
            TPD_G               => TPD_G,
            SLAVE_AXI_CONFIG_G  => TDET_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => USER_AXIS_CONFIG_G)
         port map (
            -- Clock and reset
            axisClk     => tdetClk,
            axisRst     => tdetRst,
            -- Slave Port
            sAxisMaster => tdetMaster(i),
            sAxisSlave  => tdetSlave (i),
            -- Master Port
            mAxisMaster => tdetMasterResize(i),
            mAxisSlave  => tdetSlaveResize (i));

      U_DeMux : entity work.AxiStreamDeMux
         generic map (
            TPD_G         => TPD_G,
            PIPE_STAGES_G => PIPE_STAGES_G,
            NUM_MASTERS_G => 2)
         port map (
            axisClk         => tdetClk,
            axisRst         => tdetRst,
            sAxisMaster     => tdetMasterResize(i),
            sAxisSlave      => tdetSlaveResize (i),
            mAxisMasters(0) => tdetEventMaster(i),
            mAxisMasters(1) => tdetTransMaster(i),
            mAxisSlaves (0) => tdetEventSlave (i),
            mAxisSlaves (1) => tdetTransSlave (i));

     U_SyncFullRx : entity work.Synchronizer
       port map ( clk     => rxClk,
                  dataIn  => tdetTiming(i).afull,
                  dataOut => aFullRx(i) );

     U_SyncPartition : entity work.SynchronizerVector
       generic map ( WIDTH_G => spartition(i)'length )
       port map ( clk     => rxClk,
                  dataIn  => tdetTiming(i).partition,
                  dataOut => spartition(i) );

   end generate;

   U_SyncFull : entity work.SynchronizerVector
     generic map ( WIDTH_G => NPartitions )
     port map ( clk     => txClk,
                dataIn  => aFull,
                dataOut => fullOut );

   U_SyncHdrFull : entity work.SynchronizerVector
     generic map ( WIDTH_G => NDET_G )
     port map ( clk     => tdetClk,
                dataIn  => hdrFull,
                dataOut => hdrFullT );

   U_SyncEvCountTrig : entity work.Synchronizer
     port map ( clk     => rxClk,
                dataIn  => evCountTrig,
                dataOut => evCountTrigRx );
   
   fullp : process (tdetTiming, hdrFullT) is
      variable vfull : slv(NPartitions-1 downto 0);
   begin
      vfull := (others => '0');
      for i in 0 to NDET_G-1 loop
         if tdetTiming(i).enable = '1' then
           if tdetTiming(i).afull = '1' or hdrFullT(i) = '1' then
             vfull(conv_integer(tdetTiming(i).partition)) := '1';
           end if;
         end if;
      end loop;
      aFull <= vfull;
   end process fullp;

   U_TimingFb : entity work.XpmTimingFb
      port map (
         clk      => txClk,
         rst      => txRst,
         id       => tdetTiming(0).id,
         l1input  => (others => XPM_L1_INPUT_INIT_C),
         full     => fullOut,
         phy      => timingPhy);

   comb : process ( rxRst, r, triggerBus, timingBus, aFullRx, hdrFull, pdata, pdataV,
                    pdelay, spartition ) is
     variable v     : RegType;
     variable vfull : sl;
   begin
     v := r;

     for i in 0 to NDET_G-1 loop

       vfull           := aFullRx(i) or hdrFull(i);
       v.spartition(i) := spartition(i);
       v.afull     (i) := vfull;
       v.cnts      (i) := r.cnts (i)+1;

       if uAnd(r.cnts(i))='1' then
         v.cntOflow(i) := '1';
       end if;
       
       if (triggerBus.valid = '1' and timingBus.strobe = '1' and
           triggerBus.message.partitionAddr(28)='1') then
         v.status(i).partitionAddr := triggerBus.message.partitionAddr;
       end if;

       -- full changes
       if vfull /= r.afull(i) then
         v.cnts    (i) := (others=>'0');
         v.cntOflow(i) := '0';
         v.stable  (i) := r.cntOflow(i);
         if (r.afull(i) = '1' and r.stable(i) = '1' and
             r.cntsToTrig(i) > r.status(i).fullToTrig) then
           v.status(i).fullToTrig := r.cntsToTrig(i);
         end if;
       elsif pdataV(i) = '1' and pdata(i).l0a = '1' then
         if r.afull(i) = '1' then
           v.cntsToTrig(i) := v.cnts(i);
         elsif (r.stable(i) = '1' and r.cntOflow(i) = '0' and 
                r.cnts(i) < r.status(i).nfullToTrig) then
           v.status(i).nfullToTrig := r.cnts(i);
         end if;
       end if;

     end loop;

     for i in 0 to 3 loop
       if pdataV(i) = '1' and pdata(i).l0a = '1' then
         v.dbg.evCount(i)  := pdata(i).anatag(7 downto 0);
         v.dbg.evCountDiff(8*i+7 downto 8*i) := v.dbg.evCount(i) - r.dbg.evCount(i);
       end if;
     end loop;
       
     if rxRst = '1' then
       v := REG_INIT_C;
     end if;
     
     rin <= v;

     for i in 0 to NDET_G-1 loop
       tdetStatus(i).partitionAddr <= r.status(i).partitionAddr;
       tdetStatus(i).fullToTrig    <= r.status(i).fullToTrig;
       tdetStatus(i).nfullToTrig   <= r.status(i).nfullToTrig;
       spdelay   (i)               <= pdelay(conv_integer(r.spartition(i)));
     end loop;
   end process comb;
   
   seq : process (rxClk) is
   begin
     if rising_edge(rxClk) then
       r <= rin;
     end if;
   end process seq;

   GEN_DEBUG : if DEBUG_C generate
     U_ILA : ila_0
       port map ( clk      => tdetClk,
                  probe0(31 downto  0) => dr.evCountDiff,
                  probe0(39 downto 32) => dr.evCount(0),
                  probe0(47 downto 40) => dr.evCount(1),
                  probe0(55 downto 48) => dr.evCount(2),
                  probe0(63 downto 56) => dr.evCount(3),
                  probe0(64)           => tdetMaster(0).tValid,
                  probe0(65)           => tdetMaster(1).tValid,
                  probe0(66)           => tdetMaster(2).tValid,
                  probe0(67)           => tdetMaster(3).tValid,
                  probe0(68)           => tdetSlave (0).tReady,
                  probe0(69)           => tdetSlave (1).tReady,
                  probe0(70)           => tdetSlave (2).tReady,
                  probe0(71)           => tdetSlave (3).tReady,
                  probe0(72)           => tdetMaster(0).tValid,
                  probe0(73)           => tdetMaster(0).tLast,
                  probe0(77 downto 74)   => cntRdFifo(0),
                  probe0(81 downto 78)   => cntRdFifo(1),
                  probe0(85 downto 82)   => cntRdFifo(2),
                  probe0(89 downto 86)   => cntRdFifo(3),
                  probe0(90)             => hdrOut(0).damaged,
                  probe0(91)             => hdrOut(0).damaged,
                  probe0(92)             => hdrOut(0).damaged,
                  probe0(93)             => hdrOut(0).damaged,
                  probe0( 98 downto  94)   => hdrOut(0).l1t(5 downto 1),
                  probe0(103 downto  99)   => hdrOut(1).l1t(5 downto 1),
                  probe0(108 downto 104)   => hdrOut(2).l1t(5 downto 1),
                  probe0(113 downto 109)   => hdrOut(3).l1t(5 downto 1),
                  probe0(117 downto 114)   => hdrFullT(3 downto 0),
                  probe0(255 downto 118) => (others=>'0') );

     U_ILA_DT : ila_0
       port map ( clk                    => rxClk,
                  probe0(             0) => r.stable(0),
                  probe0( 12 downto   1) => r.cnts(0),
                  probe0(            13) => r.afull(0),
                  probe0(            14) => aFullRx(0),
                  probe0( 26 downto  15) => r.cntsToTrig(0),
                  probe0( 38 downto  27) => r.status(0).fullToTrig,
                  probe0( 50 downto  39) => r.status(0).nfullToTrig,
                  probe0(            51) => r.cntOflow(0),
                  probe0(            52) => hdrFull(0),
                  probe0( 56 downto  53) => cntWrFifo(0),
                  probe0( 57 )           => pdataV(0),
                  probe0( 58 )           => pdata(0).l0a,
                  probe0( 59 )           => evCountTrigRx,
                  probe0( 91 downto  60) => r.dbg.evCountDiff,
                  probe0( 99 downto  92) => r.dbg.evCount(0),
                  probe0(107 downto 100) => r.dbg.evCount(1),
                  probe0(115 downto 108) => r.dbg.evCount(2),
                  probe0(123 downto 116) => r.dbg.evCount(3),
                  probe0(255 downto 124) => (others=>'0') );
   end generate;
   
   tcomb : process ( dr, tdetRst, tdetMaster, tdetSlave, hdrOut ) is
     variable v : DbgRegType;
   begin
     v := dr;

     for i in 0 to 3 loop
       if (tdetMaster(i).tValid = '1' and tdetSlave(i).tReady = '1') then
         v.evCount(i)  := hdrOut(i).count(7 downto 0);
         v.evCountDiff(8*i+7 downto 8*i) := v.evCount(i) - dr.evCount(i);
       end if;
     end loop;
       
     if tdetRst = '1' then
       v := DBG_REG_INIT_C;
     end if;

     drin <= v;

     if dr.evCountDiff(7 downto 0) = x"01" then
       evCountTrig <= '0';
     else
       evCountTrig <= '1';
     end if;
   end process tcomb;

   tseq : process ( tdetClk ) is
   begin
     if rising_edge(tdetClk) then
       dr <= drin;
     end if;
   end process tseq;
   
end mapping;
