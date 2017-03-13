library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.math_real.all;
 
library work;
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
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
     LCLSII_G       : boolean := TRUE );
  port (
    fmc_to_cpld      : inout slv(3 downto 0);
    front_io_fmc     : inout slv(3 downto 0);
    clk_to_fpga_p    : in    sl;
    clk_to_fpga_n    : in    sl;
    ext_trigger_p    : in    sl;
    ext_trigger_n    : in    sl;
    sync_from_fpga_p : out   sl;
    sync_from_fpga_n : out   sl;
    adcInput         : in    AdcInputArray(3 downto 0);
    pg_m2c           : in    sl;
    prsnt_m2c_l      : in    sl;
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
    dmaRxIbMaster       : out AxiStreamMasterType;
    dmaRxIbSlave        : in  AxiStreamSlaveType;
    -- EVR Ports
    evrClk              : in  sl;
    evrRst              : in  sl;
    evrBus              : in  TimingBusType;
    exptBus             : in  ExptBusType;
    ready               : out sl );
end Application;
 
 
-------------------------------------------------------------------------------
-- architecture
-------------------------------------------------------------------------------
architecture rtl of Application is

  constant NUM_AXI_MASTERS_C : integer := 4;
  constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
    0    => (
      baseAddr        => x"00080000",
      addrBits        => 11,
      connectivity    => x"FFFF"),
    1    => (
      baseAddr        => x"00080800",
      addrBits        => 10,
      connectivity    => x"FFFF"),
    2    => (
      baseAddr        => x"00081000",
      addrBits        => 12,
      connectivity    => x"FFFF"),
    3    => (
      baseAddr        => x"00082000",
      addrBits        => 12,
      connectivity    => x"FFFF") );
  signal mAxilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxilWriteSlaves  : AxiLiteWriteSlaveArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxilReadMasters  : AxiLiteReadMasterArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxilReadSlaves   : AxiLiteReadSlaveArray  (NUM_AXI_MASTERS_C-1 downto 0);

  signal adcO              : AdcDataArray(3 downto 0);
  signal adcClk            : sl;
  signal adcRst            : sl;
  signal locked            : sl;
  signal phyClk            : sl;
  signal idmaClk           : sl;
  signal idmaRst           : sl := '0';
  --signal mmcm_clk          : slv(2 downto 0);
  --signal mmcm_rst          : slv(2 downto 0);
  signal ddrClk            : sl;
  signal ddrClkInv         : sl;
  signal gbClk             : sl;
  signal pllRefClk         : sl;
  signal psClk             : sl;
  signal psEn              : sl;
  signal psIncDec          : sl;
  signal psDone            : sl;

  constant SYNC_BITS : integer := 4;
  signal trigSlot          : sl;
  signal trigSel           : sl;
  signal trig              : sl;
  signal adcSin            : slv      (SYNC_BITS-1 downto 0);
  signal adcS              : Slv8Array(SYNC_BITS-1 downto 0);
  signal adcSdelayLd       : slv      (SYNC_BITS-1 downto 0);
  signal adcSdelayLdS      : slv      (SYNC_BITS-1 downto 0);
  signal adcSdelayIn       : Slv9Array(SYNC_BITS-1 downto 0);
  signal adcSdelayInS      : Slv9Array(SYNC_BITS-1 downto 0);
  signal adcSdelayOut      : Slv9Array(SYNC_BITS-1 downto 0);
  signal adcSyncRst        : sl;
  signal adcSyncLocked     : sl;

