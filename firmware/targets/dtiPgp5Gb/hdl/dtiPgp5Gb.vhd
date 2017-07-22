-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : dti.vhd
-- Author     : Matt Weaver
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-12-14
-- Last update: 2017-07-21
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.AxiLitePkg.all;
use work.TimingPkg.all;
use work.XpmPkg.all;
use work.DtiPkg.all;
use work.AmcCarrierPkg.all;

library unisim;
use unisim.vcomponents.all;

entity dtiPgp5Gb is
  generic (
    TPD_G         : time    := 1 ns;
    BUILD_INFO_G  : BuildInfoType);
  port (
    -----------------------
    -- Application Ports --
    -----------------------
    -- -- AMC's HS Ports
    amcClkP      : in    Slv1Array(1 downto 0);
    amcClkN      : in    Slv1Array(1 downto 0);
    amcRxP       : in    Slv7Array(1 downto 0);
    amcRxN       : in    Slv7Array(1 downto 0);
    amcTxP       : out   Slv7Array(1 downto 0);
    amcTxN       : out   Slv7Array(1 downto 0);
    --  AMC SMBus Ports
    hsrScl       : inout Slv3Array(1 downto 0);
    hsrSda       : inout Slv3Array(1 downto 0);
    ------------------
    -- Bp messaging --
    ------------------
    bpRxP            : in    sl;
    bpRxN            : in    sl;
    bpTxP            : out   sl;
    bpTxN            : out   sl;
    bpClkIn          : in    sl;
    bpClkOut         : out   sl;
    ----------------
    -- Core Ports --
    ----------------   
    -- Common Fabricate Clock
    fabClkP          : in    sl;
    fabClkN          : in    sl;
    -- ETH Ports
    ethRxP           : in    slv(3 downto 0);
    ethRxN           : in    slv(3 downto 0);
    ethTxP           : out   slv(3 downto 0);
    ethTxN           : out   slv(3 downto 0);
    ethClkP          : in    sl;
    ethClkN          : in    sl;
    -- LCLS Timing Ports
    timingRxP        : in    sl;
    timingRxN        : in    sl;
    timingTxP        : out   sl;
    timingTxN        : out   sl;
    timingRefClkInP  : in    sl;
    timingRefClkInN  : in    sl;
    timingRecClkOutP : out   sl;
    timingRecClkOutN : out   sl;
    timingClkSel     : out   sl;
    timingClkScl     : inout sl;
    timingClkSda     : inout sl;
    fpgaclk_P        : out   sl;
    fpgaclk_N        : out   sl;
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
end dtiPgp5Gb;

architecture top_level of dtiPgp5Gb is

  -- AXI-Lite Interface (appClk domain)
  signal regClk         : sl;
  signal regRst         : sl;
  signal regUpdate      : sl;
  signal regClear       : sl;
  signal regReadMaster  : AxiLiteReadMasterType;
  signal regReadSlave   : AxiLiteReadSlaveType;
  signal regWriteMaster : AxiLiteWriteMasterType;
  signal regWriteSlave  : AxiLiteWriteSlaveType;

  -- Timing Interface (timingClk domain)
  signal recTimingData  : TimingRxType;
  signal recTimingBus   : TimingBusType;
  signal recExptBus     : ExptBusType;
  
  -- Reference Clocks and Resets
  signal timingRefClk : sl;
  signal recTimingClk : sl;
  signal recTimingRst : sl;
  signal ref62MHzClk  : sl;
  signal ref62MHzRst  : sl;
  signal ref125MHzClk : sl;
  signal ref125MHzRst : sl;
  signal ref156MHzClk : sl;
  signal ref156MHzRst : sl;

  signal config : DtiConfigType;
  signal status : DtiStatusType;
  
  signal obDsMasters : AxiStreamMasterArray(MaxDsLinks-1 downto 0);
  signal obDsSlaves  : AxiStreamSlaveArray (MaxDsLinks-1 downto 0);

  signal usConfig     : DtiUsLinkConfigArray(MaxUsLinks-1 downto 0) := (others=>DTI_US_LINK_CONFIG_INIT_C);
  signal usStatus     : DtiUsLinkStatusArray(MaxUsLinks-1 downto 0);
  signal usRemLinkID  : Slv8Array           (MaxUsLinks-1 downto 0);
  signal usIbMaster   : AxiStreamMasterArray(MaxUsLinks-1 downto 0);
  signal usIbSlave    : AxiStreamSlaveArray (MaxUsLinks-1 downto 0);
  signal usIbClk      : slv                 (MaxUsLinks-1 downto 0);
  signal usLinkUp     : slv                 (MaxUsLinks-1 downto 0);
  signal usRxErrs     : Slv32Array          (MaxUsLinks-1 downto 0);
  signal usObMaster   : AxiStreamMasterArray(MaxUsLinks-1 downto 0);
  signal usObSlave    : AxiStreamSlaveArray (MaxUsLinks-1 downto 0);
  signal usObClk      : slv                 (MaxUsLinks-1 downto 0);
  signal usFull       : Slv16Array          (MaxUsLinks-1 downto 0);
  signal usFullIn     : slv                 (MaxUsLinks-1 downto 0);
  signal usObTrig     : XpmPartitionDataArray(MaxUsLinks-1 downto 0);
  signal usObTrigV    : slv                  (MaxUsLinks-1 downto 0);

  signal fullOut      : slv(15 downto 0);
  
  signal dsStatus     : DtiDsLinkStatusArray(MaxDsLinks-1 downto 0);
  signal dsRemLinkID  : Slv8Array           (MaxDsLinks-1 downto 0);
  
  signal ctlRxM, ctlTxM : AxiStreamMasterArray(MaxUsLinks-1 downto 0) := (others=>AXI_STREAM_MASTER_INIT_C);
  signal ctlRxS, ctlTxS : AxiStreamSlaveArray (MaxUsLinks-1 downto 0) := (others=>AXI_STREAM_SLAVE_INIT_C);
  type UsMasterArray is array (natural range<>) of AxiStreamMasterArray(MaxDsLinks-1 downto 0);
  signal usEvtMasters : UsMasterArray(MaxUsLinks-1 downto 0)        := (others=>(others=>AXI_STREAM_MASTER_INIT_C));
  type UsSlaveArray  is array (natural range<>) of AxiStreamSlaveArray (MaxDsLinks-1 downto 0);
  signal usEvtSlaves  : UsSlaveArray (MaxUsLinks-1 downto 0) := (others=>(others=>AXI_STREAM_SLAVE_FORCE_C));
  
  type DsMasterArray is array (natural range<>) of AxiStreamMasterArray(MaxUsLinks-1 downto 0);
  signal dsEvtMasters : DsMasterArray(MaxDsLinks-1 downto 0)        := (others=>(others=>AXI_STREAM_MASTER_INIT_C));
  type DsSlaveArray  is array (natural range<>) of AxiStreamSlaveArray (MaxUsLinks-1 downto 0);
  signal dsEvtSlaves  : DsSlaveArray (MaxDsLinks-1 downto 0) := (others=>(others=>AXI_STREAM_SLAVE_FORCE_C));
  signal dsObMaster   : AxiStreamMasterArray(MaxDsLinks-1 downto 0);
  signal dsObSlave    : AxiStreamSlaveArray (MaxDsLinks-1 downto 0);
  signal dsObClk      : slv                 (MaxDsLinks-1 downto 0);
  
  signal dsFull     : slv(MaxDsLinks-1 downto 0) := (others=>'0');

  signal dsLinkUp     : slv(MaxDsLinks-1 downto 0);
  signal dsRxErr      : slv(MaxDsLinks-1 downto 0);
  signal dsFullIn     : slv(MaxDsLinks-1 downto 0);

  signal amcClockP   : slv         (1 downto 0);
  signal amcClockN   : slv         (1 downto 0);
  signal amcCoreClk  : slv         (1 downto 0);
  signal amcCoreRst  : slv         (1 downto 0);
  signal amcRefClk   : slv         (1 downto 0);
  signal coreClk     : slv        (13 downto 0);
  signal coreRst     : slv        (13 downto 0);
  signal gtRefClk    : slv        (13 downto 0);
  
  signal iquad            : QuadArray(13 downto 0);
  signal iamcRst          : slv(13 downto 0) := (others=>'0');
  signal iamcRxP          : slv(13 downto 0);
  signal iamcRxN          : slv(13 downto 0);
  signal iamcTxP          : slv(13 downto 0);
  signal iamcTxN          : slv(13 downto 0);

--  constant NPGPAXI_C : integer := 7;
  constant NPGPAXI_C : integer := 1;
  constant NMASTERS_C : integer := 2*NPGPAXI_C+2;
  
  signal mAxilReadMasters  : AxiLiteReadMasterArray (NMASTERS_C-1 downto 0);
  signal mAxilReadSlaves   : AxiLiteReadSlaveArray  (NMASTERS_C-1 downto 0);
  signal mAxilWriteMasters : AxiLiteWriteMasterArray(NMASTERS_C-1 downto 0);
  signal mAxilWriteSlaves  : AxiLiteWriteSlaveArray (NMASTERS_C-1 downto 0);

  function crossBarConfig return AxiLiteCrossbarMasterConfigArray is
    variable ret : AxiLiteCrossbarMasterConfigArray(NMASTERS_C-1 downto 0);
  begin
    ret(0).baseAddr := x"80000000";
    ret(0).addrBits := 24;
    ret(0).connectivity := x"FFFF";
    for i in 0 to 2*NPGPAXI_C-1 loop
      ret(i+1).baseAddr := x"90000000"+toSlv(i*256,32);
      ret(i+1).addrBits := 8;
      ret(i+1).connectivity := x"FFFF";
    end loop;
    ret(2*NPGPAXI_C+1).baseAddr := x"A0000000";
    ret(2*NPGPAXI_C+1).addrBits := 24;
    ret(2*NPGPAXI_C+1).connectivity := x"FFFF";
    return ret;
  end function crossBarConfig;
  
  constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NMASTERS_C-1 downto 0) := crossBarConfig;

  signal dsAxilReadMasters  : AxiLiteReadMasterArray (MaxDsLinks-1 downto 0) := (others=>AXI_LITE_READ_MASTER_INIT_C);
  signal dsAxilReadSlaves   : AxiLiteReadSlaveArray  (MaxDsLinks-1 downto 0);
  signal dsAxilWriteMasters : AxiLiteWriteMasterArray(MaxDsLinks-1 downto 0) := (others=>AXI_LITE_WRITE_MASTER_INIT_C);
  signal dsAxilWriteSlaves  : AxiLiteWriteSlaveArray (MaxDsLinks-1 downto 0);

  signal usAxilReadMasters  : AxiLiteReadMasterArray (MaxUsLinks-1 downto 0) := (others=>AXI_LITE_READ_MASTER_INIT_C);
  signal usAxilReadSlaves   : AxiLiteReadSlaveArray  (MaxUsLinks-1 downto 0);
  signal usAxilWriteMasters : AxiLiteWriteMasterArray(MaxUsLinks-1 downto 0) := (others=>AXI_LITE_WRITE_MASTER_INIT_C);
  signal usAxilWriteSlaves  : AxiLiteWriteSlaveArray (MaxUsLinks-1 downto 0);
  
  signal bpMonClk : slv( 1 downto 0);

  signal ringData : slv(19 downto 0);
