-------------------------------------------------------------------------------------
-- FILE NAME : 
-- AUTHOR    : Luis F. Munoz
-- COMPANY   : 4DSP
-- UNITS     : Entity       - 
--             Architecture - Behavioral
-- LANGUAGE  : VHDL
-- DATE      : 
-------------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------------
-- DESCRIPTION
-- ===========
-- AXI 16 Input Interrupt controller
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
entity intrc16 is
generic (
  private_start_addr_gen    : std_logic_vector(27 downto 0);
  private_stop_addr_gen     : std_logic_vector(27 downto 0)
);
port (
   s00_axi_aresetn    : in  std_logic;
   s00_axi_aclk       : in  std_logic;
   s00_s_axi  	      : in  axi32_s;
   s00_r_axi          : out axi32_r;
   irq_in             : in  std_logic_vector(15 downto 0);
   irq_out            : out std_logic
);
end intrc16;

-------------------------------------------------------------------------------------
-- ARCHITECTURE
-------------------------------------------------------------------------------------
architecture Behavioral of intrc16 is

-------------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------------
constant START_ADDR_IRQ      : std_logic_vector(27 downto 0) := PRIVATE_START_ADDR_GEN + x"0000000";
constant STOP_ADDR_IRQ       : std_logic_vector(27 downto 0) := PRIVATE_START_ADDR_GEN + x"0000007"; 

constant START_ADDR_IPCTRL   : std_logic_vector(27 downto 0) := PRIVATE_START_ADDR_GEN + x"0000008";
constant STOP_ADDR_IPCTRL    : std_logic_vector(27 downto 0) := PRIVATE_START_ADDR_GEN + x"000000F";

constant NUM_INTERRUPTS : natural := 16;


-------------------------------------------------------------------------------------
-- SIGNALS
-------------------------------------------------------------------------------------
signal irq_vector   : std_logic_vector(NUM_INTERRUPTS-1 downto 0);
signal isr          : std_logic_vector(31 downto 0);
signal isr_rd       : std_logic;
signal queue_cnt    : std_logic_vector(31 downto 0);
signal cmd_reg      : std_logic_vector(31 downto 0);
signal ier_out      : std_logic_vector(31 downto 0);
signal intr_rst     : std_logic;
signal rst          : std_logic;

signal cmd_s_out     : axi32_sbus(1 downto 0);
signal cmd_r_out     : axi32_rbus(1 downto 0);

--***********************************************************************************
begin
--***********************************************************************************

--------------------------------------------------------------------------------------
-- AXI4-Lite Command MUX
---------------------------------------------------------------------------------------
cmd2_mux_inst0:
entity work.cmdXX_mux_wrapper
generic map (
    XX   => 2,
    start_addr => private_start_addr_gen,
    stop_addr  => private_stop_addr_gen
)
port map (
    clk        	 => s00_axi_aclk,
    rstn         => s00_axi_aresetn,
    cmd_s_in     => s00_s_axi,
    cmd_r_in     => s00_r_axi,
    cmd_s_out    => cmd_s_out(1 downto 0),
    cmd_r_out    => cmd_r_out(1 downto 0)
);

--------------------------------------------------------------------------------------
-- Interrupt Generator and Status Block
---------------------------------------------------------------------------------------
irq_intrc_inst0:
entity work.irq_ctrl
generic map (
  private_start_addr_gen => START_ADDR_IRQ,
  private_stop_addr_gen  => STOP_ADDR_IRQ
)
port map (
   irq_bus_in      => conv_std_logic_vector(0,32),
   irq_out         => open,
   s_axi_aresetn   => s00_axi_aresetn,
   s_axi_aclk      => s00_axi_aclk,
   s00_s_axi  	   => cmd_s_out(0),
   s00_r_axi       => cmd_r_out(0)
);


--------------------------------------------------------------------------------------
-- IP Block Controller. Register map to control this IP Entity (4DSP Star).
---------------------------------------------------------------------------------------
intrc_ctrl_inst0:
entity work.intrc_ctrl
generic map (
  private_start_addr_gen => START_ADDR_IPCTRL,
  private_stop_addr_gen  => STOP_ADDR_IPCTRL
)
port map (
   reset_out       => rst, -- local reset 
   s_axi_aresetn   => s00_axi_aresetn,
   s_axi_aclk      => s00_axi_aclk,
   s00_s_axi  	   => cmd_s_out(1),
   s00_r_axi       => cmd_r_out(1),
   cmd_reg         => cmd_reg,   -- self clearing ctrl reg
   ier_out         => ier_out,   -- register enable register
   queue_cnt_in    => queue_cnt, -- interrupt in queue cnt
   isr_in          => isr,       -- actual interrupt data to read
   isr_rd_out      => isr_rd     -- finished reading signal
);

--------------------------------------------------------------------------------------
-- Receive interrupts and queue them
---------------------------------------------------------------------------------------
intrcXX_inst0:
entity work.intrcXX 
generic map (
    NUM_INTERRUPTS  => NUM_INTERRUPTS
)
port map (
   clk            => s00_axi_aclk,
   rst            => intr_rst,
   irq_in         => irq_vector,
   irq_out        => irq_out, 
   isr_out        => isr,
   isr_rd_in      => isr_rd,
   queue_cnt_out  => queue_cnt
);

irq_vector  <= irq_in(15 downto 0) and ier_out(15 downto 0);
intr_rst    <= rst or cmd_reg(0);

--***********************************************************************************
end architecture Behavioral;
--***********************************************************************************

