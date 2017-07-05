-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : dti.vhd
-- Author     : Matt Weaver
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-12-14
-- Last update: 2017-04-21
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

entity dti is
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
      --amcRxP       : in    Slv7Array(1 downto 0);
      --amcRxN       : in    Slv7Array(1 downto 0);
      --amcTxP       : out   Slv7Array(1 downto 0);
      --amcTxN       : out   Slv7Array(1 downto 0);
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
end dti;

architecture top_level of dti is

   -- AmcCarrierCore Configuration Constants
   constant DIAGNOSTIC_SIZE_C   : positive            := 1;
   constant DIAGNOSTIC_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);

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
   signal ref156MHzClk : sl;
   signal ref156MHzRst : sl;

   signal config : DtiConfigType;
   signal status : DtiStatusType;
   
   signal obDsMasters : AxiStreamMasterArray(MaxDsLinks-1 downto 0);
   signal obDsSlaves  : AxiStreamSlaveArray (MaxDsLinks-1 downto 0);

   signal usConfig     : DtiUsLinkConfigArray(MaxUsLinks-1 downto 0) := (others=>DTI_US_LINK_CONFIG_INIT_C);
   signal usStatus     : DtiUsLinkStatusArray(MaxUsLinks-1 downto 0);
   signal usIbMaster   : AxiStreamMasterArray(MaxUsLinks-1 downto 0);
   signal usIbSlave    : AxiStreamSlaveArray (MaxUsLinks-1 downto 0);
   signal usIbClk      : slv                 (MaxUsLinks-1 downto 0);
   signal usObMaster   : AxiStreamMasterArray(MaxUsLinks-1 downto 0);
   signal usObSlave    : AxiStreamSlaveArray (MaxUsLinks-1 downto 0);
   signal usObClk      : slv                 (MaxUsLinks-1 downto 0);
   signal usFull       : Slv16Array          (MaxUsLinks-1 downto 0);
   signal usObTrig     : XpmPartitionDataArray(MaxUsLinks-1 downto 0);

   signal fullOut      : slv(15 downto 0);
   
   signal dsStatus : DtiDsLinkStatusArray(MaxDsLinks-1 downto 0);
   
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
   
   signal gtRefClk         : sl;
   signal amcClk           : sl;

