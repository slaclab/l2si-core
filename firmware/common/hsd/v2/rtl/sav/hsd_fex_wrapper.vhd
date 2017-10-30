-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : hsd_fex_wrapper.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2017-10-18
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
use work.QuadAdcCompPkg.all;

entity hsd_fex_wrapper is
  generic ( RAM_DEPTH_G   : integer := 8192;
            AXIS_CONFIG_G : AxiStreamConfigType;
            ALGORITHM_G   : string := "RAW";
            DEBUG_G       : boolean := false );
  port (
    clk             :  in sl;
    rst             :  in sl;
    din             :  in Slv11Array(7 downto 0);  -- row of data
    lopen           :  in sl;                      -- begin sampling
    lskip           :  in sl;                      -- skip sampling (cache
                                                   -- header for readout)
    lphase          :  in slv(2 downto 0);         -- lopen location within the row
    lclose          :  in sl;                      -- end sampling
    l1in            :  in sl;                      -- once per lopen
    l1ina           :  in sl;                      -- accept/reject
    free            : out slv(15 downto 0);        -- unused rows in RAM
    nfree           : out slv( 4 downto 0);        -- unused gates 
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

  constant LATENCY_C : integer := 0;
  constant ROW_SIZE : integer := 8;
  constant IDX_BITS : integer := bitSize(ROW_SIZE-1);
  constant RAM_ADDR_WIDTH_C : integer := bitSize(RAM_DEPTH_G-1);
  constant CACHE_ADDR_LEN_C : integer := RAM_ADDR_WIDTH_C+IDX_BITS;
  constant SKIP_CHAR : slv(1 downto 0) := "10";
  
  type StateType is ( EMPTY_S,  -- buffer empty
                      OPEN_S,   -- buffer filling
                      CLOSED_S, -- buffer filled
                      READING_S,-- buffer emptying
                      LAST_S ); -- last word to empty
  type TrigStateType is ( WAIT_T,     -- awaiting trigger/veto information
                          ACCEPT_T,   -- event accepted
                          REJECT_T ); -- event vetoed
  type MapStateType is ( BEGIN_M,     -- seeking first address in RAM
                         END_M,       -- seeking last address in RAM
                         DONE_M );    -- all addresses known
  type SkipStateType is ( SKIPPING_K,
                          FILLING_K );
  
  type CacheType is record
    state  : StateType;
    trigd  : TrigStateType;
    mapd   : MapStateType;
    toffs  : slv(15 downto 0);
    boffs  : slv(IDX_BITS-1 downto 0);
    eoffs  : slv(IDX_BITS-1 downto 0);
    baddr  : slv(CACHE_ADDR_LEN_C-1 downto 0);
    eaddr  : slv(CACHE_ADDR_LEN_C-1 downto 0);
    skip   : sl;
    ovflow : sl;
  end record;
  constant CACHE_INIT_C : CacheType := (
    state  => EMPTY_S,
    trigd  => WAIT_T,
    mapd   => DONE_M,
    toffs  => (others=>'0'),
    boffs  => (others=>'0'),
    eoffs  => (others=>'0'),
    baddr  => (others=>'0'),
    eaddr  => (others=>'0'),
    skip   => '0',
    ovflow => '0' );
  
  type CacheArray is array(natural range<>) of CacheType;

  constant MAX_OVL_C : integer := 16;
  constant MAX_OVL_BITS_C : integer := bitSize(MAX_OVL_C-1);
  constant COUNT_BITS_C : integer := 14;
  constant SKIP_T       : slv(COUNT_BITS_C-1 downto 0) := toSlv(4096,COUNT_BITS_C);
  
  type RegType is record
    sync       : sl;                               -- reset time counter in FEX
    count      : slv(COUNT_BITS_C-1 downto 0);     -- local time counter
    tout_next  : slv(COUNT_BITS_C-1 downto 0);     -- time counter of next
    tout       : Slv14Array(ROW_SIZE-1 downto 0);  -- cached time counter from FEX
    dout       : Slv16Array(ROW_SIZE-1 downto 0);  -- cached data from FEX
    douten     : slv(3 downto 0);                  -- cached # to write from FEX (0 or ROW_SIZE)
    doute0     : slv(2 downto 0);                  -- (obsolete)
    iempty     : slv(MAX_OVL_BITS_C-1 downto 0);
    iopened    : slv(MAX_OVL_BITS_C-1 downto 0);
    ireading   : slv(MAX_OVL_BITS_C-1 downto 0);
    itrigger   : slv(MAX_OVL_BITS_C-1 downto 0);
    cache      : CacheArray(MAX_OVL_C-1 downto 0);
    kstate     : SkipStateType;
    rden       : sl;
    rdaddr     : slv(RAM_ADDR_WIDTH_C-1 downto 0);
    rdtail     : slv(RAM_ADDR_WIDTH_C-1 downto 0);
    wren       : slv(3 downto 0);
    wrfull     : sl;
    wrword     : slv(IDX_BITS downto 0);
    wrdata     : Slv16Array(2*ROW_SIZE downto 0);  -- data queued for RAM
    wrtout     : Slv14Array(2*ROW_SIZE downto 0);  -- (obsolete)
    wrtoutl    : slv(COUNT_BITS_C-1 downto 0);     -- (obsolete)
    wrbeg      : Slv5Array (2*ROW_SIZE downto 0);  -- marks beginning of a cache
    wrend      : Slv5Array (2*ROW_SIZE downto 0);  -- marks ending of a cache
    wraddr     : slv(RAM_ADDR_WIDTH_C-1 downto 0);
    shift      : Slv6Array(1 downto 0);
    shiftEn    : slv      (1 downto 0);
    free       : slv     (15 downto 0);
    nfree      : slv     ( 4 downto 0);
    axisMaster : AxiStreamMasterType;
  end record;
  constant REG_INIT_C : RegType := (
    sync       => '1',
    count      => (others=>'0'),
    tout_next  => (others=>'0'),
    tout       => (others=>(others=>'0')),
    dout       => (others=>(others=>'0')),
    douten     => (others=>'0'),
    doute0     => (others=>'0'),
    iempty     => (others=>'0'),
    iopened    => (others=>'0'),
    ireading   => (others=>'0'),
    itrigger   => (others=>'0'),
    cache      => (others=>CACHE_INIT_C),
    kstate     => FILLING_K,
    rden       => '0',
    rdaddr     => (others=>'0'),
    rdtail     => (others=>'0'),
    wren       => (others=>'0'),
    wrfull     => '0',
    wrword     => (others=>'0'),
    wrdata     => (others=>(others=>'0')),
    wrtout     => (others=>(others=>'0')),
    wrtoutl    => (others=>'0'),
    wrbeg      => (others=>(others=>'0')),
    wrend      => (others=>(others=>'0')),
    wraddr     => (others=>'0'),
    shift      => (others=>(others=>'0')),
    shiftEn    => (others=>'0'),
    free       => (others=>'0'),
    nfree      => (others=>'0'),
    axisMaster => AXI_STREAM_MASTER_INIT_C );

  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;

  signal rstn   : sl;
  signal dout   : Slv16Array(ROW_SIZE-1 downto 0);
  signal tout   : Slv14Array(ROW_SIZE-1 downto 0);
  signal douten : slv(IDX_BITS   downto 0);  -- number of valid points
  signal doute0 : slv(IDX_BITS-1 downto 0); -- index of first valid point
  signal rdaddr : slv(RAM_ADDR_WIDTH_C-1 downto 0);
  signal rddata : slv(ROW_SIZE*16-1 downto 0);
  signal wrdata : slv(ROW_SIZE*16-1 downto 0);
  signal maxisSlave : AxiStreamSlaveType;

  constant DEBUG_C : boolean := DEBUG_G;
  
  component ila_0
    port ( clk : in sl;
           probe0 : in slv(255 downto 0) );
  end component;

begin

  GEN_DEBUG : if DEBUG_C generate
    U_ILA : ila_0
      port map ( clk       => clk,
                 probe0(0) => lopen,
                 probe0(1) => lclose,
                 probe0(2) => l1in,
                 probe0(16 downto  3) => r.count,
                 probe0(30 downto 17) => r.cache(0).baddr(13 downto 0),
                 probe0(44 downto 31) => r.cache(0).eaddr(13 downto 0),
                 probe0(58 downto 45) => r.tout(0),
                 probe0(71 downto 59) => r.rdaddr(12 downto 0),
                 probe0(84 downto 72) => r.wraddr(12 downto 0),
                 probe0(85) => r.axisMaster.tValid,
                 probe0(86) => r.axisMaster.tLast,
                 probe0(90 downto 87) => r.iempty,
                 probe0(94 downto 91) => r.iopened,
                 probe0(98 downto 95) => r.ireading,
                 probe0(102 downto 99) => r.itrigger,
                 probe0(255 downto 103) => (others=>'0') );
  end generate;
  
  rstn <= not rst;

--  U_SHIFT : entity work.AxiStreamShift
--    generic map ( AXIS_CONFIG_G => AXIS_CONFIG_G,
--                  PIPE_STAGES_G => 1 )
--    port map ( axisClk     => clk,
--               axisRst     => rst,
----               axiStart    => r.shiftEn(0),
--               axiStart    => '1',
--               axiShiftDir => '1',
--               axiShiftCnt => r.shift(0),
--               sAxisMaster => r.axisMaster,
--               sAxisSlave  => maxisSlave,
--               mAxisMaster => axisMaster,
--               mAxisSlave  => axisSlave );
  axisMaster <= r.axisMaster;
  maxisSlave <= axisSlave;

  U_RAM : entity work.SimpleDualPortRam
    generic map ( DATA_WIDTH_G => 16*ROW_SIZE,
                  ADDR_WIDTH_G => rdaddr'length )
    port map ( clka   => clk,
               ena    => '1',
               wea    => r.wren(0),
               addra  => r.wraddr,
               dina   => wrdata,
               clkb   => clk,
               enb    => '1',
               rstb   => rst,
               addrb  => rdaddr,
               doutb  => rddata );
  
  comb : process( r, rst, lopen, lskip, lclose, lphase, l1in, l1ina,
                  tout, dout, douten, doute0, rddata, maxisSlave ) is
    variable v : RegType;
    variable n : integer range 0 to 2*ROW_SIZE-1;
    variable i,j,k : integer;
    variable imatch : integer;
    variable flush  : sl;
    variable skip   : sl;
    variable sdout  : Slv16Array(ROW_SIZE-1 downto 0) := (others=>(others=>'0'));
    variable wrbeg  : slv(4 downto 0);
    variable wrend  : slv(4 downto 0);
  begin
    v := r;
    
    v.wren    := '0' & r.wren(r.wren'left downto 1);
    v.wrfull  := '0';
    v.rden    := '1';
    v.shiftEn := '0' & r.shiftEn(1);
    v.dout    := dout;
--    v.tout    := tout;
    --  Hack for now
    v.tout(0) := tout(0);
    for i in 1 to 7 loop
      v.tout(i) := v.tout(i-1)+1;
    end loop;
      
    v.douten  := douten;
--    v.doute0  := doute0;
    --  Hack for now
    if ((dout(0) < toSlv(512,16) and dout(7) < dout(0)) or
        (dout(0) > toSlv(512,16) and dout(7) > dout(0))) then
      v.doute0 := toSlv(8-conv_integer(douten),3);
    else
      v.doute0 := (others=>'0');
    end if;

    flush     := '0';
    v.axisMaster.tKeep := genTKeep(AXIS_CONFIG_G);

    v.sync    := '0';
    if r.count = 16383 then
      v.sync  := '1';
    end if;
    v.count   := r.count+1;
    
    --
    --  A gate has opened; latch time and record data into buffer
    --
    if lopen = '1' then
      i := conv_integer(r.iempty);
      v.iempty := r.iempty+1;
      if lskip = '1' then
        v.cache(i).state  := CLOSED_S;
        v.cache(i).mapd   := DONE_M;
        v.cache(i).baddr  := resize(r.count & lphase,CACHE_ADDR_LEN_C);
        v.cache(i).skip   := '1';
      else
        v.cache(i).state  := OPEN_S;
--      v.cache(i).trigd  := WAIT_T;  -- l1t can precede open
        v.cache(i).mapd   := BEGIN_M;
        v.cache(i).baddr  := resize(r.count & lphase,CACHE_ADDR_LEN_C);
        v.cache(i).skip   := '0';
        v.wren            := (others=>'1');
--        flush := '1';  -- force out skip characters for sparsified data
        --  If no buffers are recording, force a start
        --if r.cache(conv_integer(r.iopened)).mapd /= BEGIN_M then
        --  v.tout_next := resize(r.count & lphase,r.tout_next'length);
        --end if;
      end if;
    end if;

    --
    --  A gate has closed; latch time
    --
    i := conv_integer(r.iopened);
    if lclose = '1' then
      if r.cache(i).state = OPEN_S then
        v.cache(i).state := CLOSED_S;
        v.cache(i).eaddr  := resize(r.count & lphase,CACHE_ADDR_LEN_C);
      end if;
      v.iopened := r.iopened+1;
    end if;

    for i in 0 to 15 loop
      --
      --  Search for latched open time in recorded data buffer
      --
      if r.cache(i).mapd = BEGIN_M and r.wren(0)='1' then
        for j in ROW_SIZE-1 downto 0 loop
          if r.wrbeg(j) = toSlv(i+16,5) then
            v.cache(i).mapd  := END_M;
            v.cache(i).baddr := r.wraddr & toSlv(0,IDX_BITS);
          end if;
        end loop;
      end if;

      --
      --  Search for latched close time in recorded data buffer
      --
      if r.cache(i).state = CLOSED_S then
        imatch := ROW_SIZE;
        for j in ROW_SIZE-1 downto 0 loop
          if r.wrend(j) = toSlv(i+16,5) then
            imatch := j;
          end if;
        end loop;
        if imatch < ROW_SIZE then
          if r.cache(i).mapd /= DONE_M then
            v.cache(i).mapd  := DONE_M;
--            v.cache(i).eoffs := toSlv(imatch, IDX_BITS);
            v.cache(i).eaddr := r.wraddr & toSlv(0,IDX_BITS);
--          flush := '1';  -- force out skip characters for sparsified data
            --
            --  Never found a first recorded word; skip event
            --
            if r.cache(i).mapd = BEGIN_M then
              v.cache(i).boffs := v.cache(i).eoffs;
              v.cache(i).baddr := v.cache(i).eaddr;
            end if;
          end if;
        end if;
      end if;
    end loop;

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
            v.cache(i) := CACHE_INIT_C;
            v.ireading := r.ireading+1;
          when ACCEPT_T =>
            --
            --  Prepare reading from recorded data RAM
            --
            v.rdaddr := r.cache(i).baddr(r.rdaddr'left+IDX_BITS downto IDX_BITS);
            v.shift := (resize(r.cache(i).baddr(IDX_BITS-1 downto 0),5) & '0') & toSlv(0,6);
            v.shiftEn := "01";
            --
            --  Form header word
            --
            v.axisMaster.tValid := '1';
            v.axisMaster.tData(ROW_SIZE*16-1 downto 0) := (others=>'0');

            skip := r.cache(i).skip;
            if (r.cache(i).eaddr=r.cache(i).baddr and
                r.cache(i).eoffs=r.cache(i).boffs) then
              skip := '1';
            end if;
            if skip = '1' then
              v.axisMaster.tData(30 downto IDX_BITS) := (others=>'0');
            else
              v.axisMaster.tData(30 downto IDX_BITS) :=
                resize(r.cache(i).eaddr(CACHE_ADDR_LEN_C-1 downto IDX_BITS) -
                       r.cache(i).baddr(CACHE_ADDR_LEN_C-1 downto IDX_BITS) + 1,
                       31-IDX_BITS);
            end if;
            v.axisMaster.tData(31) := r.cache(i).ovflow;
            v.axisMaster.tData( 39 downto  32) := resize(r.cache(i).boffs,8);
            v.axisMaster.tData( 47 downto  40) := resize(r.cache(i).eoffs,8);
            v.axisMaster.tData( 63 downto  48) := toSlv(i,16);
            v.axisMaster.tData( 95 downto  64) := resize(r.cache(i).toffs,32);
            v.axisMaster.tData(111 downto  96) := resize(r.cache(i).baddr,16);
            v.axisMaster.tData(127 downto 112) := resize(r.cache(i).eaddr,16);
            v.cache(i).state := READING_S;
            if skip = '1' then
              v.axisMaster.tLast := '1';
              v.cache(i) := CACHE_INIT_C;
              v.ireading := r.ireading+1;
            end if;
          when others => null;
        end case;
      elsif r.cache(i).state = READING_S then
        --
        --  Continue streaming data from RAM
        --
        v.axisMaster.tValid := '1';
        v.axisMaster.tData(rddata'range) := rddata;
        v.rdaddr := r.rdaddr+1;
        if r.rdaddr = r.cache(i).eaddr(r.rdaddr'left+IDX_BITS downto IDX_BITS) then
          if (conv_integer(r.cache(i).baddr(IDX_BITS-1 downto 0)) <
              conv_integer(r.cache(i).eaddr(IDX_BITS-1 downto 0))) then
            v.cache(i).state := LAST_S;
          else
            v.axisMaster.tLast := '1';
            v.cache(i) := CACHE_INIT_C;
            v.ireading := r.ireading+1;
          end if;
        end if;
      elsif r.cache(i).state = LAST_S then
        v.axisMaster.tValid := '1';
        v.axisMaster.tData(rddata'range) := rddata;
        v.axisMaster.tLast := '1';
        v.cache(i) := CACHE_INIT_C;
        v.ireading := r.ireading+1;
      end if;
    end if;

    --
    --  If a buffered line was written, shift away
    --
    if r.wrfull='1' then
      v.wrdata(ROW_SIZE downto 0) := r.wrData(2*ROW_SIZE downto ROW_SIZE);
      v.wrtout(ROW_SIZE downto 0) := r.wrtout(2*ROW_SIZE downto ROW_SIZE);
      v.wrbeg (ROW_SIZE downto 0) := r.wrbeg (2*ROW_SIZE downto ROW_SIZE);
      v.wrend (ROW_SIZE downto 0) := r.wrend (2*ROW_SIZE downto ROW_SIZE);
      v.wrbeg (2*ROW_SIZE downto ROW_SIZE+1) := (others=>(others=>'0'));
      v.wrend (2*ROW_SIZE downto ROW_SIZE+1) := (others=>(others=>'0'));
      v.wraddr := r.wraddr+1;
    end if;

    --
    --  Assume dout vector is contiguous and only sparsified at leading or
    --  trailing end => doute0 = leading sample, douten = num samples.
    --
    if (r.cache(conv_integer(r.iopened)).state=OPEN_S) then
      v.wren(r.wren'left) := '1';
    end if;

    i := conv_integer(r.wrword);
    if (v.wren(0)='1') then
      --  Assume we write the whole block of eight samples or nothing
--      j := conv_integer(r.doute0);
      --
      --  Insert a skip character if:
      --    New data arrives that is not contiguous with last data, or
      --    no new data but the time counter advanced "far".
      --
      imatch := ROW_SIZE;
      wrbeg  := (others=>'0');
      wrend  := (others=>'0');
      for j in 0 to 15 loop
        for k in ROW_SIZE-1 downto 0 loop
          if (r.cache(j).mapd = BEGIN_M and
              r.cache(j).baddr(13 downto 0) = r.tout(k)) then
            imatch      := k;
            wrbeg       := toSlv(j+16,5);
            v.cache(j).boffs := toSlv(i+k, IDX_BITS);
            v.cache(j).toffs := (others=>'0');
          end if;
          if (r.cache(j).mapd = END_M and
              r.cache(j).eaddr(13 downto 0) = r.tout(k)) then
            wrend       := toSlv(j+16,5);
            v.cache(j).eoffs := toSlv(i+k, IDX_BITS);
          end if;
        end loop;
      end loop;

      n := i;
      if r.douten=0 then   -- No data to be added
        --
        --  Only one skip character can be inserted
        --  Only one cache can transition
        --
        if imatch = ROW_SIZE then
          if (r.tout(0)-r.tout_next) > SKIP_T then
            imatch := 0;
          end if;
        end if;
        --
        --  Insert one skip character only
        --
        if imatch < ROW_SIZE then
          v.wrdata(i) := SKIP_CHAR & resize(r.tout(imatch)-r.tout_next,14);
          v.tout_next := r.tout(imatch)+1;
          v.wrbeg (i) := wrbeg;
          n := i+1;
        end if;
        v.wrend (i) := wrend;

      else  -- Adding a row of data
        
        --
        --  Insert one skip character
        --
        if r.tout(0)/=r.tout_next then
          v.wrdata(i) := SKIP_CHAR & resize(r.tout(0)-r.tout_next,14);
          i := i+1;
        end if;
        --
        --  Followed by the row of data
        --
        for k in 0 to ROW_SIZE-1 loop
          v.wrdata(i+k) := r.dout(k);
        end loop;
        n := i + ROW_SIZE;

        if imatch < ROW_SIZE then
          v.wrbeg(i+imatch) := wrbeg;
        end if;
        v.wrend(i+ROW_SIZE-1) := wrend;

        v.tout_next := r.tout(ROW_SIZE-1)+1;
      end if;
    end if;
    
    if n>=ROW_SIZE then
      v.wrfull := '1';
      n := n-ROW_SIZE;
    end if;
    v.wrword := toSlv(n,IDX_BITS+1);

    -- skipped buffers are causing this to fire
    if conv_integer(r.free) < 4 and false then
      --  Deadtime failed
      --  Close all open caches/gates and flag them
      v.wren   := (others=>'0');
      v.wrfull := '0';
      v.wrword := (others=>'0');
      for i in 0 to 15 loop
        if r.cache(i).state = OPEN_S then
          v.cache(i).state := CLOSED_S;
          v.cache(i).mapd  := DONE_M;
          v.cache(i).baddr := r.wraddr & toSlv(0,IDX_BITS);
          v.cache(i).eaddr := r.wraddr & toSlv(0,IDX_BITS);
          v.cache(i).ovflow := '1';
        end if;
      end loop;
    end if;
    
    v.free := resize(r.rdtail - r.wraddr,r.free'length);
      
    i := conv_integer(r.ireading);
    if r.cache(i).state = EMPTY_S then
      v.nfree := toSlv(r.cache'length,r.nfree'length);
    else
      v.nfree := resize(r.ireading-r.iempty,r.nfree'length);
    end if;
    
    if (r.cache(i).state = EMPTY_S or
        r.cache(i).mapd = BEGIN_M or
        r.cache(i).skip = '1' ) then
      v.rdtail := r.wraddr-1;
    else
      v.rdtail := r.cache(i).baddr(r.rdaddr'left+IDX_BITS downto IDX_BITS);
    end if;
      
    if rst='1' then
      v := REG_INIT_C;
    end if;

    r_in <= v;

    for i in ROW_SIZE-1 downto 0 loop
      wrdata(16*i+15 downto 16*i) <= r.wrdata(i);
    end loop;

    rdaddr <= v.rdaddr;
    free   <= r.free;
    nfree  <= r.nfree;
  end process;

  seq : process(clk) is
  begin
    if rising_edge(clk) then
      r <= r_in;
    end if;
  end process;
  
  GEN_RAW : if ALGORITHM_G = "RAW" generate
    U_FEX : entity work.hsd_raw
      generic map ( C_S_AXI_BUS_A_ADDR_WIDTH => 8 )
      port map ( sync                => r.sync,
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
                 iy_V                => doute0,
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
                 s_axi_BUS_A_BVALID  => axilWriteSlave .bvalid,
                 s_axi_BUS_A_BREADY  => axilWriteMaster.bready,
                 s_axi_BUS_A_BRESP   => axilWriteSlave .bresp );
    end generate;
    
  GEN_THR : if ALGORITHM_G = "THR" generate
    U_FEX : entity work.hsd_thr
      generic map ( C_S_AXI_BUS_A_ADDR_WIDTH => 8 )
      port map ( sync                => r.sync,
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
                 iy_V                => doute0,
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
                 s_axi_BUS_A_BVALID  => axilWriteSlave .bvalid,
                 s_axi_BUS_A_BREADY  => axilWriteMaster.bready,
                 s_axi_BUS_A_BRESP   => axilWriteSlave .bresp );
    end generate;
    
end mapping;
