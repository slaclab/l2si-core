---------------
-- Title : top project 
-- Project : quad_demo
-------------------------------------------------------------------------------
-- File : quad_demo_top.vhd
-- Author : FARCY G.
-- Compagny : e2v
-- Last update : 2009/05/07
-- Plateform :  
-------------------------------------------------------------------------------
-- Description : link all project blocks
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
 
-------------------------------------------------------------------------------
-- library description
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.math_real.all;
 
library work;
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.QuadAdcPkg.all;
use work.TimingExtnPkg.all;
use work.TimingPkg.all;
use work.TPGPkg.all;
use work.Pgp3Pkg.all;
 
library unisim;            
use unisim.vcomponents.all;  
-------------------------------------------------------------------------------
-- Configuration IODELAY on data
-- VERSION_625MHz = TRUE    no iodelay
-- VERSION_625MHz = FALSE   iodelay

-------------------------------------------------------------------------------
entity hsd_pgp3_ilv is
  generic (
    BUILD_INFO_G : BuildInfoType );
  port (
    -- PC821 Interface
    cpld_fpga_bus    : inout slv(8 downto 0);
    cpld_eeprom_wp   : out   sl;
    --
    flash_noe        : out   sl;
    flash_nwe        : out   sl;
    flash_address    : out   slv(25 downto 0);
    flash_data       : inout slv(15 downto 0);
    -- I2C
    scl            : inout sl;
    sda            : inout sl;
    -- Timing
    timingRefClkP  : in  sl;
    timingRefClkN  : in  sl;
    timingRxP      : in  sl;
    timingRxN      : in  sl;
    timingTxP      : out sl;
    timingTxN      : out sl;
    timingModAbs   : in  sl;
    timingRxLos    : in  sl;
    timingTxDis    : out sl;
    -- PCIe Ports 
    pciRstL        : in    sl;
    pciRefClkP     : in    sl;
    pciRefClkN     : in    sl;
    pciRxP         : in    slv(7 downto 0);
    pciRxN         : in    slv(7 downto 0);
    pciTxP         : out   slv(7 downto 0);
    pciTxN         : out   slv(7 downto 0);
    -- PGP Ports (to DRP)
    pgpRefClkP : in    sl;            -- 156.25 MHz
    pgpRefClkN : in    sl;            -- 156.25 MHz
    pgpAltClkP : in    sl;            -- 156.25 MHz
    pgpAltClkN : in    sl;            -- 156.25 MHz
    pgpRxP     : in    slv(3 downto 0);
    pgpRxN     : in    slv(3 downto 0);
    pgpTxP     : out   slv(3 downto 0);
    pgpTxN     : out   slv(3 downto 0);
    pgpFabClkP : in    sl;            -- 156.25 MHz 
    pgpFabClkN : in    sl;
    pgpClkEn   : out   sl;
    usrClkEn   : out   sl;
    usrClkSel  : out   sl;
    qsfpRstN   : out   sl;
    -- ADC Interface
    fmc_to_cpld      : inout Slv4Array(0 downto 0);
    front_io_fmc     : inout Slv4Array(0 downto 0);
    --
    clk_to_fpga_p    : in    slv(0 downto 0);
    clk_to_fpga_n    : in    slv(0 downto 0);
    ext_trigger_p    : in    slv(0 downto 0);
    ext_trigger_n    : in    slv(0 downto 0);
    sync_from_fpga_p : out   slv(0 downto 0);
    sync_from_fpga_n : out   slv(0 downto 0);
    --
    adr_p            : in    slv(0 downto 0);              -- serdes clk
    adr_n            : in    slv(0 downto 0);
    ad_p             : in    Slv10Array(0 downto 0);
    ad_n             : in    Slv10Array(0 downto 0);
    aor_p            : in    slv(0 downto 0);              -- out-of-range
    aor_n            : in    slv(0 downto 0);
    --
    bdr_p            : in    slv(0 downto 0);
    bdr_n            : in    slv(0 downto 0);
    bd_p             : in    Slv10Array(0 downto 0);
    bd_n             : in    Slv10Array(0 downto 0);
    bor_p            : in    slv(0 downto 0);
    bor_n            : in    slv(0 downto 0);
    --
    cdr_p            : in    slv(0 downto 0);
    cdr_n            : in    slv(0 downto 0);
    cd_p             : in    Slv10Array(0 downto 0);
    cd_n             : in    Slv10Array(0 downto 0);
    cor_p            : in    slv(0 downto 0);
    cor_n            : in    slv(0 downto 0);
    --
    ddr_p            : in    slv(0 downto 0);
    ddr_n            : in    slv(0 downto 0);
    dd_p             : in    Slv10Array(0 downto 0);
    dd_n             : in    Slv10Array(0 downto 0);
    dor_p            : in    slv(0 downto 0);
    dor_n            : in    slv(0 downto 0);
    --
    pg_m2c           : in    slv(1 downto 0);
    prsnt_m2c_l      : in    slv(1 downto 0) );
