-----------------------------------------------------------------
-- Entity freq_cnt16
----------------------------------------------------------------

library ieee;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_misc.all;
  use ieee.std_logic_arith.all;
  use ieee.math_real.all;
  use ieee.std_logic_1164.all;

library work;
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

-------------------------------------------------------------------------------------
--Entity Declaration
-------------------------------------------------------------------------------------
entity axi_freq_cnt16 is
port (
  refClk           : in  sl;
  refRst           : in  sl;
  cntRst           : in  sl;
  clock_select     : in  slv(3 downto 0);
  -- Clocks Interface
  test_clocks      : in  slv(15 downto 0);
  clock_count      : out slv(15 downto 0)
);
end axi_freq_cnt16;

-------------------------------------------------------------------------------------
--Architecture declaration
-------------------------------------------------------------------------------------
architecture freq_cnt16_syn of axi_freq_cnt16 is

  type RegType is record
    ref_cntr        : integer range 2**13-1 downto 0;
    ref_trigger     : sl;
  end record;
  constant REG_INIT_C : RegType := (
    ref_cntr        => 0,
    ref_trigger     => '1' );

-----------------------------------------------------------------------------------
-- Constant declarations
-----------------------------------------------------------------------------------
  constant NB_CNTR : integer := 16;
  type std2d_nb_cntrb is array(natural range <>) of std_logic_vector(NB_CNTR - 1  downto 0);

-----------------------------------------------------------------------------------
--Signal declarations
-----------------------------------------------------------------------------------
  signal trigger         : std_logic_vector(NB_CNTR - 1 downto 0);
  signal clk_cntr        : std2d_nb_cntrb(NB_CNTR - 1 downto 0);
  signal clk_cnt_reg     : std2d_nb_cntrb(NB_CNTR - 1 downto 0);
  signal clock_cnt_out   : std_logic_vector(NB_CNTR - 1 downto 0);

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;
  
--*****************************************************************************
begin
--*****************************************************************************
  
  comb: process (r, refRst)
    variable v : RegType;
  begin
    v := r;

    if r.ref_cntr = 2**13-1 then
      v.ref_cntr    := 0;
      v.ref_trigger := '1';
    else
      v.ref_cntr    := r.ref_cntr+1;
      v.ref_trigger := '0';
    end if;
    
    if refRst='1' then
      v := REG_INIT_C;
    end if;

    rin <= v;
  end process comb;

  seq: process(refClk) is
  begin
    if rising_edge(refClk) then
      r <= rin;
    end if;
  end process seq;

-----------------------------------------------------------------------------------
-- Clock counters
-----------------------------------------------------------------------------------

  CNTR_GEN : for i in 0 to NB_CNTR - 1 generate

    p2p_trigger_inst : entity work.SynchronizerOneShot
      port map (
        clk      => test_clocks(i),
        rst      => refRst,
        dataIn   => r.ref_trigger,
        dataOut  => trigger(i)
        );

    process(refRst, cntRst, test_clocks(i))
    begin
      if (refRst = '1' or cntRst = '1') then

        clk_cntr(i)    <= (others=>'0');
        clk_cnt_reg(i) <= (others=>'0');

      elsif (rising_edge(test_clocks(i))) then

        if (trigger(i) = '1') then
          clk_cntr(i)    <= (others=>'0');
          clk_cnt_reg(i) <= clk_cntr(i);
        else
          clk_cntr(i)    <= clk_cntr(i) + 1;
          clk_cnt_reg(i) <= clk_cnt_reg(i);
        end if;

      end if;
    end process;

  end generate;

-----------------------------------------------------------------------------------
-- Output MUX
-----------------------------------------------------------------------------------

  process(r, clk_cnt_reg, clock_select)
  begin
    clock_count <= clk_cnt_reg(conv_integer(clock_select));
  end process;


--*****************************************************************************
end freq_cnt16_syn;
--*****************************************************************************
