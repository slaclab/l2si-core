-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : hsd_fex_interleave.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2018-01-05
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
--   Wrapper for feature extraction of raw data stream.  The raw data is passed
--   to a feature extraction module (hsd_fex) and extracted data is received
--   from that module. The extracted data is stamped with an internal counter
--   reset by _sync_.  While a gate is open (_lopen_ -> _lclose)) extracted
--   data that is stamped within that gate (or any gate) is saved in a circular
--   buffer.  Gates may overlap.  Circular buffer addresses of the extracted
--   data corresponding to each gate are saved for readout pending a veto
--   decision (_l1in_/_l1ina_).  The number of free rows of the circular buffer
--   (_free_) and number of free gates (_nfree_) are exported for deadtime
--   control.
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 Timing Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 Timing Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.NUMERIC_STD.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.QuadAdcCompPkg.all;
use work.QuadAdcPkg.all;

entity hsd_fex_interleave is
  generic ( AXIS_CONFIG_G : AxiStreamConfigType;
            AXIS_SIZE_G   : integer := 1;
            ALG_ID_G      : integer := 0;
            ALGORITHM_G   : string  := "RAW";
            DEBUG_G       : boolean := false );
  port (
    clk             :  in sl;
    rst             :  in sl;
    clear           :  in sl;
    din             :  in Slv44Array(7 downto 0);  -- row of data
    lopen           :  in sl;                      -- begin sampling
    lskip           :  in sl;                      -- skip sampling (cache
                                                   -- header for readout)
    lphase          :  in slv(2 downto 0);         -- lopen location within the row
    lclose          :  in sl;                      -- end sampling
    l1in            :  in sl;                      -- once per lopen
    l1ina           :  in sl;                      -- accept/reject
    free            : out slv(15 downto 0);        -- unused rows in RAM
    nfree           : out slv( 4 downto 0);        -- unused gates
    status          : out CacheArray(MAX_OVL_C-1 downto 0);
    -- readout interface
    axisMaster      : out AxiStreamMasterArray(AXIS_SIZE_G-1 downto 0);
    axisSlave       :  in AxiStreamSlaveArray (AXIS_SIZE_G-1 downto 0);
    -- BRAM interface (clk domain)
    bramWriteMaster : out BRamWriteMasterArray(3 downto 0);
    bramReadMaster  : out BRamReadMasterArray (3 downto 0);
    bramReadSlave   : in  BRamReadSlaveArray  (3 downto 0);
    -- configuration interface
    axilReadMaster  :  in AxiLiteReadMasterType;
    axilReadSlave   : out AxiLiteReadSlaveType;
    axilWriteMaster :  in AxiLiteWriteMasterType;
    axilWriteSlave  : out AxiLiteWriteSlaveType );
end hsd_fex_interleave;