end hsd_pgp3_ilv;
 
 
-------------------------------------------------------------------------------
-- architecture
-------------------------------------------------------------------------------
architecture rtl of hsd_pgp3_ilv is

  --  Set timing specific clock parameters
--  constant LCLSII_C : boolean := false;
  constant LCLSII_C : boolean := true;
  constant NFMC_C   : integer := 1;
  
  type RegType is record
    axilWriteSlave : AxiLiteWriteSlaveType;
    axilReadSlave  : AxiLiteReadSlaveType;
    pgpClkEn  : sl;
    usrClkEn  : sl;
    usrClkSel : sl;
    qsfpRstN  : sl;
    phyRst    : sl;
    pllTxRst  : slv(3 downto 0);
    pllRxRst  : slv(3 downto 0);
    pgpTxRst  : slv(3 downto 0);
    pgpRxRst  : slv(3 downto 0);
  end record;
  constant REG_INIT_C : RegType := (
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
    pgpClkEn  => '1',
    usrClkEn  => '0',
    usrClkSel => '0',
    qsfpRstN  => '1',
    phyRst    => '1',
    pllTxRst  => (others=>'0'),
    pllRxRst  => (others=>'0'),
    pgpTxRst  => (others=>'0'),
    pgpRxRst  => (others=>'0') );

  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;
    
  signal regReadMaster  : AxiLiteReadMasterType;
  signal regReadSlave   : AxiLiteReadSlaveType;
  signal regWriteMaster : AxiLiteWriteMasterType;
  signal regWriteSlave  : AxiLiteWriteSlaveType;
  signal sysClk, sysRst : sl;
  signal dmaClk, dmaRst : sl;
  signal regClk, regRst : sl;
  signal tmpReg         : Slv32Array(0 downto 0);

  signal timingRecClk   : sl;
  signal timingRecClkRst: sl;
  signal timingBus      : TimingBusType;
  signal exptBus        : ExptBusType;

  signal timingFbClk    : sl;
  signal timingFbRst    : sl;
  signal timingFb       : TimingPhyType;

  signal dmaIbMaster    : AxiStreamMasterArray(NFMC_C-1 downto 0);
  signal dmaIbSlave     : AxiStreamSlaveArray (NFMC_C-1 downto 0);

  signal mDmaMaster    : AxiStreamMasterArray(4*NFMC_C-1 downto 0);
  signal mDmaSlave     : AxiStreamSlaveArray (4*NFMC_C-1 downto 0);

  constant PCIE_AXIS_CONFIG_C : AxiStreamConfigArray(3 downto 0) := ( others=>ssiAxiStreamConfig(32) );
  constant DMA_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(32);
  
  constant SIM_TIMING : boolean := false;
  
  signal tpgData           : TimingRxType := TIMING_RX_INIT_C;

  signal adcInput : AdcInputArray(4*NFMC_C-1 downto 0);

  signal pgpRefClk, pgpRefClkCopy, pgpCoreClk : sl;
  signal pgpAltClk, pgpAltClkCopy : sl;
  signal intFabClk, pgpFabClk : sl;
  signal pgpIbMaster         : AxiStreamMasterType;
  signal pgpIbSlave          : AxiStreamSlaveType;
  signal pgpTxMasters        : AxiStreamMasterArray   (3 downto 0);
  signal pgpTxSlaves         : AxiStreamSlaveArray    (3 downto 0);

  constant NUM_AXI_MASTERS_C : integer := 6;
  constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
    0    => (
      baseAddr        => x"00080000",
      addrBits        => 16,
      connectivity    => x"FFFF"),
    1    => (
      baseAddr        => x"00090000",
      addrBits        => 12,
      connectivity    => x"FFFF"),
    2    => (
      baseAddr        => x"00091000",
      addrBits        => 12,
      connectivity    => x"FFFF"),
    3    => (
      baseAddr        => x"00092000",
      addrBits        => 12,
      connectivity    => x"FFFF"),
    4    => (
      baseAddr        => x"00093000",
      addrBits        => 12,
      connectivity    => x"FFFF"),
    5    => (
      baseAddr        => x"00094000",
      addrBits        => 12,
      connectivity    => x"FFFF") );

  signal mAxilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxilWriteSlaves  : AxiLiteWriteSlaveArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxilReadMasters  : AxiLiteReadMasterArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxilReadSlaves   : AxiLiteReadSlaveArray  (NUM_AXI_MASTERS_C-1 downto 0);

  signal qplllock   : Slv2Array(3 downto 0);
  signal qpllclk    : Slv2Array(3 downto 0);
  signal qpllrefclk : Slv2Array(3 downto 0);
  signal qpllrst    : Slv2Array(3 downto 0);

  component ila_0
    port ( clk    : in sl;
           probe0 : in slv(255 downto 0));
  end component;

