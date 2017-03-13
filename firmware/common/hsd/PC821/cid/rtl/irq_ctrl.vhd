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
-- Generic Interrupt Request Block
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
entity irq_ctrl is
generic (
  private_start_addr_gen    : std_logic_vector(27 downto 0);
  private_stop_addr_gen     : std_logic_vector(27 downto 0)
);
port (
   irq_bus_in       : in  std_logic_vector(31 downto 0);
   irq_out          : out std_logic;
   s_axi_aresetn    : in  std_logic;
   s_axi_aclk       : in  std_logic;
   s00_s_axi        : in  axi32_s;
   s00_r_axi        : out axi32_r
);
end irq_ctrl;

-------------------------------------------------------------------------------------
-- ARCHITECTURE
-------------------------------------------------------------------------------------
architecture Behavioral of irq_ctrl is

-------------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------------
constant ADDR_ISR  : std_logic_vector(31 downto 0) := x"00000000";
constant ADDR_IER  : std_logic_vector(31 downto 0) := x"00000001";
constant ADDR_SSR  : std_logic_vector(31 downto 0) := x"00000002";
constant ADDR_REG3 : std_logic_vector(31 downto 0) := x"00000003"; -- reserved
constant ADDR_REG4 : std_logic_vector(31 downto 0) := x"00000004"; -- reserved
constant ADDR_REG5 : std_logic_vector(31 downto 0) := x"00000005"; -- reserved
constant ADDR_REG6 : std_logic_vector(31 downto 0) := x"00000006"; -- reserved
constant ADDR_REG7 : std_logic_vector(31 downto 0) := x"00000007"; -- reserved

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

signal irq_reg          : std_logic_vector(31 downto 0);
signal irq_en_reg       : std_logic_vector(31 downto 0);

--***********************************************************************************
begin
--***********************************************************************************

--------------------------------------------------------------------------------------
-- AXI command interface
---------------------------------------------------------------------------------------
inst_axi_cmd: entity xil_defaultlib.axi_cmd
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
-- Registers
----------------------------------------------------------------------------------------------------
process (rst, s_axi_aclk)
begin
    if (rst = '1') then
        in_reg_val  <= '0';
        in_reg      <= (others => '0');
        wr_ack      <= '0';

        irq_reg     <= (others=>'0');
        irq_en_reg  <= (others=>'0');
        irq_out     <= '0';

    elsif (rising_edge(s_axi_aclk)) then

        ------------------------------------------------------------
        -- Write Section
        ------------------------------------------------------------
        if (out_reg_val = '1' and out_reg_addr = ADDR_IER) then
            -- Interrupt Enable Register
            -- 32 possible interrupts, 1 means enabled, 0 means disabled.
            irq_en_reg  <= out_reg;
        end if;

        if out_reg_val = '1' then
            wr_ack <= '1';
        else
            wr_ack <= '0';
        end if;

        ------------------------------------------------------------
        -- Read Section
        ------------------------------------------------------------
        if (in_reg_req = '1' and in_reg_addr = ADDR_ISR) then
            in_reg_val        <= '1';
            in_reg            <= (irq_bus_in) or irq_reg;
            irq_reg           <= (others=>'0'); --clear interrupts when read
        elsif (in_reg_req = '1' and in_reg_addr = ADDR_IER) then
            in_reg_val        <= '1';
            in_reg            <= irq_en_reg;
       elsif (in_reg_req = '1' and in_reg_addr = ADDR_SSR) then
            in_reg_val        <= '1';
            -- Storage Space Register
            -- BIT[ 2: 0] - 0 Byte, 1 Kilobyte, 2 Megabyte, 3 Gigabyte, 4 Terabyte
            -- BIT[13: 3] - Input Storage Size
            -- BIT[24:14] - Output Storage Size
            -- BIT[32:15] - Reserved
            in_reg(2  downto  0) <= (others=>'0');
            in_reg(13 downto  3) <= (others=>'0');
            in_reg(24 downto 14) <= (others=>'0');
            in_reg(31 downto 25) <= (others=>'0');
        elsif (in_reg_req = '1' and (in_reg_addr >= ADDR_REG3 and in_reg_addr <= ADDR_REG7)) then
            in_reg_val        <= '1';
            in_reg            <= (others => '0');
        else
            in_reg_val        <= '0';
            in_reg            <= in_reg;
            irq_reg           <= (irq_bus_in) or irq_reg;
        end if;

        irq_out <= or_reduce(irq_reg and irq_en_reg);

    end if;
end process;

--***********************************************************************************
end architecture Behavioral;
--***********************************************************************************

