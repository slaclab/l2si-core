-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'L2SI Core'. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'L2SI Core', including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library unisim;
use unisim.vcomponents.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity JtagBridgeWrapper is
   port (
      ----------------------
      -- Top Level Interface
      ----------------------
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end JtagBridgeWrapper;

architecture mapping of JtagBridgeWrapper is

   component jtag_bridge
      port (
         s_axi_aclk    : in  std_logic;
         s_axi_aresetn : in  std_logic;
         tap_tdi       : out std_logic;
         tap_tdo       : in  std_logic;
         tap_tms       : out std_logic;
         tap_tck       : out std_logic;
         S_AXI_araddr  : in  std_logic_vector(4 downto 0);
         S_AXI_arprot  : in  std_logic_vector(2 downto 0);
         S_AXI_arready : out std_logic;
         S_AXI_arvalid : in  std_logic;
         S_AXI_awaddr  : in  std_logic_vector(4 downto 0);
         S_AXI_awprot  : in  std_logic_vector(2 downto 0);
         S_AXI_awready : out std_logic;
         S_AXI_awvalid : in  std_logic;
         S_AXI_bready  : in  std_logic;
         S_AXI_bresp   : out std_logic_vector(1 downto 0);
         S_AXI_bvalid  : out std_logic;
         S_AXI_rdata   : out std_logic_vector(31 downto 0);
         S_AXI_rready  : in  std_logic;
         S_AXI_rresp   : out std_logic_vector(1 downto 0);
         S_AXI_rvalid  : out std_logic;
         S_AXI_wdata   : in  std_logic_vector(31 downto 0);
         S_AXI_wready  : out std_logic;
         S_AXI_wstrb   : in  std_logic_vector(3 downto 0);
         S_AXI_wvalid  : in  std_logic
         );
   end component;

   signal aresetn : sl;

   signal tck, tdi, tdo, tms : sl;

begin

   aresetn <= not axilRst;

   U_Jtag : MASTER_JTAG
      port map (tdo => tdo,
                tdi => tdi,
                tms => tms,
                tck => tck);

   U_JtagBridge : jtag_bridge
      port map (s_axi_aclk    => axilClk,
                s_axi_aresetn => aresetn,
                tap_tdi       => tdi,
                tap_tdo       => tdo,
                tap_tms       => tms,
                tap_tck       => tck,
                S_AXI_araddr  => axilReadMaster .araddr(4 downto 0),
                S_AXI_arprot  => axilReadMaster .arprot,
                S_AXI_arready => axilReadSlave .arready,
                S_AXI_arvalid => axilReadMaster .arvalid,
                S_AXI_awaddr  => axilWriteMaster.awaddr(4 downto 0),
                S_AXI_awprot  => axilWriteMaster.awprot,
                S_AXI_awready => axilWriteSlave .awready,
                S_AXI_awvalid => axilWriteMaster.awvalid,
                S_AXI_bready  => axilWriteMaster.bready,
                S_AXI_bresp   => axilWriteSlave .bresp,
                S_AXI_bvalid  => axilWriteSlave .bvalid,
                S_AXI_rdata   => axilReadSlave .rdata,
                S_AXI_rready  => axilReadMaster .rready,
                S_AXI_rresp   => axilReadSlave .rresp,
                S_AXI_rvalid  => axilReadSlave .rvalid,
                S_AXI_wdata   => axilWriteMaster.wdata,
                S_AXI_wready  => axilWriteSlave .wready,
                S_AXI_wstrb   => axilWriteMaster.wstrb,
                S_AXI_wvalid  => axilWriteMaster.wvalid
                );

end mapping;
