-------------------------------------------------------------------------------
-- Title      : QuadAdc Wrapper for AXI PCIe Core
-------------------------------------------------------------------------------
-- File       : AxiPcieQuadAdcCore.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-02-12
-- Last update: 2017-10-26
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'AxiPcieCore'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'AxiPcieCore', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.AxiPciePkg.all;
use work.AxiPcieRegPkg.all;
use work.TimingPkg.all;
use work.I2cPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiPcieQuadAdcCore is
   generic (
      TPD_G            : time                   := 1 ns;
      DRIVER_TYPE_ID_G : slv(31 downto 0)       := x"00000000";
      AXI_APP_BUS_EN_G : boolean                := false;
      DMA_SIZE_G       : positive range 1 to 16 := 1;
      AXIS_CONFIG_G    : AxiStreamConfigArray;
      LCLSII_G         : boolean                := true;
      BUILD_INFO_G     : BuildInfoType );
   port (
      -- System Clock and Reset
      sysClk         : out   sl;        -- 250 MHz
      sysRst         : out   sl;
      -- DMA Interfaces
      dmaClk         : in    slv(DMA_SIZE_G-1 downto 0);
      dmaRst         : in    slv(DMA_SIZE_G-1 downto 0);
      dmaObMasters   : out   AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaObSlaves    : in    AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      dmaIbMasters   : in    AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaIbSlaves    : out   AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      -- (Optional) Application AXI-Lite Interfaces [0x00080000:0x000FFFFF]
      regClk         : out   sl;        -- 125 MHz
      regRst         : out   sl;
      appReadMaster  : out   AxiLiteReadMasterType;
      appReadSlave   : in    AxiLiteReadSlaveType  := AXI_LITE_READ_SLAVE_INIT_C;
      appWriteMaster : out   AxiLiteWriteMasterType;
      appWriteSlave  : in    AxiLiteWriteSlaveType := AXI_LITE_WRITE_SLAVE_INIT_C;
      -- Boot Memory Ports
      flashAddr      : out   slv(25 downto 0);
      flashData      : inout slv(15 downto 0);
      flashOe_n      : out   sl;
      flashWe_n      : out   sl;

      -- I2C
      scl            : inout sl;
      sda            : inout sl;
      
      -- Timing
      timingRefClkP  : in    sl;
      timingRefClkN  : in    sl;
      timingRxP      : in    sl;
      timingRxN      : in    sl;
      timingTxP      : out   sl;
      timingTxN      : out   sl;
      timingRecClk   : out   sl;
      timingRecClkRst: out   sl;
      timingBus      : out   TimingBusType;
      exptBus        : out   ExptBusType;
      timingFbClk    : out   sl;
      timingFbRst    : out   sl;
      timingFb       : in    TimingPhyType;
      
     -- PCIe Ports 
      pciRstL        : in    sl;
      pciRefClkP     : in    sl;
      pciRefClkN     : in    sl;
      pciRxP         : in    slv(7 downto 0);
      pciRxN         : in    slv(7 downto 0);
      pciTxP         : out   slv(7 downto 0);
      pciTxN         : out   slv(7 downto 0));        
end AxiPcieQuadAdcCore;

