-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : dti.vhd
-- Author     : Matt Weaver
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-12-14
-- Last update: 2018-08-19
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
use work.TimingExtnPkg.all;
use work.TimingPkg.all;
use work.XpmPkg.all;
use work.EventPkg.all;
use work.DtiPkg.all;
use work.AmcCarrierPkg.all;

library unisim;
use unisim.vcomponents.all;

entity dtiPgp3 is
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
    frqTbl       : inout slv      (1 downto 0);
    frqSel       : inout Slv4Array(1 downto 0);
    bwSel        : inout Slv2Array(1 downto 0);
    inc          : out   slv      (1 downto 0);
    dec          : out   slv      (1 downto 0);
    sfOut        : inout Slv2Array(1 downto 0);
    rate         : inout Slv2Array(1 downto 0);
    bypass       : out   slv      (1 downto 0);
    pllRst       : out   slv      (1 downto 0);
    lol          : in    slv      (1 downto 0);
    los          : in    slv      (1 downto 0);
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
    --ddrClkP          : in    sl;
    --ddrClkN          : in    sl;
    --ddrDm            : out   slv(7 downto 0);
    --ddrDqsP          : inout slv(7 downto 0);
    --ddrDqsN          : inout slv(7 downto 0);
    --ddrDq            : inout slv(63 downto 0);
    --ddrA             : out   slv(15 downto 0);
    --ddrBa            : out   slv(2 downto 0);
    --ddrCsL           : out   slv(1 downto 0);
    --ddrOdt           : out   slv(1 downto 0);
    --ddrCke           : out   slv(1 downto 0);
    --ddrCkP           : out   slv(1 downto 0);
    --ddrCkN           : out   slv(1 downto 0);
    --ddrWeL           : out   sl;
    --ddrRasL          : out   sl;
    --ddrCasL          : out   sl;
    --ddrRstL          : out   sl;
    --ddrAlertL        : in    sl;
    --ddrPg            : in    sl;
    --ddrPwrEnL        : out   sl;
    ddrScl           : inout sl;
    ddrSda           : inout sl;
    -- SYSMON Ports
    vPIn             : in    sl;
    vNIn             : in    sl);
end dtiPgp3;

architecture top_level of dtiPgp3 is

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
  signal recTimingHdr   : TimingHeaderType;
  signal recExptBus     : ExptBusType;
  signal timingHdr      : TimingHeaderType; -- prompt
  signal triggerBus     : ExptBusType;      -- prompt
  
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
  signal usRemLinkID  : Slv32Array          (MaxUsLinks-1 downto 0);
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
  signal usMonClk     : slv                 (MaxUsLinks-1 downto 0);
  signal usObTrig     : XpmPartitionDataArray(MaxUsLinks-1 downto 0);
  signal usObTrigV    : slv                  (MaxUsLinks-1 downto 0);

  signal fullOut      : slv(15 downto 0);
  
  signal dsStatus     : DtiDsLinkStatusArray(MaxDsLinks-1 downto 0);
  signal dsRemLinkID  : Slv32Array          (MaxDsLinks-1 downto 0);
  signal dsMonClk     : slv                 (MaxDsLinks-1 downto 0);
  
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

  signal dsLinkUp     : slv       (MaxDsLinks-1 downto 0);
  signal dsRxErrs     : Slv32Array(MaxDsLinks-1 downto 0);
  signal dsFullIn     : slv       (MaxDsLinks-1 downto 0);

  signal iquad            : QuadArray(13 downto 0);
  signal iqpllrst         : Slv2Array(13 downto 0);
  signal iamcRxP          : slv(13 downto 0);
  signal iamcRxN          : slv(13 downto 0);
  signal iamcTxP          : slv(13 downto 0);
  signal iamcTxN          : slv(13 downto 0);

--  constant NPGPAXI_C : integer := 7;
--  constant NPGPAXI_C : integer := 1;
  constant NPGPAXI_C : integer := 0;
  constant NMASTERS_C : integer := 2*NPGPAXI_C+2+MaxUsLinks;
  
  signal mAxilReadMasters  : AxiLiteReadMasterArray (NMASTERS_C-1 downto 0);
  signal mAxilReadSlaves   : AxiLiteReadSlaveArray  (NMASTERS_C-1 downto 0);
  signal mAxilWriteMasters : AxiLiteWriteMasterArray(NMASTERS_C-1 downto 0);
  signal mAxilWriteSlaves  : AxiLiteWriteSlaveArray (NMASTERS_C-1 downto 0);

  function crossBarConfig return AxiLiteCrossbarMasterConfigArray is
    variable ret : AxiLiteCrossbarMasterConfigArray(NMASTERS_C-1 downto 0);
    variable i   : integer;
  begin
    ret(0).baseAddr := x"80000000";  -- DtiReg
    ret(0).addrBits := 24;
    ret(0).connectivity := x"FFFF";
    if NPGPAXI_C > 0 then
      for i in 0 to 2*NPGPAXI_C-1 loop
        ret(i+1).baseAddr := x"90000000"+toSlv(i*256,32);
        ret(i+1).addrBits := 8;
        ret(i+1).connectivity := x"FFFF";
      end loop;
    end if;
    i := 2*NPGPAXI_C+1; 
    ret(i).baseAddr := x"A0000000";   -- AxilRingBuffer
    ret(i).addrBits := 24;
    ret(i).connectivity := x"FFFF";
    for j in 0 to MaxUsLinks-1 loop
      i := i+1;
