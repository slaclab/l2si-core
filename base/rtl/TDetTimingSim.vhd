-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : TDetTiming.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-08
-- Last update: 2019-03-20
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
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

entity TDetTimingSim is
   generic (
      TPD_G               : time             := 1 ns;
      NDET_G              : natural          := 1;
      AXIL_BASEADDR_G     : slv(31 downto 0) := (others=>'0');
      AXIL_RINGB_G        : boolean          := false );
   port (
      --------------------------------------------
      -- Trigger Interface (Timing clock domain)
      --------------------------------------------
      trigClk          : out sl;
      trigBus          : out TDetTrigArray       (NDET_G-1 downto 0);
      --------------------------------------------
      -- Readout Interface
      --------------------------------------------
      tdetClk          : in  sl;
      tdetRst          : in  sl := '0';
      tdetTiming       : in  TDetTimingArray     (NDET_G-1 downto 0);
      tdetStatus       : out TDetStatusArray     (NDET_G-1 downto 0);
      -- Event stream
      tdetEventMaster  : out AxiStreamMasterArray(NDET_G-1 downto 0);
      tdetEventSlave   : in  AxiStreamSlaveArray (NDET_G-1 downto 0);
      -- Transition stream
      tdetTransMaster  : out AxiStreamMasterArray(NDET_G-1 downto 0);
      tdetTransSlave   : in  AxiStreamSlaveArray (NDET_G-1 downto 0);
      ----------------
      -- Core Ports --
      ----------------   
      -- LCLS Timing Ports
      timingRefClkOut  : out sl;
      timingRecClkOut  : out sl;
      timingBusOut     : out TimingBusType );
end TDetTimingSim;

architecture mapping of TDetTimingSim is

   signal timingRefClk   : sl;
   signal timingRefClkDiv: sl;
   signal rxControl      : TimingPhyControlType;
   signal rxStatus       : TimingPhyStatusType := (
     locked       => '1',
     resetDone    => '1',
     bufferByDone => '1',
     bufferByErr  => '0' );
   signal rxCdrStable    : sl;
   signal rxUsrClk       : sl;
   signal rxData         : slv(15 downto 0);
   signal rxDataK        : slv(1 downto 0);
   signal rxDispErr      : slv(1 downto 0);
   signal rxDecErr       : slv(1 downto 0);
   signal rxOutClk       : sl;
   signal rxRst          : sl;
   signal txUsrClk       : sl;
   signal txUsrRst       : sl;
   signal txOutClk       : sl;
   signal loopback       : slv(2 downto 0);
   signal timingPhy      : TimingPhyType;
   signal timingBus      : TimingBusType := TIMING_BUS_INIT_C;

   signal appTimingHdr   : TimingHeaderType; -- aligned
   signal appExptBus     : ExptBusType;      -- aligned
   signal timingHdr      : TimingHeaderType; -- prompt
   signal triggerBus     : ExptBusType;      -- prompt
   signal fullOut        : slv(NPartitions-1 downto 0);

   signal pdata          : XpmPartitionDataArray(NDET_G-1 downto 0);
   signal pdataV         : slv                  (NDET_G-1 downto 0);
   signal tdetMaster     : AxiStreamMasterArray (NDET_G-1 downto 0);
   signal tdetSlave      : AxiStreamSlaveArray  (NDET_G-1 downto 0);
   signal hdrOut         : EventHeaderArray     (NDET_G-1 downto 0);

   signal xpmClk       : slv       (NDSLinks-1 downto 0);
   signal xpmDsRxData  : Slv16Array(NDSLinks-1 downto 0) := (others=>x"0000");
   signal xpmDsRxDataK : Slv2Array (NDSLinks-1 downto 0) := (others=>"00");
   signal xpmDsTxData  : Slv16Array(NDSLinks-1 downto 0);
   signal xpmDsTxDataK : Slv2Array (NDSLinks-1 downto 0);
   
