library ieee;
    use ieee.std_logic_1164.all;
    -- IEEE  
    --use ieee.numeric_std.all; 
    -- non-IEEE 
    use ieee.std_logic_unsigned.all;
    use ieee.std_logic_misc.all;
    use ieee.std_logic_arith.all; 
Library UNISIM;
    use UNISIM.vcomponents.all;
-------------------------------------------------------------------------------------
-- ENTITY
-------------------------------------------------------------------------------------
entity ev10aq190a_pattern is
port (
    i_clk           : in  std_logic;
    i_rst           : in  std_logic;
    i_data          : in  std_logic_vector(8*44-1 downto 0); -- 351 downto 0
    o_valid         : out std_logic;
    o_bit_match     : out std_logic_vector(44-1 downto 0)    -- 43 downto 0
);
end ev10aq190a_pattern;

-------------------------------------------------------------------------------------
-- ARCHITECTURE
-------------------------------------------------------------------------------------
architecture Behavioral of ev10aq190a_pattern is

-------------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------------
constant SAMPLE_WIDTH   : integer := 44;
constant MASTER_BIT     : integer := 0;

-- type bus012  is array(natural range <>) of std_logic_vector(11 downto 0); 
type bus011  is array(natural range <>) of std_logic_vector(10 downto 0); 

type check_machine is (
   CYCLE0_CHK, 
   CYCLE1_CHK, 
   CYCLE2_CHK, 
   CYCLE3_CHK, 
   CYCLE4_CHK, 
   CYCLE5_CHK, 
   CYCLE6_CHK, 
   CYCLE7_CHK, 
   CYCLE8_CHK, 
   CYCLE9_CHK, 
   CYCLE10_CHK
);


attribute mark_debug : string;
attribute syn_keep : string;

attribute keep : string;
attribute S : string;
-------------------------------------------------------------------------------------
-- SIGNALS
-------------------------------------------------------------------------------------
signal sm_chk_reg  : check_machine;

signal cycle0      : std_logic_vector(SAMPLE_WIDTH-1 downto 0);   -- 44
signal cycle1      : std_logic_vector(SAMPLE_WIDTH-1 downto 0);
signal cycle2      : std_logic_vector(SAMPLE_WIDTH-1 downto 0);
signal cycle3      : std_logic_vector(SAMPLE_WIDTH-1 downto 0);
signal cycle4      : std_logic_vector(SAMPLE_WIDTH-1 downto 0); 
signal cycle5      : std_logic_vector(SAMPLE_WIDTH-1 downto 0);
signal cycle6      : std_logic_vector(SAMPLE_WIDTH-1 downto 0);
signal cycle7      : std_logic_vector(SAMPLE_WIDTH-1 downto 0);

-- signal i           : bus012(4 downto 0);
-- signal i_dly       : bus012(4 downto 0);
-- signal q           : bus012(4 downto 0);
-- signal q_dly       : bus012(4 downto 0);

signal ch_a        : bus011(10 downto 0);
signal ch_b        : bus011(10 downto 0);
signal ch_c        : bus011(10 downto 0);
signal ch_d        : bus011(10 downto 0);

-- bit pattern 
signal bitpattern0  : std_logic_vector(7 downto 0);
signal bitpattern1  : std_logic_vector(7 downto 0);
signal bitpattern2  : std_logic_vector(7 downto 0);
signal bitpattern3  : std_logic_vector(7 downto 0);
signal bitpattern4  : std_logic_vector(7 downto 0);
signal bitpattern5  : std_logic_vector(7 downto 0);
signal bitpattern6  : std_logic_vector(7 downto 0);
signal bitpattern7  : std_logic_vector(7 downto 0);
signal bitpattern8  : std_logic_vector(7 downto 0);
signal bitpattern9  : std_logic_vector(7 downto 0);
signal bitpattern10 : std_logic_vector(7 downto 0);


signal i_master_bit : std_logic_vector(7 downto 0); 
signal data_reg     : std_logic_vector(8*SAMPLE_WIDTH-1 downto 0);
signal pattern      : std_logic_vector(8*SAMPLE_WIDTH-1 downto 0);   -- 352
signal valid        : std_logic;
signal bit_match    : std_logic_vector(SAMPLE_WIDTH-1 downto 0);

