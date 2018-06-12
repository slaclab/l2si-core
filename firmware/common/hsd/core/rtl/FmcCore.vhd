-------------------------------------------------------------------------------------
-- FILE NAME : fmc126_if.vhd
--
-- AUTHOR    : Peter Kortekaas
--
-- COMPANY   : 4DSP
--
-- ITEM      : 1
--
-- UNITS     : Entity       - fmc126_if
--             architecture - fmc126_if_syn
--
-- LANGUAGE  : VHDL
--
-------------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------------
-- DESCRIPTION
-- ===========
--
-- fmc126_if
-- Notes: fmc126_if
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
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_misc.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library unisim;
  use unisim.vcomponents.all;
library xil_defaultlib;
   use xil_defaultlib.types_pkg.all;

library work;
use work.QuadAdcPkg.all;
use work.AxiLitePkg.all;
use work.StdRtlPkg.all;

entity FmcCore is
generic (
  AXIL_BASEADDR : slv(31 downto 0) := (others=>'0') );
port (

  axilClk          : in std_logic;
  axilRst          : in std_logic;
  axilWriteMaster  : in  AxiLiteWriteMasterType;
  axilWriteSlave   : out AxiLiteWriteSlaveType;
  axilReadMaster   : in  AxiLiteReadMasterType;
  axilReadSlave    : out AxiLiteReadSlaveType;
  cmd_reg_o        : out slv(3 downto 0);
  cmd_reg_i        : in  slv(3 downto 0);
  
  phy_clk          : out std_logic; -- 625MHz
  ddr_clk          : in  std_logic; -- 625MHz
  adc_clk          : in  std_logic;
  adc_out          : out   AdcDataArray (3 downto 0);
  trigger_out      : out std_logic;
  irq_out          : out std_logic;

  ref_clk          : in  std_logic;
  
  ps_clk           : out std_logic;
  ps_en            : out std_logic;
  ps_incdec        : out std_logic;
  ps_done          : in  std_logic;
  
  --External signals
  fmc_to_cpld      : inout std_logic_vector(3 downto 0);

  clk_to_fpga_p    : in    std_logic;
  clk_to_fpga_n    : in    std_logic;
  clk_to_fpga      : out   std_logic;
  ext_trigger_p    : in    std_logic;
  ext_trigger_n    : in    std_logic;
  sync_from_fpga_p : out   std_logic;
  sync_from_fpga_n : out   std_logic;

  adc_in           : in    AdcInputArray(3 downto 0);

  pg_m2c           : in    std_logic;
  prsnt_m2c_l      : in    std_logic;

  tst_clks         : in  slv(7 downto 0) := (others=>'0');
  
  cal_clk_en       : out   std_logic
);
end FmcCore;

architecture fmc126_if_syn of FmcCore is

----------------------------------------------------------------------------------------------------
-- Constant declaration
----------------------------------------------------------------------------------------------------
  constant NUM_AXI_MASTERS_C : integer := 2;
  constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
    0    => (
      baseAddr        => AXIL_BASEADDR + x"00000000",
      addrBits        => 10,
      connectivity    => x"FFFF"),
    1    => (
      baseAddr        => AXIL_BASEADDR + x"00000400",
      addrBits        => 10,
      connectivity    => x"FFFF") );
  signal mAxilWriteMasters : AxiLiteWriteMasterArray(1 downto 0);
  signal mAxilWriteSlaves  : AxiLiteWriteSlaveArray (1 downto 0);
  signal mAxilReadMasters  : AxiLiteReadMasterArray (1 downto 0);
  signal mAxilReadSlaves   : AxiLiteReadSlaveArray  (1 downto 0);

----------------------------------------------------------------------------------------------------
--Signal declaration
----------------------------------------------------------------------------------------------------

signal test_clocks      : slv(15 downto 0);
signal clock_count      : slv(15 downto 0);
  
signal ext_trigger_buf  : std_logic;
signal clk_to_fpga_buf  : std_logic;

signal spi_irq_bus      : std_logic_vector(31 downto 0) := (others=>'0');
signal rst              : std_logic := '0';

