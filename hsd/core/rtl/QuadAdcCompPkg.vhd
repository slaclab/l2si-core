------------------------------------------------------------------------------
-- This file is part of 'L2SI-CORE'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'L2SI-CORE', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library work;
use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;

package QuadAdcCompPkg is
  component QuadAdcChannelFifov2
    generic ( BASE_ADDR_C : slv(31 downto 0) := x"00000000" );
    port (
      clk             :  in sl;
      rst             :  in sl;
      start           :  in sl;
      shift           :  in slv       (2 downto 0);
      din             :  in Slv11Array(7 downto 0);
      cfgen           : out slv       (3 downto 0);
      l1a             : out slv       (3 downto 0);
      l1v             : out slv       (3 downto 0);
      -- readout interface
      axisMaster      : out AxiStreamMasterType;
      axisSlave       :  in AxiStreamSlaveType;
      -- configuration interface
      axilClk         :  in sl;
      axilRst         :  in sl;
      axilReadMaster  :  in AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster :  in AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType );
  end component;

  component hsd_fex_wrapper
    generic ( AXIS_CONFIG_G : AxiStreamConfigType );
    port (
      clk             :  in sl;
      rst             :  in sl;
      din             :  in Slv11Array(7 downto 0);
      lopen           :  in sl;
      lclose          :  in sl;
      lphase          :  in slv(2 downto 0);
      l1in            :  in sl;
      l1ina           :  in sl;
      free            : out slv(15 downto 0);
      nfree           : out slv( 4 downto 0);
      -- readout interface
      axisMaster      : out AxiStreamMasterType;
      axisSlave       :  in AxiStreamSlaveType;
      -- configuration interface
      axilReadMaster  :  in AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster :  in AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType );
  end component;

  component hsd_fex
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
  end component;


end QuadAdcCompPkg;

package body QuadAdcCompPkg is
end package body QuadAdcCompPkg;