architecture mapping of AxiPcieQuadAdcCore is

   constant AXI_ERROR_RESP_C : slv(1 downto 0) := AXI_RESP_OK_C;  -- Always return OK to a MMAP()

   signal dmaReadMaster  : AxiReadMasterType;
   signal dmaReadSlave   : AxiReadSlaveType;
   signal dmaWriteMaster : AxiWriteMasterType;
   signal dmaWriteSlave  : AxiWriteSlaveType;

   signal regReadMaster  : AxiReadMasterType;
   signal regReadSlave   : AxiReadSlaveType;
   signal regWriteMaster : AxiWriteMasterType;
   signal regWriteSlave  : AxiWriteSlaveType;

   signal flsReadMaster  : AxiLiteReadMasterType;
   signal flsReadSlave   : AxiLiteReadSlaveType;
   signal flsWriteMaster : AxiLiteWriteMasterType;
   signal flsWriteSlave  : AxiLiteWriteSlaveType;

   signal i2cReadMaster  : AxiLiteReadMasterType;
   signal i2cReadSlave   : AxiLiteReadSlaveType;
   signal i2cWriteMaster : AxiLiteWriteMasterType;
   signal i2cWriteSlave  : AxiLiteWriteSlaveType;

   signal dmaCtrlReadMaster  : AxiLiteReadMasterType;
   signal dmaCtrlReadSlave   : AxiLiteReadSlaveType;
   signal dmaCtrlWriteMaster : AxiLiteWriteMasterType;
   signal dmaCtrlWriteSlave  : AxiLiteWriteSlaveType;

   signal phyReadMaster  : AxiLiteReadMasterType;
   signal phyReadSlave   : AxiLiteReadSlaveType;
   signal phyWriteMaster : AxiLiteWriteMasterType;
   signal phyWriteSlave  : AxiLiteWriteSlaveType;

   signal gthReadMaster  : AxiLiteReadMasterType;
   signal gthReadSlave   : AxiLiteReadSlaveType;
   signal gthWriteMaster : AxiLiteWriteMasterType;
   signal gthWriteSlave  : AxiLiteWriteSlaveType;

   signal timReadMaster  : AxiLiteReadMasterType;
   signal timReadSlave   : AxiLiteReadSlaveType;
   signal timWriteMaster : AxiLiteWriteMasterType;
   signal timWriteSlave  : AxiLiteWriteSlaveType;

   signal timingRefClk   : sl;
   signal timingClk      : sl;
   signal timingClkRst   : sl;
   signal rxStatus       : TimingPhyStatusType;
   signal rxControl      : TimingPhyControlType;
   signal rxUsrClk       : sl;
   signal rxUsrClkActive : sl;
   signal rxData         : slv(15 downto 0);
   signal rxDataK        : slv(1 downto 0);
   signal rxDispErr      : slv(1 downto 0);
   signal rxDecErr       : slv(1 downto 0);
   signal txUsrClk       : sl;
   signal txUsrRst       : sl;
   signal txStatus       : TimingPhyStatusType := TIMING_PHY_STATUS_INIT_C;
   signal loopback       : slv(2 downto 0);

   signal interrupt    : slv(DMA_SIZE_G-1 downto 0);
   
   signal axiClk  : sl;
   signal axiRst  : sl;
   signal axilClk : sl;
   signal axilRst : sl;
   signal dmaIrq  : sl;
   signal dmaIrqAck : sl;
   
   constant DEVICE_MAP_C : I2cAxiLiteDevArray(11 downto 0) := (
     -- PCA9548A I2C Mux
     0 => MakeI2cAxiLiteDevType( "1110100", 8, 0, '0' ),
     -- SI5338 Local clock synthesizer
     1 => MakeI2cAxiLiteDevType( "1110001", 8, 8, '0' ),
     -- Local CPLD
     2 => MakeI2cAxiLiteDevType( "1100000", 8, 8, '0' ),
     -- ADT7411 Voltage/Temp Mon 1
     3 => MakeI2cAxiLiteDevType( "1001000", 8, 8, '0' ),
     -- ADT7411 Voltage/Temp Mon 2
     4 => MakeI2cAxiLiteDevType( "1001010", 8, 8, '0' ),
     -- ADT7411 Voltage/Temp Mon 3
     5 => MakeI2cAxiLiteDevType( "1001011", 8, 8, '0' ),
     --  TPS2481 Current Mon 1
     6 => MakeI2cAxiLiteDevType( "1000000", 8, 8, '0' ),
     --  TPS2481 Current Mon 2
     7 => MakeI2cAxiLiteDevType( "1000001", 8, 8, '0' ),
     --  FMC SPI Bridge [1B addressing, 1B payload]
--     7 => MakeI2cAxiLiteDevType( "0101001", 8, 8, '0' ),
     --  FMC SPI Bridge [1B addressing, 1B payload]
--     8 => MakeI2cAxiLiteDevType( "0101010", 8, 8, '0' ),
     --  FMC SPI Bridge [1B addressing, 1B payload]
--     9 => MakeI2cAxiLiteDevType( "0101011", 8, 8, '0' )
     --  ADT7411 Voltage/Temp Mon FMC
     8 => MakeI2cAxiLiteDevType( "1001000", 8, 8, '0' ),
     --  FMC SPI Bridge configuration
     9 => MakeI2cAxiLiteDevType( "0101000", 8, 8, '0' ),
     --  FMC SPI Bridge [1B addressing, 1B payload]
     10 => MakeI2cAxiLiteDevType( "0101000",16, 8, '0' ),
     --  FMC SPI Bridge [2B addressing, 1B payload]
     11 => MakeI2cAxiLiteDevType( "0101000",24, 8, '0' )
   );                                                        

   signal flash_clk      : sl;
   signal flash_data_in  : slv(15 downto 0);
   signal flash_data_out : slv(15 downto 0);
   signal flash_data_tri : sl;
   signal flash_data_dts : slv(3 downto 0);
   signal flash_nce : sl;

   constant DEBUG_C : boolean := false;

   component ila_0
     port ( clk : in sl;
            probe0 : in slv(255 downto 0) );
   end component;
   
