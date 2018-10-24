
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
entity cmdXX_mux  is
generic (
    XX    : integer := 16
);
port (
    clk           : in  std_logic;
    cmd_s_in      : in  axi32_s;
    cmd_r_in      : out axi32_r;
    cmd_s_out     : out axi32_sbus(XX-1 downto 0);
    cmd_r_out     : in  axi32_rbus(XX-1 downto 0)
);
end entity cmdXX_mux;

-------------------------------------------------------------------------------------
--Architecture declaration
-------------------------------------------------------------------------------------
architecture behav of cmdXX_mux  is

-----------------------------------------------------------------------------------
--signal declarations
-----------------------------------------------------------------------------------
signal axi_arready : std_logic_vector(XX-1 downto 0);
signal axi_awready : std_logic_vector(XX-1 downto 0);
signal axi_wready  : std_logic_vector(XX-1 downto 0);
signal axi_bvalid  : std_logic_vector(XX-1 downto 0);
signal axi_rvalid  : std_logic_vector(XX-1 downto 0);

--*********************************************************************************
begin
--*********************************************************************************

-------------------------------------------------------------------------------------
-- Map each AXI input into a vector so we can use and_reduce / or_reduce
-------------------------------------------------------------------------------------
vector_mapping_gen:
for I in 0 to XX-1 generate
    axi_arready(I) <= cmd_r_out(I).arready;
    axi_awready(I) <= cmd_r_out(I).awready;
    axi_wready(I)  <= cmd_r_out(I).wready;
    axi_bvalid(I)  <= cmd_r_out(I).bvalid;
    axi_rvalid(I)  <= cmd_r_out(I).rvalid;
end generate;

-------------------------------------------------------------------------------------
-- Register outputs to help with timing
-------------------------------------------------------------------------------------
process (cmd_s_in, cmd_r_out, axi_wready, axi_awready, axi_rvalid, axi_bvalid, axi_arready)
    variable axi_rdata   : std_logic_vector(31 downto 0) := (others=>'0');
    variable axi_rresp   : std_logic_vector(1 downto 0)  := (others=>'0');
    variable axi_bresp   : std_logic_vector(1 downto 0)  := (others=>'0');
begin
        -- cmd_in gets sent out each cmd_out
        for I in 0 to XX-1 loop
            cmd_s_out(I).awaddr  <= cmd_s_in.awaddr;
            cmd_s_out(I).awvalid <= cmd_s_in.awvalid;
            cmd_s_out(I).wdata   <= cmd_s_in.wdata;
            cmd_s_out(I).wstrb   <= cmd_s_in.wstrb;
            cmd_s_out(I).wvalid  <= cmd_s_in.wvalid;
            cmd_s_out(I).bready  <= cmd_s_in.bready;
            cmd_s_out(I).araddr  <= cmd_s_in.araddr;
            cmd_s_out(I).arvalid <= cmd_s_in.arvalid;
            cmd_s_out(I).rready  <= cmd_s_in.rready;
        end loop;

        -- sequential statements to or vectors together
        axi_rdata := cmd_r_out(0).rdata;
        axi_bresp := cmd_r_out(0).bresp;
        axi_rresp := cmd_r_out(0).rresp;
        for x in 1 to XX-1 loop
            axi_rdata    := cmd_r_out(x).rdata or axi_rdata;
            axi_bresp    := cmd_r_out(x).bresp or axi_bresp;
            axi_rresp    := cmd_r_out(x).rresp or axi_rresp;
        end loop;

        -- the replies from all cmd_outs are or'ed,
        -- we are assuming only one block will respond
        cmd_r_in.wready   <= or_reduce(axi_wready);
        cmd_r_in.awready  <= or_reduce(axi_awready);
        cmd_r_in.rvalid   <= or_reduce(axi_rvalid);
        cmd_r_in.bvalid   <= or_reduce(axi_bvalid);
        cmd_r_in.arready  <= or_reduce(axi_arready);
        cmd_r_in.rdata    <= axi_rdata;
        cmd_r_in.bresp    <= axi_bresp;
        cmd_r_in.rresp    <= axi_rresp;

end process;

--*********************************************************************************
end architecture behav;
--*********************************************************************************