architecture mapping of hsd_fex_interleave is

  constant LATENCY_C    : integer := 0;
  constant COUNT_BITS_C : integer := 14;
  constant SKIP_T       : slv(COUNT_BITS_C-1 downto 0) := toSlv(4096,COUNT_BITS_C);
  constant AXIS_SZ_BITS : integer := bitSize(AXIS_SIZE_G)-1;

  type AxisRegType is record
    ireading   : slv(MAX_OVL_BITS_C-1 downto AXIS_SZ_BITS);
    rdaddr     : slv(RAM_ADDR_WIDTH_C-1 downto 0);
    axisMaster : AxiStreamMasterType;
  end record;

  constant AXIS_REG_INIT_C : AxisRegType := (
    ireading   => (others=>'0'),
    rdaddr     => (others=>'0'),
    axisMaster => AXI_STREAM_MASTER_INIT_C );

  type AxisRegArray is array(natural range<>) of AxisRegType;
  
  type RegType is record
    tout       : Slv2Array (ROW_SIZE downto 0);
    dout       : Slv64Array(ROW_SIZE downto 0);    -- cached data from FEX
    douten     : slv(3 downto 0);                  -- cached # to write from FEX (0 or ROW_SIZE)
    tin        : Slv2Array(ROW_SIZE-1 downto 0);
    lskip      : sl;
    iempty     : slv(MAX_OVL_BITS_C-1 downto 0);
    iopened    : slv(MAX_OVL_BITS_C-1 downto 0);
    itrigger   : slv(MAX_OVL_BITS_C-1 downto 0);
    cache      : CacheArray(MAX_OVL_C-1 downto 0);
    rdtail     : slv(RAM_ADDR_WIDTH_C-1 downto 0);
    wrfull     : sl;
    wrword     : slv(IDX_BITS downto 0);
    wrdata     : Slv64Array(2*ROW_SIZE downto 0);  -- data queued for RAM
    wraddr     : slv(RAM_ADDR_WIDTH_C-1 downto 0);
    free       : slv     (15 downto 0);
    nfree      : slv     ( 4 downto 0);
    axisSel    : integer range 0 to AXIS_SIZE_G;
    axisReg    : AxisRegArray(AXIS_SIZE_G-1 downto 0);
  end record;
  constant REG_INIT_C : RegType := (
    tout       => (others=>(others=>'0')),
    dout       => (others=>(others=>'0')),
    douten     => (others=>'0'),
    tin        => (others=>(others=>'0')),
    lskip      => '0',
    iempty     => (others=>'0'),
    iopened    => (others=>'0'),
    itrigger   => (others=>'0'),
    cache      => (others=>CACHE_INIT_C),
    rdtail     => (others=>'0'),
    wrfull     => '0',
    wrword     => (others=>'0'),
    wrdata     => (others=>(others=>'0')),
    wraddr     => (others=>'0'),
    free       => (others=>'0'),
    nfree      => (others=>'0'),
    axisSel    => 0,
    axisReg    => (others=>AXIS_REG_INIT_C) );

  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;

  signal rstn   : sl;
  signal tout   : Slv2Array (ROW_SIZE downto 0);
  signal dout   : Slv64Array(ROW_SIZE downto 0);
  signal douten : slv(IDX_BITS   downto 0);  -- number of valid points
  signal rdaddr : slv(RAM_ADDR_WIDTH_C-1 downto 0);
  signal rddata : slv(ROW_SIZE*64-1 downto 0);
  signal configSynct : sl;
  signal configSync  : sl;
  signal bWrite      : sl;

  signal maxisSlave  : AxiStreamSlaveArray(AXIS_SIZE_G-1 downto 0);
  
  constant SAXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(64);
  
