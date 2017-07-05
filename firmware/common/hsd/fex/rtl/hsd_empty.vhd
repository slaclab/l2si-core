library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity hsd_empty is
  generic (
    C_S_AXI_BUS_A_ADDR_WIDTH : INTEGER := 5;
    C_S_AXI_BUS_A_DATA_WIDTH : INTEGER := 32 );
  port (
    ap_start : IN STD_LOGIC;
    ap_done : OUT STD_LOGIC;
    ap_idle : OUT STD_LOGIC;
    ap_ready : OUT STD_LOGIC;
    sync  : IN STD_LOGIC;
    x0_V : IN STD_LOGIC_VECTOR (10 downto 0);
    x1_V : IN STD_LOGIC_VECTOR (10 downto 0);
    x2_V : IN STD_LOGIC_VECTOR (10 downto 0);
    x3_V : IN STD_LOGIC_VECTOR (10 downto 0);
    x4_V : IN STD_LOGIC_VECTOR (10 downto 0);
    x5_V : IN STD_LOGIC_VECTOR (10 downto 0);
    x6_V : IN STD_LOGIC_VECTOR (10 downto 0);
    x7_V : IN STD_LOGIC_VECTOR (10 downto 0);
    y0_V : OUT STD_LOGIC_VECTOR (15 downto 0);
    y1_V : OUT STD_LOGIC_VECTOR (15 downto 0);
    y2_V : OUT STD_LOGIC_VECTOR (15 downto 0);
    y3_V : OUT STD_LOGIC_VECTOR (15 downto 0);
    y4_V : OUT STD_LOGIC_VECTOR (15 downto 0);
    y5_V : OUT STD_LOGIC_VECTOR (15 downto 0);
    y6_V : OUT STD_LOGIC_VECTOR (15 downto 0);
    y7_V : OUT STD_LOGIC_VECTOR (15 downto 0);
    t0_V : OUT STD_LOGIC_VECTOR (13 downto 0);
    t1_V : OUT STD_LOGIC_VECTOR (13 downto 0);
    t2_V : OUT STD_LOGIC_VECTOR (13 downto 0);
    t3_V : OUT STD_LOGIC_VECTOR (13 downto 0);
    t4_V : OUT STD_LOGIC_VECTOR (13 downto 0);
    t5_V : OUT STD_LOGIC_VECTOR (13 downto 0);
    t6_V : OUT STD_LOGIC_VECTOR (13 downto 0);
    t7_V : OUT STD_LOGIC_VECTOR (13 downto 0);
    yv_V : OUT STD_LOGIC_VECTOR (3 downto 0);
    s_axi_BUS_A_AWVALID : IN STD_LOGIC;
    s_axi_BUS_A_AWREADY : OUT STD_LOGIC;
    s_axi_BUS_A_AWADDR : IN STD_LOGIC_VECTOR (C_S_AXI_BUS_A_ADDR_WIDTH-1 downto 0);
    s_axi_BUS_A_WVALID : IN STD_LOGIC;
    s_axi_BUS_A_WREADY : OUT STD_LOGIC;
    s_axi_BUS_A_WDATA : IN STD_LOGIC_VECTOR (C_S_AXI_BUS_A_DATA_WIDTH-1 downto 0);
    s_axi_BUS_A_WSTRB : IN STD_LOGIC_VECTOR (C_S_AXI_BUS_A_DATA_WIDTH/8-1 downto 0);
    s_axi_BUS_A_ARVALID : IN STD_LOGIC;
    s_axi_BUS_A_ARREADY : OUT STD_LOGIC;
    s_axi_BUS_A_ARADDR : IN STD_LOGIC_VECTOR (C_S_AXI_BUS_A_ADDR_WIDTH-1 downto 0);
    s_axi_BUS_A_RVALID : OUT STD_LOGIC;
    s_axi_BUS_A_RREADY : IN STD_LOGIC;
    s_axi_BUS_A_RDATA : OUT STD_LOGIC_VECTOR (C_S_AXI_BUS_A_DATA_WIDTH-1 downto 0);
    s_axi_BUS_A_RRESP : OUT STD_LOGIC_VECTOR (1 downto 0);
    s_axi_BUS_A_BVALID : OUT STD_LOGIC;
    s_axi_BUS_A_BREADY : IN STD_LOGIC;
    s_axi_BUS_A_BRESP : OUT STD_LOGIC_VECTOR (1 downto 0);
    ap_clk : IN STD_LOGIC;
    ap_rst_n : IN STD_LOGIC );
end hsd_empty;

architecture rtl of hsd_empty is

  signal rst              : sl;
  signal axilReadMaster   : AxiLiteReadMasterType := AXI_LITE_READ_MASTER_INIT_C;
  signal axilReadSlave    : AxiLiteReadSlaveType;
  signal axilWriteMaster  : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
  signal axilWriteSlave   : AxiLiteWriteSlaveType;
begin

  ap_done  <= ap_start;
  ap_idle  <= '1';
  ap_ready <= '1';

  y0_V <= (others=>'0');
  y1_V <= (others=>'0');
  y2_V <= (others=>'0');
  y3_V <= (others=>'0');
  y4_V <= (others=>'0');
  y5_V <= (others=>'0');
  y6_V <= (others=>'0');
  y7_V <= (others=>'0');
  t0_V <= (others=>'1');
  t1_V <= (others=>'0');
  t2_V <= (others=>'0');
  t3_V <= (others=>'0');
  t4_V <= (others=>'0');
  t5_V <= (others=>'0');
  t6_V <= (others=>'0');
  t7_V <= (others=>'0');

  yv_V <= x"0" when sync='0' else
          x"1";
  
  rst <= ap_rst_n;

  axilWriteMaster.awvalid            <= s_axi_BUS_A_AWVALID;
  axilWriteMaster.awaddr(4 downto 0) <= s_axi_BUS_A_AWADDR;
  axilWriteMaster.wvalid             <= s_axi_BUS_A_WVALID;
  axilWriteMaster.wdata              <= s_axi_BUS_A_WDATA;
  axilWriteMaster.wstrb(3 downto 0)  <= s_axi_BUS_A_WSTRB;

  axilReadMaster .arvalid            <= s_axi_BUS_A_ARVALID;
  axilReadMaster .araddr(4 downto 0) <= s_axi_BUS_A_ARADDR;
  axilReadMaster .rready             <= s_axi_BUS_A_RREADY;
  axilWriteMaster.bready             <= s_axi_BUS_A_BREADY;

  s_axi_BUS_A_BVALID  <= axilWriteSlave .bvalid;
  s_axi_BUS_A_BRESP   <= axilWriteSlave .bresp;
  s_axi_BUS_A_AWREADY <= axilWriteSlave .awready;
  s_axi_BUS_A_WREADY  <= axilWriteSlave .wready;

  s_axi_BUS_A_ARREADY <= axilReadSlave  .arready;
  s_axi_BUS_A_RVALID  <= axilReadSlave  .rvalid;
  s_axi_BUS_A_RDATA   <= axilReadSlave  .rdata;
  s_axi_BUS_A_RRESP   <= axilReadSlave  .rresp;
  
  U_Axi : entity work.AxiLiteEmpty
    port map ( axiClk         => ap_clk,
               axiClkRst      => rst,
               axiReadMaster  => axilReadMaster,
               axiReadSlave   => axilReadSlave,
               axiWriteMaster => axilWriteMaster,
               axiWriteSlave  => axilWriteSlave );

end rtl;