signal adc_data         : bus128(3 downto 0);

signal trigger          : std_logic;
signal trigger_clk      : std_logic;
signal trigger_cmd      : std_logic;
signal sw_trigger      : std_logic;

signal  phy_data_a      : std_logic_vector(127 downto 0);
signal  phy_data_b      : std_logic_vector(127 downto 0);
signal  phy_data_c      : std_logic_vector(127 downto 0);
signal  phy_data_d      : std_logic_vector(127 downto 0);

signal  phy_clk_a       : std_logic;
signal  phy_clk_b       : std_logic;
signal  phy_clk_c       : std_logic;
signal  phy_clk_d       : std_logic;

signal  trigger_select  : std_logic_vector(1 downto 0);

type RegType is record
  irq_en         : slv(31 downto 0);
  irq            : slv(31 downto 0);
  irq_out        : sl;
  cmd_reg           : slv(31 downto 0);
  ctrl_reg          : slv(31 downto 0);
  clock_sel      : slv(3 downto 0);
  axilWriteSlave : AxiLiteWriteSlaveType;
  axilReadSlave  : AxiLiteReadSlaveType;
end record;
constant REG_INIT_C : RegType := (
  irq_en         => (others=>'0'),
  irq            => (others=>'0'),
  irq_out        => '0',
  cmd_reg        => (others=>'0'),
  ctrl_reg       => (others=>'0'),
  clock_sel      => (others=>'0'),
  axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
  axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C );

signal r    : RegType := REG_INIT_C;
signal rin  : RegType;