--      ret(i).baseAddr := x"B0000000"+toSlv(j*2048,32);  -- DtiUsPgp3
--      ret(i).addrBits := 11;
      ret(i).baseAddr := x"B0000000"+toSlv(j*16*1024,32);  -- DtiUsPgp3
      ret(i).addrBits := 14;
      ret(i).connectivity := x"FFFF";
    end loop;
    return ret;
  end function crossBarConfig;
  
  constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NMASTERS_C-1 downto 0) := crossBarConfig;

  constant US_AXIL_BASE_ADDR_C : Slv32Array(MaxUsLinks-1 downto 0) := ( toSlv(0,32), toSlv(0,32), toSlv(0,32),
                                                                        x"B000C000", x"B0008000", x"B0004000", x"B0000000" );
  constant DS_AXIL_BASE_ADDR_C : Slv32Array(MaxDsLinks-1 downto 0) := ( toSlv(0,32), toSlv(0,32), toSlv(0,32), toSlv(0,32),
                                                                        x"B0018000", x"B0014000", x"B0010000" );
  
  signal usAxilReadMasters  : AxiLiteReadMasterArray (MaxUsLinks-1 downto 0) := (others=>AXI_LITE_READ_MASTER_INIT_C);
  signal usAxilReadSlaves   : AxiLiteReadSlaveArray  (MaxUsLinks-1 downto 0);
  signal usAxilWriteMasters : AxiLiteWriteMasterArray(MaxUsLinks-1 downto 0) := (others=>AXI_LITE_WRITE_MASTER_INIT_C);
  signal usAxilWriteSlaves  : AxiLiteWriteSlaveArray (MaxUsLinks-1 downto 0);

  signal dsAxilReadMasters  : AxiLiteReadMasterArray (MaxDsLinks-1 downto 0) := (others=>AXI_LITE_READ_MASTER_INIT_C);
  signal dsAxilReadSlaves   : AxiLiteReadSlaveArray  (MaxDsLinks-1 downto 0);
  signal dsAxilWriteMasters : AxiLiteWriteMasterArray(MaxDsLinks-1 downto 0) := (others=>AXI_LITE_WRITE_MASTER_INIT_C);
  signal dsAxilWriteSlaves  : AxiLiteWriteSlaveArray (MaxDsLinks-1 downto 0);

  signal bpMonClk : slv( 1 downto 0);

  signal ringData : slv(19 downto 0);
  signal ipAddr   : slv(31 downto 0);

  signal drpRdy   : slv(MaxUsLinks-1 downto 0);
  signal drpEn    : slv(MaxUsLinks-1 downto 0);
  signal drpWe    : slv(MaxUsLinks-1 downto 0);
  signal drpAddr  : Slv9Array (MaxUsLinks-1 downto 0);
  signal drpDi    : Slv16Array(MaxUsLinks-1 downto 0);
  signal drpDo    : Slv16Array(MaxUsLinks-1 downto 0);
