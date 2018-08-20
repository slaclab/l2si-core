library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.math_real.all;
 
library work;
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.TimingExtnPkg.all;
use work.TimingPkg.all;
use work.QuadAdcPkg.all;
 
library unisim;            
use unisim.vcomponents.all;  
-------------------------------------------------------------------------------
-- Configuration IODELAY on data
-- VERSION_625MHz = TRUE    no iodelay
-- VERSION_625MHz = FALSE   iodelay

-------------------------------------------------------------------------------
entity Application is
  generic (
     VERSION_625MHz : boolean := FALSE;
     LCLSII_G       : boolean := TRUE;
     NFMC_G         : integer := 1;
     DMA_SIZE_G     : integer := 1;
     DMA_STREAM_CONFIG_G : AxiStreamConfigType );
  port (
    fmc_to_cpld      : inout Slv4Array(NFMC_G-1 downto 0);
    front_io_fmc     : inout Slv4Array(NFMC_G-1 downto 0);
    clk_to_fpga_p    : in    slv(NFMC_G-1 downto 0);
    clk_to_fpga_n    : in    slv(NFMC_G-1 downto 0);
    ext_trigger_p    : in    slv(NFMC_G-1 downto 0);
    ext_trigger_n    : in    slv(NFMC_G-1 downto 0);
    sync_from_fpga_p : out   slv(NFMC_G-1 downto 0);
    sync_from_fpga_n : out   slv(NFMC_G-1 downto 0);
    adcInput         : in    AdcInputArray(4*NFMC_G-1 downto 0);
    pg_m2c           : in    slv(NFMC_G-1 downto 0);
    prsnt_m2c_l      : in    slv(NFMC_G-1 downto 0);
    tst_clks         : in    slv(7 downto 0) := (others=>'0');
    -- AXI-Lite and IRQ Interface
    axiClk              : in  sl;
    axiRst              : in  sl;
    axilWriteMaster     : in  AxiLiteWriteMasterType;
    axilWriteSlave      : out AxiLiteWriteSlaveType;
    axilReadMaster      : in  AxiLiteReadMasterType;
    axilReadSlave       : out AxiLiteReadSlaveType;
    -- DMA
    dmaClk              : out sl;
    dmaRst              : out sl;
    dmaRxIbMaster       : out AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
    dmaRxIbSlave        : in  AxiStreamSlaveArray (DMA_SIZE_G-1 downto 0);
    -- EVR Ports
    evrClk              : in  sl;
    evrRst              : in  sl;
    evrBus              : in  TimingBusType;
    exptBus             : in  ExptBusType;
--    ready               : out sl );
    timingFbClk         : in  sl;
    timingFbRst         : in  sl;
    timingFb            : out TimingPhyType );