signal probe0 : std_logic_vector(431 DOWNTO 0);

--attribute keep of pattern : signal is "TRUE";
--attribute keep of bit_match : signal is "TRUE";
--attribute keep of valid : signal is "TRUE";
--attribute keep of data_reg : signal is "TRUE";
--
--attribute S of pattern : signal is "TRUE";
--attribute S of bit_match : signal is "TRUE";
--attribute S of valid : signal is "TRUE";
--attribute S of data_reg : signal is "TRUE";

--***********************************************************************************
begin
--***********************************************************************************

-- CHA
ch_a(0)     <= "11111111111";
ch_a(1)     <= "00000000000";
ch_a(2)     <= "00000000000";
ch_a(3)     <= "00000000000";
ch_a(4)     <= "00000000000";
ch_a(5)     <= "00000000000";
ch_a(6)     <= "00000000000";
ch_a(7)     <= "00000000000";
ch_a(8)     <= "00000000000";
ch_a(9)     <= "00000000000";
ch_a(10)    <= "00000000000";

-- CHB
ch_b(0)     <= "11111111111";
ch_b(1)     <= "00000000000";
ch_b(2)     <= "00000000000";
ch_b(3)     <= "00000000000";
ch_b(4)     <= "00000000000";
ch_b(5)     <= "00000000000";
ch_b(6)     <= "00000000000";
ch_b(7)     <= "00000000000";
ch_b(8)     <= "00000000000";
ch_b(9)     <= "00000000000";
ch_b(10)    <= "00000000000";

-- CHC
ch_c(0)     <= "11111111111";
ch_c(1)     <= "00000000000";
ch_c(2)     <= "00000000000";
ch_c(3)     <= "00000000000";
ch_c(4)     <= "00000000000";
ch_c(5)     <= "00000000000";
ch_c(6)     <= "00000000000";
ch_c(7)     <= "00000000000";
ch_c(8)     <= "00000000000";
ch_c(9)     <= "00000000000";
ch_c(10)    <= "00000000000";

-- CHD
ch_d(0)     <= "11111111111";
ch_d(1)     <= "00000000000";
ch_d(2)     <= "00000000000";
ch_d(3)     <= "00000000000";
ch_d(4)     <= "00000000000";
ch_d(5)     <= "00000000000";
ch_d(6)     <= "00000000000";
ch_d(7)     <= "00000000000";
ch_d(8)     <= "00000000000";
ch_d(9)     <= "00000000000";
ch_d(10)    <= "00000000000";


-- i(0)        <= x"010";
-- i(1)        <= x"FEF";
-- i(2)        <= x"010";
-- i(3)        <= x"FEF";
-- i(4)        <= x"010";
-- i_dly(0)    <= x"004";
-- i_dly(1)    <= x"FFB";
-- i_dly(2)    <= x"004";
-- i_dly(3)    <= x"FFB";
-- i_dly(4)    <= x"004";
-- 
-- q_dly(0)    <= x"000";
-- q_dly(1)    <= x"FFF";
-- q_dly(2)    <= x"000";
-- q_dly(3)    <= x"FFF";
-- q_dly(4)    <= x"000";
-- q(0)        <= x"008";
-- q(1)        <= x"FF7";
-- q(2)        <= x"008";
-- q(3)        <= x"FF7";
-- q(4)        <= x"008";

--bitpattern0 <= i_dly(3)(MASTER_BIT) & i_dly(2)(MASTER_BIT) & i_dly(1)(MASTER_BIT) & i_dly(0)(MASTER_BIT); --1010
--bitpattern1 <= i_dly(2)(MASTER_BIT) & i_dly(1)(MASTER_BIT) & i_dly(0)(MASTER_BIT) & i_dly(4)(MASTER_BIT); --0100
--bitpattern2 <= i_dly(1)(MASTER_BIT) & i_dly(0)(MASTER_BIT) & i_dly(4)(MASTER_BIT) & i_dly(3)(MASTER_BIT); --1001
--bitpattern3 <= i_dly(0)(MASTER_BIT) & i_dly(4)(MASTER_BIT) & i_dly(3)(MASTER_BIT) & i_dly(2)(MASTER_BIT); --0010
--bitpattern4 <= i_dly(4)(MASTER_BIT) & i_dly(3)(MASTER_BIT) & i_dly(2)(MASTER_BIT) & i_dly(1)(MASTER_BIT); --0101

