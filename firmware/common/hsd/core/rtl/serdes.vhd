------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_misc.all;
  use ieee.numeric_std.all;
library unisim;
  use unisim.vcomponents.all;
library xil_defaultlib;
        use xil_defaultlib.types_pkg.all;

-------------------------------------------------------------------------------------
-- ENTITY
-------------------------------------------------------------------------------------
entity serdes is
generic (
  SYS_W                 : integer := 10; -- width of the data for the system
  DEV_W                 : integer := 80  -- width of the data for the device
);
port (
  -- From the system into the device
  data_in_from_pins_p   : in    std_logic_vector(SYS_W-1 downto 0);
  data_in_from_pins_n   : in    std_logic_vector(SYS_W-1 downto 0);
  data_in_to_device     : out   std_logic_vector(DEV_W-1 downto 0);
  -- Command
  rst_cmd               : in    std_logic;
  clk_cmd               : in    std_logic;
  -- IODELAY control signals
  delay_ce              : in   std_logic_vector(43 downto 0);
  delay_inc             : in   std_logic_vector(43 downto 0);
  delay_reset           : in   std_logic;                            -- active high synchronous reset for input delay
  delay_value           : out  bus009(SYS_W-1 downto 0); -- automatic alignment ready flags

  -- Clock and reset signals
  clk_in_int_buf        : in    std_logic;                            -- fast clock
  clk_in_int_inv        : in    std_logic;                            -- fast clock inverted
  clk_div               : in    std_logic;                            -- slow clock
  clk_rd                : in    std_logic;
  io_reset              : in    std_logic                             -- reset signal for io circuit
);
end serdes;


-------------------------------------------------------------------------------------
-- ARCHITECTURE
-------------------------------------------------------------------------------------
architecture serdes_arch of serdes is

----------------------------------------------------------------------------------------------------
-- Component declaration
----------------------------------------------------------------------------------------------------

component pulse2pulse is
port (
  in_clk   : in  std_logic;
  out_clk  : in  std_logic;
  rst      : in  std_logic;
  pulsein  : in  std_logic;
  inbusy   : out std_logic;
  pulseout : out std_logic
);
end component pulse2pulse;

----------------------------------------------------------------------------------------------------
-- Constant declaration
----------------------------------------------------------------------------------------------------
constant SER_W        : integer := DEV_W/SYS_W;
constant IDELAY_VALUE : integer := 0; -- initial delay value between 0 and 31

----------------------------------------------------------------------------------------------------
-- Signal declaration
----------------------------------------------------------------------------------------------------
signal data_in_to_device_reg     : std_logic_vector(DEV_W-1 downto 0);
signal data_in_to_device_sig     : std_logic_vector(DEV_W-1 downto 0);

signal data_in_from_pins_int     : std_logic_vector(SYS_W-1 downto 0);
signal data_in_from_pins_delay   : std_logic_vector(SYS_W-1 downto 0);

signal delay_ce_int              : std_logic_vector(SYS_W-1 downto 0) := (others => '0');
signal delay_inc_int             : std_logic_vector(SYS_W-1 downto 0) := (others => '0');
signal delay_value_int           : bus009(SYS_W-1 downto 0); -- automatic alignment ready flags
signal bitslip_int               : std_logic_vector(SYS_W-1 downto 0) := (others => '0');

type serdes_array is array (0 to SYS_W-1) of std_logic_vector(SER_W-1 downto 0);

signal iserdes_q                 : serdes_array := (( others => (others => '0')));

signal fifo_rd                   : std_logic_vector(SYS_W-1 downto 0);
signal fifo_empty                : std_logic_vector(SYS_W-1 downto 0);

attribute keep : string;
attribute    S : string;

attribute keep of delay_value_int : signal is "true";
attribute    S of delay_value_int : signal is "true";

--***********************************************************************************
begin
--***********************************************************************************

delay_ce_int  <= delay_ce;
delay_inc_int <= delay_inc;

fifo_rd <= not fifo_empty;

