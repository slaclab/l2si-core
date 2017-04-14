-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AmcCarrierCore.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-08
-- Last update: 2017-04-12
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.AxiLitePkg.all;
use work.AxiPkg.all;
use work.TimingPkg.all;
use work.XpmPkg.all;
use work.AmcCarrierPkg.all;

library unisim;
use unisim.vcomponents.all;

entity DtiCore is
   generic (
      TPD_G               : time                := 1 ns;   -- Simulation only parameter
      BUILD_INFO_G        : BuildInfoType;
      NAPP_LINKS_G        : integer             := 1;
      OVERRIDE_BSI_G      : boolean             := false;  -- false = Normal Operation, true = use IP_ADDR, MAC_ADDR generics
      IP_ADDR_G           : slv(31 downto 0)    := x"0b02a8c0";
      MAC_ADDR_G          : slv(47 downto 0)    := x"030300564400";
      DIAGNOSTIC_SIZE_G   : positive            := 1;
      DIAGNOSTIC_CONFIG_G : AxiStreamConfigType := ssiAxiStreamConfig(4));
   port (
      ----------------------
      -- Top Level Interface
      ----------------------
      -- AXI-Lite Interface (regClk domain)
      -- Address Range = [0x80000000:0xFFFFFFFF]
      regClk            : out   sl;
      regRst            : out   sl;
      regReadMaster     : out   AxiLiteReadMasterType;
      regReadSlave      : in    AxiLiteReadSlaveType;
      regWriteMaster    : out   AxiLiteWriteMasterType;
      regWriteSlave     : in    AxiLiteWriteSlaveType;
      -- Streaming input (regClk domain)
      ibAppMasters      : out   AxiStreamMasterArray(NAPP_LINKS_G-1 downto 0);
      ibAppSlaves       : in    AxiStreamSlaveArray (NAPP_LINKS_G-1 downto 0) := (others=>AXI_STREAM_SLAVE_FORCE_C);
      obAppMasters      : in    AxiStreamMasterArray(NAPP_LINKS_G-1 downto 0) := (others=>AXI_STREAM_MASTER_INIT_C);
      obAppSlaves       : out   AxiStreamSlaveArray (NAPP_LINKS_G-1 downto 0);
      -- Timing Interface (timingClk domain)
      timingData        : out   TimingRxType;
      timingBus         : out   TimingBusType;
      exptBus           : out   ExptBusType;
      -- BSI Interface (bsiClk domain) 
      bsiBus            : out   BsiBusType;
      -- Reference Clocks and Resets
      recTimingClk      : out   sl;
      recTimingRst      : out   sl;
      ref125MHzClk      : out   sl;
      ref125MHzRst      : out   sl;
      ref156MHzClk      : out   sl;
      ref156MHzRst      : out   sl;
      ref312MHzClk      : out   sl;
      ref312MHzRst      : out   sl;
      ref625MHzClk      : out   sl;
      ref625MHzRst      : out   sl;
      gthFabClk         : out   sl;
      ----------------
      -- Core Ports --
      ----------------
      -- Common Fabricate Clock
      fabClkP           : in    sl;
      fabClkN           : in    sl;
      -- Backplane Ethernet Ports
      ethRxP           : in    slv(3 downto 0);
      ethRxN           : in    slv(3 downto 0);
      ethTxP           : out   slv(3 downto 0);
      ethTxN           : out   slv(3 downto 0);
      ethClkP          : in    sl;
      ethClkN          : in    sl;
      -- LCLS Timing Ports
      timingRxP         : in    sl;
      timingRxN         : in    sl;
      timingTxP         : out   sl;
      timingTxN         : out   sl;
      timingRefClkInP   : in    sl;
      timingRefClkInN   : in    sl;
      timingRefClkOut   : out   sl;
      timingRecClkOutP  : out   sl;
      timingRecClkOutN  : out   sl;
      timingClkSel      : out   sl;
      timingClkScl      : inout sl;
      timingClkSda      : inout sl;
      -- Crossbar Ports
      xBarSin           : out   slv(1 downto 0);
      xBarSout          : out   slv(1 downto 0);
      xBarConfig        : out   sl;
      xBarLoad          : out   sl;
      -- IPMC Ports
      ipmcScl           : inout sl;
      ipmcSda           : inout sl;
      -- Configuration PROM Ports
      calScl            : inout sl;
      calSda            : inout sl;
      -- DDR3L SO-DIMM Ports
      ddrClkP           : in    sl;
      ddrClkN           : in    sl;
      ddrDm             : out   slv(7 downto 0);
      ddrDqsP           : inout slv(7 downto 0);
      ddrDqsN           : inout slv(7 downto 0);
      ddrDq             : inout slv(63 downto 0);
      ddrA              : out   slv(15 downto 0);
      ddrBa             : out   slv(2 downto 0);
      ddrCsL            : out   slv(1 downto 0);
      ddrOdt            : out   slv(1 downto 0);
      ddrCke            : out   slv(1 downto 0);
      ddrCkP            : out   slv(1 downto 0);
      ddrCkN            : out   slv(1 downto 0);
      ddrWeL            : out   sl;
      ddrRasL           : out   sl;
      ddrCasL           : out   sl;
      ddrRstL           : out   sl;
      ddrAlertL         : in    sl;
      ddrPg             : in    sl;
      ddrPwrEnL         : out   sl;
      ddrScl            : inout sl;
      ddrSda            : inout sl;
      -- SYSMON Ports
      vPIn              : in    sl;
      vNIn              : in    sl);
