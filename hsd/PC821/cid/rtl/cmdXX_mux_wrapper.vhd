
-------------------------------------------------------------------------------------
-- FILE NAME :
--
-- AUTHOR    : Luis F. Munoz
--
-- COMPANY   : 4DSP
--
-- ITEM      : 1
--
-- UNITS     : Entity       -
--             architecture - arch_sip_cmd10_mux
--
-- LANGUAGE  : VHDL
--
-------------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------------
-- DESCRIPTION
-- ===========
-- AXI4-Lite Command Aggregate
--
-- Notes:
-------------------------------------------------------------------------------------
--  Disclaimer: LIMITED WARRANTY AND DISCLAIMER. These designs are
--              provided to you as is.  4DSP specifically disclaims any
--              implied warranties of merchantability, non-infringement, or
--              fitness for a particular purpose. 4DSP does not warrant that
--              the functions contained in these designs will meet your
--              requirements, or that the operation of these designs will be
--              uninterrupted or error free, or that defects in the Designs
--              will be corrected. Furthermore, 4DSP does not warrant or
--              make any representations regarding use or the results of the
--              use of the designs in terms of correctness, accuracy,
--              reliability, or otherwise.
--
--              LIMITATION OF LIABILITY. In no event will 4DSP or its
--              licensors be liable for any loss of data, lost profits, cost
--              or procurement of substitute goods or services, or for any
--              special, incidental, consequential, or indirect damages
--              arising from the use or operation of the designs or
--              accompanying documentation, however caused and on any theory
--              of liability. This limitation will apply even if 4DSP
--              has been advised of the possibility of such damage. This
--              limitation shall apply not-withstanding the failure of the
--              essential purpose of any limited remedies herein.
--
----------------------------------------------
--
-------------------------------------------------------------------------------------
----------------------------------------------
--
-------------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------------
--library declaration
-------------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all ;
  use ieee.std_logic_arith.all ;
  use ieee.std_logic_unsigned.all ;
  use ieee.std_logic_misc.all ;

library xil_defaultlib;
  use xil_defaultlib.types_pkg.all;

-------------------------------------------------------------------------------------
--Entity Declaration
-------------------------------------------------------------------------------------
entity cmdXX_mux_wrapper  is
generic (
  XX          : integer := 12;
  start_addr  : std_logic_vector(27 downto 0);
  stop_addr   : std_logic_vector(27 downto 0)
);
port (
  clk         : in  std_logic;
  rstn        : in  std_logic;
  cmd_s_in    : in  axi32_s;
  cmd_r_in    : out axi32_r;
  cmd_s_out   : out axi32_sbus(XX-1 downto 0);
  cmd_r_out   : in  axi32_rbus(XX-1 downto 0)
);
end entity cmdXX_mux_wrapper;

-------------------------------------------------------------------------------------
--Architecture declaration
-------------------------------------------------------------------------------------
architecture behav of cmdXX_mux_wrapper  is

-----------------------------------------------------------------------------------
--signal declarations
-----------------------------------------------------------------------------------
signal s_axi_awprot      : std_logic_vector(2 downto 0);
signal s_axi_arprot      : std_logic_vector(2 downto 0);

signal cmd_s_in_sliced   : axi32_s;
signal cmd_r_in_sliced   : axi32_r;

signal write_addr_valid  : std_logic;
signal write_data_valid  : std_logic;
signal read_addr_valid   : std_logic;

signal rd_is_valid       : std_logic;
signal wr_is_valid       : std_logic;
signal wr_is_valid_latch : std_logic;

signal cmd_r_in_awready  : std_logic;
signal cmd_r_in_wready   : std_logic;
signal cmd_r_in_arready  : std_logic;

--*********************************************************************************
begin
--*********************************************************************************

wr_is_valid      <= '1' when cmd_s_in.awaddr(27 downto 0) >= start_addr and cmd_s_in.awaddr(27 downto 0) <= stop_addr else '0';

write_addr_valid <= cmd_s_in.awvalid when wr_is_valid = '1' else '0';
cmd_r_in.awready <= cmd_r_in_awready when wr_is_valid = '1' else '0';