bitpattern0    <= ch_a(7)(MASTER_BIT) & ch_a(6)(MASTER_BIT) & ch_a(5)(MASTER_BIT) & 
                  ch_a(4)(MASTER_BIT) & ch_a(3)(MASTER_BIT) & ch_a(2)(MASTER_BIT) & 
                  ch_a(1)(MASTER_BIT) & ch_a(0)(MASTER_BIT);  -- x"01"

bitpattern1    <= ch_a(4)(MASTER_BIT) & ch_a(3)(MASTER_BIT) & ch_a(2)(MASTER_BIT) & 
                  ch_a(1)(MASTER_BIT) & ch_a(0)(MASTER_BIT) & ch_a(10)(MASTER_BIT) & 
                  ch_a(9)(MASTER_BIT) & ch_a(8)(MASTER_BIT);  -- x"08";

bitpattern2    <= ch_a(1)(MASTER_BIT) & ch_a(0)(MASTER_BIT) & ch_a(10)(MASTER_BIT) & 
                  ch_a(9)(MASTER_BIT) & ch_a(8)(MASTER_BIT) & ch_a(7)(MASTER_BIT) & 
                  ch_a(6)(MASTER_BIT) & ch_a(5)(MASTER_BIT);  -- x"40";

bitpattern3    <= ch_a(9)(MASTER_BIT) & ch_a(8)(MASTER_BIT) & ch_a(7)(MASTER_BIT) & 
                  ch_a(6)(MASTER_BIT) & ch_a(5)(MASTER_BIT) & ch_a(4)(MASTER_BIT) & 
                  ch_a(3)(MASTER_BIT) & ch_a(2)(MASTER_BIT);  -- x"00";

bitpattern4    <= ch_a(6)(MASTER_BIT) & ch_a(5)(MASTER_BIT) & ch_a(4)(MASTER_BIT) & 
                  ch_a(3)(MASTER_BIT) & ch_a(2)(MASTER_BIT) & ch_a(1)(MASTER_BIT) & 
                  ch_a(0)(MASTER_BIT) & ch_a(10)(MASTER_BIT);  -- x"02";

bitpattern5    <= ch_a(3)(MASTER_BIT) & ch_a(2)(MASTER_BIT) & ch_a(1)(MASTER_BIT) & 
                  ch_a(0)(MASTER_BIT) & ch_a(10)(MASTER_BIT) & ch_a(9)(MASTER_BIT) & 
                  ch_a(8)(MASTER_BIT) & ch_a(7)(MASTER_BIT);  -- x"10";

bitpattern6    <= ch_a(0)(MASTER_BIT) & ch_a(10)(MASTER_BIT) & ch_a(9)(MASTER_BIT) & 
                  ch_a(8)(MASTER_BIT) & ch_a(7)(MASTER_BIT) & ch_a(6)(MASTER_BIT) & 
                  ch_a(5)(MASTER_BIT) & ch_a(4)(MASTER_BIT);  -- x"80";

bitpattern7    <= ch_a(8)(MASTER_BIT) & ch_a(7)(MASTER_BIT) & ch_a(6)(MASTER_BIT) & 
                  ch_a(5)(MASTER_BIT) & ch_a(4)(MASTER_BIT) & ch_a(3)(MASTER_BIT) & 
                  ch_a(2)(MASTER_BIT) & ch_a(1)(MASTER_BIT);  -- x"00";

bitpattern8    <= ch_a(5)(MASTER_BIT) & ch_a(4)(MASTER_BIT) & ch_a(3)(MASTER_BIT) & 
                  ch_a(2)(MASTER_BIT) & ch_a(1)(MASTER_BIT) & ch_a(0)(MASTER_BIT) & 
                  ch_a(10)(MASTER_BIT) & ch_a(9)(MASTER_BIT);  -- x"04";

