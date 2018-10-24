-------------------------------------------------------------------------------------
-- FILE NAME : 
-- AUTHOR    : Luis F. Munoz
-- COMPANY   : 
-- UNITS     : Entity       - 
--             Architecture - Behavioral
-- LANGUAGE  : VHDL
-- DATE      : 
-------------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------------
-- DESCRIPTION
-- ===========
-- 
-- 
--
-------------------------------------------------------------------------------------
 
-------------------------------------------------------------------------------------
-- LIBRARIES
-------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.std_logic_unsigned.all;
    use ieee.std_logic_misc.all;
    use ieee.std_logic_arith.all; 
Library UNISIM;
    use UNISIM.vcomponents.all;

library xil_defaultlib;
   use xil_defaultlib.types_pkg.all; 
-------------------------------------------------------------------------------------
-- ENTITY
-------------------------------------------------------------------------------------
entity intrc_ctrl is
generic (
  private_start_addr_gen    : std_logic_vector(27 downto 0);
  private_stop_addr_gen     : std_logic_vector(27 downto 0)
);
port (
   reset_out        : out std_logic;
   s_axi_aresetn    : in  std_logic;
   s_axi_aclk       : in  std_logic;
   s00_s_axi  	    : in  axi32_s;
   s00_r_axi        : out axi32_r;
   cmd_reg          : out std_logic_vector(31 downto 0);
   queue_cnt_in     : in  std_logic_vector(31 downto 0);
   isr_in           : in std_logic_vector(31 downto 0);
   ier_out          : out std_logic_vector(31 downto 0);
   isr_rd_out       : out std_logic
);
end intrc_ctrl;

-------------------------------------------------------------------------------------
-- ARCHITECTURE
-------------------------------------------------------------------------------------
architecture Behavioral of intrc_ctrl is

-------------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------------
constant ADDR_REG0 : std_logic_vector(31 downto 0) := x"00000000"; 
constant ADDR_REG1 : std_logic_vector(31 downto 0) := x"00000001";
constant ADDR_REG2 : std_logic_vector(31 downto 0) := x"00000002";
constant ADDR_REG3 : std_logic_vector(31 downto 0) := x"00000003";
constant ADDR_REG4 : std_logic_vector(31 downto 0) := x"00000004";
constant ADDR_REG5 : std_logic_vector(31 downto 0) := x"00000005";
constant ADDR_REG6 : std_logic_vector(31 downto 0) := x"00000006";
constant ADDR_REG7 : std_logic_vector(31 downto 0) := x"00000007";

-------------------------------------------------------------------------------------
-- SIGNALS
-------------------------------------------------------------------------------------
signal out_reg_val      : std_logic;
signal out_reg_addr     : std_logic_vector(27 downto 0);
signal out_reg          : std_logic_vector(31 downto 0);
signal in_reg_req       : std_logic;
signal in_reg_addr      : std_logic_vector(27 downto 0);
signal in_reg_val       : std_logic;
signal in_reg           : std_logic_vector(31 downto 0);
signal rst              : std_logic;
signal wr_ack           : std_logic;
signal register_map     : bus032(3 downto 0);

--***********************************************************************************
begin
--***********************************************************************************

reset_out       <= rst;
cmd_reg         <= register_map(0);
ier_out         <= register_map(2);

--------------------------------------------------------------------------------------
-- AXI command interface
---------------------------------------------------------------------------------------
inst_axi_cmd:
entity xil_defaultlib.axi_cmd
generic map (
   START_ADDR    =>   private_start_addr_gen,
   STOP_ADDR     =>   private_stop_addr_gen
)
port map (
   -- axi-lite command interface
   s_axi_aclk       =>  s_axi_aclk,
   s_axi_aresetn    =>  s_axi_aresetn,
   s_axi_awaddr     =>  s00_s_axi.awaddr,
   s_axi_awvalid    =>  s00_s_axi.awvalid,
   s_axi_awready    =>  s00_r_axi.awready,
   s_axi_wdata      =>  s00_s_axi.wdata,
   s_axi_wstrb      =>  s00_s_axi.wstrb,
   s_axi_wvalid     =>  s00_s_axi.wvalid,
   s_axi_wready     =>  s00_r_axi.wready,
   s_axi_bresp      =>  s00_r_axi.bresp,
   s_axi_bvalid     =>  s00_r_axi.bvalid,
   s_axi_bready     =>  s00_s_axi.bready,
   s_axi_araddr     =>  s00_s_axi.araddr,
   s_axi_arvalid    =>  s00_s_axi.arvalid,
   s_axi_arready    =>  s00_r_axi.arready,
   s_axi_rdata      =>  s00_r_axi.rdata,
   s_axi_rresp      =>  s00_r_axi.rresp,
   s_axi_rvalid     =>  s00_r_axi.rvalid,
   s_axi_rready     =>  s00_s_axi.rready,

   o_rst            => rst, -- local reset
   out_wr_ack       => wr_ack,
   out_reg_val      => out_reg_val, 
   out_reg_addr     => out_reg_addr, 
   out_reg          => out_reg, 
   in_reg           => in_reg, 
   in_reg_val       => in_reg_val, 
   in_reg_req       => in_reg_req, 
   in_reg_addr      => in_reg_addr
);

----------------------------------------------------------------------------------------------------
-- Register Map
-- 0x0 - Command Registe, Write/Read ,Self-Clearing, Read Constant
-- 0x1 - ISR  (read only)
-- 0x2 - IER 
-- 0x3 - Number of interrupts in queue (read only)
----------------------------------------------------------------------------------------------------
process (rst, s_axi_aclk)
begin
    if (rst = '1') then
        in_reg_val      <= '0';
        in_reg          <= (others => '0');
        register_map(0) <= (others=>'0'); -- cmd reg
        register_map(1) <= (others=>'0'); -- isr
        register_map(2) <= (others=>'1'); -- ier (all enable by default)
        register_map(3) <= (others=>'0'); -- queue
        wr_ack          <= '0';
        isr_rd_out      <= '0';

    elsif (rising_edge(s_axi_aclk)) then
        ------------------------------------------------------------
        -- Write
        ------------------------------------------------------------
        -- Self-Clearing Register
        if (out_reg_val = '1' and out_reg_addr = ADDR_REG0) then
            register_map(0) <= out_reg;
        else
            register_map(0) <= (others=>'0');
        end if;

        if (out_reg_val = '1' and out_reg_addr = ADDR_REG2) then
            register_map(2) <= out_reg;
        end if;

        if out_reg_val = '1' then
            wr_ack <= '1';
        else
            wr_ack <= '0';
        end if;

        ------------------------------------------------------------
        -- Read
        ------------------------------------------------------------
        if (in_reg_req = '1' and in_reg_addr = ADDR_REG0) then
            in_reg_val  <= '1';
            in_reg      <= x"01234567"; --constant
        elsif (in_reg_req = '1' and in_reg_addr = ADDR_REG1) then
            in_reg_val  <= '1';
            in_reg      <= isr_in; 
            isr_rd_out  <= '1';    -- clear current interrupt
        elsif (in_reg_req = '1' and in_reg_addr = ADDR_REG2) then
            in_reg_val  <= '1';
            in_reg      <= register_map(2); --ier
       elsif (in_reg_req = '1' and in_reg_addr = ADDR_REG3) then
            in_reg_val  <= '1';
            in_reg      <= queue_cnt_in;
        else
            in_reg_val  <= '0';
            in_reg      <= in_reg;
            isr_rd_out  <= '0'; --default
        end if;


    end if;
end process;

--***********************************************************************************
end architecture Behavioral;
--***********************************************************************************