begin

  status.qplllock <= iquad(1).qpllLock & iquad(0).qpllLock;

  GEN_USAXIL : for i in 0 to 3 generate
    usAxilReadMasters (i) <= mAxilReadMasters (i+2*NPGPAXI_C+2);
    usAxilWriteMasters(i) <= mAxilWriteMasters(i+2*NPGPAXI_C+2);
    mAxilReadSlaves  (i+2*NPGPAXI_C+2) <= usAxilReadSlaves(i);
    mAxilWriteSlaves (i+2*NPGPAXI_C+2) <= usAxilWriteSlaves(i);
  end generate;
  
  GEN_DSAXIL : for i in 0 to 2 generate
    dsAxilReadMasters (i) <= mAxilReadMasters (i+2*NPGPAXI_C+6);
    dsAxilWriteMasters(i) <= mAxilWriteMasters(i+2*NPGPAXI_C+6);
    mAxilReadSlaves  (i+2*NPGPAXI_C+6) <= dsAxilReadSlaves(i);
    mAxilWriteSlaves (i+2*NPGPAXI_C+6) <= dsAxilWriteSlaves(i);
  end generate;
  
  GEN_AMC : for j in 0 to 1 generate
    U_QPLL : entity work.DtiPgp3QuadPllArray
      port map ( axilClk  => regClk,
                 axilRst  => regRst,
                 amcClkP  => amcClkP  (j)(0),
                 amcClkN  => amcClkN  (j)(0),
                 amcTxP   => amcTxP   (j),
                 amcTxN   => amcTxN   (j),
                 amcRxP   => amcRxP   (j),
                 amcRxN   => amcRxN   (j),
                 --  channel ports
                 chanPllRst => iqpllrst(6+7*j downto 0+7*j),
                 chanTxP    => iamcTxP (6+7*j downto 0+7*j),
                 chanTxN    => iamcTxN (6+7*j downto 0+7*j),
                 chanRxP    => iamcRxP (6+7*j downto 0+7*j),
                 chanRxN    => iamcRxN (6+7*j downto 0+7*j),
                 chanQuad   => iquad   (6+7*j downto 0+7*j) );
  end generate;

  --
  --  Feed the AMC PLL for driving the Timing synchronous AMC devclk(3:2)
  --
  U_FPGACLK0 : entity work.ClkOutBufDiff
    generic map (
      XIL_DEVICE_G => "ULTRASCALE")
      port map (
        clkIn   => ref156MHzClk,
        clkOutP => fpgaclk_P(0),
        clkOutN => fpgaclk_N(0));

  U_FPGACLK2 : entity work.ClkOutBufDiff
    generic map (
      XIL_DEVICE_G => "ULTRASCALE")
      port map (
        clkIn   => ref156MHzClk,
        clkOutP => fpgaclk_P(2),
        clkOutN => fpgaclk_N(2));

  fpgaclk_P(1) <= '0';
  fpgaclk_N(1) <= '1';
  fpgaclk_P(3) <= '0';
  fpgaclk_N(3) <= '1';
  
   GEN_PLL : for i in 0 to 1 generate
     U_Pll : entity work.XpmPll
       port map (
         config      => config.amcPll(i),
         status      => status.amcPll(i),
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
       axilReadMaster          => mAxilReadMasters (2*NPGPAXI_C+1),
       axilReadSlave           => mAxilReadSlaves  (2*NPGPAXI_C+1),
       axilWriteMaster         => mAxilWriteMasters(2*NPGPAXI_C+1),
       axilWriteSlave          => mAxilWriteSlaves (2*NPGPAXI_C+1) );

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
      timingHdr         => recTimingHdr,
      exptBus           => recExptBus,
      timingHdrP        => timingHdr,
      triggerBus        => triggerBus,
      fullOut           => fullOut,
      msgDelay          => status.msgDelaySet,
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
      ipAddr           => ipAddr,
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
      --ddrClkP           => ddrClkP,
      --ddrClkN           => ddrClkN,
      --ddrDqsP           => ddrDqsP,
      --ddrDqsN           => ddrDqsN,
      --ddrDm             => ddrDm,
      --ddrDq             => ddrDq,
      --ddrA              => ddrA,
      --ddrBa             => ddrBa,
      --ddrCsL            => ddrCsL,
      --ddrOdt            => ddrOdt,
      --ddrCke            => ddrCke,
      --ddrCkP            => ddrCkP,
      --ddrCkN            => ddrCkN,
      --ddrWeL            => ddrWeL,
      --ddrRasL           => ddrRasL,
      --ddrCasL           => ddrCasL,
      --ddrRstL           => ddrRstL,
      --ddrPwrEnL         => ddrPwrEnL,
      --ddrPg             => ddrPg,
      --ddrAlertL         => ddrAlertL,
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
               timingHdr    => recTimingHdr,
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
    generic map ( AXIL_BASE_ADDR_G => AXI_CROSSBAR_MASTERS_CONFIG_C(0).baseAddr )
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
               monclk(0)       => bpMonClk(0),
               monclk(1)       => bpMonClk(1),
               monclk(2)       => usMonClk(0),
               monclk(3)       => dsMonClk(0) );

  --
  --  Translate AMC I/O into AxiStream
  --
  --    Register r/w commands are buffered and streamed forward
  --    Register read replies are buffered and streamed to CPU
  --    Unsolicited data is timestamped and streamed to downstream link
  --    Downstream inputs are translated to full status

  GEN_US_PGP : for i in 0 to MaxUsLinks-1 generate
    U_Core : entity work.DtiUsCore
      generic map ( DEBUG_G     => (i=0) )
      port map ( sysClk        => regClk,
                 sysRst        => regRst,
                 clear         => regClear,
                 update        => regUpdate,
                 config        => config.usLink(i),
                 status        => status.usLink(i),
                 remLinkID     => usRemLinkID  (i),
                 fullOut       => usFull       (i),
                 msgDelay      => status.msgDelayGet(i),
                 --
                 --ctlClk        => regClk,
                 --ctlRst        => regRst,
                 --ctlRxMaster   => dsCtlRxM (i),
                 --ctlRxSlave    => dsCtlRxS (i),
                 --ctlTxMaster   => ctlTxM (i),
                 --ctlTxSlave    => ctlTxS (i),
                 --
                 timingClk     => recTimingClk,  -- outbound data (to sensor)
                 timingRst     => recTimingRst,
                 timingHdr     => recTimingHdr,
                 exptBus       => recExptBus  ,
                 timingHdrP    => timingHdr   ,
                 triggerBus    => triggerBus  ,
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
                 obTrigValid   => usObTrigV (i) );

    U_App : entity work.DtiUsPgp3
      generic map ( ID_G             => x"0" & toSlv(i,4),
                    AXIL_BASE_ADDR_G => US_AXIL_BASE_ADDR_C(i),
--                    EN_AXIL_G        => ite(i<4, true, false),
                    EN_AXIL_G        => false,
                    DEBUG_G          => (i=0) )
