-------------------------------------------------------------------------------------
-- FILE NAME :
-- AUTHOR    : Luis Munoz
-- COMPANY   : 4DSP
-- UNITS     : Entity       -
--             Architecture -
-- LANGUAGE  : VHDL
-- DATE      : May 21, 2010
-------------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------------
-- DESCRIPTION
-- ===========
--
-------------------------------------------------------------------------------------
-- LIBRARIES
-------------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_misc.all;
  use ieee.numeric_std.ALL;

library unisim;
  use unisim.vcomponents.all;

library xil_defaultlib;
  use xil_defaultlib.types_pkg.all;

-------------------------------------------------------------------------------------
-- ENTITY
-------------------------------------------------------------------------------------
entity bit_read_end is
generic (
  MAX_MMCM_TAPS   : std_logic_vector(5 downto 0) := "110111"
);
port (
  i_clk           : in    std_logic;
  i_rst           : in    std_logic;
  i_tap_result    : in    std_logic_vector(63 downto 0);
  i_start         : in    std_logic;
  o_tap_value     : out   std_logic_vector(5 downto 0);
  o_status        : out   std_logic
);
end bit_read_end;

-------------------------------------------------------------------------------------
-- ARCHITECTURE
-------------------------------------------------------------------------------------
architecture Behavioral of bit_read_end is

-----------------------------------------------------------------------------------
-- CONSTANTS
-----------------------------------------------------------------------------------
type tap_sm_states is (
   IDLE,
   FIND_START,
   FIND_END,
   DONE
);

-----------------------------------------------------------------------------------
-- SIGNALS
-----------------------------------------------------------------------------------
signal cal_sm     : tap_sm_states;
signal index      : std_logic_vector(5 downto 0);
signal tap_start  : std_logic_vector(5 downto 0);
signal tap_end    : std_logic_vector(5 downto 0);
signal tap_tmp    : std_logic_vector(5 downto 0);
signal pass       : std_logic;

--***********************************************************************************
begin
--***********************************************************************************
o_status    <= pass;
-------------------------------------------------------------------------------------
-- Register outputs
-------------------------------------------------------------------------------------
process (i_clk, i_rst)
begin
   if rising_edge(i_clk) then
      if i_rst = '1' then
        tap_start   <= (others => '0');
        tap_end     <= (others => '0');
        index       <= "000001";
        cal_sm      <= IDLE;
        pass        <= '0';
      else
         case cal_sm is
            -------------------------------------------------------------------------------------
            --  Wait for start command
            -------------------------------------------------------------------------------------
            when IDLE =>
                index <= "000001";
                if i_start = '1' then
                    cal_sm       <= FIND_START;
                    pass         <= '0';
                end if;
            -------------------------------------------------------------------------------------
            -- Find first good tap
            -------------------------------------------------------------------------------------
            when FIND_START =>
                if i_tap_result((to_integer(unsigned(index)))) = '1' then
                    cal_sm       <= FIND_END;
                    tap_start    <= index;
                elsif index = MAX_MMCM_TAPS then
                    cal_sm          <= DONE;
                    tap_start    <= (others => '0');
                    tap_end      <= (others => '0');
                    pass         <= '0'; -- didn't find a good window
                else
                    index        <=  index + 1;
                end if;
            -------------------------------------------------------------------------------------
            -- Find last good tap in current window
            -------------------------------------------------------------------------------------
        when FIND_END =>
                if i_tap_result((to_integer(unsigned(index)))) = '0' then
                    cal_sm       <= DONE;
                    tap_end      <= index;
                    pass         <= '1';
                elsif index = MAX_MMCM_TAPS then
                    cal_sm       <= DONE;
                    tap_end      <= MAX_MMCM_TAPS;
                    pass         <= '1'; -- all taps are good (strange)
                else
                    index        <=  index + 1;
                end if;
           -------------------------------------------------------------------------------------
           -- Done
           -------------------------------------------------------------------------------------
        when DONE =>
                cal_sm          <= IDLE;
           -------------------------------------------------------------------------------------
           -- Others
           -------------------------------------------------------------------------------------
           when others =>
                 cal_sm       <= IDLE;
                 pass         <= '0';
          end case;

        end if;
    end if;
end process;

process(i_clk)
begin
  if rising_edge(i_clk) then
    if i_rst = '1' then
      o_tap_value  <= (others=>'0');
    else
      tap_tmp      <= tap_end - tap_start;
      o_tap_value  <= tap_tmp(5 downto 1) + tap_start;
    end if;
  end if;
end process;


--***********************************************************************************
end Behavioral;
--***********************************************************************************