begin

  --
  --  The AMC SFP channels are reordered - the mapping to MGT quads is non-trivial
  --    amcTx/Rx indexed by MGT
  --    iamcTx/Rx indexed by SFP
  --
  reorder_p : process (amcClkP,amcClkN,amcRxP,amcRxN,iamcTxP,iamcTxN,
                       amcCoreClk,amcCoreRst,amcRefClk) is
  begin
    for i in 0 to 1 loop
      amcClockP(i)  <= amcClkP(i)(0);
      amcClockN(i)  <= amcClkN(i)(0);
      for j in 0 to 3 loop
        amcTxP(i)(j) <= iamcTxP(i*7+j+2);
        amcTxN(i)(j) <= iamcTxN(i*7+j+2);
        iamcRxP (i*7+j+2) <= amcRxP(i)(j);
        iamcRxN (i*7+j+2) <= amcRxN(i)(j);
        coreClk (i*7+j+2) <= amcCoreClk(i);
        coreRst (i*7+j+2) <= amcCoreRst(i);
        gtRefClk(i*7+j+2) <= amcRefClk(i);
      end loop;
      for j in 4 to 5 loop
        amcTxP(i)(j) <= iamcTxP(i*7+j-4);
        amcTxN(i)(j) <= iamcTxN(i*7+j-4);
        iamcRxP (i*7+j-4) <= amcRxP(i)(j);
        iamcRxN (i*7+j-4) <= amcRxN(i)(j);
        coreClk (i*7+j-4) <= amcCoreClk(i);
        coreRst (i*7+j-4) <= amcCoreRst(i);
        gtRefClk(i*7+j-4) <= amcRefClk(i);
      end loop;
      for j in 6 to 6 loop
        amcTxP(i)(j) <= iamcTxP(i*7+j);
        amcTxN(i)(j) <= iamcTxN(i*7+j);
        iamcRxP (i*7+j) <= amcRxP(i)(j);
        iamcRxN (i*7+j) <= amcRxN(i)(j);
        coreClk (i*7+j) <= amcCoreClk(i);
        coreRst (i*7+j) <= amcCoreRst(i);
        gtRefClk(i*7+j) <= amcRefClk(i);
      end loop;
    end loop;
  end process;

  --
  --  Feed the AMC PLL for driving the Timing synchronous AMC devclk(3:2)
  --
  U_FPGACLK : entity work.ClkOutBufDiff
    generic map (
      XIL_DEVICE_G => "ULTRASCALE")
    port map (
      clkIn   => recTimingClk,
      clkOutP => fpgaclk_P,
      clkOutN => fpgaclk_N);

  ringData(15 downto  0) <= recTimingData.data;
  ringData(17 downto 16) <= recTimingData.dataK;
  ringData(19 downto 18) <= recTimingData.dspErr or recTimingData.decErr;
  
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
       axilReadMaster          => mAxilReadMasters (NMASTERS_C-1),
       axilReadSlave           => mAxilReadSlaves  (NMASTERS_C-1),
       axilWriteMaster         => mAxilWriteMasters(NMASTERS_C-1),
       axilWriteSlave          => mAxilWriteSlaves (NMASTERS_C-1));

  U_Core : entity work.DtiCore
    generic map (
      BUILD_INFO_G        => BUILD_INFO_G,
      NAPP_LINKS_G        => MaxUsLinks )
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
      ibAppMasters      => ctlRxM,
      ibAppSlaves       => ctlRxS,
      obAppMasters      => ctlTxM,
      obAppSlaves       => ctlTxS,
      -- Timing Interface (timingClk domain)
      timingData        => recTimingData,
      timingBus         => recTimingBus,
      exptBus           => recExptBus,
      fullOut           => fullOut,
      -- Reference Clocks and Resets
      recTimingClk      => recTimingClk,
      recTimingRst      => recTimingRst,
      ref62MHzClk       => ref62MHzClk,
      ref62MHzRst       => ref62MHzRst,
      ref125MHzClk      => ref125MHzClk,
      ref125MHzRst      => ref125MHzRst,
      ref156MHzClk      => ref156MHzClk,
      ref156MHzRst      => ref156MHzRst,
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
      timingRxP         => timingRxP,
      timingRxN         => timingRxN,
      timingTxP         => timingTxP,
      timingTxN         => timingTxN,
      timingRefClkInP   => timingRefClkInP,
      timingRefClkInN   => timingRefClkInN,
      timingRefClkOut   => timingRefClk,
      timingRecClkOutP  => timingRecClkOutP,
      timingRecClkOutN  => timingRecClkOutN,
      timingClkSel      => timingClkSel,
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
      -- Configuration PROM Ports
      calScl            => calScl,
      calSda            => calSda,
      -- AMC SMBus Ports
      hsrScl            => hsrScl,
      hsrSda            => hsrSda,
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

  U_Backplane : entity work.DtiBp
    port map ( ref125MHzClk => ref125MHzClk,
               ref125MHzRst => ref125MHzRst,
               rxFull(0)    => fullOut,
               bpPeriod     => config.bpPeriod,
               status       => status.bpLink,
               monClk       => bpMonClk,
               --
               timingClk    => recTimingClk,
               timingRst    => recTimingRst,
               timingBus    => recTimingBus,
               ----------------
               -- Core Ports --
               ----------------
               -- Backplane Ports
               bpClkIn      => bpClkIn,
               bpClkOut     => bpClkOut,
               bpBusRxP     => bpRxP,
               bpBusRxN     => bpRxN,
               bpBusTxP     => bpTxP,
               bpBusTxN     => bpTxN );

  --------------------------
  -- AXI-Lite: Crossbar Core for Application registers
  --------------------------
  U_XBAR : entity work.AxiLiteCrossbar
    generic map (
      TPD_G              => TPD_G,
      DEC_ERROR_RESP_G   => AXI_RESP_DECERR_C,
      NUM_SLAVE_SLOTS_G  => 1,
      NUM_MASTER_SLOTS_G => AXI_CROSSBAR_MASTERS_CONFIG_C'length,
      MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
    port map (
      axiClk           => regClk,
      axiClkRst        => regRst,
      sAxiWriteMasters(0) => regWriteMaster,
      sAxiWriteSlaves (0) => regWriteSlave,
      sAxiReadMasters (0) => regReadMaster,
      sAxiReadSlaves  (0) => regReadSlave,
      mAxiWriteMasters => mAxilWriteMasters,
      mAxiWriteSlaves  => mAxilWriteSlaves,
      mAxiReadMasters  => mAxilReadMasters,
      mAxiReadSlaves   => mAxilReadSlaves);

  U_Reg : entity work.DtiReg
    port map ( axilClk         => regClk,
               axilRst         => regRst,
               axilUpdate      => regUpdate,
               axilClear       => regClear,
               axilReadMaster  => mAxilReadMasters (0),
               axilReadSlave   => mAxilReadSlaves  (0),
               axilWriteMaster => mAxilWriteMasters(0),
               axilWriteSlave  => mAxilWriteSlaves (0),
               --      
               status          => status,
               config          => config,
               monclk(0)       => amcCoreClk(0),
               monclk(1)       => usIbClk(0),
               monclk(2)       => bpMonClk(0),
               monclk(3)       => bpMonClk(1) );

  U_PLL : entity work.DtiCPllArray
    port map ( amcClkP  => amcClockP,
               amcClkN  => amcClockN,
               coreClk  => amcCoreClk,
               gtRefClk => amcRefClk );

  amcCoreRst <= (others=>'0');
  
  --
  --  Translate AMC I/O into AxiStream
  --
  --    Register r/w commands are buffered and streamed forward
  --    Register read replies are buffered and streamed to CPU
  --    Unsolicited data is timestamped and streamed to downstream link
  --    Downstream inputs are translated to full status

  GEN_US_PGP : for i in 0 to MaxUsLinks-1 generate
    U_Core : entity work.DtiUsCore
      generic map ( DEBUG_G     => ite(i>0, false, true) )
      port map ( sysClk        => regClk,
                 sysRst        => regRst,
                 clear         => regClear,
                 update        => regUpdate,
                 config        => config.usLink(i),
                 status        => status.usLink(i),
                 remLinkID     => usRemLinkID  (i),
                 fullOut       => usFull       (i),
                 --
                 ctlClk        => regClk,
                 ctlRst        => regRst,
                 ctlRxMaster   => ctlRxM (i),
                 ctlRxSlave    => ctlRxS (i),
                 ctlTxMaster   => ctlTxM (i),
                 ctlTxSlave    => ctlTxS (i),
                 --
                 timingClk     => recTimingClk,  -- outbound data (to sensor)
                 timingRst     => recTimingRst,
                 timingBus     => recTimingBus,
                 exptBus       => recExptBus  ,
                 --
                 eventClk      => ref156MHzClk,      -- inbound data (from sensor)
                 eventRst      => ref156MHzRst,
                 eventMasters  => usEvtMasters(i),
                 eventSlaves   => usEvtSlaves (i),
                 dsFull        => dsFull,
                 --
                 ibClk         => usIbClk   (i),
                 ibLinkUp      => usLinkUp  (i),
                 ibErrs        => usRxErrs  (i),
                 ibFull        => usFullIn  (i),
                 ibMaster      => usIbMaster(i),
                 ibSlave       => usIbSlave (i),
                 --
                 obClk         => usObClk   (i),
                 obTrig        => usObTrig  (i),
                 obTrigValid   => usObTrigV (i),
                 obMaster      => usObMaster(i),
                 obSlave       => usObSlave (i) );

    U_App : entity work.DtiUsPgp5Gb
      generic map ( ID_G           => x"0" & toSlv(i,4),
                    DEBUG_G        => ite(i>0, false, true),
                    INCLUDE_AXIL_G => ite(i<NPGPAXI_C, true, false) )
      port map ( coreClk  => coreClk(i),
                 coreRst  => coreRst(i),
                 gtRefClk => gtRefClk(i),
                 remLinkID => usRemLinkID(i),
                 status   => status.usApp(i),
                 amcRxP   => iamcRxP(i),
                 amcRxN   => iamcRxN(i),
                 amcTxP   => iamcTxP(i),
                 amcTxN   => iamcTxN(i),
                 fifoRst  => regClear,
                 --
                 axilClk          => regClk,
                 axilRst          => regRst,
                 axilReadMaster   => usAxilReadMasters (i),
                 axilReadSlave    => usAxilReadSlaves  (i),
                 axilWriteMaster  => usAxilWriteMasters(i),
                 axilWriteSlave   => usAxilWriteSlaves (i),
                 --
                 ibClk    => usIbClk   (i),
                 ibRst    => regRst,
                 ibMaster => usIbMaster(i),
                 ibSlave  => usIbSlave (i),
                 linkUp   => usLinkUp  (i),
                 rxErrs   => usRxErrs  (i),
                 txFull   => usFullIn  (i),
                 --
                 obClk       => usObClk   (i),
                 obRst       => recTimingRst,
                 obMaster    => usObMaster(i),
                 obSlave     => usObSlave (i),
                 --  Timing clock domain
                 timingClk   => recTimingClk,
                 timingRst   => recTimingRst,
                 obTrig      => usObTrig  (i),
                 obTrigValid => usObTrigV (i) );
    GEN_AXIL : if i < NPGPAXI_C generate
      usAxilReadMasters (i)   <= mAxilReadMasters (i+1);
      usAxilWriteMasters(i)   <= mAxilWriteMasters(i+1);
      mAxilReadSlaves   (i+1) <= usAxilReadSlaves (i);
      mAxilWriteSlaves  (i+1) <= usAxilWriteSlaves (i);
    end generate;
  end generate;
  
  GEN_DS : for i in 0 to MaxDsLinks-1 generate
    U_Core : entity work.DtiDsCore
      generic map ( DEBUG_G => ite(i>5, true, false) )
      port map ( clear          => regClear,
                 update         => regUpdate,
                 remLinkID      => dsRemLinkID  (i),
                 status         => status.dsLink(i),
                 --
                 eventClk       => ref156MHzClk,
                 eventRst       => ref156MHzRst,
                 eventMasters   => dsEvtMasters(i),
                 eventSlaves    => dsEvtSlaves (i),
                 fullOut        => dsFull      (i),
                 --
                 linkUp         => dsLinkUp  (i),
                 rxErr          => dsRxErr   (i),
                 fullIn         => dsFullIn  (i),
                 --
                 obClk          => dsObClk   (i),
                 obMaster       => dsObMaster(i),
                 obSlave        => dsObSlave (i) );
    
    U_App : entity work.DtiDsPgp5Gb
      generic map ( ID_G           => x"1" & toSlv(i,4),
                    INCLUDE_AXIL_G => ite(i<NPGPAXI_C, true, false) )
      port map ( coreClk       => coreClk (13-i),
                 coreRst       => coreRst (13-i),
                 gtRefClk      => gtRefClk(13-i),
                 amcRxP        => iamcRxP (13-i),
                 amcRxN        => iamcRxN (13-i),
                 amcTxP        => iamcTxP (13-i),
                 amcTxN        => iamcTxN (13-i),
                 fifoRst       => regClear,
                 --
                 axilClk          => regClk,
                 axilRst          => regRst,
                 axilReadMaster   => dsAxilReadMasters (i),
                 axilReadSlave    => dsAxilReadSlaves  (i),
                 axilWriteMaster  => dsAxilWriteMasters(i),
                 axilWriteSlave   => dsAxilWriteSlaves (i),
                 --
                 ibRst         => '0',
                 --
                 linkUp        => dsLinkUp    (i),
                 remLinkID     => dsRemLinkID (i),
                 rxErr         => dsRxErr     (i),
                 full          => dsFullIn    (i),
                 obClk         => dsObClk     (i),
                 obMaster      => dsObMaster  (i),
                 obSlave       => dsObSlave   (i));

    GEN_AXIL : if i < NPGPAXI_C generate
      dsAxilReadMasters (i)   <= mAxilReadMasters (i+NPGPAXI_C+1);
      dsAxilWriteMasters(i)   <= mAxilWriteMasters(i+NPGPAXI_C+1);
      mAxilReadSlaves   (i+NPGPAXI_C+1) <= dsAxilReadSlaves (i);
      mAxilWriteSlaves  (i+NPGPAXI_C+1) <= dsAxilWriteSlaves(i);
    end generate;

    GEN_USDS : for j in 0 to MaxUsLinks-1 generate
      usEvtSlaves (j)(i) <= dsEvtSlaves (i)(j);
      dsEvtMasters(i)(j) <= usEvtMasters(j)(i);
    end generate;

  end generate;


  process ( usFull ) is
    variable v : slv(15 downto 0);
  begin
    v := (others=>'0');
    for i in 0 to 15 loop
      for j in 0 to MaxUsLinks-1 loop
        v(i) := v(i) or usFull(j)(i);
      end loop;
    end loop;
    fullOut <= v;
  end process;
  
end top_level;