write_data_valid <= cmd_s_in.wvalid  when wr_is_valid = '1' or wr_is_valid_latch = '1' else '0';
cmd_r_in.wready  <= cmd_r_in_wready  when wr_is_valid = '1' or wr_is_valid_latch = '1' else '0';

process (rstn, clk)
begin
  if rstn = '0' then
    wr_is_valid_latch <= '0';
  elsif rising_edge(clk) then
    if wr_is_valid_latch = '0' and write_addr_valid = '1' and write_data_valid = '0' then
      wr_is_valid_latch <= '1';
    end if;
    if wr_is_valid_latch = '1' and write_data_valid = '1' then
      wr_is_valid_latch <= '0';
    end if;
  end if;
end process;

rd_is_valid      <= '1' when cmd_s_in.araddr(27 downto 0) >= start_addr and cmd_s_in.araddr(27 downto 0) <= stop_addr else '0';
read_addr_valid  <= cmd_s_in.arvalid when rd_is_valid = '1' else '0';
cmd_r_in.arready <= cmd_r_in_arready when rd_is_valid = '1' else '0';

axi_slice_in_0: entity work.axi_register_slice
port map (
  aclk            => clk,
  aresetn         => rstn,
  s_axi_awaddr    => cmd_s_in.awaddr,
  s_axi_awprot    => s_axi_awprot,
  s_axi_awvalid   => write_addr_valid,
  s_axi_awready   => cmd_r_in_awready,
  s_axi_wdata     => cmd_s_in.wdata,
  s_axi_wstrb     => cmd_s_in.wstrb,
  s_axi_wvalid    => write_data_valid,
  s_axi_wready    => cmd_r_in_wready,
  s_axi_bresp     => cmd_r_in.bresp,
  s_axi_bvalid    => cmd_r_in.bvalid,
  s_axi_bready    => cmd_s_in.bready,
  s_axi_araddr    => cmd_s_in.araddr,
  s_axi_arprot    => s_axi_arprot,
  s_axi_arvalid   => read_addr_valid,
  s_axi_arready   => cmd_r_in_arready,
  s_axi_rdata     => cmd_r_in.rdata,
  s_axi_rresp     => cmd_r_in.rresp,
  s_axi_rvalid    => cmd_r_in.rvalid,
  s_axi_rready    => cmd_s_in.rready,
  m_axi_awaddr    => cmd_s_in_sliced.awaddr,
  m_axi_awprot    => open,
  m_axi_awvalid   => cmd_s_in_sliced.awvalid,
  m_axi_awready   => cmd_r_in_sliced.awready,
  m_axi_wdata     => cmd_s_in_sliced.wdata,
  m_axi_wstrb     => cmd_s_in_sliced.wstrb,
  m_axi_wvalid    => cmd_s_in_sliced.wvalid,
  m_axi_wready    => cmd_r_in_sliced.wready,
  m_axi_bresp     => cmd_r_in_sliced.bresp,
  m_axi_bvalid    => cmd_r_in_sliced.bvalid,
  m_axi_bready    => cmd_s_in_sliced.bready,
  m_axi_araddr    => cmd_s_in_sliced.araddr,
  m_axi_arprot    => open,
  m_axi_arvalid   => cmd_s_in_sliced.arvalid,
  m_axi_arready   => cmd_r_in_sliced.arready,
  m_axi_rdata     => cmd_r_in_sliced.rdata,
  m_axi_rresp     => cmd_r_in_sliced.rresp,
  m_axi_rvalid    => cmd_r_in_sliced.rvalid,
  m_axi_rready    => cmd_s_in_sliced.rready
);

s_axi_awprot <= (others=>'0');
s_axi_arprot <= (others=>'0');


-------------------------------------------------------------------------------------
-- Local command mux
-------------------------------------------------------------------------------------
cmd_mux_inst0:
entity work.cmdXX_mux
generic map (
  XX        => XX
)
port map (
  clk       => clk,
  cmd_s_in  => cmd_s_in_sliced,
  cmd_r_in  => cmd_r_in_sliced,
  cmd_s_out => cmd_s_out(XX-1 downto 0),
  cmd_r_out => cmd_r_out(XX-1 downto 0)
);


--*********************************************************************************
end architecture behav;
--*********************************************************************************

