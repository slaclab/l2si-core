----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:01:39 04/25/2014 
-- Design Name: 
-- Module Name:    iodelay_set - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
  use IEEE.STD_LOGIC_1164.ALL;
  use IEEE.STD_LOGIC_ARITH.ALL;
  use IEEE.STD_LOGIC_UNSIGNED.ALL;
	
-- Xilinx specific libraries...
library unisim;
use unisim.vcomponents.all;

-------------------------------------------------------------------------------------
--Entity declaration
-------------------------------------------------------------------------------------
entity iodelay_set is
port (
	-- synchronous reset for the auxiliary clock
	RST_AUX 			 	 : in std_logic;     
	-- slower clock for use by less critical components
	CLK_AUX 			 	 : in std_logic;
	-- is the IDELAY controller ready
	IDELAYCTRL_READY   : in std_logic;
	-- idelay value to set (2**9 = 512)
	DELAY_VALUE 	 	 : in std_logic_vector(8 downto 0);
	-- connect directly to iodelay
	IDELAY_CE			 : out std_logic; -- enable iodelay change
	IDLEAY_VALUEOUT	 : in  std_logic_vector(8 downto 0);
	IDELAY_INC			 : out std_logic -- determine if we are going to increase or decrease
    
);
end iodelay_set;

-------------------------------------------------------------------------------------
--Architecture declaration
-------------------------------------------------------------------------------------
architecture Behavioral of iodelay_set is


-------------------------------------------------------------------------------------
--Constants declaration
-------------------------------------------------------------------------------------
type   prog_state_type is ( prog_idle, prog_s1, delay0, delay1, delay2, delay3, delay4 );

-------------------------------------------------------------------------------------
--Signal declaration
-------------------------------------------------------------------------------------
signal delay_value_reg 	: std_logic_VECTOR(8 downto 0); -- desired value
signal delay_adj_reg 	: std_logic_VECTOR(8 downto 0); -- current value
signal delay_adj_ctr 	: std_logic_VECTOR(8 downto 0); -- abs(current value - current value)

signal prog_state 		: prog_state_type;

signal local_rst			: std_logic;
signal local_rst0			: std_logic;

--******************************************************************************************
begin
--******************************************************************************************



--process (RST_AUX, CLK_AUX )
--begin	
--	if rising_edge(CLK_AUX) then
--		local_rst0 	<= RST_AUX;
--		local_rst	<= local_rst0;
--	end if;
--end process;


delay_adjustment:
process (RST_AUX, CLK_AUX )
begin	
	if rising_edge(clk_aux) then
	
		if RST_AUX = '1' then
			IDELAY_CE				<= '0';				-- programming disabled
			IDELAY_INC				<= '0';
			delay_value_reg		<= (others=>'0');		-- desired programming
			delay_adj_reg			<= (others=>'0');		-- current programmed value
			delay_adj_ctr			<= (others=>'0');                             
			prog_state				<= prog_idle;		
		
		else
			delay_adj_reg 			<= IDLEAY_VALUEOUT; 
		
			delay_value_reg		<= DELAY_VALUE; 	-- register input

			case prog_state is

				when prog_idle => 

					if ( IDELAYCTRL_READY = '1' and delay_value_reg /= delay_adj_reg ) then -- program  
						-- if what we want is greater than what we have we increase
						if ( delay_value_reg > delay_adj_reg ) then
							IDELAY_INC      <= '1';                                     -- increment
							delay_adj_ctr   <= ( delay_value_reg - delay_adj_reg );
						-- if what we want is less than what we have we decrease
						else
							IDELAY_INC      <= '0';                                     -- decrement
							delay_adj_ctr   <= ( delay_adj_reg - delay_value_reg );
						end if;

					--	delay_adj_reg       <= delay_value_reg; -- save last programmed value
						prog_state          <= prog_s1;                    
					end if;

				-- We change the delay value
				when prog_s1 => 

					if ( delay_adj_ctr /= "00000" )  then
						IDELAY_CE         <= '1';						-- adjust tap
						delay_adj_ctr     <= delay_adj_ctr - 1;          
					else                                         -- adjustment complete
						IDELAY_CE         <= '0';
						prog_state        <= delay0;                    
					end if;
				-- we delay a few cycles for the output to stabalize	
				when delay0 =>
					prog_state          <= delay1;  
				when delay1 =>
					prog_state          <= delay2;  
				when delay2 =>
					prog_state          <= delay3;  
				when delay3 =>
					prog_state          <= delay4;  
				when delay4 =>				
					prog_state          <= prog_idle;  
				when others => 

			end case;
			
		end if; 
											  
	end if; 
end process;

--******************************************************************************************
end Behavioral;
--******************************************************************************************





