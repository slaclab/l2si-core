-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : TDetTiming.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-08
-- Last update: 2019-03-13
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

library unisim;
use unisim.vcomponents.all;

entity TDetTiming is
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
      -- AXI-Lite Interface (axilClk domain)
      axilClk          : in  sl;
      axilRst          : in  sl;
      axilReadMaster   : in  AxiLiteReadMasterType;
      axilReadSlave    : out AxiLiteReadSlaveType;
      axilWriteMaster  : in  AxiLiteWriteMasterType;
      axilWriteSlave   : out AxiLiteWriteSlaveType;
      -- LCLS Timing Ports
      timingRxP        : in  sl;
      timingRxN        : in  sl;
      timingTxP        : out sl;
      timingTxN        : out sl;
      timingRefClkInP  : in  sl;
      timingRefClkInN  : in  sl;
      timingRefClkOut  : out sl;
      timingRecClkOut  : out sl;
      timingBusOut     : out TimingBusType );
end TDetTiming;

architecture mapping of TDetTiming is

   signal timingRefClk   : sl;
   signal timingRefClkDiv: sl;
   signal rxControl      : TimingPhyControlType;
   signal rxStatus       : TimingPhyStatusType;
   signal rxCdrStable    : sl;
   signal rxUsrClk       : sl;
   signal rxData         : slv(15 downto 0);
   signal rxDataK        : slv(1 downto 0);
   signal rxDispErr      : slv(1 downto 0);
   signal rxDecErr       : slv(1 downto 0);
   signal rxOutClk       : sl;
   signal rxRst          : sl;
   signal txStatus       : TimingPhyStatusType := TIMING_PHY_STATUS_INIT_C;
   signal txUsrClk       : sl;
   signal txUsrRst       : sl;
   signal txOutClk       : sl;
   signal loopback       : slv(2 downto 0);
   signal timingPhy      : TimingPhyType;
   signal timingBus      : TimingBusType;

begin

   trigClk         <= rxOutClk;
   timingRecClkOut <= rxOutClk;
   timingBusOut    <= timingBus;

   U_AxilXbar0 : entity work.AxiLiteCrossbar
    generic map ( NUM_SLAVE_SLOTS_G  => 1,
                  NUM_MASTER_SLOTS_G => AXIL_MASTERS_CONFIG_C'length,
                  MASTERS_CONFIG_G   => AXIL_MASTERS_CONFIG_C )
    port map    ( axiClk              => axilClk,
                  axiClkRst           => axilRst,
                  sAxiWriteMasters(0) => axilWriteMaster,
                  sAxiWriteSlaves (0) => axilWriteSlave ,
                  sAxiReadMasters (0) => axilReadMaster ,
                  sAxiReadSlaves  (0) => axilReadSlave  ,
                  mAxiWriteMasters    => axilWriteMasters,
                  mAxiWriteSlaves     => axilWriteSlaves ,
                  mAxiReadMasters     => axilReadMasters ,
                  mAxiReadSlaves      => axilReadSlaves  );
  
   -------------------------------------------------------------------------------------------------
   -- Clock Buffers
   -------------------------------------------------------------------------------------------------
   TIMING_REFCLK_IBUFDS_GTE3 : IBUFDS_GTE3
      generic map (
         REFCLK_EN_TX_PATH  => '0',
         REFCLK_HROW_CK_SEL => "00",    -- 2'b01: ODIV2 = Divide-by-2 version of O
         REFCLK_ICNTL_RX    => "00")
      port map (
         I     => timingRefClkInP,
         IB    => timingRefClkInN,
         CEB   => '0',
         ODIV2 => timingRefClkDiv,
         O     => timingRefClk);

   U_BUFG_GT : BUFG_GT
    port map (
      I       => timingRefClkDiv,
      CE      => '1',
      CLR     => '0',
      CEMASK  => '1',
      CLRMASK => '1',
      DIV     => "000",              -- Divide by 1
      O       => timingRefClkOut );

   -------------------------------------------------------------------------------------------------
   -- GTH Timing Receiver
   -------------------------------------------------------------------------------------------------
     TimingGthCoreWrapper_1 : entity work.TimingGtCoreWrapper
       generic map ( TPD_G            => TPD_G,
                     EXTREF_G         => true,
                     AXIL_BASE_ADDR_G => AXIL_MASTERS_CONFIG_C(1).baseAddr )
       port map (
         axilClk        => axilClk,
         axilRst        => axilRst,
         axilReadMaster => axilReadMasters (1),
         axilReadSlave  => axilReadSlaves  (1),
         axilWriteMaster=> axilWriteMasters(1),
         axilWriteSlave => axilWriteSlaves (1),
         stableClk      => axilClk,
         stableRst      => axilRst,
         gtRefClk       => timingRefClk,
         gtRefClkDiv2   => '0',
         gtRxP          => timingRxP,
         gtRxN          => timingRxN,
         gtTxP          => timingTxP,
         gtTxN          => timingTxN,
         rxControl      => rxControl,
         rxStatus       => rxStatus,
         rxUsrClkActive => '1',
         rxCdrStable    => rxCdrStable,
         rxUsrClk       => rxUsrClk,
         rxData         => rxData,
         rxDataK        => rxDataK,
         rxDispErr      => rxDispErr,
         rxDecErr       => rxDecErr,
         rxOutClk       => rxOutClk,
         txControl      => timingPhy.control,
         txStatus       => txStatus,
         txUsrClk       => txUsrClk,
         txUsrClkActive => '1',
         txData         => timingPhy.data,
         txDataK        => timingPhy.dataK,
         txOutClk       => txUsrClk,
         loopback       => loopback);

   txUsrRst         <= not (txStatus.resetDone);
   rxRst            <= not (rxStatus.resetDone);
   rxUsrClk         <= rxOutClk;
   
   TimingCore_1 : entity work.TimingCore
     generic map ( TPD_G             => TPD_G,
                   CLKSEL_MODE_G     => "LCLSII",
                   USE_TPGMINI_G     => false,
                   ASYNC_G           => false,
                   AXIL_BASE_ADDR_G  => AXIL_MASTERS_CONFIG_C(0).baseAddr )
     port map (
         gtTxUsrClk      => txUsrClk,
         gtTxUsrRst      => txUsrRst,
         gtRxRecClk      => rxOutClk,
         gtRxData        => rxData,
         gtRxDataK       => rxDataK,
         gtRxDispErr     => rxDispErr,
         gtRxDecErr      => rxDecErr,
         gtRxControl     => rxControl,
         gtRxStatus      => rxStatus,
         gtLoopback      => loopback,
         appTimingClk    => rxOutClk,
         appTimingRst    => rxRst,
         appTimingBus    => timingBus,
         timingPhy       => open, -- TPGMINI
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters (0),
         axilReadSlave   => axilReadSlaves  (0),
         axilWriteMaster => axilWriteMasters(0),
         axilWriteSlave  => axilWriteSlaves (0) );

   U_HeaderCache : entity work.EventHeaderCacheWrapper
      generic map (
         TPD_G   => TPD_G,  
         NDET_G  => NDET_G)      
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
         rxControl       => rxControl,
         timingBus       => timingBus,
         -- LCLS RX Timing Interface (txClk domain)
         txClk           => txUsrClk,
         txRst           => txUsrRst,
         txStatus        => txStatus,
         timingPhy       => timingPhy);
         
end mapping;