bitpattern9    <= ch_a(2)(MASTER_BIT) & ch_a(1)(MASTER_BIT) & ch_a(0)(MASTER_BIT) & 
                  ch_a(10)(MASTER_BIT) & ch_a(9)(MASTER_BIT) & ch_a(8)(MASTER_BIT) & 
                  ch_a(7)(MASTER_BIT) & ch_a(6)(MASTER_BIT);  -- x"20";

bitpattern10   <= ch_a(10)(MASTER_BIT) & ch_a(9)(MASTER_BIT) & ch_a(8)(MASTER_BIT) & 
                  ch_a(7)(MASTER_BIT) & ch_a(6)(MASTER_BIT) & ch_a(5)(MASTER_BIT) & 
                  ch_a(4)(MASTER_BIT) & ch_a(3)(MASTER_BIT);  -- x"00";


i_master_bit <= 
    i_data(44*7+MASTER_BIT) &
    i_data(44*6+MASTER_BIT) &
    i_data(44*5+MASTER_BIT) &
    i_data(44*4+MASTER_BIT) &
    i_data(44*3+MASTER_BIT) &
    i_data(44*2+MASTER_BIT) &
    i_data(44*1+MASTER_BIT) & 
    i_data(44*0+MASTER_BIT);

o_valid     <= valid;
o_bit_match <= bit_match;


-------------------------------------------------------------------------------------
-- check state-machine
-------------------------------------------------------------------------------------
pattern <= cycle7 & cycle6 & cycle5 & cycle4 & cycle3 & cycle2 & cycle1 & cycle0;  -- 44*8 = 352