--                    INCLUDE_AXIL_G => ite(i<NPGPAXI_C, true, false) )
      port map ( amcClk   => iquad(i).coreClk,
                 amcRst   => '0',
                 status   => status.usApp(i),
                 amcRxP   => iamcRxP(i),
                 amcRxN   => iamcRxN(i),
                 amcTxP   => iamcTxP(i),
                 amcTxN   => iamcTxN(i),
                 fifoRst  => regClear,
                 --
                 qplllock      => iquad(i).qplllock,
                 qplloutclk    => iquad(i).qplloutclk,
                 qplloutrefclk => iquad(i).qplloutrefclk,
                 qpllRst       => iqpllrst(i),
                 -- DRP Interface
                 axilClk          => regClk,
                 axilRst          => regRst,
                 axilReadMaster   => usAxilReadMasters (i),
                 axilReadSlave    => usAxilReadSlaves  (i),
                 axilWriteMaster  => usAxilWriteMasters(i),
                 axilWriteSlave   => usAxilWriteSlaves (i),
                 --
                 ibClk            => usIbClk    (i),
                 ibRst            => regRst,
                 ibMaster(VC_EVT) => usIbMaster (i),
                 ibMaster(VC_CTL) => ctlTxM     (i),
                 ibSlave (VC_EVT) => usIbSlave  (i),
                 ibSlave (VC_CTL) => ctlTxS     (i),
                 loopback         => config.loopback(i),
                 linkUp           => usLinkUp   (i),
                 locLinkID        => dtiUsLinkId(ipAddr,i),
                 remLinkID        => usRemLinkID(i),
                 rxErrs           => usRxErrs   (i),
                 txFull           => usFullIn   (i),
                 monClk           => usMonClk   (i),
                 --
                 obClk       => usObClk   (i),
                 obRst       => recTimingRst,
                 obMaster    => ctlRxM    (i),
                 obSlave     => ctlRxS    (i),
                 --  Timing clock domain
                 timingClk   => recTimingClk,
                 timingRst   => recTimingRst,
                 obTrig      => usObTrig  (i),
                 obTrigValid => usObTrigV (i) );
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
                 rxErrs         => dsRxErrs  (i),
                 fullIn         => dsFullIn  (i),
                 --
                 obClk          => dsObClk   (i),
                 obMaster       => dsObMaster(i),
                 obSlave        => dsObSlave (i) );
    
    U_App : entity work.DtiDsPgp3
      generic map ( ID_G             => x"1" & toSlv(i,4),
                    AXIL_BASE_ADDR_G => DS_AXIL_BASE_ADDR_C(i),
                    EN_AXIL_G        => ite(i<3, true, false),
                    DEBUG_G          => ite(i=2, true, false) )
      port map ( amcClk   => iquad(13-i).coreClk,
                 amcRst   => '0',
                 amcRxP   => iamcRxP(13-i),
                 amcRxN   => iamcRxN(13-i),
                 amcTxP   => iamcTxP(13-i),
                 amcTxN   => iamcTxN(13-i),
                 fifoRst  => regClear,
                 qplllock      => iquad(13-i).qplllock,
                 qplloutclk    => iquad(13-i).qplloutclk,
                 qplloutrefclk => iquad(13-i).qplloutrefclk,
                 qpllRst       => iqpllrst(13-i),
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
                 loopback      => config.loopback(i+16),
                 linkUp        => dsLinkUp    (i),
                 remLinkID     => dsRemLinkID (i),
                 rxErrs        => dsRxErrs    (i),
                 full          => dsFullIn    (i),
                 monClk        => dsMonClk    (i),
                 obClk         => dsObClk     (i),
                 obMaster      => dsObMaster  (i),
                 obSlave       => dsObSlave   (i));

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

