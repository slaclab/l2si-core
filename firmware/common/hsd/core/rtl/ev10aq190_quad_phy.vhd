-------------------------------------------------------------------------------------
-- FILE NAME : ev10aq190_quad_phy.vhd
--
-- AUTHOR    : Peter Kortekaas
--
-- COMPANY   : 4DSP
--
-- ITEM      : 1
--
-- UNITS     : Entity       - ev10aq190_quad_phy
--             architecture - ev10aq190_quad_phy_syn
--
-- LANGUAGE  : VHDL
--
-------------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------------
-- DESCRIPTION
-- ===========
--
-- ev10aq190_quad_phy
-- Notes: ev10aq190_quad_phy
-------------------------------------------------------------------------------------
--  Disclaimer: LIMITED WARRANTY AND DISCLAIMER. These designs are
--              provided to you as is.  4DSP specifically disclaims any
--              implied warranties of merchantability, non-infringement, or
--              fitness for a particular purpose. 4DSP does not warrant that
--              the functions contained in these designs will meet your
--              requirements, or that the operation of these designs will be
--              uninterrupted or error free, or that defects in the Designs
--              will be corrected. Furthermore, 4DSP does not warrant or
--              make any representations regarding use or the results of the
--              use of the designs in terms of correctness, accuracy,
--              reliability, or otherwise.
--
--              LIMITATION OF LIABILITY. In no event will 4DSP or its
--              licensors be liable for any loss of data, lost profits, cost
--              or procurement of substitute goods or services, or for any
--              special, incidental, consequential, or indirect damages
--              arising from the use or operation of the designs or
--              accompanying documentation, however caused and on any theory
--              of liability. This limitation will apply even if 4DSP
--              has been advised of the possibility of such damage. This
--              limitation shall apply not-withstanding the failure of the
--              essential purpose of any limited remedies herein.
--
----------------------------------------------

-- Library declarations
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_misc.all;
  use ieee.numeric_std.all;
Library UNISIM;
    use UNISIM.vcomponents.all;
library xil_defaultlib;
    use xil_defaultlib.types_pkg.all;
library work;
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.QuadAdcPkg.all;

entity ev10aq190_quad_phy is
  generic
  (
    DMUX_MODE    : integer := 1 -- either 1 for 1:1 mode or 2 for 1:2 mode
  );
  port (

    -- Command Interface
    axilClk          : in std_logic;
    axilRst          : in std_logic;
    axilWriteMaster  : in  AxiLiteWriteMasterType;
    axilWriteSlave   : out AxiLiteWriteSlaveType;
    axilReadMaster   : in  AxiLiteReadMasterType;
    axilReadSlave    : out AxiLiteReadSlaveType;

    -- Sync signal to ADC
    sync_p       : out std_logic;
    sync_n       : out std_logic;

    -- Channel A: DDR LVDS Interface
    adr_p        : in  std_logic;
    adr_n        : in  std_logic;
    ad_p         : in  std_logic_vector(9 downto 0);
    ad_n         : in  std_logic_vector(9 downto 0);
    aor_p        : in  std_logic;
    aor_n        : in  std_logic;

    -- Channel B: DDR LVDS Interface
    bdr_p        : in  std_logic;
    bdr_n        : in  std_logic;
    bd_p         : in  std_logic_vector(9 downto 0);
    bd_n         : in  std_logic_vector(9 downto 0);
    bor_p        : in  std_logic;
    bor_n        : in  std_logic;

    -- Channel C: DDR LVDS Interface
    cdr_p        : in  std_logic;
    cdr_n        : in  std_logic;
    cd_p         : in  std_logic_vector(9 downto 0);
    cd_n         : in  std_logic_vector(9 downto 0);
    cor_p        : in  std_logic;
    cor_n        : in  std_logic;

    -- Channel D: DDR LVDS Interface
    ddr_p        : in  std_logic;
    ddr_n        : in  std_logic;
    dd_p         : in  std_logic_vector(9 downto 0);
    dd_n         : in  std_logic_vector(9 downto 0);
    dor_p        : in  std_logic;
    dor_n        : in  std_logic;

    phy_clk      : in  std_logic;  -- 625 MHz
    adc_clk      : in  std_logic;  -- 156.25 MHz

    ps_clk           : out std_logic;
    ps_en            : out std_logic;
    ps_incdec        : out std_logic;
    ps_done          : in  std_logic;

    -- Output data ports synchronous to one clock
    phy_data_a   : out std_logic_vector(127 downto 0); -- 8 samples in parallel in 16-bit format
    phy_data_b   : out std_logic_vector(127 downto 0); -- 8 samples in parallel in 16-bit format
    phy_data_c   : out std_logic_vector(127 downto 0); -- 8 samples in parallel in 16-bit format
    phy_data_d   : out std_logic_vector(127 downto 0); -- 8 samples in parallel in 16-bit format

    -- Output clocks, for frequency monitoring
    phy_clk_a    : out std_logic;                      -- clock 1/2 of the sample frequecy
    phy_clk_b    : out std_logic;                      -- clock 1/2 of the sample frequecy
    phy_clk_c    : out std_logic;                      -- clock 1/2 of the sample frequecy
    phy_clk_d    : out std_logic                       -- clock 1/2 of the sample frequecy
  );
