library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.NUMERIC_STD.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;

entity hsd_fex_wrapper is
  generic ( RAM_DEPTH_G   : integer := 4096;
            AXIS_CONFIG_G : AxiStreamConfigType );
  port (
    clk             :  in sl;
    rst             :  in sl;
    din             :  in Slv11Array(7 downto 0);
    lopen           :  in sl;  -- begin sampling
    lphase          :  in slv(2 downto 0);
    lclose          :  in sl;  -- end sampling
    l1in            :  in sl;  -- once per lopen
    l1a             :  in sl;  -- accept/reject
    -- readout interface
    axisMaster      : out AxiStreamMasterType;
    axisSlave       :  in AxiStreamSlaveType;
    -- configuration interface
    axilReadMaster  :  in AxiLiteReadMasterType;
    axilReadSlave   : out AxiLiteReadSlaveType;
    axilWriteMaster :  in AxiLiteWriteMasterType;
    axilWriteSlave  : out AxiLiteWriteSlaveType );
end hsd_fex_wrapper;

architecture mapping of hsd_fex_wrapper is

  component hsd_fex
    generic (
      C_S_AXI_BUS_A_ADDR_WIDTH : INTEGER := 5;
      C_S_AXI_BUS_A_DATA_WIDTH : INTEGER := 32 );
    port (
      ap_start : IN STD_LOGIC;
      ap_done : OUT STD_LOGIC;
      ap_idle : OUT STD_LOGIC;
      ap_ready : OUT STD_LOGIC;
      sync  : IN STD_LOGIC;
      x0_V : IN STD_LOGIC_VECTOR (10 downto 0);
      x1_V : IN STD_LOGIC_VECTOR (10 downto 0);
      x2_V : IN STD_LOGIC_VECTOR (10 downto 0);
      x3_V : IN STD_LOGIC_VECTOR (10 downto 0);
      x4_V : IN STD_LOGIC_VECTOR (10 downto 0);
      x5_V : IN STD_LOGIC_VECTOR (10 downto 0);
      x6_V : IN STD_LOGIC_VECTOR (10 downto 0);
      x7_V : IN STD_LOGIC_VECTOR (10 downto 0);
      y0_V : OUT STD_LOGIC_VECTOR (15 downto 0);
      y1_V : OUT STD_LOGIC_VECTOR (15 downto 0);
      y2_V : OUT STD_LOGIC_VECTOR (15 downto 0);
      y3_V : OUT STD_LOGIC_VECTOR (15 downto 0);
      y4_V : OUT STD_LOGIC_VECTOR (15 downto 0);
      y5_V : OUT STD_LOGIC_VECTOR (15 downto 0);
      y6_V : OUT STD_LOGIC_VECTOR (15 downto 0);
      y7_V : OUT STD_LOGIC_VECTOR (15 downto 0);
      t0_V : OUT STD_LOGIC_VECTOR (13 downto 0);
      t1_V : OUT STD_LOGIC_VECTOR (13 downto 0);
      t2_V : OUT STD_LOGIC_VECTOR (13 downto 0);
      t3_V : OUT STD_LOGIC_VECTOR (13 downto 0);
      t4_V : OUT STD_LOGIC_VECTOR (13 downto 0);
      t5_V : OUT STD_LOGIC_VECTOR (13 downto 0);
      t6_V : OUT STD_LOGIC_VECTOR (13 downto 0);
      t7_V : OUT STD_LOGIC_VECTOR (13 downto 0);
      yv_V : OUT STD_LOGIC_VECTOR (3 downto 0);
      s_axi_BUS_A_AWVALID : IN STD_LOGIC;
      s_axi_BUS_A_AWREADY : OUT STD_LOGIC;
      s_axi_BUS_A_AWADDR : IN STD_LOGIC_VECTOR (C_S_AXI_BUS_A_ADDR_WIDTH-1 downto 0);
      s_axi_BUS_A_WVALID : IN STD_LOGIC;
      s_axi_BUS_A_WREADY : OUT STD_LOGIC;
      s_axi_BUS_A_WDATA : IN STD_LOGIC_VECTOR (C_S_AXI_BUS_A_DATA_WIDTH-1 downto 0);
      s_axi_BUS_A_WSTRB : IN STD_LOGIC_VECTOR (C_S_AXI_BUS_A_DATA_WIDTH/8-1 downto 0);
      s_axi_BUS_A_ARVALID : IN STD_LOGIC;
      s_axi_BUS_A_ARREADY : OUT STD_LOGIC;
      s_axi_BUS_A_ARADDR : IN STD_LOGIC_VECTOR (C_S_AXI_BUS_A_ADDR_WIDTH-1 downto 0);
      s_axi_BUS_A_RVALID : OUT STD_LOGIC;
      s_axi_BUS_A_RREADY : IN STD_LOGIC;
      s_axi_BUS_A_RDATA : OUT STD_LOGIC_VECTOR (C_S_AXI_BUS_A_DATA_WIDTH-1 downto 0);
      s_axi_BUS_A_RRESP : OUT STD_LOGIC_VECTOR (1 downto 0);
      s_axi_BUS_A_BVALID : OUT STD_LOGIC;
      s_axi_BUS_A_BREADY : IN STD_LOGIC;
      s_axi_BUS_A_BRESP : OUT STD_LOGIC_VECTOR (1 downto 0);
      ap_clk : IN STD_LOGIC;
      ap_rst_n : IN STD_LOGIC );
  end component;

  constant LATENCY_C : integer := 0;
  constant ROW_SIZE : integer := 8;
  constant IDX_BITS : integer := bitSize(ROW_SIZE-1);
  constant RAM_ADDR_WIDTH_C : integer := bitSize(RAM_DEPTH_G);
  constant CACHE_ADDR_LEN_C : integer := RAM_ADDR_WIDTH_C+IDX_BITS;

  type StateType is ( EMPTY_S, OPENING_S, OPEN_S, CLOSING_S, CLOSED_S, READING_S, LAST_S );
  type TrigStateType is ( WAIT_T, ACCEPT_T, REJECT_T );
  type MapStateType is ( BEGIN_M, END_M, DONE_M );
  
  type CacheType is record
    state  : StateType;
    trigd  : TrigStateType;
    mapd   : MapStateType;
    boffs  : slv(13 downto 0);
    baddr  : slv(CACHE_ADDR_LEN_C-1 downto 0);
    eaddr  : slv(CACHE_ADDR_LEN_C-1 downto 0);
  end record;
  constant CACHE_INIT_C : CacheType := (
    state  => EMPTY_S,
    trigd  => WAIT_T,
    mapd   => DONE_M,
    boffs  => (others=>'0'),
    baddr  => (others=>'0'),
    eaddr  => (others=>'0') );
  
  type CacheArray is array(natural range<>) of CacheType;

  constant MAX_OVL_C : integer := 16;
  constant MAX_OVL_BITS_C : integer := bitSize(MAX_OVL_C-1);

  type RegType is record
    sync       : sl;
    count      : slv(13 downto 0);
    tout       : Slv14Array(ROW_SIZE-1 downto 0);
    dout       : Slv16Array(ROW_SIZE-1 downto 0);
    douten     : slv(3 downto 0);
    iempty     : slv(MAX_OVL_BITS_C-1 downto 0);
    iopening   : slv(MAX_OVL_BITS_C-1 downto 0);
    iopened    : slv(MAX_OVL_BITS_C-1 downto 0);
    iclosing   : slv(MAX_OVL_BITS_C-1 downto 0);
    ireading   : slv(MAX_OVL_BITS_C-1 downto 0);
    itrigger   : slv(MAX_OVL_BITS_C-1 downto 0);
    ibegin     : slv(MAX_OVL_BITS_C-1 downto 0);
    iend       : slv(MAX_OVL_BITS_C-1 downto 0);
    cache      : CacheArray(MAX_OVL_C-1 downto 0);
    rden       : sl;
    rdaddr     : slv(RAM_ADDR_WIDTH_C-1 downto 0);
    wren       : sl;
    wrfull     : sl;
    wrword     : slv(IDX_BITS-1 downto 0);
    wrdata     : Slv16Array(2*ROW_SIZE-1 downto 0);
    wraddr     : slv(RAM_ADDR_WIDTH_C-1 downto 0);
    shift      : Slv6Array(1 downto 0);
    shiftEn    : slv      (1 downto 0);
    axisMaster : AxiStreamMasterType;
  end record;
  constant REG_INIT_C : RegType := (
    sync       => '1',
    count      => (others=>'0'),
    tout       => (others=>(others=>'0')),
    dout       => (others=>(others=>'0')),
    douten     => (others=>'0'),
    iempty     => (others=>'0'),
    iopening   => (others=>'0'),
    iopened    => (others=>'0'),
    iclosing   => (others=>'0'),
    ireading   => (others=>'0'),
    itrigger   => (others=>'0'),
    ibegin     => (others=>'0'),
    iend       => (others=>'0'),
    cache      => (others=>CACHE_INIT_C),
    rden       => '0',
    rdaddr     => (others=>'0'),
    wren       => '0',
    wrfull     => '0',
    wrword     => (others=>'0'),
    wrdata     => (others=>(others=>'0')),
    wraddr     => (others=>'0'),
    shift      => (others=>(others=>'0')),
    shiftEn    => (others=>'0'),
    axisMaster => AXI_STREAM_MASTER_INIT_C );

  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;

  signal rstn   : sl;
  signal dout   : Slv16Array(ROW_SIZE-1 downto 0);
  signal tout   : Slv14Array(ROW_SIZE-1 downto 0);
  signal douten : slv(IDX_BITS downto 0);
  signal ldone  : sl;
  signal rdaddr : slv(RAM_ADDR_WIDTH_C-1 downto 0);
  signal rddata : slv(ROW_SIZE*16-1 downto 0);
  signal wrdata : slv(ROW_SIZE*16-1 downto 0);
  signal maxisSlave : AxiStreamSlaveType;
  