begin  -- rtl

  dmaClk <= idmaClk;
  dmaRst <= idmaRst;

  U_FRONT_IOBUF0 : IOBUF
    port map ( O  => open,
               IO => front_io_fmc(0),
               I  => pllRefClk,
               T  => '0' );

  front_io_fmc(3 downto 1) <= (others => 'Z');
  
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
    port map ( clk_in1  => phyClk,
               clk_out1 => ddrClk,
               clk_out2 => adcClk,
               clk_out3 => open,
               clk_out4 => gbClk,
               psclk    => psClk,
               psen     => psEn,
               psincdec => psIncDec,
               psdone   => psDone,
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
                 LOAD                   => adcSdelayLdS(i),
                 CNTVALUEIN             => adcSdelayIn (i),
                 CNTVALUEOUT            => adcSdelayOut(i),
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
                 RST               => '0',                           -- 1-bit Asynchronous reset only.
                 FIFO_RD_CLK       => '0',
                 FIFO_RD_EN        => '0',
                 FIFO_EMPTY        => open,
                 INTERNAL_DIVCLK   => open );

    U_Sync_DelayIn : entity work.SynchronizerVector
      generic map ( WIDTH_G => 9 )
      port map ( clk     => adcClk,
                 dataIn  => adcSdelayIn (i),
                 dataOut => adcSdelayInS(i) );
    
    U_Sync_DelayLd : entity work.SynchronizerOneShot
      port map ( clk     => adcClk,
                 dataIn  => adcSdelayLd (i),
                 dataOut => adcSdelayLdS(i) );
    
  end generate GEN_ADCSYNC;

  U_SyncCal : entity work.AdcSyncCal
    generic map ( SYNC_BITS_G => SYNC_BITS )
    port map (
      axiClk              => axiClk,
      axiRst              => axiRst,
      axilWriteMaster     => mAxilWriteMasters(3),
      axilWriteSlave      => mAxilWriteSlaves (3),
      axilReadMaster      => mAxilReadMasters (3),
      axilReadSlave       => mAxilReadSlaves  (3),
      --
      evrClk              => evrClk,
      trigSlot            => trigSlot,
      trigSel             => trigSel,
      trigOut             => trig,
      --
      syncClk             => adcClk,
      sync                => adcS,
      delayLd             => adcSdelayLd,
      delayOut            => adcSdelayIn,
      delayIn             => adcSdelayOut );              

  --adcClk  <= mmcm_clk(0);
  --idmaClk <= mmcm_clk(1);
  --idmaRst <= mmcm_rst(1);
  --gbClk   <= mmcm_clk(2);

  --U_MMCM : entity work.ClockManagerUltraScale
  --  generic map ( NUM_CLOCKS_G      => 3,
  --                CLKIN_PERIOD_G    => 1.6,  -- PHY 6.4, LCLS-I 8.40, LCLS-II 5.37
  --                CLKFBOUT_MULT_F_G => 2.0,  -- PHY 8,   LCLS-I 10,   LCLS-II 6
  --                CLKOUT0_DIVIDE_G  => 8,    -- (156.25M, 148.75M, 139.3M)
  --                CLKOUT1_DIVIDE_G  => 10,   -- (125M   , 119.00M, 111.4M)
  --                CLKOUT2_DIVIDE_G  => 40 )  -- (31.25M ,  29.75M,  27.9M)
  --  port map ( clkIn          => phyClk,
  --             rstIn          => '0',
  --             clkOut         => mmcm_clk,
  --             rstOut         => mmcm_rst,
  --             locked         => locked,
  --             axilClk        => axiClk,
  --             axilRst        => axiRst,
  --             axilReadMaster => mAxilReadMasters (1),
  --             axilReadSlave  => mAxilReadSlaves  (1),
  --             axilWriteMaster=> mAxilWriteMasters(1),
  --             axilWriteSlave => mAxilWriteSlaves (1) );
    
  U_MMCM_t : entity work.ClockManagerUltraScale
    -- LCLS   : Fvco = 119M * 10.5 = 1249.5M
    --          Fout = 119M * 10.5/125 = 9.996M
    -- LCLSII : Fvco = 1300M/7 * 6 = 1114.3M
    --          Fout = 1300M/7 * 6/75 = 14-7/8M
    generic map ( NUM_CLOCKS_G       => 1,
                  CLKIN_PERIOD_G     => ite(LCLSII_G, 5.37, 8.40),
                  CLKFBOUT_MULT_F_G  => ite(LCLSII_G, 6.0, 10.5),
                  CLKOUT0_DIVIDE_F_G => ite(LCLSII_G, 75.0, 125.0))
    port map ( clkIn          => evrClk,
               rstIn          => adcSyncRst,
               clkOut(0)      => pllRefClk,
               rstOut         => open,
               locked         => adcSyncLocked,
               axilClk        => axiClk,
               axilRst        => axiRst,
               axilReadMaster => mAxilReadMasters (1),
               axilReadSlave  => mAxilReadSlaves  (1),
               axilWriteMaster=> mAxilWriteMasters(1),
               axilWriteSlave => mAxilWriteSlaves (1) );
    
  U_Core : entity work.QuadAdcCore
    generic map ( LCLSII_G    => LCLSII_G,
                  SYNC_BITS_G => SYNC_BITS )
    port map (
      axiClk              => axiClk,
      axiRst              => axiRst,
      axilWriteMaster     => mAxilWriteMasters(0),
      axilWriteSlave      => mAxilWriteSlaves (0),
      axilReadMaster      => mAxilReadMasters (0),
      axilReadSlave       => mAxilReadSlaves  (0),
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
      ready               => ready,
      -- ADC
      gbClk               => gbClk,
      adcClk              => adcClk,
      adcRst              => adcRst,
      adc                 => adcO,
      --
      trigSlot            => trigSlot,
      trigOut             => trigSel,
      trigIn              => adcS,
      adcSyncRst          => adcSyncRst,
      adcSyncLocked       => adcSyncLocked );

  adcRst <= not locked;
  
  U_FMC : entity work.FmcCore
    port map (
      axilClk          => axiClk,
      axilRst          => axiRst,
      axilWriteMaster  => mAxilWriteMasters(2),
      axilWriteSlave   => mAxilWriteSlaves (2),
      axilReadMaster   => mAxilReadMasters (2),
      axilReadSlave    => mAxilReadSlaves  (2),

      phy_clk          => phyClk,
      ddr_clk          => ddrClk,
      adc_clk          => adcClk,
      adc_out          => adcO,

      ref_clk          => pllRefClk,

      ps_clk           => psClk,
      ps_en            => psEn,
      ps_incdec        => psIncDec,
      ps_done          => psDone,
      
      trigger_out      => open,
      irq_out          => open,

      --External signals
      fmc_to_cpld      => fmc_to_cpld,

      clk_to_fpga_p    => clk_to_fpga_p,
      clk_to_fpga_n    => clk_to_fpga_n,
      ext_trigger_p    => ext_trigger_p,
      ext_trigger_n    => ext_trigger_n,
      sync_from_fpga_p => sync_from_fpga_p,
      sync_from_fpga_n => sync_from_fpga_n,

      adc_in           => adcInput,

      pg_m2c           => pg_m2c,
      prsnt_m2c_l      => prsnt_m2c_l );

end rtl;