end Application;
 
 
-------------------------------------------------------------------------------
-- architecture
-------------------------------------------------------------------------------
architecture rtl of Application is

  constant NUM_AXI_MASTERS_C : integer := 7;
  constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
    0    => (
      baseAddr        => x"00080000",
      addrBits        => 11,
      connectivity    => x"FFFF"),
    1    => (
      baseAddr        => x"00080800",
      addrBits        => 11,
      connectivity    => x"FFFF"),
    2    => (
      baseAddr        => x"00081000",
      addrBits        => 11,
      connectivity    => x"FFFF"),
    3    => (
      baseAddr        => x"00081800",
      addrBits        => 11,
      connectivity    => x"FFFF"),
    4    => (
      baseAddr        => x"00082000",
      addrBits        => 11,
      connectivity    => x"FFFF"),
    5    => (
      baseAddr        => x"00082800",
      addrBits        => 11,
      connectivity    => x"FFFF"),
    6    => (
      baseAddr        => x"00088000",
      addrBits        => 15,
      connectivity    => x"FFFF") );
  signal mAxilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxilWriteSlaves  : AxiLiteWriteSlaveArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxilReadMasters  : AxiLiteReadMasterArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxilReadSlaves   : AxiLiteReadSlaveArray  (NUM_AXI_MASTERS_C-1 downto 0);

  signal cAxilWriteMasters : AxiLiteWriteMasterArray(2 downto 0);
  signal cAxilWriteSlaves  : AxiLiteWriteSlaveArray (2 downto 0);
  signal cAxilReadMasters  : AxiLiteReadMasterArray (2 downto 0);
  signal cAxilReadSlaves   : AxiLiteReadSlaveArray  (2 downto 0);
  
  signal adcO              : AdcDataArray(4*NFMC_G-1 downto 0);
  signal adcClk            : sl;
  signal adcRst            : sl;
  signal locked            : sl;
  signal phyClk            : slv(NFMC_G-1 downto 0);
  signal idmaClk           : sl;
  signal idmaRst           : sl := '0';
  --signal mmcm_clk          : slv(2 downto 0);
  --signal mmcm_rst          : slv(2 downto 0);
  signal ddrClk            : sl;
  signal ddrClkInv         : sl;
  signal gbClk             : sl;
  signal pllRst            : sl;
  signal pllRefClk         : slv(1 downto 0);
  signal psClk             : slv(1 downto 0);
  signal psEn              : slv(1 downto 0);
  signal psIncDec          : slv(1 downto 0);
  signal psDone            : slv(1 downto 0);
  signal cmd_reg           : Slv4Array(1 downto 0);
  signal calClkEn          : slv(1 downto 0);
  signal calClkEnN         : slv(1 downto 0);
  
  constant SYNC_BITS : integer := 4;
  signal trigSlot          : sl;
  signal trigSel           : sl;
  signal trig              : sl;
  signal adcSin            : slv      (SYNC_BITS-1 downto 0);
  signal adcS              : Slv8Array(SYNC_BITS-1 downto 0);
  --signal adcSdelayLd       : slv      (SYNC_BITS-1 downto 0);
  --signal adcSdelayLdS      : slv      (SYNC_BITS-1 downto 0);
  --signal adcSdelayIn       : Slv9Array(SYNC_BITS-1 downto 0);
  --signal adcSdelayInS      : Slv9Array(SYNC_BITS-1 downto 0);
  --signal adcSdelayOut      : Slv9Array(SYNC_BITS-1 downto 0);
  signal adcSyncRst        : sl;
  signal adcSyncLocked     : sl;
  signal clk_to_fpga       : slv(NFMC_G-1 downto 0);
  
  constant DIVCLK_G : boolean := LCLSII_G;
  