begin

  rstn <= not rst;

  U_SHIFT : entity work.AxiStreamShift
    generic map ( AXIS_CONFIG_G => AXIS_CONFIG_G )
    port map ( axisClk     => clk,
               axisRst     => rst,
               axiStart    => r.shiftEn(0),
               axiShiftDir => '1',
               axiShiftCnt => r.shift(0),
               sAxisMaster => r.axisMaster,
               sAxisSlave  => maxisSlave,
               mAxisMaster => axisMaster,
               mAxisSlave  => axisSlave );
               
  U_FEX : hsd_fex
    port map ( ap_start            => '1',
               ap_done             => open,
               ap_idle             => open,
               ap_ready            => open,
               sync                => r.sync,
               ap_clk              => clk,
               ap_rst_n            => rstn,
               x0_V                => din(0),
               x1_V                => din(1),
               x2_V                => din(2),
               x3_V                => din(3),
               x4_V                => din(4),
               x5_V                => din(5),
               x6_V                => din(6),
               x7_V                => din(7),
               y0_V                => dout(0),
               y1_V                => dout(1),
               y2_V                => dout(2),
               y3_V                => dout(3),
               y4_V                => dout(4),
               y5_V                => dout(5),
               y6_V                => dout(6),
               y7_V                => dout(7),
               t0_V                => tout(0),
               t1_V                => tout(1),
               t2_V                => tout(2),
               t3_V                => tout(3),
               t4_V                => tout(4),
               t5_V                => tout(5),
               t6_V                => tout(6),
               t7_V                => tout(7),
               yv_V                => douten,
               s_axi_BUS_A_AWVALID => axilWriteMaster.awvalid,
               s_axi_BUS_A_AWREADY => axilWriteSlave .awready,
               s_axi_BUS_A_AWADDR  => axilWriteMaster.awaddr(4 downto 0),
               s_axi_BUS_A_WVALID  => axilWriteMaster.wvalid,
               s_axi_BUS_A_WREADY  => axilWriteSlave .wready,
               s_axi_BUS_A_WDATA   => axilWriteMaster.wdata,
               s_axi_BUS_A_WSTRB   => axilWriteMaster.wstrb(3 downto 0),
               s_axi_BUS_A_ARVALID => axilReadMaster .arvalid,
               s_axi_BUS_A_ARREADY => axilReadSlave  .arready,
               s_axi_BUS_A_ARADDR  => axilReadMaster .araddr(4 downto 0),
               s_axi_BUS_A_RVALID  => axilReadSlave  .rvalid,
               s_axi_BUS_A_RREADY  => axilReadMaster .rready,
               s_axi_BUS_A_RDATA   => axilReadSlave  .rdata,
               s_axi_BUS_A_RRESP   => axilReadSlave  .rresp,
               s_axi_BUS_A_BVALID  => axilWriteSlave .bvalid,
               s_axi_BUS_A_BREADY  => axilWriteMaster.bready,
               s_axi_BUS_A_BRESP   => axilWriteSlave .bresp );

  U_RAM : entity work.SimpleDualPortRam
    generic map ( DATA_WIDTH_G => 16*ROW_SIZE,
                  ADDR_WIDTH_G => rdaddr'length )
    port map ( clka   => clk,
               ena    => '1',
               wea    => r.wren,
               addra  => r.wraddr,
               dina   => wrdata,
               clkb   => clk,
               enb    => '1',
               rstb   => rst,
               addrb  => rdaddr,
               doutb  => rddata );
  
  comb : process( r, rst, lopen, lclose, lphase, l1in, l1a,
                  tout, dout, douten, rddata, maxisSlave ) is
    variable v : RegType;
    variable n : integer range 0 to 2*ROW_SIZE-1;
    variable i,j : integer;
    variable imatch : integer;
  begin
    v := r;

    v.wren    := '0';
    v.wrfull  := '0';
    v.rden    := '1';
    v.shiftEn := '0' & r.shiftEn(1);
    v.dout    := dout;
    v.tout    := tout;
    v.douten  := douten;
    v.sync    := '0';
    
    if r.sync = '1' then
      v.count := (others=>'0');
    else
      v.count   := r.count+1;
    end if;

    if lopen = '1' then
      i := conv_integer(r.iempty);
      v.iempty := r.iempty+1;
      v.cache(i).state  := OPEN_S;
      v.cache(i).trigd  := WAIT_T;
      v.cache(i).mapd   := BEGIN_M;
      v.cache(i).baddr  := resize(r.count & lphase,CACHE_ADDR_LEN_C);
    end if;

    if lclose = '1' then
      i := conv_integer(r.iopened);
      v.cache(i).state := CLOSED_S;
      v.cache(i).eaddr  := resize(r.count & lphase,CACHE_ADDR_LEN_C);
      v.iopened := r.iopened+1;
    end if;

    i := conv_integer(r.ibegin);
    if r.cache(i).mapd = BEGIN_M then
      imatch := 8;
      for j in conv_integer(r.douten)-1 downto 0 loop
        if r.tout(j) >= r.cache(i).baddr(13 downto 0) then
          imatch := j;
        end if;
      end loop;
      if imatch < 8 then
        v.cache(i).mapd  := END_M;
        n := conv_integer(r.wrword)+imatch;
        v.cache(i).boffs(2 downto 0) := toSlv(n, 3);
        if n < 8 then
          v.cache(i).baddr := r.wraddr & toSlv(0,IDX_BITS);
        else
          v.cache(i).baddr := r.wraddr+1 & toSlv(0,IDX_BITS);
        end if;
        v.ibegin := r.ibegin+1;
      end if;
    end if;
    
    i := conv_integer(r.iend);
    if (r.cache(i).mapd = END_M and
        r.cache(i).state = CLOSED_S) then
      imatch := 8;
      for j in conv_integer(r.douten)-1 downto 0 loop
        if r.tout(j) >= r.cache(i).eaddr(13 downto 0) then
          imatch := j;
        end if;
      end loop;
      if imatch < 8 then
        v.cache(i).mapd  := DONE_M;
        if r.wrword+imatch < 8 then
          v.cache(i).eaddr := r.wraddr & toSlv(0,IDX_BITS);
        else
          v.cache(i).eaddr := r.wraddr+1 & toSlv(0,IDX_BITS);
        end if;
        v.iend := r.iend+1;
      end if;
    end if;
    
    if l1in = '1' then
      i := conv_integer(r.itrigger);
      if l1a = '1' then
        v.cache(i).trigd := ACCEPT_T;
      else
        v.cache(i).trigd := REJECT_T;
      end if;
      v.itrigger := r.itrigger+1;
    end if;

    if maxisSlave.tReady='1' then
      v.axisMaster.tValid := '0';
    end if;

    if v.axisMaster.tValid='0' then
      i := conv_integer(r.ireading);
      v.axisMaster.tLast := '0';
      if (r.cache(i).state = CLOSED_S and
          r.cache(i).mapd = DONE_M) then
        case r.cache(i).trigd is
          when WAIT_T   => null;
          when REJECT_T =>
            v.cache(i).state := EMPTY_S;
            v.ireading := r.ireading+1;
          when ACCEPT_T =>
            v.rdaddr := r.cache(i).baddr(r.rdaddr'left+IDX_BITS downto IDX_BITS);
            v.shift := (resize(r.cache(i).baddr(IDX_BITS-1 downto 0),5) & '0') & toSlv(0,6);
            v.shiftEn := "11";
            v.axisMaster.tValid := '1';
            v.axisMaster.tData(ROW_SIZE*16-1 downto 0) := (others=>'0');
            
            v.axisMaster.tData(31 downto IDX_BITS) :=
              resize(r.cache(i).eaddr(CACHE_ADDR_LEN_C-1 downto IDX_BITS) -
                     r.cache(i).baddr(CACHE_ADDR_LEN_C-1 downto IDX_BITS) + 1,
                     32-IDX_BITS);
            v.axisMaster.tData(63 downto 32) := resize(r.cache(i).boffs,32);
            v.cache(i).state := READING_S;
            if r.cache(i).eaddr = r.cache(i).baddr then
              v.axisMaster.tLast := '1';
              v.cache(i).state := EMPTY_S;
            end if;
          when others => null;
        end case;
      elsif r.cache(i).state = READING_S then
        v.axisMaster.tValid := '1';
        v.axisMaster.tData(rddata'range) := rddata;
        v.rdaddr := r.rdaddr+1;
        if r.rdaddr = r.cache(i).eaddr(r.rdaddr'left+IDX_BITS-1 downto IDX_BITS) then
          if r.cache(i).baddr(IDX_BITS-1 downto 0) < r.cache(i).eaddr(IDX_BITS-1 downto 0) then
            v.cache(i).state := LAST_S;
          else
            v.axisMaster.tLast := '1';
            v.cache(i).state := EMPTY_S;
            v.ireading := r.ireading+1;
          end if;
        end if;
      elsif r.cache(i).state = LAST_S then
        v.axisMaster.tLast := '1';
        v.cache(i).state := EMPTY_S;
        v.ireading := r.ireading+1;
      end if;
    end if;
    
    if r.wrfull='1' then
      v.wrdata(ROW_SIZE-1 downto 0) := r.wrData(2*ROW_SIZE-1 downto ROW_SIZE);
        v.wraddr := r.wraddr+1;
    end if;
    
    if (r.douten/=0 and v.cache(conv_integer(r.iopened)).state=OPEN_S) then
      i := conv_integer(r.wrword);
      v.wrdata(i+ROW_SIZE-1 downto i) := r.dout;
      n := i+conv_integer(r.douten);
      v.wren := '1';
      if n>=ROW_SIZE then
        v.wrfull := '1';
      end if;
      v.wrword := toSlv(n,IDX_BITS);
    end if;

    if rst='1' then
      v := REG_INIT_C;
    end if;

    r_in <= v;

    for i in ROW_SIZE-1 downto 0 loop
      wrdata(16*i+15 downto 16*i) <= r.wrdata(i);
    end loop;

    rdaddr <= v.rdaddr;

  end process;

  seq : process(clk) is
  begin
    if rising_edge(clk) then
      r <= r_in;
    end if;
  end process;
  
end mapping;