begin

  status <= r.cache;

  GEN_FIFO : for i in 0 to AXIS_SIZE_G-1 generate
    U_FIFO : entity work.AxiStreamFifoV2
      generic map ( SLAVE_AXI_CONFIG_G  => SAXIS_CONFIG_C,
                    MASTER_AXI_CONFIG_G => AXIS_CONFIG_G )
      port map ( -- Slave Port
        sAxisClk    => clk,
        sAxisRst    => rst,
        sAxisMaster => r.axisReg   (i).axisMaster,
        sAxisSlave  => maxisSlave  (i),
        -- Master Port
        mAxisClk    => clk,
        mAxisRst    => rst,
        mAxisMaster => axisMaster  (i),
        mAxisSlave  => axisSlave   (i) );
  end generate;
  
  GEN_CHAN : for j in 0 to 3 generate
    bramWriteMaster(j).en   <= '1';
    bramWriteMaster(j).addr <= r.wraddr;
    bramReadMaster (j).en   <= '1';
    bramReadMaster (j).addr <= rdaddr;
    GEN_BRAMWR : for i in 0 to ROW_SIZE-1 generate
      bramWriteMaster(j).data(16*i+15 downto 16*i) <= r.wrdata(i)(16*j+15 downto 16*j);
      rddata(64*i+16*j+15 downto 64*i+16*j) <= bramReadSlave(j).data(16*i+15 downto 16*i);
    end generate;
  end generate;

  rstn <= not rst;

  configSynct <= bWrite or rst;
  
  U_ConfigSync : entity work.RstSync
    port map ( clk      => clk,
               asyncRst => configSynct,
               syncRst  => configSync );
  
  comb : process( r, clear, lopen, lskip, lclose, lphase, l1in, l1ina,
                  tout, dout, douten, rddata, maxisSlave ) is
    variable v : RegType;
    variable n : integer range 0 to 2*ROW_SIZE-1;
    variable i,j,k  : integer;
    variable imatch : integer;
    variable flush  : sl;
    variable skip   : sl;
    variable q      : AxisRegType;
  begin
    v := r;
    
    v.wrfull  := '0';
    v.dout    := dout;
    v.tout    := tout;
    v.douten  := douten;
    v.tin     := (others=>"00");
    v.tin(conv_integer(lphase)) := lclose & lopen;

    if lopen='1' then
      v.lskip   := lskip;
    end if;

    flush     := '0';

    --
    --  Push the data to RAM
    --  If a buffered line was written, shift away
    --
    if r.wrfull='1' then
      v.wrdata(ROW_SIZE downto 0) := r.wrData(2*ROW_SIZE downto ROW_SIZE);
      v.wraddr := r.wraddr+1;
    end if;

    k := conv_integer(r.wrword);

    for i in r.dout'range loop
      v.wrdata(k+i) := r.dout(i);
    end loop;
    n := k + conv_integer(r.douten);

    if n >= ROW_SIZE then
      v.wrfull := '1';
      n := n-ROW_SIZE;
    end if;
    v.wrword := toSlv(n,IDX_BITS+1);
    
    --
    --  check if a gate has closed; latch time
    --
    imatch := ROW_SIZE+1;
    for j in ROW_SIZE downto 0 loop
      if r.tout(j)(1)='1' then  -- lclose
        imatch := j;
      end if;
    end loop;
    if imatch <= ROW_SIZE then
      i := conv_integer(r.iopened);
      v.iopened := r.iopened+1;
      v.cache(i).state  := CLOSED_S;
      v.cache(i).eaddr  := (v.wraddr & toSlv(k,IDX_BITS)) + toSlv(imatch,CACHE_ADDR_LEN_C);
    end if;

    --
    --  check if a gate has opened; latch sample location
    --
    imatch := ROW_SIZE+1;
    for j in ROW_SIZE downto 0 loop
      if r.tout(j)(0)='1' then  -- lopen
        imatch := j;
      end if;
    end loop;
    if imatch <= ROW_SIZE then
        i := conv_integer(r.iempty);
        v.iempty := r.iempty+1;
        v.cache(i).state  := OPEN_S;
--      v.cache(i).trigd  := WAIT_T;  -- l1t can precede open
        v.cache(i).skip   := r.lskip;