end ev10aq190_quad_phy;

architecture ev10aq190_quad_phy_syn of ev10aq190_quad_phy is

constant SYS_W           : integer := 44;
----------------------------------------------------------------------------------------------------
-- Signals
----------------------------------------------------------------------------------------------------
type RegType is record
  cmd_reg                : slv(31 downto 0);
  master_start           : slv( 8 downto 0);
  adrclk_delay_set_auto  : slv( 5 downto 0);
  transpose_s            : slv(63 downto 0);
  adc_req_tap_s          : slv( 8 downto 0);
  channel_select         : slv( 5 downto 0);
  pattern_error_rst      : sl;
  axilWriteSlave : AxiLiteWriteSlaveType;
  axilReadSlave  : AxiLiteReadSlaveType;
end record;
constant REG_INIT_C : RegType := (
  cmd_reg                => (others=>'0'),
  master_start           => (others=>'0'),
  adrclk_delay_set_auto  => (others=>'0'),
  transpose_s            => (others=>'0'),
  adc_req_tap_s          => (others=>'0'),
  channel_select         => (others=>'0'),
  pattern_error_rst      => '0',
  axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
  axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C );

signal r    : RegType := REG_INIT_C;
signal rin  : RegType;

signal rst            : std_logic;

signal cal_status     : std_logic_vector(4 downto 0);
signal cal_status_b0  : sl;

signal pattern_error_latch     : slv( 3 downto 0);
signal pattern_error_latch_int : slv( 3 downto 0);

signal adc_delay_ce   : std_logic_vector(43 downto 0);
signal adc_delay_inc  : std_logic_vector(43 downto 0);

-- start align command
signal start_align0         : std_logic;
signal start_align0_init    : std_logic;
signal start_align2         : std_logic;

-- clock signals
signal clk_buf_o            : std_logic;
signal clk_inv_o            : std_logic;
signal clk_div_o            : std_logic;

-- reset signals
signal delay_reset          : std_logic;
signal clk_reset            : std_logic;
signal io_reset             : std_logic;

signal delay_reset_init     : std_logic;
signal io_reset_init        : std_logic;

signal clk_in_int                : slv(3 downto 0);
signal adrclk_delay_ce           : std_logic;
signal adrclk_delay_inc          : std_logic;
signal adrclk_delay_done         : std_logic;
signal adrclk_delay_set_done     : std_logic;
signal adrclk_delay_set_done_phy : std_logic := '0';
signal adrclk_delay_set_done_phy_ms : std_logic := '0';
signal pattern_match             : std_logic_vector(SYS_W-1 downto 0);
signal transpose                 : bus064(43 downto 0);
signal transpose_r               : bus064(43 downto 0);

signal in_p                      : std_logic_vector(SYS_W-1 downto 0);
signal in_n                      : std_logic_vector(SYS_W-1 downto 0); -- system width 44
signal serdes_out                : std_logic_vector(SYS_W*8-1 downto 0); -- 352

signal adc_req_tap               : bus009(43 downto 0);
signal adc_req_tap_r             : bus009(43 downto 0);

signal adc_delay_tap             : bus009(43 downto 0);
signal locked               : std_logic := '0';
signal sync_pls             : std_logic;

----------------------------------------------------------------------------------------------------
begin
----------------------------------------------------------------------------------------------------

  rst            <= axilRst;
  axilReadSlave  <= r.axilReadSlave;
  axilWriteSlave <= r.axilWriteSlave;
  