process (i_rst, i_clk)
begin
   if rising_edge(i_clk) then
      if i_rst = '1' then
         sm_chk_reg  <= CYCLE0_CHK;
         cycle0      <= (others=>'0');
         cycle1      <= (others=>'0');
         cycle2      <= (others=>'0');
         cycle3      <= (others=>'0');
         cycle4      <= (others=>'0');
         cycle5      <= (others=>'0');
         cycle6      <= (others=>'0');
         cycle7      <= (others=>'0');
         valid       <= '0';
      else 
         data_reg <=  i_data;

         case sm_chk_reg is
            --------------------------------------------------------------
            -- CYCLE STATE 0 - The 0th pattern is detected
            --------------------------------------------------------------                
            when CYCLE0_CHK =>
               if i_master_bit = bitpattern0 then         
                  sm_chk_reg     <= CYCLE1_CHK;
                  valid  <= '1';
               else
                  sm_chk_reg     <= CYCLE0_CHK;
                  valid  <= '0';
               end if;
               cycle0  <= ch_d(0) & ch_c(0) & ch_b(0) & ch_a(0);  -- 11*4 = 44
               cycle1  <= ch_d(1) & ch_c(1) & ch_b(1) & ch_a(1);
               cycle2  <= ch_d(2) & ch_c(2) & ch_b(2) & ch_a(2);
               cycle3  <= ch_d(3) & ch_c(3) & ch_b(3) & ch_a(3);
               cycle4  <= ch_d(4) & ch_c(4) & ch_b(4) & ch_a(4);
               cycle5  <= ch_d(5) & ch_c(5) & ch_b(5) & ch_a(5);
               cycle6  <= ch_d(6) & ch_c(6) & ch_b(6) & ch_a(6);
               cycle7  <= ch_d(7) & ch_c(7) & ch_b(7) & ch_a(7);
            --------------------------------------------------------------
            -- CYCLE STATE 1 - The 1st pattern is detected
            --------------------------------------------------------------                 
             when CYCLE1_CHK  =>
               if i_master_bit = bitpattern1 then                              
                  sm_chk_reg     <= CYCLE2_CHK;
               else 
                  sm_chk_reg     <= CYCLE0_CHK;
                  valid  <= '0';
               end if;
               cycle0  <= ch_d(8) & ch_c(8) & ch_b(8) & ch_a(8);     -- 11*4 = 44
               cycle1  <= ch_d(9) & ch_c(9) & ch_b(9) & ch_a(9);
               cycle2  <= ch_d(10) & ch_c(10) & ch_b(10) & ch_a(10);
               cycle3  <= ch_d(0) & ch_c(0) & ch_b(0) & ch_a(0);
               cycle4  <= ch_d(1) & ch_c(1) & ch_b(1) & ch_a(1);
               cycle5  <= ch_d(2) & ch_c(2) & ch_b(2) & ch_a(2);
               cycle6  <= ch_d(3) & ch_c(3) & ch_b(3) & ch_a(3);
               cycle7  <= ch_d(4) & ch_c(4) & ch_b(4) & ch_a(4);
            --------------------------------------------------------------
            -- CYCLE STATE 2 - The 2nd pattern is detected
            --------------------------------------------------------------                
             when CYCLE2_CHK  =>
               if i_master_bit =bitpattern2 then                                   
                  sm_chk_reg     <= CYCLE3_CHK;
               else 
                  sm_chk_reg     <= CYCLE0_CHK;
                  valid  <= '0';
               end if;
               cycle0  <= ch_d(5) & ch_c(5) & ch_b(5) & ch_a(5);  -- 11*4 = 44
               cycle1  <= ch_d(6) & ch_c(6) & ch_b(6) & ch_a(6);
               cycle2  <= ch_d(7) & ch_c(7) & ch_b(7) & ch_a(7);
               cycle3  <= ch_d(8) & ch_c(8) & ch_b(8) & ch_a(8);
               cycle4  <= ch_d(9) & ch_c(9) & ch_b(9) & ch_a(9);
               cycle5  <= ch_d(10) & ch_c(10) & ch_b(10) & ch_a(10);
               cycle6  <= ch_d(0) & ch_c(0) & ch_b(0) & ch_a(0);
               cycle7  <= ch_d(1) & ch_c(1) & ch_b(1) & ch_a(1);
            --------------------------------------------------------------
            -- CYCLE STATE 3 - The 3rd pattern is detected
            --------------------------------------------------------------                    
             when CYCLE3_CHK  =>
               if i_master_bit = bitpattern3 then   
                  sm_chk_reg     <= CYCLE4_CHK;
               else 
                  sm_chk_reg     <= CYCLE0_CHK;
                  valid  <= '0';
               end if;      
               cycle0  <= ch_d(2) & ch_c(2) & ch_b(2) & ch_a(2);  -- 11*4 = 44
               cycle1  <= ch_d(3) & ch_c(3) & ch_b(3) & ch_a(3);
               cycle2  <= ch_d(4) & ch_c(4) & ch_b(4) & ch_a(4);
               cycle3  <= ch_d(5) & ch_c(5) & ch_b(5) & ch_a(5);
               cycle4  <= ch_d(6) & ch_c(6) & ch_b(6) & ch_a(6);
               cycle5  <= ch_d(7) & ch_c(7) & ch_b(7) & ch_a(7);
               cycle6  <= ch_d(8) & ch_c(8) & ch_b(8) & ch_a(8);
               cycle7  <= ch_d(9) & ch_c(9) & ch_b(9) & ch_a(9);
            --------------------------------------------------------------
            -- CYCLE STATE 4 - The 4th pattern is detected
            --------------------------------------------------------------                 
             when CYCLE4_CHK  =>
               if i_master_bit =bitpattern4 then   
                  sm_chk_reg     <= CYCLE5_CHK;
               else 
                  sm_chk_reg     <= CYCLE0_CHK;
                  valid  <= '0';
               end if;
               cycle0  <= ch_d(10) & ch_c(10) & ch_b(10) & ch_a(10);  -- 11*4 = 44
               cycle1  <= ch_d(0) & ch_c(0) & ch_b(0) & ch_a(0);
               cycle2  <= ch_d(1) & ch_c(1) & ch_b(1) & ch_a(1);
               cycle3  <= ch_d(2) & ch_c(2) & ch_b(2) & ch_a(2);
               cycle4  <= ch_d(3) & ch_c(3) & ch_b(3) & ch_a(3);
               cycle5  <= ch_d(4) & ch_c(4) & ch_b(4) & ch_a(4);
               cycle6  <= ch_d(5) & ch_c(5) & ch_b(5) & ch_a(5);
               cycle7  <= ch_d(6) & ch_c(6) & ch_b(6) & ch_a(6);
            --------------------------------------------------------------
            -- CYCLE STATE 5 - The 5th pattern is detected
            --------------------------------------------------------------                 
             when CYCLE5_CHK  =>
               if i_master_bit =bitpattern5 then   
                  sm_chk_reg     <= CYCLE6_CHK;
               else 
                  sm_chk_reg     <= CYCLE0_CHK;
                  valid  <= '0';
               end if;
               cycle0  <= ch_d(10) & ch_c(10) & ch_b(10) & ch_a(10);  -- 11*4 = 44
               cycle1  <= ch_d(0) & ch_c(0) & ch_b(0) & ch_a(0);
               cycle2  <= ch_d(1) & ch_c(1) & ch_b(1) & ch_a(1);
               cycle3  <= ch_d(2) & ch_c(2) & ch_b(2) & ch_a(2);
               cycle4  <= ch_d(3) & ch_c(3) & ch_b(3) & ch_a(3);
               cycle5  <= ch_d(4) & ch_c(4) & ch_b(4) & ch_a(4);
               cycle6  <= ch_d(5) & ch_c(5) & ch_b(5) & ch_a(5);
               cycle7  <= ch_d(6) & ch_c(6) & ch_b(6) & ch_a(6);
            --------------------------------------------------------------
            -- CYCLE STATE 6 - The 6th pattern is detected
            --------------------------------------------------------------                 
             when CYCLE6_CHK  =>
               if i_master_bit =bitpattern6 then   
                  sm_chk_reg     <= CYCLE7_CHK;
               else 
                  sm_chk_reg     <= CYCLE0_CHK;
                  valid  <= '0';
               end if;
               cycle0  <= ch_d(7) & ch_c(7) & ch_b(7) & ch_a(7);  -- 11*4 = 44
               cycle1  <= ch_d(8) & ch_c(8) & ch_b(8) & ch_a(8);
               cycle2  <= ch_d(9) & ch_c(9) & ch_b(9) & ch_a(9);
               cycle3  <= ch_d(10) & ch_c(10) & ch_b(10) & ch_a(10);
               cycle4  <= ch_d(0) & ch_c(0) & ch_b(0) & ch_a(0);
               cycle5  <= ch_d(1) & ch_c(1) & ch_b(1) & ch_a(1);
               cycle6  <= ch_d(2) & ch_c(2) & ch_b(2) & ch_a(2);
               cycle7  <= ch_d(3) & ch_c(3) & ch_b(3) & ch_a(3);
            --------------------------------------------------------------
            -- CYCLE STATE 7 - The 7th pattern is detected
            --------------------------------------------------------------                 
             when CYCLE7_CHK  =>
               if i_master_bit =bitpattern7 then   
                  sm_chk_reg     <= CYCLE8_CHK;
               else 
                  sm_chk_reg     <= CYCLE0_CHK;
                  valid  <= '0';
               end if;
               cycle0  <= ch_d(4) & ch_c(4) & ch_b(4) & ch_a(4);  -- 11*4 = 44
               cycle1  <= ch_d(5) & ch_c(5) & ch_b(5) & ch_a(5);
               cycle2  <= ch_d(6) & ch_c(6) & ch_b(6) & ch_a(6);
               cycle3  <= ch_d(7) & ch_c(7) & ch_b(7) & ch_a(7);
               cycle4  <= ch_d(8) & ch_c(8) & ch_b(8) & ch_a(8);
               cycle5  <= ch_d(9) & ch_c(9) & ch_b(9) & ch_a(9);
               cycle6  <= ch_d(10) & ch_c(10) & ch_b(10) & ch_a(10);
               cycle7  <= ch_d(0) & ch_c(0) & ch_b(0) & ch_a(0);
            --------------------------------------------------------------
            -- CYCLE STATE 8 - The 8th pattern is detected
            --------------------------------------------------------------                 
             when CYCLE8_CHK  =>
               if i_master_bit =bitpattern8 then   
                  sm_chk_reg     <= CYCLE9_CHK;
               else 
                  sm_chk_reg     <= CYCLE0_CHK;
                  valid  <= '0';
               end if;
               cycle0  <= ch_d(1) & ch_c(1) & ch_b(1) & ch_a(1);  -- 11*4 = 44
               cycle1  <= ch_d(2) & ch_c(2) & ch_b(2) & ch_a(2);
               cycle2  <= ch_d(3) & ch_c(3) & ch_b(3) & ch_a(3);
               cycle3  <= ch_d(4) & ch_c(4) & ch_b(4) & ch_a(4);
               cycle4  <= ch_d(5) & ch_c(5) & ch_b(5) & ch_a(5);
               cycle5  <= ch_d(6) & ch_c(6) & ch_b(6) & ch_a(6);
               cycle6  <= ch_d(7) & ch_c(7) & ch_b(7) & ch_a(7);
               cycle7  <= ch_d(8) & ch_c(8) & ch_b(8) & ch_a(8);
            --------------------------------------------------------------
            -- CYCLE STATE 9 - The 9th pattern is detected
            --------------------------------------------------------------                 
             when CYCLE9_CHK  =>
               if i_master_bit =bitpattern9 then   
                  sm_chk_reg     <= CYCLE10_CHK;
               else 
                  sm_chk_reg     <= CYCLE0_CHK;
                  valid  <= '0';
               end if;
               cycle0  <= ch_d(9) & ch_c(9) & ch_b(9) & ch_a(9);  -- 11*4 = 44
               cycle1  <= ch_d(10) & ch_c(10) & ch_b(10) & ch_a(10);
               cycle2  <= ch_d(0) & ch_c(0) & ch_b(0) & ch_a(0);
               cycle3  <= ch_d(1) & ch_c(1) & ch_b(1) & ch_a(1);
               cycle4  <= ch_d(2) & ch_c(2) & ch_b(2) & ch_a(2);
               cycle5  <= ch_d(3) & ch_c(3) & ch_b(3) & ch_a(3);
               cycle6  <= ch_d(4) & ch_c(4) & ch_b(4) & ch_a(4);
               cycle7  <= ch_d(5) & ch_c(5) & ch_b(5) & ch_a(5);
            --------------------------------------------------------------
            -- CYCLE STATE 10 - The 10th pattern is detected
            --------------------------------------------------------------                 
             when CYCLE10_CHK  =>
               if i_master_bit =bitpattern10 then   
                  sm_chk_reg     <= CYCLE0_CHK;
               else 
                  sm_chk_reg     <= CYCLE0_CHK;
                  valid  <= '0';
               end if;
               cycle0  <= ch_d(6) & ch_c(6) & ch_b(6) & ch_a(6);  -- 11*4 = 44
               cycle1  <= ch_d(7) & ch_c(7) & ch_b(7) & ch_a(7);
               cycle2  <= ch_d(8) & ch_c(8) & ch_b(8) & ch_a(8);
               cycle3  <= ch_d(9) & ch_c(9) & ch_b(9) & ch_a(9);
               cycle4  <= ch_d(10) & ch_c(10) & ch_b(10) & ch_a(10);
               cycle5  <= ch_d(0) & ch_c(0) & ch_b(0) & ch_a(0);
               cycle6  <= ch_d(1) & ch_c(1) & ch_b(1) & ch_a(1);
               cycle7  <= ch_d(2) & ch_c(2) & ch_b(2) & ch_a(2);
            --------------------------------------------------------------
            -- others
            --------------------------------------------------------------     
            when others =>
               cycle0 <= (others=>'0');
               cycle1 <= (others=>'0');
               cycle2 <= (others=>'0');
               cycle3 <= (others=>'0');
               cycle4 <= (others=>'0');
               cycle5 <= (others=>'0');
               cycle6 <= (others=>'0');
               cycle7 <= (others=>'0');
               valid <= '0';
          end case;
        end if;
    end if;
end process;


generate_bit_match: 
for X in 0 to SAMPLE_WIDTH-1 generate -- for each bit

    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                 bit_match(X) <= '0';
            else
                if pattern(X) = data_reg(X) then
                    bit_match(X) <= '1';
                else
                    bit_match(X) <= '0';
                end if;
            end if;
        end if;
    end process;

end generate;

--***********************************************************************************
end architecture Behavioral;
--***********************************************************************************

