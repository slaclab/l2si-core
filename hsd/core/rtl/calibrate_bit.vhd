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
--  use ieee.std_logic_arith.all;
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
entity calibrate_bit is
port(
    i_clk        : in std_logic;
    i_rst        : in std_logic;
    i_start_cal  : in std_logic;
    o_start_cal  : out std_logic;
    i_bit_match  : in std_logic;
    o_tap_value  : out std_logic_vector(8 downto 0);
    o_tap_vector : out std_logic_vector(63 downto 0);
    o_status     : out std_logic;
    i_adjust_done : in std_logic;
    i_tap_start  : in std_logic_vector(8 downto 0) := (others=>'0')
);
end calibrate_bit;

-------------------------------------------------------------------------------------
-- ARCHITECTURE
-------------------------------------------------------------------------------------
architecture Behavioral of calibrate_bit is

-----------------------------------------------------------------------------------
-- CONSTANTS
-----------------------------------------------------------------------------------
type align_sm_states is (
   IDLE,
   START_WAIT,
   CHECK_START,
   INC_TAP,
   DONE_WAIT,
   BITSLIP_ALIGN,
   DONE
);

constant SYNC_CNT       : std_logic_vector(19 downto 0) := x"0003F";
constant TRAIN_CNT      : std_logic_vector(19 downto 0) := x"001FF";

-----------------------------------------------------------------------------------
-- SIGNALS
-----------------------------------------------------------------------------------
signal cal_sm          : align_sm_states;
signal tap_value       : std_logic_vector(8 downto 0);
signal watch_dog_cnt   : std_logic_vector(19 downto 0);
signal watch_dog_rst   : std_logic;
signal error_latch_rst : std_logic;
signal error_latch     : std_logic;
signal tap_vector      : std_logic_vector(63 downto 0);
signal tap_vector_r    : std_logic_vector(63 downto 0);
signal done_signal     : std_logic;
signal tap_result      : std_logic_vector(8 downto 0);
signal local_rst       : std_logic;
signal pass            : std_logic;
signal match_state     : std_logic;

--***********************************************************************************
begin
--***********************************************************************************

bit_read_inst0:
entity work.bit_read
port map(
   i_clk       => i_clk,
   i_rst       => local_rst,
   i_tap_result => tap_vector_r,
   i_start     => done_signal,
   o_tap_value => tap_result,
   o_status    => pass,
   i_tap_start => i_tap_start
);

process (i_clk)
begin
    if rising_edge(i_clk) then
        local_rst       <= i_rst;
        o_status        <= pass;
    end if;
end process;

tap_vector_r <= tap_vector;
o_tap_vector <= tap_vector_r;

-------------------------------------------------------------------------------------
-- Register outputs
-------------------------------------------------------------------------------------
process (i_clk, local_rst)
begin
   if rising_edge(i_clk) then
      if local_rst = '1' then
        watch_dog_rst      <= '1';
        error_latch_rst    <= '0';
        tap_vector         <= (others=>'0');
        done_signal        <= '0';
        match_state        <= '0';
        o_start_cal        <= '0';
        tap_value          <= (others => '0');
      else
         done_signal      <= '0';
         match_state      <= i_bit_match;
         o_start_cal      <= '0';
         case cal_sm is
            -------------------------------------------------------------------------------------
            -- Wait for start signal
            -------------------------------------------------------------------------------------
            when IDLE =>
                watch_dog_rst   <= '1';
                error_latch_rst <= '1';
                if i_start_cal = '1' then
                    tap_value    <= (others => '0');
                    cal_sm       <= START_WAIT;
                end if;
            -------------------------------------------------------------------------------------
            -- Wait for TAP increment to take effect
            -------------------------------------------------------------------------------------
            when START_WAIT  =>
                watch_dog_rst   <= '0';
                error_latch_rst <= '1';
                if watch_dog_cnt >= SYNC_CNT and i_adjust_done = '1' then
                  cal_sm     <= CHECK_START;
                end if;
            -------------------------------------------------------------------------------------
            -- Monitor that we don't get errors for TRAIN_CNT then save results
            -------------------------------------------------------------------------------------
        when CHECK_START =>
                error_latch_rst <= '0';
                watch_dog_rst   <= '0';
                if watch_dog_cnt = TRAIN_CNT then
                    cal_sm       <= INC_TAP;
                    tap_vector(to_integer(unsigned(tap_value(8 downto 3)))) <= not error_latch;
                end if;
            -------------------------------------------------------------------------------------
            -- Increment TAP
            -------------------------------------------------------------------------------------
        when INC_TAP =>
                watch_dog_rst    <= '1';
                 error_latch_rst <= '1';
                if tap_value(8 downto 3) = "111111" then
                   cal_sm       <= DONE;
                else
                   tap_value    <= tap_value + 8;
                   cal_sm       <= START_WAIT;
                end if;
           -------------------------------------------------------------------------------------
           -- set the last tap in the valid window
           -------------------------------------------------------------------------------------
       when DONE =>
                cal_sm       <= DONE_WAIT;
                done_signal  <= '1';
           -------------------------------------------------------------------------------------
           -- wait for the clk tap to get set before we signal the next stage.
           -------------------------------------------------------------------------------------
           when DONE_WAIT =>
                cal_sm          <= IDLE;
                o_start_cal     <= '1';
           -------------------------------------------------------------------------------------
           -- Others
           -------------------------------------------------------------------------------------
           when others =>
                cal_sm          <= IDLE;
                done_signal     <= '0';
                watch_dog_rst   <= '1';
                error_latch_rst <= '1';
          end case;

        end if;
    end if;
end process;

-------------------------------------------------------------------------------------
-- Error latch. Monitor the match state and latch any errors that occur
-------------------------------------------------------------------------------------
process(i_clk, error_latch_rst)
begin
   if rising_edge(i_clk) then
      if error_latch_rst = '1' then
         error_latch <= '0';
      else
        if match_state = '0' then
            error_latch <= '1';
        end if;
      end if;
   end if;
end process;

-------------------------------------------------------------------------------------
-- Select tap
-------------------------------------------------------------------------------------
process(i_clk, local_rst)
begin
   if rising_edge(i_clk) then
      if local_rst = '1' then
         o_tap_value <= (others=>'0');
      else
        if cal_sm = IDLE then
            o_tap_value <= tap_result;
        else
            o_tap_value <= tap_value;
        end if;
      end if;
   end if;
end process;

-------------------------------------------------------------------------------------
-- Watch dog timer for errors
-------------------------------------------------------------------------------------
process(i_clk, watch_dog_rst)
begin
   if rising_edge(i_clk) then
      if watch_dog_rst = '1' then
         watch_dog_cnt <= (others=>'0');
      else
         watch_dog_cnt <= watch_dog_cnt + 1;
      end if;
   end if;
end process;

--***********************************************************************************
end Behavioral;
--***********************************************************************************