--        v.cache(i).mapd   := END_M; -- look for close
        v.cache(i).baddr  := (v.wraddr & toSlv(k,IDX_BITS)) + toSlv(imatch,CACHE_ADDR_LEN_C);
    end if;
        
    --
    --  Capture veto decision
    --
    if l1in = '1' then
      i := conv_integer(r.itrigger);
      if l1ina = '1' then
        v.cache(i).trigd := ACCEPT_T;
      else
        v.cache(i).trigd := REJECT_T;
      end if;
      v.itrigger := r.itrigger+1;
    end if;

    --
    --  Stream out data for pending event buffers
    --
    for j in 0 to AXIS_SIZE_G-1 loop

      q := v.axisReg(j);

      if maxisSlave(j).tReady='1' then
        q.axisMaster.tValid := '0';
      end if;

      if q.axisMaster.tValid='0' then
        q.axisMaster.tLast := '0';

        if AXIS_SIZE_G > 1 then
          i := conv_integer(q.ireading & toSlv(j,AXIS_SZ_BITS));
        else
          i := conv_integer(q.ireading);
        end if;
        
        if r.axisSel = j then

          v.free := resize(r.rdtail - r.wraddr,r.free'length);
          
          if r.cache(i).state = EMPTY_S then
            v.nfree := toSlv(r.cache'length,r.nfree'length);
          else
            v.nfree := resize(q.ireading-r.iempty,r.nfree'length);
          end if;
          
          if (r.cache(i).state = EMPTY_S or
              r.cache(i).skip = '1' ) then
            v.rdtail := r.wraddr-1;
          else
            v.rdtail := r.cache(i).baddr(q.rdaddr'left+IDX_BITS downto IDX_BITS);
          end if;

          if (r.cache(i).state = CLOSED_S) then
--          and r.cache(i).mapd = DONE_M) then
            case r.cache(i).trigd is
              when WAIT_T   => null;
              when REJECT_T =>
                v.cache(i) := CACHE_INIT_C;
                q.ireading := q.ireading+1;
              when ACCEPT_T =>
                --
                --  Prepare reading from recorded data RAM
                --
                q.rdaddr := r.cache(i).baddr(q.rdaddr'left+IDX_BITS downto IDX_BITS);
                --
                --  Form header word
                --
                q.axisMaster.tValid := '1';
                q.axisMaster.tData(ROW_SIZE*16-1 downto 0) := (others=>'0');

                skip := r.cache(i).skip;
                if skip = '1' then
                  q.axisMaster.tData(30 downto IDX_BITS+2) := (others=>'0');
                else
                  q.axisMaster.tData(30 downto IDX_BITS+2) :=
                    resize(r.cache(i).eaddr(CACHE_ADDR_LEN_C-1 downto IDX_BITS) -
                           r.cache(i).baddr(CACHE_ADDR_LEN_C-1 downto IDX_BITS) + 1,
                           29-IDX_BITS);
                end if;
                q.axisMaster.tData(31) := r.cache(i).ovflow;
                q.axisMaster.tData( 39 downto  32) := resize(r.cache(i).baddr(IDX_BITS-1 downto 0),6) & "00";
                q.axisMaster.tData( 47 downto  40) := toSlv(8-conv_integer(r.cache(i).eaddr(IDX_BITS-1 downto 0)),6) & "00";
                q.axisMaster.tData( 55 downto  48) := toSlv(i,8);
                q.axisMaster.tData( 63 downto  56) := toSlv(ALG_ID_G,8);
                q.axisMaster.tData( 95 downto  64) := resize(r.cache(i).toffs,32);
                q.axisMaster.tData(111 downto  96) := resize(r.cache(i).baddr,16);
                q.axisMaster.tData(127 downto 112) := resize(r.cache(i).eaddr,16);
--                q.axisMaster.tKeep := genTKeep(16);
                q.axisMaster.tKeep := genTKeep(64);  -- Drop the upper 48 bytes
                                                     -- on the master side
                ssiSetUserSof(SAXIS_CONFIG_C, q.axisMaster, '1');
                v.cache(i).state := READING_S;
                if skip = '1' then
                  q.axisMaster.tLast := '1';
                  v.cache(i) := CACHE_INIT_C;
                  q.ireading := q.ireading+1;
                end if;
              when others => null;
            end case;
          elsif r.cache(i).state = READING_S then
            --
            --  Continue streaming data from RAM
            --
            q.axisMaster.tValid := '1';
            q.axisMaster.tData(rddata'range) := rddata;
            q.axisMaster.tKeep := genTKeep(64);
            ssiSetUserSof(SAXIS_CONFIG_C, q.axisMaster, '0');
            if q.rdaddr = r.cache(i).eaddr(q.rdaddr'left+IDX_BITS downto IDX_BITS) then
              q.axisMaster.tLast := '1';
              v.cache(i) := CACHE_INIT_C;
              q.ireading := q.ireading+1;
            end if;
            q.rdaddr := q.rdaddr+1;
          end if;
        end if;

        v.axisReg(j) := q;
      end if;
    end loop;

    v.axisSel := r.axisSel+1;
    if v.axisSel = AXIS_SIZE_G then
      v.axisSel := 0;
    end if;
    
    -- skipped buffers are causing this to fire
    if conv_integer(r.free) < 4 and false then
      --  Deadtime failed
      --  Close all open caches/gates and flag them
      v.wrfull := '0';
      v.wrword := (others=>'0');
      for i in 0 to 15 loop
        if r.cache(i).state = OPEN_S then
          v.cache(i).state := CLOSED_S;
--          v.cache(i).mapd  := DONE_M;
          v.cache(i).baddr := r.wraddr & toSlv(0,IDX_BITS);
          v.cache(i).eaddr := r.wraddr & toSlv(0,IDX_BITS);
          v.cache(i).ovflow := '1';
        end if;
      end loop;
    end if;
    
    if clear='1' then
      v := REG_INIT_C;
    end if;

    r_in   <= v;
    free   <= r.free;
    nfree  <= r.nfree;

    if AXIS_SIZE_G > 1 then
      rdaddr <= r.axisReg(v.axisSel).rdaddr;
    else
      rdaddr <= v.axisReg(v.axisSel).rdaddr;
    end if;
  end process;

  seq : process(clk) is
  begin
    if rising_edge(clk) then
      r <= r_in;
    end if;
  end process;

  axilWriteSlave .bvalid <= bWrite;
  
  GEN_RAW : if ALGORITHM_G = "RAW" generate
    U_FEX : entity work.hsd_raw_ilv
      generic map ( C_S_AXI_BUS_A_ADDR_WIDTH => 8 )
      port map ( ap_clk              => clk,
                 ap_rst_n            => rstn,
                 sync                => configSync,
                 x0_V                => din(0),
                 x1_V                => din(1),
                 x2_V                => din(2),
                 x3_V                => din(3),
                 x4_V                => din(4),
                 x5_V                => din(5),
                 x6_V                => din(6),
                 x7_V                => din(7),
                 ti0_V               => r.tin(0),
                 ti1_V               => r.tin(1),
                 ti2_V               => r.tin(2),
                 ti3_V               => r.tin(3),
                 ti4_V               => r.tin(4),
                 ti5_V               => r.tin(5),
                 ti6_V               => r.tin(6),
                 ti7_V               => r.tin(7),
                 y0_V                => dout(0),
                 y1_V                => dout(1),
                 y2_V                => dout(2),
                 y3_V                => dout(3),
                 y4_V                => dout(4),
                 y5_V                => dout(5),
                 y6_V                => dout(6),
                 y7_V                => dout(7),
                 y8_V                => dout(8),
                 yv_V                => douten,
                 to0_V               => tout(0),
                 to1_V               => tout(1),
                 to2_V               => tout(2),
                 to3_V               => tout(3),
                 to4_V               => tout(4),
                 to5_V               => tout(5),
                 to6_V               => tout(6),
                 to7_V               => tout(7),
                 to8_V               => tout(8),
                 s_axi_BUS_A_AWVALID => axilWriteMaster.awvalid,
                 s_axi_BUS_A_AWREADY => axilWriteSlave .awready,
                 s_axi_BUS_A_AWADDR  => axilWriteMaster.awaddr(7 downto 0),
                 s_axi_BUS_A_WVALID  => axilWriteMaster.wvalid,
                 s_axi_BUS_A_WREADY  => axilWriteSlave .wready,
                 s_axi_BUS_A_WDATA   => axilWriteMaster.wdata,
                 s_axi_BUS_A_WSTRB   => axilWriteMaster.wstrb(3 downto 0),
                 s_axi_BUS_A_ARVALID => axilReadMaster .arvalid,
                 s_axi_BUS_A_ARREADY => axilReadSlave  .arready,
                 s_axi_BUS_A_ARADDR  => axilReadMaster .araddr(7 downto 0),
                 s_axi_BUS_A_RVALID  => axilReadSlave  .rvalid,
                 s_axi_BUS_A_RREADY  => axilReadMaster .rready,
                 s_axi_BUS_A_RDATA   => axilReadSlave  .rdata,
                 s_axi_BUS_A_RRESP   => axilReadSlave  .rresp,
                 s_axi_BUS_A_BVALID  => bWrite,
                 s_axi_BUS_A_BREADY  => axilWriteMaster.bready,
                 s_axi_BUS_A_BRESP   => axilWriteSlave .bresp );
  end generate;
    
  GEN_THR : if ALGORITHM_G = "THR" generate
    U_FEX : entity work.hsd_thr_ilv
      generic map ( C_S_AXI_BUS_A_ADDR_WIDTH => 8 )
      port map ( ap_clk              => clk,
                 ap_rst_n            => rstn,
                 sync                => configSync,
                 x0_V                => din(0),
                 x1_V                => din(1),
                 x2_V                => din(2),
                 x3_V                => din(3),
                 x4_V                => din(4),
                 x5_V                => din(5),
                 x6_V                => din(6),
                 x7_V                => din(7),
                 ti0_V               => r.tin(0),
                 ti1_V               => r.tin(1),
                 ti2_V               => r.tin(2),
                 ti3_V               => r.tin(3),
                 ti4_V               => r.tin(4),
                 ti5_V               => r.tin(5),
                 ti6_V               => r.tin(6),
                 ti7_V               => r.tin(7),
                 y0_V                => dout(0),
                 y1_V                => dout(1),
                 y2_V                => dout(2),
                 y3_V                => dout(3),
                 y4_V                => dout(4),
                 y5_V                => dout(5),
                 y6_V                => dout(6),
                 y7_V                => dout(7),
                 y8_V                => dout(8),
                 yv_V                => douten,
                 to0_V               => tout(0),
                 to1_V               => tout(1),
                 to2_V               => tout(2),
                 to3_V               => tout(3),
                 to4_V               => tout(4),
                 to5_V               => tout(5),
                 to6_V               => tout(6),
                 to7_V               => tout(7),
                 to8_V               => tout(8),
                 s_axi_BUS_A_AWVALID => axilWriteMaster.awvalid,
                 s_axi_BUS_A_AWREADY => axilWriteSlave .awready,
                 s_axi_BUS_A_AWADDR  => axilWriteMaster.awaddr(7 downto 0),
                 s_axi_BUS_A_WVALID  => axilWriteMaster.wvalid,
                 s_axi_BUS_A_WREADY  => axilWriteSlave .wready,
                 s_axi_BUS_A_WDATA   => axilWriteMaster.wdata,
                 s_axi_BUS_A_WSTRB   => axilWriteMaster.wstrb(3 downto 0),
                 s_axi_BUS_A_ARVALID => axilReadMaster .arvalid,
                 s_axi_BUS_A_ARREADY => axilReadSlave  .arready,
                 s_axi_BUS_A_ARADDR  => axilReadMaster .araddr(7 downto 0),
                 s_axi_BUS_A_RVALID  => axilReadSlave  .rvalid,
                 s_axi_BUS_A_RREADY  => axilReadMaster .rready,
                 s_axi_BUS_A_RDATA   => axilReadSlave  .rdata,
                 s_axi_BUS_A_RRESP   => axilReadSlave  .rresp,
                 s_axi_BUS_A_BVALID  => bWrite,
                 s_axi_BUS_A_BREADY  => axilWriteMaster.bready,
                 s_axi_BUS_A_BRESP   => axilWriteSlave .bresp );
    end generate;
    
end mapping;