end DtiCore;

architecture mapping of DtiCore is

   constant AXI_ERROR_RESP_C : slv(1 downto 0) := AXI_RESP_DECERR_C;
   
   signal axilClk          : sl;
   signal axilRst          : sl;
   signal axilReadMasters  : AxiLiteReadMasterArray (1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray  (1 downto 0);
   signal axilWriteMasters : AxiLiteWriteMasterArray(1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray (1 downto 0);

   signal axiClk         : sl;
   signal axiRst         : sl;
   signal axiWriteMaster : AxiWriteMasterType;
   signal axiWriteSlave  : AxiWriteSlaveType;
   signal axiReadMaster  : AxiReadMasterType;
   signal axiReadSlave   : AxiReadSlaveType;

   signal timingReadMaster  : AxiLiteReadMasterType;
   signal timingReadSlave   : AxiLiteReadSlaveType;
   signal timingWriteMaster : AxiLiteWriteMasterType;
   signal timingWriteSlave  : AxiLiteWriteSlaveType;

   signal ethReadMaster  : AxiLiteReadMasterType;
   signal ethReadSlave   : AxiLiteReadSlaveType;
   signal ethWriteMaster : AxiLiteWriteMasterType;
   signal ethWriteSlave  : AxiLiteWriteSlaveType;

   signal ddrReadMaster  : AxiLiteReadMasterType;
   signal ddrReadSlave   : AxiLiteReadSlaveType;
   signal ddrWriteMaster : AxiLiteWriteMasterType;
   signal ddrWriteSlave  : AxiLiteWriteSlaveType;
   signal ddrMemReady    : sl;
   signal ddrMemError    : sl;
 
   signal mpsReadMaster  : AxiLiteReadMasterType;
   signal mpsReadSlave   : AxiLiteReadSlaveType;
   signal mpsWriteMaster : AxiLiteWriteMasterType;
   signal mpsWriteSlave  : AxiLiteWriteSlaveType;

   signal bsiMac     : slv(47 downto 0);
   signal bsiIp      : slv(31 downto 0);

   signal localMac   : slv(47 downto 0);
   signal localIp    : slv(31 downto 0);
   signal linkUp     : sl;

   signal refClk : slv(3 downto 0);
   signal refRst : slv(3 downto 0);
begin

  regClk       <= axilClk;
  regRst       <= axilRst;
  
  ref125MHzClk <= refClk(0);
  ref125MHzRst <= refRst(0);
  ref156MHzClk <= refClk(1);
  ref156MHzRst <= refRst(1);
  ref312MHzClk <= refClk(2);
  ref312MHzRst <= refRst(2);
  ref625MHzClk <= refClk(3);
  ref625MHzRst <= refRst(3);
  
  GEN_BSI_OVERRIDE: if OVERRIDE_BSI_G=true generate
    localIp    <= IP_ADDR_G;
    localMac   <= MAC_ADDR_G;
  end generate GEN_BSI_OVERRIDE;

  GEN_NO_BSI_OVERRIDE: if OVERRIDE_BSI_G=false generate
    localIp    <= bsiIp;
    localMac   <= bsiMac;
  end generate GEN_NO_BSI_OVERRIDE;
  
   --------------------------------
   -- Common Clock and Reset Module
   -------------------------------- 
   U_ClkAndRst : entity work.XpmClkAndRst
      generic map (
         TPD_G         => TPD_G )
      port map (
         -- Reference Clocks and Resets
         ref125MHzClk => refClk(0),
         ref125MHzRst => refRst(0),
         ref156MHzClk => refClk(1),
         ref156MHzRst => refRst(1),
         ref312MHzClk => refClk(2),
         ref312MHzRst => refRst(2),
         ref625MHzClk => refClk(3),
         ref625MHzRst => refRst(3),
         gthFabClk    => gthFabClk,
         -- AXI-Lite Clocks and Resets
         axilClk      => axilClk,
         axilRst      => axilRst,
         ----------------
         -- Core Ports --
         ----------------   
         -- Common Fabricate Clock
         fabClkP      => fabClkP,
         fabClkN      => fabClkN );

   ------------------------------------
   -- Ethernet Module (ATCA ZONE 2)
   ------------------------------------
   U_Eth : entity work.DtiCoreEth
      generic map (
         TPD_G             => TPD_G,
         NAPP_LINKS_G      => NAPP_LINKS_G,
         AXI_ERROR_RESP_G  => AXI_ERROR_RESP_C)
      port map (
         -- Local Configuration
         localMac          => localMac,
         localIp           => localIp,
         ethPhyReady       => linkUp,
         -- Master AXI-Lite Interface
         mAxilReadMasters  => axilReadMasters,
         mAxilReadSlaves   => axilReadSlaves,
         mAxilWriteMasters => axilWriteMasters,
         mAxilWriteSlaves  => axilWriteSlaves,
         -- AXI-Lite Interface
         axilClk           => axilClk,
         axilRst           => axilRst,
         axilReadMaster    => ethReadMaster,
         axilReadSlave     => ethReadSlave,
         axilWriteMaster   => ethWriteMaster,
         axilWriteSlave    => ethWriteSlave,
         -- Application Debug Interface
         obAppMasters      => obAppMasters,
         obAppSlaves       => obAppSlaves,
         ibAppMasters      => ibAppMasters,
         ibAppSlaves       => ibAppSlaves,
         ----------------------
         -- Top Level Interface
         ----------------------
        ----------------
         -- Core Ports --
         ----------------   
         -- ETH Ports
         ethRxP           => ethRxP,
         ethRxN           => ethRxN,
         ethTxP           => ethTxP,
         ethTxN           => ethTxN,
         ethClkP          => ethClkP,
         ethClkN          => ethClkN);

   ----------------------------------   
   -- Register Address Mapping Module
   ----------------------------------   
   U_RegMap : entity work.AmcCarrierSysReg
      generic map (
         TPD_G               => TPD_G,
         BUILD_INFO_G        => BUILD_INFO_G,
         AXI_ERROR_RESP_G    => AXI_ERROR_RESP_C,
         APP_TYPE_G          => APP_NULL_TYPE_C,
         TIMING_MODE_G       => true,
         FSBL_G              => false)
      port map (
         -- Primary AXI-Lite Interface
         axilClk           => axilClk,
         axilRst           => axilRst,
         sAxilReadMasters  => axilReadMasters,
         sAxilReadSlaves   => axilReadSlaves,
         sAxilWriteMasters => axilWriteMasters,
         sAxilWriteSlaves  => axilWriteSlaves,
         -- Timing AXI-Lite Interface
         timingReadMaster  => timingReadMaster,
         timingReadSlave   => timingReadSlave,
         timingWriteMaster => timingWriteMaster,
         timingWriteSlave  => timingWriteSlave,
         -- BSA AXI-Lite Interface
         bsaReadMaster     => open,
         bsaReadSlave      => AXI_LITE_READ_SLAVE_INIT_C,
         bsaWriteMaster    => open,
         bsaWriteSlave     => AXI_LITE_WRITE_SLAVE_INIT_C,
         -- ETH PHY AXI-Lite Interface
         ethReadMaster     => ethReadMaster,
         ethReadSlave      => ethReadSlave,
         ethWriteMaster    => ethWriteMaster,
         ethWriteSlave     => ethWriteSlave,
         -- DDR PHY AXI-Lite Interface
         ddrReadMaster     => ddrReadMaster,
         ddrReadSlave      => ddrReadSlave,
         ddrWriteMaster    => ddrWriteMaster,
         ddrWriteSlave     => ddrWriteSlave,
         ddrMemReady       => ddrMemReady,
         ddrMemError       => ddrMemError,
         -- MPS PHY AXI-Lite Interface
         mpsReadMaster     => mpsReadMaster,
         mpsReadSlave      => mpsReadSlave,
         mpsWriteMaster    => mpsWriteMaster,
         mpsWriteSlave     => mpsWriteSlave,
         -- Local Configuration
         localMac          => bsiMac,
         localIp           => bsiIp,
         ethLinkUp         => linkUp,
         ----------------------
         -- Top Level Interface
         ----------------------              
         -- Application AXI-Lite Interface
         appReadMaster     => regReadMaster,
         appReadSlave      => regReadSlave,
         appWriteMaster    => regWriteMaster,
         appWriteSlave     => regWriteSlave,
         -- BSI Interface
         bsiBus            => bsiBus,
         ----------------
         -- Core Ports --
         ----------------   
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
         -- Clock Cleaner Ports
         timingClkScl      => timingClkScl,
         timingClkSda      => timingClkSda,
         -- DDR3L SO-DIMM Ports
         ddrScl            => ddrScl,
         ddrSda            => ddrSda,
         -- SYSMON Ports
         vPIn              => vPIn,
         vNIn              => vNIn);

   --------------
   -- Timing Core
   --------------
   U_Timing : entity work.XpmTiming
      generic map (
         TPD_G               => TPD_G,
         APP_TYPE_G          => APP_NULL_TYPE_C,
         AXI_ERROR_RESP_G    => AXI_ERROR_RESP_C )
      port map (
         -- AXI-Lite Interface (axilClk domain)
         axilClk          => axilClk,
         axilRst          => axilRst,
         axilReadMaster   => timingReadMaster,
         axilReadSlave    => timingReadSlave,
         axilWriteMaster  => timingWriteMaster,
         axilWriteSlave   => timingWriteSlave,
         ----------------------
         -- Top Level Interface
         ----------------------         
         -- Timing Interface 
         recTimingClk     => recTimingClk,
         recTimingRst     => recTimingRst,
         recTimingBus     => timingBus,
         recExptBus       => exptBus,
         recData          => timingData,
         
         appTimingPhy     => TIMING_PHY_INIT_C,
         appTimingPhyClk  => open,
         appTimingPhyRst  => open,
         ----------------
         -- Core Ports --
         ----------------   
         -- LCLS Timing Ports
         timingRxP        => timingRxP,
         timingRxN        => timingRxN,
         timingTxP        => timingTxP,
         timingTxN        => timingTxN,
         timingRefClkInP  => timingRefClkInP,
         timingRefClkInN  => timingRefClkInN,
         timingRefClkOut  => timingRefClkOut,
         timingRecClkOutP => timingRecClkOutP,
         timingRecClkOutN => timingRecClkOutN,
         timingClkSel     => timingClkSel);

   ------------------
   -- DDR Memory Core
   ------------------
   U_DdrMem : entity work.AmcCarrierDdrMem
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_C,
         FSBL_G           => false,
         SIM_SPEEDUP_G    => false)
      port map (
         -- AXI-Lite Interface
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => ddrReadMaster,
         axilReadSlave   => ddrReadSlave,
         axilWriteMaster => ddrWriteMaster,
         axilWriteSlave  => ddrWriteSlave,
         memReady        => ddrMemReady,
         memError        => ddrMemError,
         -- AXI4 Interface
         axiClk          => axiClk,
         axiRst          => axiRst,
         axiWriteMaster  => axiWriteMaster,
         axiWriteSlave   => axiWriteSlave,
         axiReadMaster   => axiReadMaster,
         axiReadSlave    => axiReadSlave,
         ----------------
         -- Core Ports --
         ----------------   
         -- DDR3L SO-DIMM Ports
         ddrClkP         => ddrClkP,
         ddrClkN         => ddrClkN,
         ddrDqsP         => ddrDqsP,
         ddrDqsN         => ddrDqsN,
         ddrDm           => ddrDm,
         ddrDq           => ddrDq,
         ddrA            => ddrA,
         ddrBa           => ddrBa,
         ddrCsL          => ddrCsL,
         ddrOdt          => ddrOdt,
         ddrCke          => ddrCke,
         ddrCkP          => ddrCkP,
         ddrCkN          => ddrCkN,
         ddrWeL          => ddrWeL,
         ddrRasL         => ddrRasL,
         ddrCasL         => ddrCasL,
         ddrRstL         => ddrRstL,
         ddrPwrEnL       => ddrPwrEnL,
         ddrPg           => ddrPg,
         ddrAlertL       => ddrAlertL);

end mapping;
