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
library work;
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

-------------------------------------------------------------------------------------
-- ENTITY
-------------------------------------------------------------------------------------
entity quadadc_mmcm is
port (
  -- From the system into the device
  clk_in1  : in  sl;
  clk_out1 : out sl;
  clk_out2 : out sl;
  clk_out3 : out sl;
  clk_out4 : out sl;
  psclk    : in  sl;
  psen     : in  sl;
  psincdec : in  sl;
  psdone   : out sl;
  reset    : in  sl;
  locked   : out sl );
end quadadc_mmcm;


-------------------------------------------------------------------------------------
-- ARCHITECTURE
-------------------------------------------------------------------------------------
architecture arch of quadadc_mmcm is

  signal clk_in1_buf : sl;
  signal clkfb_out   : sl;
  signal clkfb_in    : sl;
  signal clk_out1_int : sl;
  signal clk_out2_int : sl;
  signal clk_out3_int : sl;
  signal clk_out4_int : sl;

--***********************************************************************************
begin
--***********************************************************************************

  U_FBBUF : BUFG
    port map ( I => clkfb_out,
               O => clkfb_in  );

  U_OBUF1 : BUFG
    port map ( I => clk_out1_int,
               O => clk_out1 );

  U_OBUF2 : BUFG
    port map ( I => clk_out2_int,
               O => clk_out2 );

  U_OBUF3 : BUFG
    port map ( I => clk_out3_int,
               O => clk_out3 );

  U_OBUF4 : BUFG
    port map ( I => clk_out4_int,
               O => clk_out4 );

  U_MMCM : MMCME3_ADV
    generic map ( BANDWIDTH            => "OPTIMIZED",
                  CLKOUT4_CASCADE      => "FALSE",
                  COMPENSATION         => "AUTO",
                  STARTUP_WAIT         => "FALSE",
                  DIVCLK_DIVIDE        => 2,
                  CLKFBOUT_MULT_F      => 2.000,
                  CLKFBOUT_PHASE       => 0.000,
                  CLKFBOUT_USE_FINE_PS => "FALSE",
                  CLKOUT0_DIVIDE_F     => 1.000,
                  CLKOUT0_PHASE        => 0.000,
                  CLKOUT0_DUTY_CYCLE   => 0.500,
                  CLKOUT0_USE_FINE_PS  => "FALSE",
                  CLKOUT1_DIVIDE       => 4,
                  CLKOUT1_PHASE        => 0.000,
                  CLKOUT1_DUTY_CYCLE   => 0.500,
                  CLKOUT1_USE_FINE_PS  => "FALSE",
                  CLKOUT2_DIVIDE       => 5,
                  CLKOUT2_PHASE        => 0.000,
                  CLKOUT2_DUTY_CYCLE   => 0.500,
                  CLKOUT2_USE_FINE_PS  => "FALSE",
                  CLKOUT3_DIVIDE       => 20,
                  CLKOUT3_PHASE        => 0.000,
                  CLKOUT3_DUTY_CYCLE   => 0.500,
                  CLKOUT3_USE_FINE_PS  => "FALSE",
                  CLKIN1_PERIOD        => 1.6)
    port map ( 
      CLKFBOUT            => clkfb_out,
      CLKFBOUTB           => open,
      CLKOUT0             => clk_out1_int,
      CLKOUT0B            => open,
      CLKOUT1             => clk_out2_int,
      CLKOUT1B            => open,
      CLKOUT2             => clk_out3_int,
      CLKOUT2B            => open,
      CLKOUT3             => clk_out4_int,
      CLKOUT3B            => open,
      CLKOUT4             => open,
      CLKOUT5             => open,
      CLKOUT6             => open,
      -- Input clock control
      CLKFBIN             => clkfb_in,
      CLKIN1              => clk_in1,
      CLKIN2              => '0',
      -- Tied to always select the primary input clock
      CLKINSEL            => '1',
      -- Ports for dynamic reconfiguration
      DCLK     => '0',
      DRDY     => open,
      DEN      => '0',
      DWE      => '0',
      DADDR    => (others=>'0'),
      DI       => (others=>'0'),
      DO       => open,
      CDDCDONE            => open,
      CDDCREQ             => '0',
      -- Ports for dynamic phase shift
      PSCLK               => psclk,
      PSEN                => psen,
      PSINCDEC            => psincdec,
      PSDONE              => psdone,
      -- Other control and status signals
      LOCKED              => locked,
      CLKINSTOPPED        => open,
      CLKFBSTOPPED        => open,
      PWRDWN              => '0',
      RST                 => reset);

end arch;