----------------------------------------------------------------------------------------------------
-- Registers
----------------------------------------------------------------------------------------------------
comb: process (r, rst, cal_status, cal_status_b0, locked, transpose_r, adc_req_tap_r, axilWriteMaster, axilReadMaster, pattern_error_latch)
  variable v            : RegType;
  variable axilStatus   : AxiLiteStatusType;
    
  procedure axilSlaveRegisterR (addr : in slv; off : in integer; reg : in sl) is
    variable q : slv(0 downto 0);
  begin
    q(0) := reg;
    axiSlaveRegister(axilReadMaster, v.axilReadSlave, axilStatus, addr, off, q);
  end procedure;
  procedure axilSlaveRegisterR (addr : in slv; off : in integer; reg : in slv) is
  begin
    if (axilStatus.readEnable = '1') then
      if (std_match(axilReadMaster.araddr(addr'length-1 downto 0), addr)) then
        v.axilReadSlave.rdata(reg'length+off-1 downto off) := reg;
        axiSlaveReadResponse(v.axilReadSlave);
      end if;
    end if;
  end procedure;
  procedure axilSlaveRegisterW (addr : in slv; offset : in integer; reg : inout slv) is
  begin
    axiSlaveRegister(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, addr, offset, reg);
  end procedure;
  procedure axilSlaveRegisterW (addr : in slv; offset : in integer; reg : inout sl) is
  begin
    axiSlaveRegister(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, addr, offset, reg);
  end procedure;
  procedure axilSlaveDefault (
    axilResp : in slv(1 downto 0)) is
  begin
    axiSlaveDefault(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, axilResp);
  end procedure;

begin
  v := r;

  -- strobe signals
  v.cmd_reg := (others=>'0');
  
  axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);
  v.axilReadSlave.rdata := (others=>'0');

  axilSlaveRegisterW(toSlv( 0,9), 0, v.cmd_reg);
  axilSlaveRegisterR(toSlv( 4,9), 0, cal_status);
  axilSlaveRegisterR(toSlv( 4,9), 5, cal_status_b0);
  axilSlaveRegisterR(toSlv( 4,9), 8, locked);
  axilSlaveRegisterR(toSlv( 4,9),12, pattern_error_latch);
  axilSlaveRegisterW(toSlv( 8,9), 0, v.master_start);
  axilSlaveRegisterW(toSlv(12,9), 0, v.adrclk_delay_set_auto);
  axilSlaveRegisterW(toSlv(16,9), 0, v.channel_select);
  axilSlaveRegisterR(toSlv(20,9), 0, v.transpose_s  (31 downto 0));
  axilSlaveRegisterR(toSlv(24,9), 0, v.transpose_s  (63 downto 32));
  axilSlaveRegisterR(toSlv(28,9), 0, v.adc_req_tap_s);

  if axilStatus.readEnable='1' and std_match(axilReadMaster.araddr(8 downto 0),toSlv(4,9)) then
    v.pattern_error_rst := '1';
  else
    v.pattern_error_rst := '0';
  end if;

  v.transpose_s   := transpose_r  (conv_integer(r.channel_select(5 downto 0)));
  v.adc_req_tap_s := adc_req_tap_r(conv_integer(r.channel_select(5 downto 0)));
  
  if rst='1' then
    v := REG_INIT_C;
  end if;

  rin <= v;
end process;

seq: process(axilClk) is
begin
  if rising_edge(axilClk) then
    r <= rin;
  end if;
end process seq;

pelatch : process (clk_div_o, r) is
begin
  if r.pattern_error_rst='1' then
    pattern_error_latch_int <= x"0";
  elsif rising_edge(clk_div_o) then
    pattern_error_latch_int <= pattern_error_latch_int or
                               (not uAnd(pattern_match(43 downto 33)) &
                                not uAnd(pattern_match(32 downto 22)) &
                                not uAnd(pattern_match(21 downto 11)) &
                                not uAnd(pattern_match(10 downto  0)));
  end if;
end process;

process (rst, axilClk)
begin
  if (rst = '1') then
    transpose_r              <= (others=>(others=>'0'));
    adc_req_tap_r            <= (others=>(others=>'0'));
  elsif (rising_edge(axilClk)) then
    transpose_r              <= transpose;
    adc_req_tap_r            <= adc_req_tap;
   end if;
end process;


----------------------------------------------------------------------------------------------------
-- Map commands
----------------------------------------------------------------------------------------------------
delay_reset     <= r.cmd_reg(0) or rst;
clk_reset       <= r.cmd_reg(1) or rst;
io_reset        <= r.cmd_reg(2) or rst;
start_align0    <= r.cmd_reg(3);  -- start align command from sw


pulse2pulse_delay_reset: entity work.pulse2pulse
port map (
  in_clk   => axilClk,
  out_clk  => clk_div_o,
  rst      => '0',              -- rst,
  pulsein  => delay_reset,
  inbusy   => open,
  pulseout => delay_reset_init
);

pulse2pulse_io_reset : entity work.pulse2pulse
port map (
  in_clk   => axilClk,
  out_clk  => clk_div_o,
  rst      => '0',              --rst,
  pulsein  => io_reset,
  inbusy   => open,
  pulseout => io_reset_init
);

pulse2pulse_start_align0 : entity work.pulse2pulse
port map (
  in_clk   => axilClk,
  out_clk  => clk_div_o,
  rst      => '0',
  pulsein  => start_align0,
  inbusy   => open,
  pulseout => start_align0_init
);

U_Sync_pattern_error : entity work.SynchronizerVector
  generic map ( WIDTH_G => 4 )
  port map ( clk     => axilClk,
             rst     => axilRst,
             dataIn  => pattern_error_latch_int,
             dataOut => pattern_error_latch );

sync_pls <= '1';

sync_out : obufds
port map (
    i   => sync_pls,
    o   => sync_p,
    ob  => sync_n
);

----------------------------------------------------------------------------------------------------
-- Create the clock logic
----------------------------------------------------------------------------------------------------

inst_iodelay_q_dclk : entity work.clk_idelay_set
port map(
  RST_AUX           => clk_reset,
  CLK_AUX           => axilClk,
  DELAY_VALUE       => r.adrclk_delay_set_auto, --delay value to set (in)
  IDELAY_CE         => adrclk_delay_ce,
  IDELAY_INC        => adrclk_delay_inc,
  IDELAY_DONE       => adrclk_delay_done,
  ADJUST_DONE       => adrclk_delay_set_done
);

clk_inst_a : IBUFGDS
port map (
    I  => adr_p,
    IB => adr_n,
    O  => clk_in_int(0)
);

clk_inst_b : IBUFGDS
port map (
    I  => bdr_p,
    IB => bdr_n,
    O  => clk_in_int(1)
);

clk_inst_c : IBUFGDS
port map (
    I  => cdr_p,
    IB => cdr_n,
    O  => clk_in_int(2)
);

clk_inst_d : IBUFGDS
port map (
    I  => ddr_p,
    IB => ddr_n,
    O  => clk_in_int(3)
);

clk_div_o <= adc_clk;
clk_buf_o <= phy_clk;
clk_inv_o <= not clk_buf_o;

ps_clk            <= axilClk;
ps_en             <= adrclk_delay_ce;
ps_incdec         <= adrclk_delay_inc;
adrclk_delay_done <= ps_done;
--ps_clk            <= '0';
--ps_en             <= '0';
--ps_incdec         <= '0';

--serdes_mmcm_inst : entity work.serdes_mmcm
--port map (
--  CLK_IN1    => clk_in_int(0), -- 625 MHz
--  CLK_OUT1   => clk_buf_o,  -- 625 MHz
--  CLK_OUT2   => clk_div_o,  -- 156.25 MHz
----  CLK_OUT3   => open,       -- open
--  RESET      => clk_reset,
--  LOCKED     => locked,
--  PSCLK      => axilClk,
--  PSEN       => adrclk_delay_ce,
--  PSINCDEC   => adrclk_delay_inc,
--  PSDONE     => adrclk_delay_done
--);


-----------------------------------------------------
-- Calibration of ADC data
-----------------------------------------------------
-- continously check pattern
ev10aq190a_pattern_inst : entity work.ev10aq190a_pattern
port map (
    i_clk       => clk_div_o,      -- in clock in
    i_rst       => io_reset_init,  -- in reset
    i_data      => serdes_out,     -- in data pattern
    o_valid     => open,           -- out
    o_bit_match => pattern_match   -- out identify which pins are good/bad
);


-- Phase 2: Calibrate master bit (bit 0)
-- Select the tap for the master bit at the best location
-- because the clock was adjusted to the first bad position it should
-- be right at the start of the next window
calibrate_master_bit_inst:
entity work.calibrate_bit
port map(
    i_clk         => clk_div_o,
    i_rst         => io_reset_init,
    i_start_cal   => start_align0_init,
    o_start_cal   => start_align2,
    o_tap_value   => adc_req_tap(0),
    o_tap_vector  => transpose(0),
    i_bit_match   => pattern_match(0),
    o_status      => cal_status_b0,
    i_adjust_done => adrclk_delay_set_done_phy,
    i_tap_start   => r.master_start
);


---- Phase 3: Calibrate remaining bits
-- select the tap for the slave bits at the best location (without moving master bit)
adc_calibrate_inst:
entity work.calibrate
generic map(
   SAMPLE_WIDTH      => 43
)
port map(
  clk         => clk_div_o,
  rst         => io_reset_init,
  i_start_cal => start_align2,
  o_tap_value => adc_req_tap(43 downto 1),
  i_bit_match => pattern_match(43 downto 1),
  o_transpose => transpose(43 downto 1), -- tap value to set
  cal_status  => cal_status              -- calibration status
);

----------------------------------------------------------------------------------------------------
-- Channels inputs
----------------------------------------------------------------------------------------------------
-- 4 channels total, 11 bit each channel
in_p <= dor_p & dd_p & cor_p & cd_p & bor_p & bd_p & aor_p & ad_p;
in_n <= dor_n & dd_n & cor_n & cd_n & bor_n & bd_n & aor_n & ad_n;

serdes_inst : entity work.serdes
generic map (
  SYS_W               => 44,
  DEV_W               => 44*8
)
port map (
  data_in_from_pins_p => in_p,                             -- in
  data_in_from_pins_n => in_n,                             -- in
  data_in_to_device   => serdes_out,                       -- out
  rst_cmd             => rst,                              -- in
  clk_cmd             => axilClk,                       -- in

  delay_reset         => delay_reset_init,                 -- in
  delay_ce            => adc_delay_ce,                     -- in
  delay_value         => adc_delay_tap,                    -- out
  delay_inc           => adc_delay_inc,                    -- in


  clk_in_int_buf      => clk_buf_o, -- 625 MHz             -- in
  clk_in_int_inv      => clk_inv_o, -- 625 MHz inversed    -- in
  clk_div             => clk_div_o, -- 156.25 MHz          -- in
  clk_rd              => '0',
  io_reset            => io_reset_init                     -- in
);


-- iodelay control (44 pins)
generate_iodelay_adc:
for pin_count in 0 to 43 generate

   inst_iodelay_set : entity work.iodelay_set
   port map(
      RST_AUX           => delay_reset_init,
      CLK_AUX           => clk_div_o,
      IDELAYCTRL_READY  => '1', -- we assume the IDELAYCTRL is ready
      DELAY_VALUE       => adc_req_tap(pin_count), --delay value to set (in)
      IDLEAY_VALUEOUT   => adc_delay_tap(pin_count),
      IDELAY_CE         => adc_delay_ce(pin_count),
      IDELAY_INC        => adc_delay_inc(pin_count)
   );

end generate;


----------------------------------------------------------------------------------------------------
-- Serdes output mapping
----------------------------------------------------------------------------------------------------
phy_clk_a  <= clk_in_int(0);
phy_clk_b  <= clk_in_int(1);
phy_clk_c  <= clk_in_int(2);
phy_clk_d  <= clk_in_int(3);

process(clk_div_o)
begin
  if rising_edge(clk_div_o) then
    phy_data_a <=
      "00000" & serdes_out(318 downto 308) &
      "00000" & serdes_out(274 downto 264) &
      "00000" & serdes_out(230 downto 220) &
      "00000" & serdes_out(186 downto 176) &
      "00000" & serdes_out(142 downto 132) &
      "00000" & serdes_out(098 downto 088) &
      "00000" & serdes_out(054 downto 044) &
      "00000" & serdes_out(010 downto 000) ;

    phy_data_b <=
      "00000" & serdes_out(329 downto 319) &
      "00000" & serdes_out(285 downto 275) &
      "00000" & serdes_out(241 downto 231) &
      "00000" & serdes_out(197 downto 187) &
      "00000" & serdes_out(153 downto 143) &
      "00000" & serdes_out(109 downto 099) &
      "00000" & serdes_out(065 downto 055) &
      "00000" & serdes_out(021 downto 011);

    phy_data_c <=
      "00000" & serdes_out(340 downto 330) &
      "00000" & serdes_out(296 downto 286) &
      "00000" & serdes_out(252 downto 242) &
      "00000" & serdes_out(208 downto 198) &
      "00000" & serdes_out(164 downto 154) &
      "00000" & serdes_out(120 downto 110) &
      "00000" & serdes_out(076 downto 066) &
      "00000" & serdes_out(032 downto 022);

    phy_data_d <=
      "00000" & serdes_out(351 downto 341) &
      "00000" & serdes_out(307 downto 297) &
      "00000" & serdes_out(263 downto 253) &
      "00000" & serdes_out(219 downto 209) &
      "00000" & serdes_out(175 downto 165) &
      "00000" & serdes_out(131 downto 121) &
      "00000" & serdes_out(087 downto 077) &
      "00000" & serdes_out(043 downto 033);

    adrclk_delay_set_done_phy_ms <= adrclk_delay_set_done;
    adrclk_delay_set_done_phy    <= adrclk_delay_set_done_phy_ms;
  end if;
end process;

----------------------------------------------------------------------------------------------------
-- end
----------------------------------------------------------------------------------------------------
end ev10aq190_quad_phy_syn;