begin

   GEN_DBUG : if DEBUG_C generate
     U_ILA : ila_0
       port map ( clk  => axiClk,
                  probe0(0) => dmaWriteMaster.awvalid,
                  probe0(1) => dmaWriteSlave .awready,
                  probe0(2) => dmaWriteMaster.wvalid,
                  probe0(3) => dmaWriteSlave .wready,
                  probe0(4) => dmaWriteMaster.wlast,
                  probe0(5) => dmaWriteMaster.bready,
                  probe0(6) => dmaWriteSlave .bvalid,
                  probe0( 8 downto  7) => dmaWriteSlave .bresp,
                  probe0(16 downto  9) => dmaWriteMaster.awlen,
                  probe0(48 downto 17) => dmaWriteMaster.awaddr(31 downto 0),
                  probe0(80 downto 49) => dmaWriteMaster.wdata (31 downto 0),

                  probe0(81) => regWriteMaster.awvalid,
                  probe0(82) => regWriteSlave .awready,
                  probe0(83) => regWriteMaster.wvalid,
                  probe0(84) => regWriteSlave .wready,
                  probe0(85) => regWriteMaster.wlast,
                  probe0(86) => regWriteMaster.bready,
                  probe0(87) => regWriteSlave .bvalid,
                  probe0( 89 downto  88) => regWriteSlave .bresp,
                  probe0( 97 downto  90) => regWriteMaster.awlen,
                  probe0(129 downto  98) => regWriteMaster.awaddr(31 downto 0),
                  probe0(161 downto 130) => regWriteMaster.wdata (31 downto 0),
                  
                  probe0(162) => regReadMaster.arvalid,
                  probe0(163) => regReadSlave .arready,
                  probe0(164) => '0',
                  probe0(165) => regReadSlave .rvalid,
                  probe0(166) => '0',
                  probe0(167) => regReadMaster.rready,
                  probe0(168) => regReadSlave .rlast,
                  probe0(170 downto 169) => regReadSlave .rresp,
                  probe0(178 downto 171) => regReadMaster.arlen,
                  probe0(210 downto 179) => regReadMaster.araddr(31 downto 0),
                  probe0(242 downto 211) => regReadSlave .rdata (31 downto 0),

                  probe0(243) => dmaIrq,
                  probe0(244) => dmaIrqAck,

                  probe0(255 downto 245) => (others=>'0') );
   end generate;
   
   sysClk <= axiClk;
   sysRst <= axiRst;
   regClk <= axilClk;
   regRst <= axilRst;
   dmaIrq <= uOr(interrupt);

   ---------------
   -- AXI Lite clk
   ---------------
   --U_AxilClk : entity work.ClockManagerUltraScale
   --  generic map ( INPUT_BUFG_G       => false,
   --                NUM_CLOCKS_G       => 1,
   --                CLKIN_PERIOD_G     => 4.0,
   --                CLKFBOUT_MULT_F_G  => 5.0,
   --                CLKOUT0_DIVIDE_F_G => 10.0 )
   --  port map ( clkIn => axiClk,
   --             rstIn => axiRst,
   --             clkOut(0) => axilClk,
   --             rstOut(0) => axilRst );
   U_Clk : entity work.ClockManagerUltraScale
     generic map ( INPUT_BUFG_G      => false,
                   NUM_CLOCKS_G       => 1,
                   CLKIN_PERIOD_G     => 8.0,
                   CLKFBOUT_MULT_F_G  => 8.0,
                   CLKOUT0_DIVIDE_F_G => 10.0 )
     port map ( clkIn => axiClk,
                rstIn => axiRst,
                clkOut(0) => flash_clk,
                rstOut(0) => open );
                   
   axilClk <= axiClk;
   axilRst <= axiRst;
   
   ---------------
   -- AXI PCIe PHY
   ---------------   
   U_AxiPciePhy : entity work.AxiPcieQuadAdcIpCoreWrapper
      generic map (
         TPD_G => TPD_G)   
      port map (
         -- AXI4 Interfaces
         axiClk         => axiClk,
         axiRst         => axiRst,
         dmaReadMaster  => dmaReadMaster,
         dmaReadSlave   => dmaReadSlave,
         dmaWriteMaster => dmaWriteMaster,
         dmaWriteSlave  => dmaWriteSlave,
         regReadMaster  => regReadMaster,
         regReadSlave   => regReadSlave,
         regWriteMaster => regWriteMaster,
         regWriteSlave  => regWriteSlave,
         phyReadMaster  => phyReadMaster,
         phyReadSlave   => phyReadSlave,
         phyWriteMaster => phyWriteMaster,
         phyWriteSlave  => phyWriteSlave,
         -- Interrupt Interface
         dmaIrq         => dmaIrq,
         dmaIrqAck      => dmaIrqAck,
         -- PCIe Ports 
         pciRstL        => pciRstL,
         pciRefClkP     => pciRefClkP,
         pciRefClkN     => pciRefClkN,
         pciRxP         => pciRxP,
         pciRxN         => pciRxN,
         pciTxP         => pciTxP,
         pciTxN         => pciTxN);

   ---------------
   -- AXI PCIe REG
   --------------- 
   U_REG : entity work.AxiPcieReg
      generic map (
         TPD_G            => TPD_G,
         DRIVER_TYPE_ID_G => DRIVER_TYPE_ID_G,
         AXI_APP_BUS_EN_G => AXI_APP_BUS_EN_G,
--         AXI_CLK_FREQ_G   => 250.0E+6,  -- units of Hz
         AXI_CLK_FREQ_G   => 125.0E+6,  -- units of Hz
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_C,
         XIL_DEVICE_G     => "ULTRASCALE",
         DMA_SIZE_G       => DMA_SIZE_G,
         BUILD_INFO_G     => BUILD_INFO_G )
      port map (
         -- AXI4 Interfaces
         axiClk             => axiClk,
         axiRst             => axiRst,
         regReadMaster      => regReadMaster,
         regReadSlave       => regReadSlave,
         regWriteMaster     => regWriteMaster,
         regWriteSlave      => regWriteSlave,
         -- AXI-Lite Interfaces
         axilClk            => axilClk,
         axilRst            => axilRst,
         -- I2C AXI-Lite Interfaces [0x00008000:0x0000FFFF]
         flsReadMaster      => flsReadMaster,
         flsReadSlave       => flsReadSlave,
         flsWriteMaster     => flsWriteMaster,
         flsWriteSlave      => flsWriteSlave,
         -- I2C AXI-Lite Interfaces [0x00010000:0x0001FFFF]
         i2cReadMaster      => i2cReadMaster,
         i2cReadSlave       => i2cReadSlave,
         i2cWriteMaster     => i2cWriteMaster,
         i2cWriteSlave      => i2cWriteSlave,
         -- DMA AXI-Lite Interfaces [0x00020000:0x0002FFFF]
         dmaCtrlReadMaster  => dmaCtrlReadMaster,
         dmaCtrlReadSlave   => dmaCtrlReadSlave,
         dmaCtrlWriteMaster => dmaCtrlWriteMaster,
         dmaCtrlWriteSlave  => dmaCtrlWriteSlave,
         -- PHY AXI-Lite Interfaces [0x00030000:0x00030FFF]
         phyReadMaster      => phyReadMaster,
         phyReadSlave       => phyReadSlave,
         phyWriteMaster     => phyWriteMaster,
         phyWriteSlave      => phyWriteSlave,
         -- GTH AXI-Lite Interfaces [0x00031000:0x00031FFF]
         gthReadMaster      => gthReadMaster,
         gthReadSlave       => gthReadSlave,
         gthWriteMaster     => gthWriteMaster,
         gthWriteSlave      => gthWriteSlave,
         -- Timing AXI-Lite Interfaces [0x00040000:0x0004FFFF]
         timReadMaster      => timReadMaster,
         timReadSlave       => timReadSlave,
         timWriteMaster     => timWriteMaster,
         timWriteSlave      => timWriteSlave,
         -- (Optional) Application AXI-Lite Interfaces [0x00080000:0x000FFFFF]
         appReadMaster      => appReadMaster,
         appReadSlave       => appReadSlave,
         appWriteMaster     => appWriteMaster,
         appWriteSlave      => appWriteSlave,
         -- Interrupts
         interrupt          => interrupt);

   flash_data_dts               <= (others => flash_data_tri);
   
   U_STARTUPE3 : STARTUPE3
      generic map (
         PROG_USR      => "FALSE",  -- Activate program event security feature. Requires encrypted bitstreams.
         SIM_CCLK_FREQ => 0.0)          -- Set the Configuration Clock Frequency(ns) for simulation
      port map (
         CFGCLK    => open,             -- 1-bit output: Configuration main clock output
         CFGMCLK   => open,  -- 1-bit output: Configuration internal oscillator clock output
         DI        => flash_data_in(3 downto 0),
         EOS       => open,  -- 1-bit output: Active high output signal indicating the End Of Startup.
         PREQ      => open,             -- 1-bit output: PROGRAM request to fabric output         
         DO        => flash_data_out(3 downto 0),
         DTS       => flash_data_dts,
         FCSBO     => flash_nce,
         FCSBTS    => '0',              -- 1-bit input: Tristate the FCS_B pin
         GSR       => '0',  -- 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
         GTS       => '1',  -- 1-bit input: Global 3-state input (GTS cannot be used for the port name)
         KEYCLEARB => '0',  -- 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
         PACK      => '0',              -- 1-bit input: PROGRAM acknowledge input
         USRCCLKO  => flash_clk,        -- 1-bit input: User CCLK input
         USRCCLKTS => '1',              -- 1-bit input: User CCLK 3-state enable input
         USRDONEO  => '0',              -- 1-bit input: User DONE pin output control
         USRDONETS => '1');  -- 1-bit input: User DONE 3-state enable output              

   GEN_FLASH : for i in 4 to 15 generate
     U_IOB : IOBUF
       port map ( I  => flash_data_out(i),
                  O  => flash_data_in (i),
                  IO => flashData     (i),
                  T  => flash_data_tri );
   end generate GEN_FLASH;

   U_FLASH : entity work.parallel_flash_if
     generic map ( START_ADDR => x"0000000",
                   STOP_ADDR  => x"0000020" )
     port map ( flash_clk       => flash_clk,
                axilClk         => axilClk,
                axilRst         => axilRst,
                axilWriteMaster => flsWriteMaster,
                axilWriteSlave  => flsWriteSlave,
                axilReadMaster  => flsReadMaster,
                axilReadSlave   => flsReadSlave,
                flash_address   => flashAddr,
                flash_data_o    => flash_data_out,
                flash_data_i    => flash_data_in ,
                flash_data_tri  => flash_data_tri,
                flash_noe       => flashOe_n,
                flash_nwe       => flashWe_n,
                flash_nce       => flash_nce );
   
   ---------------
   -- AXI PCIe DMA
   ---------------   
   U_AxiPcieDma : entity work.AxiPcieDma
      generic map (
         TPD_G            => TPD_G,
         DMA_SIZE_G       => DMA_SIZE_G,
         USE_IP_CORE_G    => false,
         AXIL_BASE_ADDR_G => DMA_ADDR_C,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_C,
         AXIS_CONFIG_G    => AXIS_CONFIG_G)
      port map (
         -- Clock and reset
         axiClk          => axiClk,
         axiRst          => axiRst,
         -- AXI4 Interfaces
         axiReadMaster   => dmaReadMaster,
         axiReadSlave    => dmaReadSlave,
         axiWriteMaster  => dmaWriteMaster,
         axiWriteSlave   => dmaWriteSlave,
         -- AXI4-Lite Interfaces
         axilReadMaster  => dmaCtrlReadMaster,
         axilReadSlave   => dmaCtrlReadSlave,
         axilWriteMaster => dmaCtrlWriteMaster,
         axilWriteSlave  => dmaCtrlWriteSlave,
         -- Interrupts
         interrupt       => interrupt,
         interruptAck    => dmaIrqAck,
         -- DMA Interfaces
         dmaClk          => dmaClk,
         dmaRst          => dmaRst,
         dmaObMasters    => dmaObMasters,
         dmaObSlaves     => dmaObSlaves,
         dmaIbMasters    => dmaIbMasters,
         dmaIbSlaves     => dmaIbSlaves);

   
   ---------------
   -- Timing
   ---------------   
    TIMING_REFCLK_IBUFDS_GTE3 : IBUFDS_GTE3
      generic map (
         REFCLK_EN_TX_PATH  => '0',
         REFCLK_HROW_CK_SEL => "01",    -- 2'b01: ODIV2 = Divide-by-2 version of O
         REFCLK_ICNTL_RX    => "00")
      port map (
         I     => timingRefClkP,
         IB    => timingRefClkN,
         CEB   => '0',
         ODIV2 => open,
         O     => timingRefClk);

   timingClkRst   <= not(rxStatus.resetDone);

   timingRecClk   <= timingClk;
   timingRecClkRst<= timingClkRst;

   txUsrRst       <= not(txStatus.resetDone);

   rxUsrClk       <= timingClk;
   rxUsrClkActive <= '1';
   
   U_TimingGth : entity work.TimingGthCoreWrapper
      generic map (
         EXTREF_G         => LCLSII_G,  -- because Si5338 can't generate 371MHz
         AXIL_BASE_ADDR_G => GTH_ADDR_C )
      port map (
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => gthReadMaster,
         axilReadSlave   => gthReadSlave,
         axilWriteMaster => gthWriteMaster,
         axilWriteSlave  => gthWriteSlave,
         stableClk       => axilClk,
         gtRefClk        => timingRefClk,
         gtRxP           => timingRxP,
         gtRxN           => timingRxN,
         gtTxP           => timingTxP,
         gtTxN           => timingTxN,
         rxControl       => rxControl,
         rxStatus        => rxStatus,
         rxUsrClkActive  => rxUsrClkActive,
         rxCdrStable     => open,
         rxUsrClk        => rxUsrClk,
         rxData          => rxData,
         rxDataK         => rxDataK,
         rxDispErr       => rxDispErr,
         rxDecErr        => rxDecErr,
         rxOutClk        => timingClk,
         txControl       => timingFb.control,
         txStatus        => txStatus,
         txUsrClk        => txUsrClk,
         txUsrClkActive  => '1',
         txData          => timingFb.data,
         txDataK         => timingFb.dataK,
         txOutClk        => txUsrClk,
         loopback        => loopback);

    TimingCore_1 : entity work.TimingCore
      generic map (
         TPD_G             => TPD_G,
         TPGEN_G           => false,
         ASYNC_G           => false,
         CLKSEL_MODE_G     => "LCLSII",
--         PROG_DELAY_G      => true,
         AXIL_BASE_ADDR_G  => TIM_ADDR_C,
         AXIL_ERROR_RESP_G => AXI_RESP_DECERR_C,
--         AXIL_RINGB        => true,
         USE_TPGMINI_G     => false )
      port map (
         gtTxUsrClk      => txUsrClk,
         gtTxUsrRst      => txUsrRst,
         gtRxRecClk      => timingClk,
         gtRxData        => rxData,
         gtRxDataK       => rxDataK,
         gtRxDispErr     => rxDispErr,
         gtRxDecErr      => rxDecErr,
         gtRxControl     => rxControl,
         gtRxStatus      => rxStatus,
         gtLoopback      => loopback,
         appTimingClk    => timingClk,
         appTimingRst    => timingClkRst,
         appTimingBus    => timingBus,
         exptBus         => exptBus,
         timingPhy       => open,
         timingClkSel    => open,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => timReadMaster,
         axilReadSlave   => timReadSlave,
         axilWriteMaster => timWriteMaster,
         axilWriteSlave  => timWriteSlave);

   timingFbClk <= txUsrClk;
   timingFbRst <= txUsrRst;
   
   --U_TxFb : entity work.DaqControlTx
   --  port map ( txclk          => txUsrClk,
   --             txrst          => txUsrRst,
   --             rxrst          => timingClkRst,
   --             ready          => readoutReady,
   --             data           => timingPhy.data,
   --             dataK          => timingPhy.dataK );
                
   U_I2C : entity work.AxiI2cRegMaster
     generic map ( DEVICE_MAP_G   => DEVICE_MAP_C,
--                   AXI_CLK_FREQ_G => 250.0E+6 )
                   AXI_CLK_FREQ_G => 125.0E+6 )
     port map ( scl            => scl,
                sda            => sda,
                axiReadMaster  => i2cReadMaster,
                axiReadSlave   => i2cReadSlave,
                axiWriteMaster => i2cWriteMaster,
                axiWriteSlave  => i2cWriteSlave,
                axiClk         => axiClk,
                axiRst         => axiRst );
   
end mapping;

