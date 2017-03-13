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
use work.TimingPkg.all;
use work.TPGPkg.all;
 
library unisim;            
use unisim.vcomponents.all;  
-------------------------------------------------------------------------------
-- Configuration IODELAY on data
-- VERSION_625MHz = TRUE    no iodelay
-- VERSION_625MHz = FALSE   iodelay

-------------------------------------------------------------------------------
entity hsd is
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
    -- ADC Interface
    fmc_to_cpld      : inout slv(3 downto 0);
    front_io_fmc     : inout slv(3 downto 0);
    --
    clk_to_fpga_p    : in    sl;
    clk_to_fpga_n    : in    sl;
    ext_trigger_p    : in    sl;
    ext_trigger_n    : in    sl;
    sync_from_fpga_p : out   sl;
    sync_from_fpga_n : out   sl;
    --
    adr_p            : in    sl;              -- serdes clk
    adr_n            : in    sl;
    ad_p             : in    slv(9 downto 0); -- data
    ad_n             : in    slv(9 downto 0);
    aor_p            : in    sl;              -- out-of-range
    aor_n            : in    sl;
    --
    bdr_p            : in    sl;
    bdr_n            : in    sl;
    bd_p             : in    slv(9 downto 0);
    bd_n             : in    slv(9 downto 0);
    bor_p            : in    sl;
    bor_n            : in    sl;
    --
    cdr_p            : in    sl;
    cdr_n            : in    sl;
    cd_p             : in    slv(9 downto 0);
    cd_n             : in    slv(9 downto 0);
    cor_p            : in    sl;
    cor_n            : in    sl;
    --
    ddr_p            : in    sl;
    ddr_n            : in    sl;
    dd_p             : in    slv(9 downto 0);
    dd_n             : in    slv(9 downto 0);
    dor_p            : in    sl;
    dor_n            : in    sl;
    --
    pg_m2c           : in    sl;
    prsnt_m2c_l      : in    sl );
end hsd;
 
 
-------------------------------------------------------------------------------
-- architecture
-------------------------------------------------------------------------------
architecture rtl of hsd is

  --  Set timing specific clock parameters
  constant LCLSII_C : boolean := false;
  
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

  signal dmaIbMaster    : AxiStreamMasterType;
  signal dmaIbSlave     : AxiStreamSlaveType;
  
  constant DMA_AXIS_CONFIG_C : AxiStreamConfigArray(0 downto 0) := (
    others=> (
     TSTRB_EN_C    => false,
     TDATA_BYTES_C => 32,
     TDEST_BITS_C  => 0,
     TID_BITS_C    => 0,
     TKEEP_MODE_C  => TKEEP_NORMAL_C,
     TUSER_BITS_C  => 0,
     TUSER_MODE_C  => TUSER_NORMAL_C ));

  constant SIM_TIMING : boolean := false;
  
  signal tpgData           : TimingRxType := TIMING_RX_INIT_C;
  signal readoutReady      : sl;

  signal adcInput : AdcInputArray(3 downto 0);
  
  component ila_0
    port ( clk    : in sl;
           probe0 : in slv(255 downto 0));
  end component;
-------------------------------------------------------------------------------
-- architecture begin
-------------------------------------------------------------------------------
begin  -- rtl

  timingTxDis <= '0';
  
  --dmaClk <= sysClk;
  --dmaRst <= sysRst;
  
  U_Core : entity work.AxiPcieQuadAdcCore
    generic map ( AXI_APP_BUS_EN_G => true,
                  AXIS_CONFIG_G    => DMA_AXIS_CONFIG_C,
                  LCLSII_G         => LCLSII_C )
    port map ( sysClk         => sysClk,
               sysRst         => sysRst,
               -- DMA Interfaces
               dmaClk      (0)=> dmaClk,
               dmaRst      (0)=> dmaRst,
               dmaObMasters   => open,
               dmaObSlaves    => (others=>AXI_STREAM_SLAVE_INIT_C),
               dmaIbMasters(0)=> dmaIbMaster,
               dmaIbSlaves (0)=> dmaIbSlave,
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
               readoutReady   => readoutReady,
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
               -- PCIE Ports
               pciRstL        => pciRstL,
               pciRefClkP     => pciRefClkP,
               pciRefClkN     => pciRefClkN,
               pciRxP         => pciRxP,
               pciRxN         => pciRxN,
               pciTxP         => pciTxP,
               pciTxN         => pciTxN );

  adcInput(0).clkp <= adr_p;
  adcInput(0).clkn <= adr_n;
  adcInput(0).datap <= aor_p & ad_p;
  adcInput(0).datan <= aor_n & ad_n;
  adcInput(1).clkp <= bdr_p;
  adcInput(1).clkn <= bdr_n;
  adcInput(1).datap <= bor_p & bd_p;
  adcInput(1).datan <= bor_n & bd_n;
  adcInput(2).clkp <= cdr_p;
  adcInput(2).clkn <= cdr_n;
  adcInput(2).datap <= cor_p & cd_p;
  adcInput(2).datan <= cor_n & cd_n;
  adcInput(3).clkp <= ddr_p;
  adcInput(3).clkn <= ddr_n;
  adcInput(3).datap <= dor_p & dd_p;
  adcInput(3).datan <= dor_n & dd_n;
  
  U_APP : entity work.Application
    generic map ( LCLSII_G => LCLSII_C )
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
      pg_m2c           => pg_m2c,
      prsnt_m2c_l      => prsnt_m2c_l,
      --
      axiClk              => regClk,
      axiRst              => regRst,
      axilWriteMaster     => regWriteMaster,
      axilWriteSlave      => regWriteSlave,
      axilReadMaster      => regReadMaster,
      axilReadSlave       => regReadSlave,
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
      ready               => readoutReady );

end rtl;
