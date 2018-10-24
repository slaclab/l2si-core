-------------------------------------------------------------------------------------
-- FILE NAME : 
-- AUTHOR    : Luis
-- COMPANY   : 
-- UNITS     : Entity       - 
--             Architecture - Behavioral
-- LANGUAGE  : VHDL
-- DATE      : AUG 21, 2015
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

-------------------------------------------------------------------------------------
-- ENTITY
-------------------------------------------------------------------------------------
entity ext_trigger is
port (
    clk_in                 : in  std_logic;
    ext_trigger_p          : in  std_logic;
    ext_trigger_n          : in  std_logic;
    sw_trigger             : in  std_logic;
    trigger_select         : in  std_logic_vector(1 downto 0);
    ext_trigger            : out std_logic
);
end ext_trigger;

-------------------------------------------------------------------------------------
-- ARCHITECTURE
-------------------------------------------------------------------------------------
architecture Behavioral of ext_trigger is

-------------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------------
 
-------------------------------------------------------------------------------------
-- SIGNALS
-------------------------------------------------------------------------------------
signal ext_trigger_buf  : std_logic;
signal ext_trigger_reg0 : std_logic;
signal ext_trigger_reg1 : std_logic;

--***********************************************************************************
begin
--***********************************************************************************

ext_trigger <= ext_trigger_reg1;

-- double register input
process (clk_in)
begin
  if (rising_edge(clk_in)) then
    if(trigger_select = "00") then
      ext_trigger_reg0    <= ext_trigger_buf;
      ext_trigger_reg1    <= ext_trigger_reg0;
    else
      ext_trigger_reg0    <= sw_trigger;
      ext_trigger_reg1    <= ext_trigger_reg0;
    end if;
  end if;
end process;

-- xilinx lvds input
ibufds_trig : ibufds
generic map (
  IOSTANDARD => "LVDS_25",
  DIFF_TERM => TRUE
)
port map (
  i  => ext_trigger_p,
  ib => ext_trigger_n,
  o  => ext_trigger_buf
);


--***********************************************************************************
end architecture Behavioral;
--***********************************************************************************

