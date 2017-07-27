-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : xpm.vhd
-- Author     : Matt Weaver
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-12-14
-- Last update: 2017-07-23
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Firmware Target's Top Level
-- 
-- Note: Common-to-Application interface defined here (see URL below)
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
use ieee.std_logic_arith.all;

library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.AxiLitePkg.all;
use work.TimingPkg.all;
use work.XpmPkg.all;
use work.AmcCarrierPkg.all;

entity xpm is
   generic (
      TPD_G         : time    := 1 ns;
      BUILD_INFO_G  : BuildInfoType);
   port (
      -----------------------
      -- Application Ports --
      -----------------------
      -- -- AMC's HS Ports
      dsClkP      : in    Slv1Array(1 downto 0);
      dsClkN      : in    Slv1Array(1 downto 0);
      dsRxP       : in    Slv7Array(1 downto 0);
      dsRxN       : in    Slv7Array(1 downto 0);
      dsTxP       : out   Slv7Array(1 downto 0);
      dsTxN       : out   Slv7Array(1 downto 0);
      frqTbl      : inout slv      (1 downto 0);
      frqSel      : inout Slv4Array(1 downto 0);
      bwSel       : inout Slv2Array(1 downto 0);
      inc         : out   slv      (1 downto 0);
      dec         : out   slv      (1 downto 0);
      sfOut       : inout Slv2Array(1 downto 0);
      rate        : inout Slv2Array(1 downto 0);
      bypass      : out   slv      (1 downto 0);
      pllRst      : out   slv      (1 downto 0);
      lol         : in    slv      (1 downto 0);
      los         : in    slv      (1 downto 0);
      hsrScl      : inout Slv3Array(1 downto 0);
      hsrSda      : inout Slv3Array(1 downto 0);
      ----------------
      -- Core Ports --
      ----------------   
      -- Common Fabric Clock
      fabClkP         : in    sl;
      fabClkN         : in    sl;
      -- XAUI Ports
      ethRxP          : in    slv(3 downto 0);
      ethRxN          : in    slv(3 downto 0);
      ethTxP          : out   slv(3 downto 0);
      ethTxN          : out   slv(3 downto 0);
      ethClkP         : in    sl;
      ethClkN         : in    sl;
       -- Backplane MPS Ports
      bpClkIn         : in    sl;
      bpClkOut        : out   sl;
      bpBusRxP        : in    slv(14 downto 1);
      bpBusRxN        : in    slv(14 downto 1);
     -- LCLS Timing Ports
      -- Synchronous Timing Distribution (zone 2)
      timingTxP        : out   sl;
      timingTxN        : out   sl;
      timingRxP        : in    sl;
      timingRxN        : in    sl;
      -- use dsClk(1) for synchronous transmission
      --timingRefClkInP  : in    sl;
      --timingRefClkInN  : in    sl;
      -- Upstream timing reception, feedback transmission (if slave)
      usRxP            : in    sl;
      usRxN            : in    sl;
      usTxP            : out   sl;
      usTxN            : out   sl;
      usClkP           : in    sl;  -- use genRef(0) with 371MHz osc
      usClkN           : in    sl;
      --
      timingRecClkOutP : out   sl;
      timingRecClkOutN : out   sl;
      timingClkSel     : out   sl;
      timingClkScl     : inout sl;  -- jitter cleaner (unused)
      timingClkSda     : inout sl;
      fpgaclk_P        : out   slv(3 downto 0);
      fpgaclk_N        : out   slv(3 downto 0);
      -- Crossbar Ports
      xBarSin          : out   slv(1 downto 0);
      xBarSout         : out   slv(1 downto 0);
      xBarConfig       : out   sl;
      xBarLoad         : out   sl;
      -- IPMC Ports
      ipmcScl          : inout sl;
      ipmcSda          : inout sl;
      -- Configuration PROM Ports
      calScl           : inout sl;
      calSda           : inout sl;
      -- DDR3L SO-DIMM Ports
      ddrClkP          : in    sl;
      ddrClkN          : in    sl;
      ddrDm            : out   slv(7 downto 0);
      ddrDqsP          : inout slv(7 downto 0);
      ddrDqsN          : inout slv(7 downto 0);
      ddrDq            : inout slv(63 downto 0);
      ddrA             : out   slv(15 downto 0);
      ddrBa            : out   slv(2 downto 0);
      ddrCsL           : out   slv(1 downto 0);
      ddrOdt           : out   slv(1 downto 0);
      ddrCke           : out   slv(1 downto 0);
      ddrCkP           : out   slv(1 downto 0);
      ddrCkN           : out   slv(1 downto 0);
      ddrWeL           : out   sl;
      ddrRasL          : out   sl;
      ddrCasL          : out   sl;
      ddrRstL          : out   sl;
      ddrAlertL        : in    sl;
      ddrPg            : in    sl;
      ddrPwrEnL        : out   sl;
      ddrScl           : inout sl;
      ddrSda           : inout sl;
      -- SYSMON Ports
      vPIn             : in    sl;
      vNIn             : in    sl);