begin

  U_FPGACLK : entity work.ClkOutBufDiff
    generic map (
      XIL_DEVICE_G => "ULTRASCALE")
    port map (
      clkIn   => recTimingClk,
      clkOutP => fpgaclk_P,
      clkOutN => fpgaclk_N);

  --U_ILA : ila_1x256x1024
  --  port map ( clk      => recTimingClk,
  --             probe0( 15 downto   0) => dsTxData(0),
  --             probe0( 17 downto  16) => dsTxDataK(0),
  --             probe0(255 downto  18) => (others=>'0'));
               
  
   --U_XBAR : entity work.AxiLiteCrossbar
   --   generic map (
   --      DEC_ERROR_RESP_G   => AXI_RESP_DECERR_C,
   --      NUM_SLAVE_SLOTS_G  => 1,
   --      NUM_MASTER_SLOTS_G => 2,
   --      MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
   --   port map (
   --      axiClk              => regClk,
   --      axiClkRst           => regRst,
   --      sAxiWriteMasters(0) => regWriteMaster,
   --      sAxiWriteSlaves (0) => regWriteSlave,
   --      sAxiReadMasters (0) => regReadMaster,
   --      sAxiReadSlaves  (0) => regReadSlave,
   --      mAxiWriteMasters    => axilWriteMasters,
   --      mAxiWriteSlaves     => axilWriteSlaves,
   --      mAxiReadMasters     => axilReadMasters,
   --      mAxiReadSlaves      => axilReadSlaves);      

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
         -- Reference Clocks and Resets
         recTimingClk      => recTimingClk,
         recTimingRst      => recTimingRst,
         ref125MHzClk      => open,
         ref125MHzRst      => open,
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
    port map ( ref156MHzClk => ref156MHzClk,
               ref156MHzRst => ref156MHzRst,
               rxFull(0)    => fullOut,
               linkUp       => status.bpLinkUp,
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
               
  U_Reg : entity work.DtiReg
    port map ( axilClk         => regClk,
               axilRst         => regRst,
               axilUpdate      => regUpdate,
               axilClear       => regClear,
               axilReadMaster  => regReadMaster,
               axilReadSlave   => regReadSlave,
               axilWriteMaster => regWriteMaster,
               axilWriteSlave  => regWriteSlave,
               --      
               status          => status,
               config          => config );

  --
  --  Translate AMC I/O into AxiStream
  --
  --    Register r/w commands are buffered and streamed forward
  --    Register read replies are buffered and streamed to CPU
  --    Unsolicited data is timestamped and streamed to downstream link
  --    Downstream inputs are translated to full status
  
    DEVCLK_IBUFDS_GTE3 : IBUFDS_GTE3
      generic map (
        REFCLK_EN_TX_PATH  => '0',
        REFCLK_HROW_CK_SEL => "00",    -- 2'b01: ODIV2 = Divide-by-2 version of O
        REFCLK_ICNTL_RX    => "00")
      port map (
        I     => amcClkP(0)(0),
        IB    => amcClkN(0)(0),
        CEB   => '0',
        ODIV2 => gtRefClk,
        O     => open);

    --AMCCLK_BUFG_GT : BUFG_GT
    --  port map ( I       => gtRefClk,
    --             CE      => '1',
    --             CEMASK  => '1',
    --             CLR     => '0',
    --             CLRMASK => '1',
    --             DIV     => "000",
    --             O       => amcClk );
    amcClk  <= regClk;
  
    GEN_US : for i in 0 to MaxUsLinks-1 generate
      U_Core : entity work.DtiUsCore
        generic map ( DEBUG_G => ite(i>0, false, true) )
        port map ( sysClk        => regClk,
                   sysRst        => regRst,
                   clear         => regClear,
                   update        => regUpdate,
                   config        => config.usLink(i),
                   status        => status.usLink(i),
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
                   full          => dsFull,
                   --
                   ibClk         => usIbClk   (i),
                   ibLinkUp      => '1',
                   ibErrs        => (others=>'0'),
                   ibMaster      => usIbMaster(i),
                   ibSlave       => usIbSlave (i),
                   --
                   obClk         => usObClk   (i),
                   obTrig        => usObTrig  (i),
                   obMaster      => usObMaster(i),
                   obSlave       => usObSlave (i) );

      U_App : entity work.DtiUsSimApp
        generic map ( SERIAL_ID_G => x"ABADCAFE",
                      DEBUG_G => ite(i>0, false, true) )
        port map ( amcClk   => amcClk,
                   amcRst   => '0',
                   status   => status.usApp(i),
                   --
                   fifoRst  => regClear,
                   --
                   ibClk    => usIbClk   (i),
                   ibRst    => regRst,
                   ibMaster => usIbMaster(i),
                   ibSlave  => usIbSlave (i),
                   --
                   obClk    => usObClk   (i),
                   obRst    => recTimingRst,
                   obTrig   => usObTrig  (i),
                   obMaster => usObMaster(i),
                   obSlave  => usObSlave (i));
    end generate;
      
    GEN_DS : for i in 0 to MaxDsLinks-1 generate
      U_Core : entity work.DtiDsCore
        port map ( clear          => regClear,
                   update         => regUpdate,
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
      
      U_App : entity work.DtiDsSimApp
       port map ( amcClk        => amcClk,
                  amcRst        => '0',
                  ibRst         => '0',
                  --
                  linkUp        => dsLinkUp    (i),
                  rxErr         => dsRxErr     (i),
                  full          => open,
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