----------------------------------------------------------------------------------------------------
-- Physical Connections
----------------------------------------------------------------------------------------------------
-- We have multiple bits - step over every bit, instantiating the required elements
pins: for pin_count in 0 to SYS_W-1 generate

  -- Instantiate a buffer for every bit of the data bus
  ibufds_inst : IBUFDS
  generic map (
    DIFF_TERM  => TRUE,             -- Differential termination
    IOSTANDARD => "LVDS_25"
  )
  port map (
    i          => data_in_from_pins_p(pin_count),
    ib         => data_in_from_pins_n(pin_count),
    o          => data_in_from_pins_int(pin_count)
  );

  -- Instantiate the delay primitive
     iodelay_bus : IDELAYE3
       generic map (
         DELAY_SRC              => "IDATAIN",    -- IDATAIN, DATAIN
         CASCADE                => "NONE",
         DELAY_TYPE             => "VARIABLE",   -- FIXED, VARIABLE, or VAR_LOAD
         DELAY_VALUE            => IDELAY_VALUE, -- 0 to 31
         REFCLK_FREQUENCY       => 312.5,
         DELAY_FORMAT           => "COUNT",
         UPDATE_MODE            => "ASYNC"
       )
       port map (
         CASC_RETURN            => '0',
         CASC_IN                => '0',
         CASC_OUT               => open,
         CE                     => delay_ce_int(pin_count),
         CLK                    => clk_div,
         INC                    => delay_inc_int(pin_count),
         LOAD                   => '0',
         CNTVALUEIN             => "000000000",
         CNTVALUEOUT            => delay_value_int(pin_count),
         DATAIN                 => '0', -- Data from FPGA logic
         IDATAIN                => data_in_from_pins_int(pin_count), -- Driven by IOB
         DATAOUT                => data_in_from_pins_delay(pin_count),
         RST                    => delay_reset,
         EN_VTC                 => '0'
       );

  ----------------------------------------------------------------------------------------------------
  -- Instantiate the serdes primitive, master/slave serdes for 8x deserialisation
  ----------------------------------------------------------------------------------------------------
  serdes_w4: if SER_W = 4 generate
    iserdese3_by4 : ISERDESE3
    generic map (
      DATA_WIDTH        => 4,
--      FIFO_ENABLE       => "TRUE", -- Beam synchronous
      FIFO_ENABLE       => "FALSE",  -- Beam asynchronous
      FIFO_SYNC_MODE    => "FALSE"
    )
    port map (
      CLK               => clk_in_int_buf,                     -- Fast Source Synchronous SERDES clock from BUFIO
      CLK_B             => clk_in_int_inv,                     -- Locally inverted clock
      CLKDIV            => clk_div,                            -- Slow clock driven by BUFR
      D                 => data_in_from_pins_delay(pin_count),
      Q                 => iserdes_q(pin_count),
      RST               => io_reset,                           -- 1-bit Asynchronous reset only.
      FIFO_RD_CLK       => clk_rd,
      FIFO_RD_EN        => fifo_rd   (pin_count),
      FIFO_EMPTY        => fifo_empty(pin_count),
      INTERNAL_DIVCLK   => open
    );

  end generate;

  serdes_w8: if SER_W = 8 generate
    iserdese3_by8 : ISERDESE3
    generic map (
      DATA_WIDTH        => 8,
      FIFO_ENABLE       => "FALSE",
      FIFO_SYNC_MODE    => "FALSE"
    )
    port map (
      CLK               => clk_in_int_buf,                     -- Fast Source Synchronous SERDES clock from BUFIO
      CLK_B             => clk_in_int_inv,                     -- Locally inverted clock
      CLKDIV            => clk_div,                            -- Slow clock driven by BUFR
      D                 => data_in_from_pins_delay(pin_count),
      Q                 => iserdes_q(pin_count),
      RST               => io_reset,                           -- 1-bit Asynchronous reset only.
      FIFO_RD_CLK       => clk_rd,
      FIFO_RD_EN        => fifo_rd   (pin_count),
      FIFO_EMPTY        => fifo_empty(pin_count),
      INTERNAL_DIVCLK   => open
    );

  end generate;

end generate pins;

----------------------------------------------------------------------------------------------------
-- Reorder bits to one parallel bus
----------------------------------------------------------------------------------------------------
sys_bits: for p in 0 to SYS_W-1 generate --loop per pin

  ser_bits: for b in 0 to SER_W-1 generate --loop per bit

    data_in_to_device_sig(b*SYS_W+p) <= iserdes_q(p)(b);

  end generate ser_bits;

end generate sys_bits;

----------------------------------------------------------------------------------------------------
-- Register output
----------------------------------------------------------------------------------------------------
process(clk_div)
begin
   if rising_edge(clk_div) then
      data_in_to_device_reg   <= data_in_to_device_sig;
      delay_value             <= delay_value_int;
   end if;
end process;

-- connect to toplevel
data_in_to_device <= data_in_to_device_reg;

----------------------------------------------------------------------------------------------------
-- End
----------------------------------------------------------------------------------------------------
end serdes_arch;