end xpm;

architecture top_level of xpm is

   -- AmcCarrierCore Configuration Constants
   constant DIAGNOSTIC_SIZE_C   : positive            := 1;
   constant DIAGNOSTIC_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);

   -- AXI-Lite Interface (appClk domain)
   signal regClk         : sl;
   signal regRst         : sl;
   signal regUpdate      : slv(NPartitions-1 downto 0);
   signal regReadMaster  : AxiLiteReadMasterType;
   signal regReadSlave   : AxiLiteReadSlaveType;
   signal regWriteMaster : AxiLiteWriteMasterType;
   signal regWriteSlave  : AxiLiteWriteSlaveType;

   -- Timing Interface (timingClk domain)
   signal recTimingData  : TimingRxType;
   signal recTimingBus   : TimingBusType;
   signal recExptBus     : ExptBusType;
   signal timingPhy      : TimingPhyType;
   
   -- Reference Clocks and Resets
   signal timingRefClk : sl;
   signal timingPhyClk : sl;
   signal recTimingClk : sl;
   signal recTimingRst : sl;
   signal ref125MHzClk : sl;
   signal ref125MHzRst : sl;
   signal ref156MHzClk : sl;
   signal ref156MHzRst : sl;

   constant NDsLinks : integer := 14;
   constant NBpLinks : integer := 6;
   
   signal xpmConfig : XpmConfigType;
   signal xpmStatus : XpmStatusType;
   signal bpStatus  : XpmBpLinkStatusArray(NBpLinks downto 0);
   signal pllStatus : XpmPllStatusArray ( 1 downto 0);

   signal dsClockP     :   slv(1 downto 0);
   signal dsClockN     :   slv(1 downto 0);
   signal idsRxP       :   Slv7Array(1 downto 0);
   signal idsRxN       :   Slv7Array(1 downto 0);
   signal idsTxP       :   Slv7Array(1 downto 0);
   signal idsTxN       :   Slv7Array(1 downto 0);

   signal dsLinkStatus : XpmLinkStatusArray(NDsLinks-1 downto 0);
   signal dsTxData  : Slv16Array(NDsLinks-1 downto 0);
   signal dsTxDataK : Slv2Array (NDsLinks-1 downto 0);
   signal dsRxData  : Slv16Array(NDsLinks-1 downto 0);
   signal dsRxDataK : Slv2Array (NDsLinks-1 downto 0);
   signal dsRxClk   : slv       (NDsLinks-1 downto 0);
   signal dsRxRst   : slv       (NDsLinks-1 downto 0);
   signal dsRxErr   : slv       (NDsLinks-1 downto 0);

   signal bpRxLinkUp     : slv               (NBpLinks-1 downto 0);
   signal bpRxLinkFull   : Slv16Array        (NBpLinks-1 downto 0);
   signal bpTxLinkStatus : XpmLinkStatusType;
   signal bpTxData       : Slv16Array(0 downto 0);
   signal bpTxDataK      : Slv2Array (0 downto 0);
   
   signal dbgChan   : slv( 4 downto 0);
   signal dbgChanS  : slv( 4 downto 0);
   signal ringData  : slv(19 downto 0);
   signal ringDataI : Slv19Array(NDsLinks-1 downto 0);
   signal ringDataV : slv       (NDsLinks-1 downto 0);
   
   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(1 downto 0) := (
     1              => (
       baseAddr     => x"80010000",
       addrBits     => 16,
       connectivity => x"FFFF"),
     0              => (
       baseAddr     => x"80000000",
       addrBits     => 16,
       connectivity => x"FFFF"));

   signal axilReadMasters  : AxiLiteReadMasterArray (1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray  (1 downto 0);
   signal axilWriteMasters : AxiLiteWriteMasterArray(1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray (1 downto 0);

   signal ibDebugMaster    : AxiStreamMasterType;
   signal ibDebugSlave     : AxiStreamSlaveType;

   signal dsClkBuf         : slv(1 downto 0);

   signal bpMonClk         : sl;
   
begin

  --
  --  The AMC SFP channels are reordered - the mapping to MGT quads is non-trivial
  --    amcTx/Rx indexed by MGT
  --    iamcTx/Rx indexed by SFP
  --
  reorder_p : process (dsClkP,dsClkN,dsRxP,dsRxN,idsTxP,idsTxN) is
  begin
    for i in 0 to 1 loop
      dsClockP(i)  <= dsClkP(i)(0);
      dsClockN(i)  <= dsClkN(i)(0);
      for j in 0 to 3 loop
        dsTxP(i)(j) <= idsTxP(i)(j+2);
        dsTxN(i)(j) <= idsTxN(i)(j+2);
        idsRxP (i)(j+2) <= dsRxP(i)(j);
        idsRxN (i)(j+2) <= dsRxN(i)(j);
      end loop;
      for j in 4 to 5 loop
        dsTxP(i)(j) <= idsTxP(i)(j-4);
        dsTxN(i)(j) <= idsTxN(i)(j-4);
        idsRxP (i)(j-4) <= dsRxP(i)(j);
        idsRxN (i)(j-4) <= dsRxN(i)(j);
      end loop;
      for j in 6 to 6 loop
        dsTxP(i)(j) <= idsTxP(i)(j);
        dsTxN(i)(j) <= idsTxN(i)(j);
        idsRxP (i)(j) <= dsRxP(i)(j);
        idsRxN (i)(j) <= dsRxN(i)(j);
      end loop;
    end loop;
  end process;

  
  U_FPGACLK0 : entity work.ClkOutBufDiff
    generic map (
      XIL_DEVICE_G => "ULTRASCALE")
      port map (
        clkIn   => recTimingClk,
        clkOutP => fpgaclk_P(0),
        clkOutN => fpgaclk_N(0));

  U_FPGACLK2 : entity work.ClkOutBufDiff
    generic map (
      XIL_DEVICE_G => "ULTRASCALE")
      port map (
        clkIn   => recTimingClk,
        clkOutP => fpgaclk_P(2),
        clkOutN => fpgaclk_N(2));

  fpgaclk_P(1) <= '0';
  fpgaclk_N(1) <= '1';
  fpgaclk_P(3) <= '0';
  fpgaclk_N(3) <= '1';
  
   regClk <= ref125MHzClk;
   regRst <= ref125MHzRst;

   U_XBAR : entity work.AxiLiteCrossbar
      generic map (
         DEC_ERROR_RESP_G   => AXI_RESP_DECERR_C,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => 2,
         MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
      port map (
         axiClk              => regClk,
         axiClkRst           => regRst,
         sAxiWriteMasters(0) => regWriteMaster,
         sAxiWriteSlaves (0) => regWriteSlave,
         sAxiReadMasters (0) => regReadMaster,
         sAxiReadSlaves  (0) => regReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);      

   U_SyncDbg : entity work.SynchronizerVector
     generic map ( WIDTH_G => dbgChan'length )
     port map ( clk     => recTimingClk,
                dataIn  => dbgChan,
                dataOut => dbgChanS );

   GEN_RINGD : for i in 0 to NDSLinks-1 generate
     U_Sync : entity work.SynchronizerFifo
       generic map ( DATA_WIDTH_G => 19 )
       port map ( wr_clk => dsRxClk(i),
                  din(18)           => dsRxErr  (i),
                  din(17 downto 16) => dsRxDataK(i),
                  din(15 downto  0) => dsRxData (i),
                  rd_clk            => recTimingClk,
                  valid             => ringDataV(i),
                  dout              => ringDataI(i) );
   end generate;
       
   process (recTimingClk) is
     variable iLink     : integer;
   begin
     if rising_edge(recTimingClk) then
       iLink := conv_integer(dbgChanS);
       ringData <= ringDataV(iLink) & ringDataI(iLink);
     end if;
   end process;
   
   AxiLiteRingBuffer_1 : entity work.AxiLiteRingBuffer
     generic map (
       TPD_G            => TPD_G,
       BRAM_EN_G        => true,
       REG_EN_G         => true,
       DATA_WIDTH_G     => 20,
       RAM_ADDR_WIDTH_G => 13)
     port map (
       dataClk                 => recTimingClk,
       dataRst                 => '0',
       dataValid               => '1',
       dataValue               => ringData,
       axilClk                 => regClk,
       axilRst                 => regRst,
       axilReadMaster          => axilReadMasters (1),
       axilReadSlave           => axilReadSlaves  (1),
       axilWriteMaster         => axilWriteMasters(1),
       axilWriteSlave          => axilWriteSlaves (1));

   GEN_PLL : for i in 0 to 1 generate
     U_Pll : entity work.XpmPll
       port map (
         config      => xpmConfig.pll(i),
         status      => pllStatus    (i),
         frqTbl      => frqTbl       (i),
         frqSel      => frqSel       (i),
         bwSel       => bwSel        (i),
         inc         => inc          (i),
         dec         => dec          (i),
         sfOut       => sfOut        (i),
         rate        => rate         (i),
         bypass      => bypass       (i),
         pllRst      => pllRst       (i),
         lol         => lol          (i),
         los         => los          (i) );
   end generate;
     
   U_Application : entity work.XpmApp
      generic map (
         NDsLinks  => NDsLinks,
         NBpLinks  => NBpLinks )
      port map (
         -----------------------
         -- Application Ports --
         -----------------------
         -- -- AMC's DS Ports
         dsLinkStatus    => dsLinkStatus,
         dsRxData        => dsRxData,
         dsRxDataK       => dsRxDataK,
         dsTxData        => dsTxData,
         dsTxDataK       => dsTxDataK,
         dsRxClk         => dsRxClk,
         dsRxRst         => dsRxRst,
         dsRxErr         => dsRxErr,
         --  BP DS Ports
         bpTxData        => bpTxData (0),
         bpTxDataK       => bpTxDataK(0),
         bpStatus        => bpStatus,
         bpRxLinkFull    => bpRxLinkFull,
         ----------------------
         -- Top Level Interface
         ----------------------
         regclk          => regClk,
         update          => regUpdate,
         status          => xpmStatus,
         config          => xpmConfig,
         -- Timing Interface (timingClk domain) 
         timingClk       => recTimingClk,
         timingRst       => recTimingRst,
         timingIn        => recTimingData,
         timingFbClk     => timingPhyClk,
         timingFbRst     => '0',
         timingFb        => timingPhy );

   U_Backplane : entity work.XpmBp
     generic map ( NBpLinks => NBpLinks )
     port map (
      ----------------------
      -- Top Level Interface
      ----------------------
      ref125MHzClk    => ref125MHzClk,
      ref125MHzRst    => ref125MHzRst,
      rxFull          => bpRxLinkFull,
      config          => xpmConfig.bpLink(NBpLinks downto 1),
      status          => bpStatus(NBpLinks downto 1),
      monClk          => bpMonClk,
      --
      timingClk       => recTimingClk,
      timingRst       => recTimingRst,
      timingBus       => recTimingBus,
      ----------------
      -- Core Ports --
      ----------------
      -- Backplane MPS Ports
      bpClkIn         => bpClkIn,
      bpClkOut        => bpClkOut,
      bpBusRxP        => bpBusRxP(NBpLinks downto 1),
      bpBusRxN        => bpBusRxN(NBpLinks downto 1) );

   GEN_BPRX : for i in NBpLinks+1 to 14 generate
     U_RX : IBUFDS
       port map ( I  => bpBusRxP(i),
                  IB => bpBusRxN(i),
                  O  => open );
   end generate;
  
   U_Core : entity work.XpmCore
      generic map (
        BUILD_INFO_G         => BUILD_INFO_G )
      port map (
         ----------------------
         -- Top Level Interface
         ----------------------
         -- AXI-Lite Interface (regClk domain)
         regClk            => regClk,
         regRst            => regRst,
         regReadMaster     => regReadMaster,
         regReadSlave      => regReadSlave,
         regWriteMaster    => regWriteMaster,
         regWriteSlave     => regWriteSlave,
         -- Streaming input (regClk domain)
         ibDebugMaster     => ibDebugMaster,
         ibDebugSlave      => ibDebugSlave,
         -- Timing Interface (timingClk domain)
         timingData        => recTimingData,
         timingBus         => recTimingBus,
         exptBus           => recExptBus,
         timingPhy         => timingPhy,
         -- Reference Clocks and Resets
         timingPhyClk      => timingPhyClk,
         recTimingClk      => recTimingClk,
         recTimingRst      => recTimingRst,
         ref125MHzClk      => ref125MHzClk,
         ref125MHzRst      => ref125MHzRst,
         ref156MHzClk      => ref156MHzClk,
         ref156MHzRst      => ref156MHzRst,
         ref312MHzClk      => open,
         ref312MHzRst      => open,
         ref625MHzClk      => open,
         ref625MHzRst      => open,
         gthFabClk         => open,
         ----------------
         -- Core Ports --
         ----------------   
         -- Common Fabricate Clock
         fabClkP           => fabClkP,
         fabClkN           => fabClkN,
         -- ETH Ports
         ethRxP           => ethRxP,
         ethRxN           => ethRxN,
         ethTxP           => ethTxP,
         ethTxN           => ethTxN,
         ethClkP          => ethClkP,
         ethClkN          => ethClkN,
         -- LCLS Timing Ports
         usRxP             => usRxP,
         usRxN             => usRxN,
         usTxP             => usTxP,
         usTxN             => usTxN,
         usRefClkP         => usClkP,  -- GEN0 REF
         usRefClkN         => usClkN,
         timingRecClkOutP  => timingRecClkOutP,  -- to AMC PLL
         timingRecClkOutN  => timingRecClkOutN,
         --
         timingRefClkOut   => timingRefClk,
--         timingClkSel      => timingClkSel,
         timingClkScl      => timingClkScl,
         timingClkSda      => timingClkSda,
         -- Crossbar Ports
         xBarSin           => xBarSin,
         xBarSout          => xBarSout,
         xBarConfig        => xBarConfig,
         xBarLoad          => xBarLoad,
         -- IPMC Ports
         ipmcScl           => ipmcScl,
         ipmcSda           => ipmcSda,
         -- AMC SMBus Ports
         hsrScl            => hsrScl,
         hsrSda            => hsrSda,
         -- Configuration PROM Ports
         calScl            => calScl,
         calSda            => calSda,
         -- DDR3L SO-DIMM Ports
         ddrClkP           => ddrClkP,
         ddrClkN           => ddrClkN,
         ddrDqsP           => ddrDqsP,
         ddrDqsN           => ddrDqsN,
         ddrDm             => ddrDm,
         ddrDq             => ddrDq,
         ddrA              => ddrA,
         ddrBa             => ddrBa,
         ddrCsL            => ddrCsL,
         ddrOdt            => ddrOdt,
         ddrCke            => ddrCke,
         ddrCkP            => ddrCkP,
         ddrCkN            => ddrCkN,
         ddrWeL            => ddrWeL,
         ddrRasL           => ddrRasL,
         ddrCasL           => ddrCasL,
         ddrRstL           => ddrRstL,
         ddrPwrEnL         => ddrPwrEnL,
         ddrPg             => ddrPg,
         ddrAlertL         => ddrAlertL,
         ddrScl            => ddrScl,
         ddrSda            => ddrSda,
         -- SYSMON Ports
         vPIn              => vPIn,
         vNIn              => vNIn);

  U_Reg : entity work.XpmReg
    port map ( axilClk         => regClk,
               axilRst         => regRst,
               axilUpdate      => regUpdate,
               axilReadMaster  => axilReadMasters (0),
               axilReadSlave   => axilReadSlaves  (0),
               axilWriteMaster => axilWriteMasters(0),
               axilWriteSlave  => axilWriteSlaves (0),
               -- Streaming input (regClk domain)
               ibDebugMaster   => ibDebugMaster,
               ibDebugSlave    => ibDebugSlave,
               staClk          => recTimingClk,
               pllStatus       => pllStatus,
               status          => xpmStatus,
               monClk(0)       => bpMonClk,
               monClk(1)       => timingPhyClk,
               monClk(2)       => recTimingClk,
               monClk(3)       => bpMonClk,
               config          => xpmConfig,
               dbgChan         => dbgChan );

  GEN_AMC_MGT : for i in 0 to 1 generate
    U_Rcvr : entity work.XpmGthUltrascaleWrapper
      generic map ( GTGCLKRX   => false,
                    NLINKS_G   => 7,
                    USE_IBUFDS => true)
      port map ( stableClk       => ref156MHzClk,
                 gtTxP           => idsTxP   (i),
                 gtTxN           => idsTxN   (i),
                 gtRxP           => idsRxP   (i),
                 gtRxN           => idsRxN   (i),
                 devClkP         => dsClockP (i),
                 devClkN         => dsClockN (i),
                 devClkOut       => dsClkBuf (i),
                 txData          => dsTxData  (7*i+6 downto 7*i),
                 txDataK         => dsTxDataK (7*i+6 downto 7*i),
                 rxData          => dsRxData  (7*i+6 downto 7*i),
                 rxDataK         => dsRxDataK (7*i+6 downto 7*i),
                 rxClk           => dsRxClk   (7*i+6 downto 7*i),
                 rxRst           => dsRxRst   (7*i+6 downto 7*i),
                 rxErr           => dsRxErr   (7*i+6 downto 7*i),
                 txClk           => open,
                 txClkIn         => recTimingClk,
                 config          => xpmConfig.dsLink(7*i+6 downto 7*i),
                 status          => dsLinkStatus    (7*i+6 downto 7*i) );
  end generate;

  U_BpTx : entity work.XpmGthUltrascaleWrapper
    generic map ( GTGCLKRX   => false,
                  NLINKS_G   => 1,
                  USE_IBUFDS => false )
    port map ( stableClk       => ref156MHzClk,
               gtTxP       (0) => timingTxP,
               gtTxN       (0) => timingTxN,
               gtRxP       (0) => timingRxP,  -- not used
               gtRxN       (0) => timingRxN,
               devClkIn        => dsClkBuf(0),
               txData      (0) => bpTxData (0),
               txDataK     (0) => bpTxDataK(0),
               rxData      (0) => open,
               rxDataK     (0) => open,
               rxClk       (0) => open,
               rxRst       (0) => open,
               rxErr       (0) => open,
               txClk           => open,
               txClkIn         => recTimingClk,
               config      (0) => xpmConfig.bpLink(0),
               status      (0) => bpTxLinkStatus );

  bpStatus(0).linkUp  <= bpTxLinkStatus.txReady;
  bpStatus(0).ibRecv  <= (others=>'0');
    
end top_level;