begin

   trigClk         <= rxOutClk;
   timingRecClkOut <= rxOutClk;
   timingBusOut    <= timingBus;
   rxRst           <= tdetRst;
   
   process is
   begin
     rxOutClk <= '1';
     wait for 2.69 ns;
     rxOutClk <= '0';
     wait for 2.69 ns;
   end process;

   --  Need timingBus with extn
   process is
     variable pulseId : slv(63 downto 0) := (others=>'0');
     variable anatag  : slv(23 downto 0) := (others=>'0');
     variable pmsg    : XpmPartitionMsgType  := XPM_PARTITION_MSG_INIT_C;
     variable pdat    : XpmPartitionDataType := XPM_PARTITION_DATA_INIT_C;
     variable frame   : slv( 3 downto 0) := (others=>'0');
   begin
     timingBus <= TIMING_BUS_INIT_C;
     timingBus.valid     <= '1';
     timingBus.modesel   <= '1';
     timingBus.message.version    <= toSlv(1,16);

     wait for 1 us;
     wait until rxOutClk = '0';

     for j in 0 to 99 loop
       timingBus.message.pulseId    <= pulseId;
       timingBus.message.timeStamp  <= pulseId;
       timingBus.strobe    <= '1';

       timingBus.extn.expt.partitionWord(0)(0)  <= '0'; -- No L0
       timingBus.extn.expt.partitionWord(0)(15) <= '1'; -- No Msg
       if frame = x"0" then
         pmsg.hdr     := MSG_DELAY_PWORD;
         pmsg.payload := toSlv(3,8);
         pmsg.anatag  := anatag;
         anatag       := anatag+1;
         timingBus.extn.expt.partitionWord(0) <= toSlv(pmsg);
         timingBus.extnValid                  <= '1';
       elsif frame = x"8" then
         pmsg.l0tag   := anatag(4 downto 0);
         pmsg.hdr     := toSlv(2,8);
         pmsg.payload := x"FE";
         pmsg.anatag  := anatag;
         anatag       := anatag+1;
         timingBus.extn.expt.partitionWord(0) <= toSlv(pmsg);
       elsif frame = x"F" then
         pdat.l0a    := '1';
         pdat.l0tag  := anatag(4 downto 0);
         pdat.anatag := anatag;
         anatag      := anatag+1;
         timingBus.extn.expt.partitionWord(0) <= toSlv(pdat);
       end if;
       if frame /= x"F" then
         frame := frame+1;
       end if;

       pulseId := pulseId+1;
       for i in 0 to 199 loop
         wait until rxOutClk = '1';
         wait until rxOutClk = '0';
         timingBus.strobe <= '0';
       end loop;
     end loop;
     wait;
   end process;

   U_Cache : entity work.EventHeaderCacheWrapper
     generic map ( USER_TIMING_BITS_G => 32,
                   NDET_G             => NDET_G )
     port map (
       -- Trigger Interface (rxClk domain)
       trigBus         => trigBus,
       -- Readout Interface (tdetClk domain)
       tdetClk         => tdetClk,
       tdetRst         => tdetRst,
       tdetTiming      => tdetTiming,
       tdetStatus      => tdetStatus,
       -- Event stream (tdetClk domain)
       tdetEventMaster => tdetEventMaster,
       tdetEventSlave  => tdetEventSlave,
       -- Transition stream (tdetClk domain)
       tdetTransMaster => tdetTransMaster,
       tdetTransSlave  => tdetTransSlave,
       -- LCLS RX Timing Interface (rxClk domain)
       rxClk           => rxOutClk,
       rxRst           => rxRst,
       timingBus       => timingBus,
       userTimingIn    => timingBus.message.pulseId(31 downto 0),
       -- LCLS RX Timing Interface (txClk domain)
       txClk           => txUsrClk,
       txRst           => txUsrRst,
       timingPhy       => timingPhy );

end mapping;
