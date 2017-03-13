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
-- AXI Interrupt controller
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
    use ieee.math_real.all;
Library UNISIM;
    use UNISIM.vcomponents.all;

library xil_defaultlib;
   use xil_defaultlib.types_pkg.all;
-------------------------------------------------------------------------------------
-- ENTITY
-------------------------------------------------------------------------------------
entity intrcXX is
generic (
    NUM_INTERRUPTS    : natural := 16
);
port (
   clk              : in  std_logic;
   rst              : in  std_logic;
   irq_in           : in  std_logic_vector(NUM_INTERRUPTS-1 downto 0);
   irq_out          : out std_logic;
   isr_out          : out std_logic_vector(31 downto 0);
   isr_rd_in        : in std_logic;
   queue_cnt_out    : out std_logic_vector(31 downto 0)
);
end intrcXX;

-------------------------------------------------------------------------------------
-- ARCHITECTURE
-------------------------------------------------------------------------------------
architecture Behavioral of intrcXX is

-----------------------------------------------------------------------------------
-- COMPONENTS
-----------------------------------------------------------------------------------
COMPONENT fwft_intr_queue
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    rd_data_count : OUT STD_LOGIC_VECTOR(10 DOWNTO 0)
  );
END COMPONENT;

-----------------------------------------------------------------------------------
-- CONSTANTS
-----------------------------------------------------------------------------------
constant NUM_INTR_LOG_2 :natural := NATURAL(CEIL(LOG2(REAL(NUM_INTERRUPTS))));

-------------------------------------------------------------------------------------
-- SIGNALS
-------------------------------------------------------------------------------------
signal fwft_wr_en   : std_logic;
signal fwft_rd_en   : std_logic;
signal fwft_din     : std_logic_vector(31 downto 0);
signal fwft_dout    : std_logic_vector(31 downto 0);
signal fwft_empty   : std_logic;
signal fwft_rd_cnt  : std_logic_vector(10 downto 0);


signal arbitrator_cnt : std_logic_vector(NUM_INTR_LOG_2-1 downto 0);

signal irq_clr        : std_logic_vector(NUM_INTERRUPTS-1 downto 0);
signal irq_active     : std_logic_vector(NUM_INTERRUPTS-1 downto 0);
signal irq_in_prev    : std_logic_vector(NUM_INTERRUPTS-1 downto 0);

--***********************************************************************************
begin
--***********************************************************************************

---------------------------------------------------------------------------------------
-- FWFT FIFO queue 1024 deep
---------------------------------------------------------------------------------------
fwft_intr_queue_inst0 : fwft_intr_queue
port map (
    rst           => rst,
    wr_clk        => clk,
    rd_clk        => clk,
    din           => fwft_din,
    wr_en         => fwft_wr_en,
    rd_en         => fwft_rd_en,
    dout          => fwft_dout,
    full          => open,
    empty         => fwft_empty,
    rd_data_count => fwft_rd_cnt
);

--each time we read the interrupt queue we have to make sure that we deassert
--the interrupt signal. This to allow an edge sensitive
--receiver to detect that we cleared one interrupt
irq_out       <= not fwft_empty and not isr_rd_in;
fwft_rd_en    <= isr_rd_in;
isr_out       <= fwft_dout;
queue_cnt_out <= conv_std_logic_vector(0, 32-fwft_rd_cnt'length) & fwft_rd_cnt(fwft_rd_cnt'range);

--------------------------------------------------------------------------------------
-- Interrupt Arbitrator, check each interrupt in a round robin fashion
---------------------------------------------------------------------------------------
process(clk, rst)
begin
    if rising_edge(clk) then
        if rst = '1' then
            arbitrator_cnt <= (others=>'0');
            fwft_wr_en     <= '0';
            fwft_din       <= (others=>'0');
            irq_clr        <= (others=>'1');
        else
           -- loop through each interrupt continously
           if  arbitrator_cnt = NUM_INTERRUPTS then
               arbitrator_cnt <= (others=>'0');
           else
               arbitrator_cnt <= arbitrator_cnt + 1;
           end if;


           if irq_active(conv_integer(arbitrator_cnt)) = '1' then
               fwft_wr_en   <= '1';
               irq_clr(conv_integer(arbitrator_cnt))  <= '1';
           else
               fwft_wr_en   <= '0';
               irq_clr(conv_integer(arbitrator_cnt-1)) <= '0';
           end if;
           fwft_din <= conv_std_logic_vector(0, 32-arbitrator_cnt'length) & arbitrator_cnt;

        end if;
    end if;
end process;

gen_capture_interrupt:
for i in 0 to (NUM_INTERRUPTS - 1) generate

        process (clk, irq_clr(i))
        begin
            if rising_edge(clk) then
      irq_in_prev <= irq_in;
                if irq_clr(i) = '1' then
                    irq_active(i) <= '0';
                else
        --we only request to transmit an IRQ once per rising edge of each irq
                    if irq_in(i)='1'  and irq_in_prev(i) = '0' then
                        irq_active(i) <= '1';
                    end if;
                end if;
            end if;
        end process;

end generate;



--***********************************************************************************
end architecture Behavioral;
--***********************************************************************************