-------------------------------------------------------------------------------
-- architecture begin
-------------------------------------------------------------------------------
begin  -- rtl

  cpld_eeprom_wp <= '0';
  timingTxDis    <= '0';
  
  --dmaClk <= sysClk;
  --dmaRst <= sysRst;
  
  U_Core : entity work.AxiPcieQuadAdcCore
    generic map ( AXI_APP_BUS_EN_G => true,
                  AXIS_CONFIG_G    => PCIE_AXIS_CONFIG_C,
                  ENABLE_DMA_G     => false,
                  LCLSII_G         => LCLSII_C,
                  BUILD_INFO_G     => BUILD_INFO_G )
    port map ( sysClk         => sysClk,
               sysRst         => sysRst,
               -- DMA Interfaces
               dmaClk      (0)=> dmaClk,
               dmaRst      (0)=> dmaRst,
               dmaObMasters   => open,
               dmaObSlaves    => (others=>AXI_STREAM_SLAVE_INIT_C),
               dmaIbMasters(0)=> AXI_STREAM_MASTER_INIT_C,
               dmaIbSlaves (0)=> open,
               -- Application AXI-Lite
               regClk         => regClk,
               regRst         => regRst,
               appReadMaster  => regReadMaster,
               appReadSlave   => regReadSlave,
               appWriteMaster => regWriteMaster,
               appWriteSlave  => regWriteSlave,
               -- Boot Memory Ports
               flashAddr      => flash_address,
               flashData      => flash_data,
               flashOe_n      => flash_noe,
               flashWe_n      => flash_nwe,
               -- I2C
               scl            => scl,
               sda            => sda,
               -- Timing
--               readoutReady   => readoutReady,
               timingRefClkP  => timingRefClkP,
               timingRefClkN  => timingRefClkN,
               timingRxP      => timingRxP,
               timingRxN      => timingRxN,
               timingTxP      => timingTxP,
               timingTxN      => timingTxN,
               timingRecClk   => timingRecClk,
               timingRecClkRst=> timingRecClkRst,
               timingBus      => timingBus,
               exptBus        => exptBus,
               timingFbClk    => timingFbClk,
               timingFbRst    => timingFbRst,
               timingFb       => timingFb,
               -- PCIE Ports
               pciRstL        => pciRstL,
               pciRefClkP     => pciRefClkP,
               pciRefClkN     => pciRefClkN,
               pciRxP         => pciRxP,
               pciRxN         => pciRxN,
               pciTxP         => pciTxP,
               pciTxN         => pciTxN );

  GEN_ADCINP : for i in 0 to NFMC_C-1 generate
    adcInput(0+4*i).clkp <= adr_p(i);
    adcInput(0+4*i).clkn <= adr_n(i);
    adcInput(0+4*i).datap <= aor_p(i) & ad_p(i);
    adcInput(0+4*i).datan <= aor_n(i) & ad_n(i);
    adcInput(1+4*i).clkp <= bdr_p(i);
    adcInput(1+4*i).clkn <= bdr_n(i);
    adcInput(1+4*i).datap <= bor_p(i) & bd_p(i);
    adcInput(1+4*i).datan <= bor_n(i) & bd_n(i);
    adcInput(2+4*i).clkp <= cdr_p(i);
    adcInput(2+4*i).clkn <= cdr_n(i);
    adcInput(2+4*i).datap <= cor_p(i) & cd_p(i);
    adcInput(2+4*i).datan <= cor_n(i) & cd_n(i);
    adcInput(3+4*i).clkp <= ddr_p(i);
    adcInput(3+4*i).clkn <= ddr_n(i);
    adcInput(3+4*i).datap <= dor_p(i) & dd_p(i);
    adcInput(3+4*i).datan <= dor_n(i) & dd_n(i);
  end generate;

  --------------------------
  -- AXI-Lite: Crossbar Core
  --------------------------
  U_XBAR : entity work.AxiLiteCrossbar
    generic map (
      DEC_ERROR_RESP_G   => AXI_RESP_OK_C,
      NUM_SLAVE_SLOTS_G  => 1,
      NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
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

  U_APP : entity work.Application
    generic map ( LCLSII_G => LCLSII_C,
                  DMA_STREAM_CONFIG_G => DMA_AXIS_CONFIG_C,
                  DMA_SIZE_G          => NFMC_C,
                  NFMC_G              => NFMC_C )
    port map (
      fmc_to_cpld      => fmc_to_cpld,
      front_io_fmc     => front_io_fmc,
      --
      clk_to_fpga_p    => clk_to_fpga_p,
      clk_to_fpga_n    => clk_to_fpga_n,
      ext_trigger_p    => ext_trigger_p,
      ext_trigger_n    => ext_trigger_n,
      sync_from_fpga_p => sync_from_fpga_p,
      sync_from_fpga_n => sync_from_fpga_n,
      --
      adcInput         => adcInput,
      --
      pg_m2c           => pg_m2c     (NFMC_C-1 downto 0),
      prsnt_m2c_l      => prsnt_m2c_l(NFMC_C-1 downto 0),
      tst_clks(0)      => pgpCoreClk,
      tst_clks(1)      => pgpAltClk,
      tst_clks(2)      => pgpFabClk,
      tst_clks(7 downto 3) => (others=>'0'),
      --
      axiClk              => regClk,
      axiRst              => regRst,
      axilWriteMaster     => mAxilWriteMasters(0),
      axilWriteSlave      => mAxilWriteSlaves (0),
      axilReadMaster      => mAxilReadMasters (0),
      axilReadSlave       => mAxilReadSlaves  (0),
      -- DMA
      dmaClk              => dmaClk,
      dmaRst              => dmaRst,
      dmaRxIbMaster       => dmaIbMaster,
      dmaRxIbSlave        => dmaIbSlave,
      -- EVR Ports
      evrClk              => timingRecClk,
      evrRst              => timingRecClkRst,
      evrBus              => timingBus,
      exptBus             => exptBus,
--      ready               => readoutReady );
      timingFbClk         => timingFbClk,
      timingFbRst         => timingFbRst,
      timingFb            => timingFb );

  IBUFDS_GTE3_Inst : IBUFDS_GTE3
    generic map (
      REFCLK_EN_TX_PATH  => '0',
      REFCLK_HROW_CK_SEL => "00",    -- 2'b00: ODIV2 = O
      REFCLK_ICNTL_RX    => "00")
    port map (
      I     => pgpRefClkP,
      IB    => pgpRefClkN,
      CEB   => '0',
      ODIV2 => pgpRefClkCopy,
      O     => pgpRefClk);  

  BUFG_GT_Inst : BUFG_GT
    port map (
      I       => pgpRefClkCopy,
      CE      => '1',
      CEMASK  => '1',
      CLR     => '0',
      CLRMASK => '1',
      DIV     => "000",
      O       => pgpCoreClk);

  U_QPLL : entity work.Pgp3GthUsQpll
    generic map ( TPD_G      => 1 ns,
                  EN_DRP_G   => false )
    port map (
      stableClk  => regClk,
      stableRst  => regRst,
      --
      pgpRefClk  => pgpRefClk ,
      qpllLock   => qplllock  ,
      qpllClk    => qpllclk   ,
      qpllRefClk => qpllrefclk,
      qpllRst    => qpllrst    );

  IBUFDS_GTE3_Alt : IBUFDS_GTE3
    generic map (
      REFCLK_EN_TX_PATH  => '0',
      REFCLK_HROW_CK_SEL => "00",    -- 2'b00: ODIV2 = O
      REFCLK_ICNTL_RX    => "00")
    port map (
      I     => pgpAltClkP,
      IB    => pgpAltClkN,
      CEB   => '0',
      ODIV2 => pgpAltClkCopy,
      O     => open );  

  BUFG_GT_Alt : BUFG_GT
    port map (
      I       => pgpAltClkCopy,
      CE      => '1',
      CEMASK  => '1',
      CLR     => '0',
      CLRMASK => '1',
      DIV     => "000",
      O       => pgpAltClk);

  U_IBUFDS_PGP : IBUFDS
    port map (
      I     => pgpFabClkP,
      IB    => pgpFabClkN,
      O     => intFabClk);

  U_BUFG_PGPFAB : BUFG
    port map ( I => intFabClk,
               O => pgpFabClk );

  U_PGP_ILV : entity work.AxiStreamInterleave
    generic map ( LANES_G        => 4,
                  SAXIS_CONFIG_G => DMA_AXIS_CONFIG_C,
                  MAXIS_CONFIG_G => PGP3_AXIS_CONFIG_C )
    port map ( axisClk     => dmaClk,
               axisRst     => dmaRst,
               sAxisMaster => dmaIbMaster(0),
               sAxisSlave  => dmaIbSlave (0),
               mAxisMaster => mDmaMaster,
               mAxisSlave  => mDmaSlave );
               
  GEN_PGP : for i in 0 to 3 generate
    qpllrst(i)(1) <= '0';
    U_Pgp : entity work.Pgp3Hsd
      generic map ( ID_G             => toSlv(3*16+i,8),
                    AXIL_BASE_ADDR_G => AXI_CROSSBAR_MASTERS_CONFIG_C(i+1).baseAddr,
                    AXIS_CONFIG_G    => PGP3_AXIS_CONFIG_C )
      port map ( coreClk         => pgpCoreClk,  -- unused
                 coreRst         => '0',
                 pgpRxP          => pgpRxP(i),
                 pgpRxN          => pgpRxN(i),
                 pgpTxP          => pgpTxP(i),
                 pgpTxN          => pgpTxN(i),
                 fifoRst         => dmaRst,
                 --
                 qplllock        => qplllock  (i)(0),
                 qplloutclk      => qpllclk   (i)(0),
                 qplloutrefclk   => qpllrefclk(i)(0),
                 qpllRst         => qpllrst   (i)(0),
                 --
                 axilClk         => regClk,
                 axilRst         => regRst,
                 axilReadMaster  => mAxilReadMasters (i+1),
                 axilReadSlave   => mAxilReadSlaves  (i+1),
                 axilWriteMaster => mAxilWriteMasters(i+1),
                 axilWriteSlave  => mAxilWriteSlaves (i+1),
                 --
                 --phyRst          => r.phyRst,
                 --txPllRst        => r.pllTxRst(i),
                 --rxPllRst        => r.pllRxRst(i),
                 --txPgpRst        => r.pgpTxRst(i),
                 --rxPgpRst        => r.pgpRxRst(i),
                 --
                 --  App Interface
                 ibRst           => dmaRst,
                 linkUp          => open,
                 rxErr           => open,
                 --
                 obClk           => dmaClk,
                 obMaster        => mDmaMaster(i),
                 obSlave         => mDmaSlave (i) );

  end generate;

  comb : process ( r, regRst, pg_m2c, prsnt_m2c_l, mAxilReadMasters, mAxilWriteMasters ) is
    variable v : RegType;
    variable ep : AxiLiteEndPointType;
  begin
    v := r;

    axiSlaveWaitTxn(ep, mAxilWriteMasters(5), mAxilReadMasters(5), v.axilWriteSlave, v.axilReadSlave);
    ep.axiReadSlave.rdata := (others=>'0');

    axiSlaveRegisterR( ep, toSlv(0,5),  0, prsnt_m2c_l(1));
    axiSlaveRegisterR( ep, toSlv(0,5),  1, pg_m2c     (1));
    axiSlaveRegister ( ep, toSlv(4,5),  0, v.pgpClkEn );
    axiSlaveRegister ( ep, toSlv(4,5),  1, v.usrClkEn );
    axiSlaveRegister ( ep, toSlv(4,5),  2, v.usrClkSel);
    axiSlaveRegister ( ep, toSlv(4,5),  3, v.qsfpRstN);
    axiSlaveRegister ( ep, toSlv(4,5),  4, v.phyRst);
    axiSlaveRegister ( ep, toSlv(4,5), 16, v.pllTxRst);
    axiSlaveRegister ( ep, toSlv(4,5), 20, v.pllRxRst);
    axiSlaveRegister ( ep, toSlv(4,5), 24, v.pgpTxRst);
    axiSlaveRegister ( ep, toSlv(4,5), 28, v.pgpRxRst);

    axiSlaveDefault( ep, v.axilWriteSlave, v.axilReadSlave );

    if regRst='1' then
      v := REG_INIT_C;
    end if;

    r_in <= v;

    mAxilWriteSlaves(5) <= r.axilWriteSlave;
    mAxilReadSlaves (5) <= r.axilReadSlave;
    pgpClkEn    <= r.pgpClkEn ;
    usrClkEn    <= r.usrClkEn ;
    usrClkSel   <= r.usrClkSel;
    qsfpRstN    <= r.qsfpRstN;
  end process;

  seq: process ( regClk ) is
  begin
    if rising_edge(regClk) then
      r <= r_in;
    end if;
  end process;
end rtl;
