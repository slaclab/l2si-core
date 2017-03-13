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
  use ieee.numeric_std.all;

library unisim;
  use unisim.vcomponents.all;

library xil_defaultlib;
  use xil_defaultlib.types_pkg.all;

-------------------------------------------------------------------------------------
-- ENTITY
-------------------------------------------------------------------------------------
entity calibrate is
generic (
   SAMPLE_WIDTH        : integer := 24
);
port(
   clk            : in  std_logic;
   rst            : in  std_logic;
   i_start_cal    : in  std_logic;
   o_tap_value    : out bus009(SAMPLE_WIDTH-1 downto 0);
   i_bit_match    : in  std_logic_vector(SAMPLE_WIDTH-1 downto 0);
   o_transpose    : out bus064(SAMPLE_WIDTH-1 downto 0);
   cal_status     : out std_logic_vector(4 downto 0)
);
end calibrate;

-------------------------------------------------------------------------------------
-- ARCHITECTURE
-------------------------------------------------------------------------------------
architecture Behavioral of calibrate is

-----------------------------------------------------------------------------------
-- CONSTANTS
-----------------------------------------------------------------------------------
type align_sm_states is (
   IDLE,
   START_WAIT,
   CHECK_START,
   INC_TAP,
   DONE
);

constant SYNC_CNT       : std_logic_vector(19 downto 0) := x"0002F";
constant TRAIN_CNT      : std_logic_vector(19 downto 0) := x"001FF";

type bus043  is array(natural range <>) of std_logic_vector(42 downto 0); 

-----------------------------------------------------------------------------------
-- SIGNALS
-----------------------------------------------------------------------------------
signal cal_sm          : align_sm_states;
signal tap_value       : std_logic_vector(8 downto 0);
signal watch_dog_cnt   : std_logic_vector(19 downto 0);
signal watch_dog_rst   : std_logic;
signal error_latch_rst : std_logic;
signal error_latch     : std_logic_vector(SAMPLE_WIDTH-1 downto 0);
signal tap_table       : bus043(63 downto 0);
signal done_signal     : std_logic;
signal tap_value_vec   : bus009(SAMPLE_WIDTH-1 downto 0);

signal local_rst       : std_logic;
signal pass            : std_logic_vector(SAMPLE_WIDTH-1 downto 0);

signal transpose  : bus064(SAMPLE_WIDTH-1 downto 0);

--***********************************************************************************
begin
--***********************************************************************************

o_transpose <= transpose;

bit_table_generate:
for B in 0 to SAMPLE_WIDTH-1 generate
    tap_table_generate:
    for T in 0 to 63 generate
        transpose(B)(T) <= tap_table(T)(B);
    end generate;
end generate;

tap_get_generate:
for X in 0 to SAMPLE_WIDTH-1 generate

 bit_read_inst0:
 entity work.bit_read
 port map(
     i_clk           => clk,
     i_rst           => local_rst,
     i_tap_result    => transpose(X),
     i_start         => done_signal,
     o_tap_value     => tap_value_vec(X),
     o_status        => pass(X)
 );
end generate;



process (clk, rst)
begin
    if rising_edge(clk) then
        local_rst       <= rst ;
        cal_status(4)   <= and_reduce(pass);
    end if;
end process;


-------------------------------------------------------------------------------------
-- Register outputs
-------------------------------------------------------------------------------------
process (clk, local_rst)
begin
   if rising_edge(clk) then
      if local_rst = '1' then
        watch_dog_rst      <= '1';
        error_latch_rst    <= '0';
        tap_table          <= (others=> (others=>'0'));
        done_signal        <= '0';
        cal_status(3 downto 0)<= (others=>'0');
      else
         done_signal        <= '0';
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
            cal_status(3 downto 0) <= x"6";
            -------------------------------------------------------------------------------------
            -- Wait for TAP increment to take effect
            -------------------------------------------------------------------------------------
            when START_WAIT  =>
                watch_dog_rst    <= '0';
                 error_latch_rst <= '1';
                if watch_dog_cnt = SYNC_CNT then
                  cal_sm     <= CHECK_START;
                end if;
            cal_status(3 downto 0) <= x"5";
            -------------------------------------------------------------------------------------
            -- Monitor that we don't get errors for TRAIN_CNT then save results
            -------------------------------------------------------------------------------------
        when CHECK_START =>
                error_latch_rst <= '0';
                watch_dog_rst   <= '0';
                if watch_dog_cnt = TRAIN_CNT then
                    cal_sm       <= INC_TAP;
                    tap_table(to_integer(unsigned(tap_value(8 downto 3)))) <= not error_latch;
                end if;
            cal_status(3 downto 0) <= x"4";
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
            cal_status(3 downto 0) <= x"3";
           -------------------------------------------------------------------------------------
           -- set the last tap in the valid window
           -------------------------------------------------------------------------------------
       when DONE =>
                cal_sm       <= IDLE;
                done_signal  <= '1';
            cal_status(3 downto 0) <= x"2";
           -------------------------------------------------------------------------------------
           -- Others
           -------------------------------------------------------------------------------------
           when others =>
                cal_sm          <= IDLE;
                done_signal     <= '0';
                watch_dog_rst   <= '1';
                error_latch_rst <= '1';
          cal_status(3 downto 0)   <= x"1";
          end case;

        end if;
    end if;
end process;

-------------------------------------------------------------------------------------
-- Error latch. Monitor the match state and latch any errors that occur
-------------------------------------------------------------------------------------
error_latch_generate_0:
for X in 0 to SAMPLE_WIDTH-1 generate

    process(clk, error_latch_rst)
    begin
       if rising_edge(clk) then
          if error_latch_rst = '1' then
             error_latch(X) <= '0';
          else
            if i_bit_match(X) = '0' then
                error_latch(X) <= '1';
            end if;
          end if;
       end if;
    end process;


    process(clk, local_rst)
    begin
       if rising_edge(clk) then
          if local_rst = '1' then
             o_tap_value(X) <= (others=>'0');
          else
            if cal_sm = IDLE then
                o_tap_value(X) <= tap_value_vec(X);
            else
                o_tap_value(X) <= tap_value;
            end if;
          end if;
       end if;
    end process;



end generate;



-------------------------------------------------------------------------------------
-- Watch dog timer for errors
-------------------------------------------------------------------------------------
process(clk, watch_dog_rst)
begin
   if rising_edge(clk) then
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