begin  -- rtl

  dmaClk <= idmaClk;
  dmaRst <= idmaRst;

  calClkEnN <= not calClkEn;
  
  GEN_FRONT_IO : for i in 0 to NFMC_G-1 generate
    --U_FRONT_IOBUF0 : IOBUF
      --port map ( O  => open,
      --           IO => front_io_fmc(i)(0),
    U_FRONT_IOBUF0 : OBUFT
      port map ( O  => front_io_fmc(i)(0),
                 I  => pllRefClk(i),
                 T  => '0' );
    --U_FRONT_IOBUF1 : IOBUF
    --  port map ( O  => open,
    --             IO => front_io_fmc(i)(1),
    U_FRONT_IOBUF1 : OBUFT
      port map ( O  => front_io_fmc(i)(1),
                 I  => adcClk,     -- 156.25MHz
                 T  => calClkEnN(i) );

    front_io_fmc(i)(3 downto 2) <= (others => 'Z');
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
      axiClk           => axiClk,
      axiClkRst        => axiRst,
      sAxiWriteMasters(0) => axilWriteMaster,
      sAxiWriteSlaves (0) => axilWriteSlave,
      sAxiReadMasters (0) => axilReadMaster,
      sAxiReadSlaves  (0) => axilReadSlave,
      mAxiWriteMasters => mAxilWriteMasters,
      mAxiWriteSlaves  => mAxilWriteSlaves,
      mAxiReadMasters  => mAxilReadMasters,
      mAxiReadSlaves   => mAxilReadSlaves);

  idmaClk <= adcClk;
  
  U_MMCM : entity work.quadadc_mmcm
    port map ( clk_in1  => phyClk(0),
               clk_out1 => ddrClk,
               clk_out2 => adcClk,
               clk_out3 => open,
               clk_out4 => gbClk,
               psclk    => psClk(0),
               psen     => psEn(0),
               psincdec => psIncDec(0),
               psdone   => psDone(0),
               reset    => '0',
               locked   => locked );

  ddrClkInv <= not ddrClk;
    
  GEN_ADCSYNC : for i in 0 to SYNC_BITS-1 generate
    U_BeamSync_Delay : IDELAYE3
      generic map ( DELAY_SRC              => "DATAIN",
                    CASCADE                => "NONE",
                    DELAY_TYPE             => "VAR_LOAD",   -- FIXED, VARIABLE, or VAR_LOAD
                    DELAY_VALUE            => 0, -- 0 to 31
                    REFCLK_FREQUENCY       => 312.5,
                    DELAY_FORMAT           => "COUNT",
                    UPDATE_MODE            => "ASYNC" )
      port map ( CASC_RETURN            => '0',
                 CASC_IN                => '0',
                 CASC_OUT               => open,
                 CE                     => '0',
                 CLK                    => adcClk,
                 INC                    => '0',
                 --LOAD                   => adcSdelayLdS(i),
                 --CNTVALUEIN             => adcSdelayIn (i),
                 --CNTVALUEOUT            => adcSdelayOut(i),
                 LOAD                   => '0',
                 CNTVALUEIN             => (others=>'0'),
                 CNTVALUEOUT            => open,
                 DATAIN                 => trig,         -- Data from FPGA logic
                 IDATAIN                => '0',          -- Driven by IOB
                 DATAOUT                => adcSin(i),
                 RST                    => '0',
                 EN_VTC                 => '0'
                 );

    U_BeamSync_Serdes : ISERDESE3
      generic map ( DATA_WIDTH        => 8,
                    FIFO_ENABLE       => "FALSE",
                    FIFO_SYNC_MODE    => "FALSE" )
      port map ( CLK               => ddrClk,                     -- Fast Source Synchronous SERDES clock from BUFIO
                 CLK_B             => ddrClkInv,                     -- Locally inverted clock
                 CLKDIV            => adcClk,                            -- Slow clock driven by BUFR
                 D                 => adcSin(i),
                 Q                 => adcS(i),
                 RST               => idmaRst,                           -- 1-bit Asynchronous reset only.
                 FIFO_RD_CLK       => '0',
                 FIFO_RD_EN        => '0',
                 FIFO_EMPTY        => open,
                 INTERNAL_DIVCLK   => open );

    --U_Sync_DelayIn : entity work.SynchronizerVector
    --  generic map ( WIDTH_G => 9 )
    --  port map ( clk     => adcClk,
    --             dataIn  => adcSdelayIn (i),
    --             dataOut => adcSdelayInS(i) );
    
    --U_Sync_DelayLd : entity work.SynchronizerOneShot
    --  port map ( clk     => adcClk,
    --             dataIn  => adcSdelayLd (i),
    --             dataOut => adcSdelayLdS(i) );
    
  end generate GEN_ADCSYNC;

  trig <= trigSel;
  
  U_SyncCal : entity work.AdcSyncCal
    generic map ( SYNC_BITS_G => SYNC_BITS,
                  NFMC_G      => NFMC_G )
    port map (
      axiClk              => axiClk,
      axiRst              => axiRst,
      axilWriteMaster     => mAxilWriteMasters(4),
      axilWriteSlave      => mAxilWriteSlaves (4),
      axilReadMaster      => mAxilReadMasters (4),
      axilReadSlave       => mAxilReadSlaves  (4),
      --
      evrClk              => evrClk,
      evrRst              => evrRst,
      evrBus              => evrBus,
      pllRstIn            => adcSyncRst,
      pllRst              => pllRst,
      adcClk              => clk_to_fpga,
      sync_p              => sync_from_fpga_p,
      sync_n              => sync_from_fpga_n );
      --
      --delayLd             => adcSdelayLd,
      --delayOut            => adcSdelayIn,
      --delayIn             => adcSdelayOut );              

  GEN_DIVCLK : if DIVCLK_G generate
    U_DIVCLK : entity work.HsdDivClk
      generic map ( DIV_G => ite(LCLSII_G, 25, 7) ) -- 929kHz*4
      port map ( ClkIn  => evrClk,
                 RstIn  => evrRst,
                 Sync   => evrBus.strobe,
                 ClkOut => pllRefClk,
                 Locked => adcSyncLocked );
  end generate;

  GEN_MMCM : if not DIVCLK_G generate
    U_MMCM_t : entity work.mmcm_fineps
      -- LCLS   : Fvco = 119M * 10.5 = 1249.5M
      --          Fout = 119M * 10.5/125 = 9.996M
      -- LCLSII : Fvco = 1300M/7 * 6 = 1114.3M
      --          Fout = 1300M/7 * 6/75 = 14-6/7M = 929kHz*16
      generic map ( NUM_CLOCKS_G       => 2,
                    CLKIN_PERIOD_G     => ite(LCLSII_G, 5.37, 8.40),
                    CLKFBOUT_MULT_F_G  => ite(LCLSII_G, 6.0, 10.5),
                    CLKOUT0_DIVIDE_F_G => ite(LCLSII_G, 75.0, 125.0),
                    CLKOUT1_DIVIDE_G   => ite(LCLSII_G, 75  , 125  ) )
      port map ( clkIn          => evrClk,
                 rstIn          => pllRst,
                 clkOut(0)      => pllRefClk(0),
                 clkOut(1)      => pllRefClk(1),
                 rstOut         => open,
                 locked         => adcSyncLocked,
                 psClk          => psClk   (1),
                 psEn           => psEn    (1),
                 psIncDec       => psIncDec(1),
                 psDone         => psDone  (1),
                 axilClk        => axiClk,
                 axilRst        => axiRst,
                 axilReadMaster => mAxilReadMasters (1),
                 axilReadSlave  => mAxilReadSlaves  (1),
                 axilWriteMaster=> mAxilWriteMasters(1),
                 axilWriteSlave => mAxilWriteSlaves (1) );
  end generate;
  
  cAxilWriteMasters(0) <= mAxilWriteMasters(0);
  cAxilReadMasters (0) <= mAxilReadMasters (0);
  mAxilWriteSlaves (0) <= cAxilWriteSlaves (0);
  mAxilReadSlaves  (0) <= cAxilReadSlaves  (0);
  cAxilWriteMasters(1) <= mAxilWriteMasters(6);
  cAxilReadMasters (1) <= mAxilReadMasters (6);
  mAxilWriteSlaves (6) <= cAxilWriteSlaves (1);
  mAxilReadSlaves  (6) <= cAxilReadSlaves  (1);
  cAxilWriteMasters(2) <= mAxilWriteMasters(5);
  cAxilReadMasters (2) <= mAxilReadMasters (5);
  mAxilWriteSlaves (5) <= cAxilWriteSlaves (2);
  mAxilReadSlaves  (5) <= cAxilReadSlaves  (2);
  --cAxilWriteMasters(1) <= AXI_LITE_WRITE_MASTER_INIT_C;
  --cAxilReadMasters (1) <= AXI_LITE_READ_MASTER_INIT_C;
  
  U_Core : entity work.QuadAdcCore
    generic map ( NFMC_G      => NFMC_G,
                  SYNC_BITS_G => SYNC_BITS,
                  BASE_ADDR_C => AXI_CROSSBAR_MASTERS_CONFIG_C(6).baseAddr,
                  DMA_SIZE_G  => DMA_SIZE_G,
                  DMA_STREAM_CONFIG_G => DMA_STREAM_CONFIG_G )
    port map (
      axiClk              => axiClk,
      axiRst              => axiRst,
      axilWriteMasters    => cAxilWriteMasters,
      axilWriteSlaves     => cAxilWriteSlaves ,
      axilReadMasters     => cAxilReadMasters ,
      axilReadSlaves      => cAxilReadSlaves  ,
      -- DMA
      dmaClk              => idmaClk,
      dmaRst              => idmaRst,
      dmaRxIbMaster       => dmaRxIbMaster,
      dmaRxIbSlave        => dmaRxIbSlave ,
      -- EVR Ports
      evrClk              => evrClk,
      evrRst              => evrRst,
      evrBus              => evrBus,
      exptBus             => exptBus,
--      ready               => ready,
      timingFbClk         => timingFbClk,
      timingFbRst         => timingFbRst,
      timingFb            => timingFb,
      -- ADC
      gbClk               => gbClk,
      adcClk              => adcClk,
      adcRst              => adcRst,
      adc                 => adcO,
      fmcClk              => clk_to_fpga,
      --
      trigSlot            => trigSlot,
      trigOut             => trigSel,
      trigIn              => adcS,
      adcSyncRst          => adcSyncRst,
      adcSyncLocked       => adcSyncLocked );

  adcRst <= not locked;

  GEN_FMC : for i in 0 to NFMC_G-1 generate
    U_FMC : entity work.FmcCore
      generic map ( AXIL_BASEADDR => AXI_CROSSBAR_MASTERS_CONFIG_C(2+i).baseAddr )
      port map (
        axilClk          => axiClk,
        axilRst          => axiRst,
        axilWriteMaster  => mAxilWriteMasters(2+i),
        axilWriteSlave   => mAxilWriteSlaves (2+i),
        axilReadMaster   => mAxilReadMasters (2+i),
        axilReadSlave    => mAxilReadSlaves  (2+i),
        cmd_reg_o        => cmd_reg(i),
        cmd_reg_i        => cmd_reg(0),
        
        phy_clk          => phyClk(i),
        ddr_clk          => ddrClk,
        adc_clk          => adcClk,
        adc_out          => adcO(4*i+3 downto 4*i),

        ref_clk          => pllRefClk(0),

        ps_clk           => psClk   (i),
        ps_en            => psEn    (i),
        ps_incdec        => psIncDec(i),
        ps_done          => psDone  (i),
        
        trigger_out      => open,
        irq_out          => open,

        --External signals
        fmc_to_cpld      => fmc_to_cpld(i),

        clk_to_fpga_p    => clk_to_fpga_p(i),
        clk_to_fpga_n    => clk_to_fpga_n(i),
        clk_to_fpga      => clk_to_fpga  (i),
        ext_trigger_p    => ext_trigger_p(i),
        ext_trigger_n    => ext_trigger_n(i),
        sync_from_fpga_p => open,
        sync_from_fpga_n => open,

        adc_in           => adcInput(4*i+3 downto 4*i),

        pg_m2c           => pg_m2c     (i),
        prsnt_m2c_l      => prsnt_m2c_l(i),

        tst_clks         => tst_clks,
        
        cal_clk_en       => calClkEn   (i));
  end generate;

  GEN_NOFMC : if NFMC_G=1 generate
    U_NOFMC : entity work.AxiLiteEmpty
      port map ( axiClk         => axiClk,
                 axiClkRst      => axiRst,
                 axiWriteMaster => mAxilWriteMasters(3),
                 axiWriteSlave  => mAxilWriteSlaves (3),
                 axiReadMaster  => mAxilReadMasters (3),
                 axiReadSlave   => mAxilReadSlaves  (3) );
  end generate;
  
end rtl;