begin

  trigger_cmd         <= r.cmd_reg(3);
  trigger_select      <= r.ctrl_reg(5 downto 4);
  cal_clk_en          <= r.cmd_reg(0);
  
  comb: process(r, axilRst, mAxilWriteMasters(0), mAxilReadMasters(0), 
                spi_irq_bus, clock_count, pg_m2c, prsnt_m2c_l) is
    variable v : RegType;
    variable axilStatus : AxiLiteStatusType;

    procedure axilSlaveRegisterR (addr : in slv; off : integer; reg : in sl) is
      variable q : slv(0 downto 0);
    begin
      axiSlaveRegister(mAxilReadMasters(0), v.axilReadSlave, axilStatus, addr, off, reg);
    end procedure;
    procedure axilSlaveRegisterR (addr : in slv; off : integer; reg : in slv) is
    begin
      if (axilStatus.readEnable = '1') then
        if (std_match(mAxilReadMasters(0).araddr(addr'length-1 downto 0), addr)) then
          v.axilReadSlave.rdata(reg'length+off-1 downto off) := reg;
          axiSlaveReadResponse(v.axilReadSlave);
        end if;
      end if;
    end procedure;
    procedure axilSlaveRegisterW (addr : in slv; offset : in integer; reg : inout slv) is
    begin
      axiSlaveRegister(mAxilWriteMasters(0), mAxilReadMasters(0), v.axilWriteSlave, v.axilReadSlave, axilStatus, addr, offset, reg);
    end procedure;
    procedure axilSlaveRegisterW (addr : in slv; offset : in integer; reg : inout sl) is
    begin
      axiSlaveRegister(mAxilWriteMasters(0), mAxilReadMasters(0), v.axilWriteSlave, v.axilReadSlave, axilStatus, addr, offset, reg);
    end procedure;
    procedure axilSlaveDefault (
      axilResp : in slv(1 downto 0)) is
    begin
      axiSlaveDefault(mAxilWriteMasters(0), mAxilReadMasters(0), v.axilWriteSlave, v.axilReadSlave, axilStatus, axilResp);
    end procedure;

  begin
    v := r;

    v.irq_out := uOr(r.irq and r.irq_en);
    v.irq := r.irq or spi_irq_bus;
    v.cmd_reg := (others=>'0');
    
    axiSlaveWaitTxn(mAxilWriteMasters(0), mAxilReadMasters(0), v.axilWriteSlave, v.axilReadSlave, axilStatus);
    v.axilReadSlave.rdata := (others=>'0');

    axilSlaveRegisterR(toSlv( 0,8), 0, r.irq);
    axilSlaveRegisterW(toSlv( 4,8), 0, v.irq_en);
    axilSlaveRegisterR(toSlv(32,8), 0, prsnt_m2c_l);
    axilSlaveRegisterR(toSlv(32,8), 1, pg_m2c);
    axilSlaveRegisterW(toSlv(36,8), 0, v.cmd_reg);
    axilSlaveRegisterW(toSlv(40,8), 0, v.ctrl_reg);
    axilSlaveRegisterW(toSlv(64,8), 0, v.clock_sel);
    axilSlaveRegisterR(toSlv(68,8), 0, clock_count);
    
    if axilStatus.readEnable='1' and std_match(mAxilReadMasters(0).araddr,x"00") then
      v.irq := (others=>'0');
    end if;
    
    if axilRst='1' then
      v := REG_INIT_C;
    end if;

    rin <= v;

    irq_out             <= r.irq_out;
    mAxilWriteSlaves(0) <= r.axilWriteSlave;
    mAxilReadSlaves (0) <= r.axilReadSlave;
  end process comb;

  seq: process(axilClk) is
  begin
    if rising_edge(axilClk) then
      r <= rin;
    end if;
  end process seq;

  U_XBAR : entity work.AxiLiteCrossbar
    generic map (
      DEC_ERROR_RESP_G   => AXI_RESP_OK_C,
      NUM_SLAVE_SLOTS_G  => 1,
      NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
      MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
    port map (
      axiClk           => axilClk,
      axiClkRst        => axilRst,
      sAxiWriteMasters(0) => axilWriteMaster,
      sAxiWriteSlaves (0) => axilWriteSlave,
      sAxiReadMasters (0) => axilReadMaster,
      sAxiReadSlaves  (0) => axilReadSlave,
      mAxiWriteMasters => mAxilWriteMasters,
      mAxiWriteSlaves  => mAxilWriteSlaves,
      mAxiReadMasters  => mAxilReadMasters,
      mAxiReadSlaves   => mAxilReadSlaves);

----------------------------------------------------------------------------------------------------
-- Physical Data Interface for ADC0-3
----------------------------------------------------------------------------------------------------
ev10aq190_quad_phy_inst : entity work.ev10aq190_quad_phy
  port map (
    axilClk         => axilClk,
    axilRst         => axilRst,
    axilWriteMaster => mAxilWriteMasters(1),
    axilWriteSlave  => mAxilWriteSlaves (1),
    axilReadMaster  => mAxilReadMasters (1),
    axilReadSlave   => mAxilReadSlaves  (1),
    cmd_reg_o       => cmd_reg_o,
    cmd_reg_i       => cmd_reg_i,
    
    sync_p          => sync_from_fpga_p,
    sync_n          => sync_from_fpga_n,

    adr_p           => adc_in(0).clkp,
    adr_n           => adc_in(0).clkn,
    ad_p            => adc_in(0).datap(9 downto 0),
    ad_n            => adc_in(0).datan(9 downto 0),
    aor_p           => adc_in(0).datap(10),
    aor_n           => adc_in(0).datan(10),

    bdr_p           => adc_in(1).clkp,
    bdr_n           => adc_in(1).clkn,
    bd_p            => adc_in(1).datap(9 downto 0),
    bd_n            => adc_in(1).datan(9 downto 0),
    bor_p           => adc_in(1).datap(10),
    bor_n           => adc_in(1).datan(10),

    cdr_p           => adc_in(2).clkp,
    cdr_n           => adc_in(2).clkn,
    cd_p            => adc_in(2).datap(9 downto 0),
    cd_n            => adc_in(2).datan(9 downto 0),
    cor_p           => adc_in(2).datap(10),
    cor_n           => adc_in(2).datan(10),

    ddr_p           => adc_in(3).clkp,
    ddr_n           => adc_in(3).clkn,
    dd_p            => adc_in(3).datap(9 downto 0),
    dd_n            => adc_in(3).datan(9 downto 0),
    dor_p           => adc_in(3).datap(10),
    dor_n           => adc_in(3).datan(10),

    phy_clk         => ddr_clk,
    adc_clk         => adc_clk,
    ps_clk          => ps_clk,
    ps_en           => ps_en,
    ps_incdec       => ps_incdec,
    ps_done         => ps_done,

    phy_data_a      => phy_data_a,
    phy_data_b      => phy_data_b,
    phy_data_c      => phy_data_c,
    phy_data_d      => phy_data_d,

    phy_clk_a       => phy_clk_a,
    phy_clk_b       => phy_clk_b,
    phy_clk_c       => phy_clk_c,
    phy_clk_d       => phy_clk_d
  );

phy_clk        <= phy_clk_a;
adc_data(0)    <= phy_data_a;
adc_data(1)    <= phy_data_b;
adc_data(2)    <= phy_data_c;
adc_data(3)    <= phy_data_d;



---------------------------------------------------------------------------
-- ADC0-ADC3 Out Streams
-- Assuming ADC is configured for 368.64 MSPS,
-- 16-bit per sample, 8 samples in a 128-bit stream @ 92.12 MHz
---------------------------------------------------------------------------
generate_adc_output_stream:
for I in 0 to 3 generate

    process(adc_clk)
    begin
        if rising_edge(adc_clk) then
          for i in 0 to 3 loop
            for j in 0 to 7 loop
              -- is OOR in bit 10?
              adc_out(i).data(j) <= adc_data(i)(j*16+10 downto j*16);
            end loop;
          end loop;
        end if;
    end process;

end generate;

----------------------------------------------------------------------------------------------------
-- Frequency counter
----------------------------------------------------------------------------------------------------
sip_freq_cnt16_inst : entity work.axi_freq_cnt16
port map (
  refClk          => axilClk,
  refRst          => axilRst,
  cntRst          => '0',
  test_clocks     => test_clocks,
  clock_select    => r.clock_sel,
  clock_count     => clock_count );

test_clocks(0) <= axilClk; -- clk_cmd;
test_clocks(1) <= phy_clk_a;
test_clocks(2) <= phy_clk_b;
test_clocks(3) <= phy_clk_c;
test_clocks(4) <= phy_clk_d;
test_clocks(5) <= ref_clk;
test_clocks(6) <= clk_to_fpga_buf;
test_clocks(7) <= adc_clk;
test_clocks(15 downto 8) <= tst_clks;

U_TRGCLK : BUFG
  port map ( I => trigger,
             O => trigger_clk );

pulse2pulse_sw_trigget_inst:
entity work.SynchronizerOneShot
port map (
  clk       => adc_clk,
  rst       => rst,
  dataIn    => trigger_cmd,
  dataOut   => sw_trigger );

-------------------------------------------------------------------------------------
-- External Trigger
-------------------------------------------------------------------------------------
ext_trigger_inst0:
entity work.ext_trigger
port map (
    clk_in          => adc_clk,
    ext_trigger_p   => ext_trigger_p,  -- external in
    ext_trigger_n   => ext_trigger_n,  -- external in
    sw_trigger      => sw_trigger,     -- software trigger in
    trigger_select  => trigger_select, -- 0 = external, 1 = internal
    ext_trigger     => trigger
);

trigger_out <= trigger;


----------------------------------------------------------------------------------------------------
-- Clock input
----------------------------------------------------------------------------------------------------

clk_to_fpga <= clk_to_fpga_buf;

ibufgds_ref_clk : ibufgds
generic map (
  IOSTANDARD => "LVDS_25",
  DIFF_TERM => TRUE
)
port map (
  i  => clk_to_fpga_p,
  ib => clk_to_fpga_n,
  o  => clk_to_fpga_buf
);

----------------------------------------------------------------------------------------------------
-- CPLD Bus
----------------------------------------------------------------------------------------------------
-- The CPLD bus is mapped to the CPLD on the FMC12x and is reserved for future use. These signals
-- are not used by the CPLD on the FMC12x.
----------------------------------------------------------------------------------------------------
fmc_to_cpld <= (others => 'Z');

----------------------------------------------------------------------------------------------------
-- End
----------------------------------------------------------------------------------------------------
end fmc126_if_syn;

