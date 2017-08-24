-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadAdcChannelFifo.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2017-08-24
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
--   Consider having two data formats: one for multi-channels over a certain
--   length and one for single channel any length or multi-channel under a
--   certain length.  The first would be interleaved allowing minimal buffering.
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
--use work.TimingPkg.all;
use work.QuadAdcPkg.all;
use work.QuadAdcCompPkg.all;
use work.FexAlgPkg.all;

entity QuadAdcChannelFifo is
  generic ( BASE_ADDR_C   : slv(31 downto 0) := x"00000000";
            AXIS_CONFIG_G : AxiStreamConfigType;
            ALGORITHM_G   : StringArray;
            DEBUG_G       : boolean := false );
  port (
    clk             :  in sl;
    rst             :  in sl;
    clear           :  in sl;
    start           :  in sl;
    shift           :  in slv       (2 downto 0);
    din             :  in Slv11Array(7 downto 0);
    l1in            :  in sl;
    l1ina           :  in sl;
    l1a             : out slv       (3 downto 0);
    l1v             : out slv       (3 downto 0);
    almost_full     : out sl;
    full            : out sl;
    -- readout interface
    axisMaster      : out AxiStreamMasterType;
    axisSlave       :  in AxiStreamSlaveType;
    -- configuration interface
    axilClk         :  in sl;
    axilRst         :  in sl;
    axilReadMaster  :  in AxiLiteReadMasterType;
    axilReadSlave   : out AxiLiteReadSlaveType;
    axilWriteMaster :  in AxiLiteWriteMasterType;
    axilWriteSlave  : out AxiLiteWriteSlaveType );
end QuadAdcChannelFifo;

architecture mapping of QuadAdcChannelFifo is

  constant NSTREAMS_C : integer := ALGORITHM_G'length;

  type TrigState is ( WAIT_T, REJECT_T, ACCEPT_T );
  type PendType is record
    streams    : slv(NSTREAMS_C-1 downto 0);
    trigd      : TrigState;
  end record;

  constant PEND_INIT_C : PendType := (
    streams    => (others=>'0'),
    trigd      => WAIT_T );

  type PendArray is array(natural range<>) of PendType;
  
  type RegType is record
    fexEnable  : slv(NSTREAMS_C-1 downto 0);
    fexPrescale: Slv10Array(NSTREAMS_C-1 downto 0);
    fexPreCount: Slv10Array(NSTREAMS_C-1 downto 0);
    fexBegin   : Slv14Array(NSTREAMS_C-1 downto 0);
    fexLength  : Slv14Array(NSTREAMS_C-1 downto 0);
    skip       : slv       (NSTREAMS_C-1 downto 0);
    start      : slv       (NSTREAMS_C-1 downto 0);
    l1in       : slv       (NSTREAMS_C-1 downto 0);
    l1ina      : slv       (NSTREAMS_C-1 downto 0);
    ropend     : PendArray (15 downto 0);
    npend      : slv       ( 3 downto 0);
    ntrig      : slv       ( 3 downto 0);
    nread      : slv       ( 3 downto 0);
    aFull      : Slv16Array(NSTREAMS_C-1 downto 0);
    aFullN     : Slv5Array (NSTREAMS_C-1 downto 0);
    almost_full: slv       (NSTREAMS_C-1 downto 0);
    fexb       : slv(NSTREAMS_C-1 downto 0);
    fexn       : integer range 0 to NSTREAMS_C-1;
    axisMaster : AxiStreamMasterType;
    axisSlaves : AxiStreamSlaveArray(NSTREAMS_C-1 downto 0);
    axilReadSlave  : AxiLiteReadSlaveType;
    axilWriteSlave : AxiLiteWriteSlaveType;
  end record;

  constant REG_INIT_C : RegType := (
    fexEnable  => (others=>'0'),
    fexPrescale=> (others=>(others=>'0')),
    fexPreCount=> (others=>(others=>'0')),
    fexBegin   => (others=>(others=>'0')),
    fexLength  => (others=>(others=>'0')),
    skip       => (others=>'0'),
    start      => (others=>'0'),
    l1in       => (others=>'0'),
    l1ina      => (others=>'0'),
    ropend     => (others=>PEND_INIT_C),
    npend      => (others=>'0'),
    ntrig      => (others=>'0'),
    nread      => (others=>'0'),
    aFull      => (others=>(others=>'0')),
    aFullN     => (others=>(others=>'0')),
    almost_full=> (others=>'0'),
    fexb       => (others=>'0'),
    fexn       => 0,
    axisMaster => AXI_STREAM_MASTER_INIT_C,
    axisSlaves => (others=>AXI_STREAM_SLAVE_INIT_C),
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal lopen, lclose, lskip : slv(NSTREAMS_C-1 downto 0);
  signal free              : Slv16Array(NSTREAMS_C-1 downto 0);
  signal nfree             : Slv5Array (NSTREAMS_C-1 downto 0);

  signal maxilReadMaster   : AxiLiteReadMasterType;
  signal maxilReadSlave    : AxiLiteReadSlaveType;
  signal maxilWriteMaster  : AxiLiteWriteMasterType;
  signal maxilWriteSlave   : AxiLiteWriteSlaveType;
  signal maxilReadMasters  : AxiLiteReadMasterArray (NSTREAMS_C downto 0);
  signal maxilReadSlaves   : AxiLiteReadSlaveArray  (NSTREAMS_C downto 0);
  signal maxilWriteMasters : AxiLiteWriteMasterArray(NSTREAMS_C downto 0);
  signal maxilWriteSlaves  : AxiLiteWriteSlaveArray (NSTREAMS_C downto 0);

  signal axisMasters       : AxiStreamMasterArray   (NSTREAMS_C-1 downto 0);
  signal maxisSlave        : AxiStreamSlaveType;
  
  constant SAXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(16);
--  constant MAXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(32);
  constant MAXIS_CONFIG_C : AxiStreamConfigType := AXIS_CONFIG_G;

  function AxilCrossbarConfig  return AxiLiteCrossbarMasterConfigArray is
    variable ret : AxiLiteCrossbarMasterConfigArray(NSTREAMS_C downto 0);
  begin
    for i in 0 to NSTREAMS_C loop
      ret(i) := (baseAddr => BASE_ADDR_C+toSlv(i*256,32),
                 addrBits => 8,
                 connectivity => x"ffff");
    end loop;
    return ret;
  end function AxilCrossbarConfig;
  
  constant AXIL_XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NSTREAMS_C downto 0) := AxilCrossbarConfig;

  -- signals for debugging
  signal rData : slv(127 downto 0);
  signal sData : slv(127 downto 0);

  component ila_0
    port ( clk : in sl;
           probe0 : in slv(255 downto 0) );
  end component;
  
begin  -- mapping

  rData <= r.axisMaster.tData(127 downto 0);
  sData <= axisMasters(0).tData(127 downto 0);

  GEN_DEBUG : if DEBUG_G generate
    U_ILA : ila_0
      port map ( clk           => clk,
                 probe0(0)     => rst,
                 probe0(1)     => clear,
                 probe0(2)     => start,
                 probe0(3)     => l1in,
                 probe0(4)     => l1ina,
                 probe0(5)     => lopen(0),
                 probe0(6)     => lskip(0),
                 probe0(7)     => lclose(0),
                 probe0(8)     => r.start(0),
                 probe0(9)     => r.l1in (0),
                 probe0(10)    => r.l1ina(0),
                 probe0(11)    => axisMasters(0).tValid,
                 probe0(12)    => axisMasters(0).tLast,
                 probe0(13)    => rin.axisSlaves(0).tReady,
                 probe0(14)    => r.fexEnable(0),
                 probe0(18 downto 15) => r.npend,
                 probe0(22 downto 19) => r.ntrig,
                 probe0(26 downto 23) => r.nread,
                 probe0(27)           => maxilWriteMasters(0).awvalid,
                 probe0(28)           => maxilWriteMasters(0).wvalid,
                 probe0(29)           => maxilWriteMasters(0).bready,
                 probe0(61 downto 30) => maxilWriteMasters(0).awaddr,
                 probe0(93 downto 62) => maxilWriteMasters(0).wdata,
                 probe0(255 downto 94) => (others=>'0') );
  end generate;
  
  --  Do we have to cross clock domains here or does VivadoHLS do it for us?
  GEN_AXIL_ASYNC : entity work.AxiLiteAsync
    port map ( sAxiClk         => axilClk,
               sAxiClkRst      => axilRst,
               sAxiReadMaster  => axilReadMaster,
               sAxiReadSlave   => axilReadSlave,
               sAxiWriteMaster => axilWriteMaster,
               sAxiWriteSlave  => axilWriteSlave,
               mAxiClk         => clk,
               mAxiClkRst      => rst,
               mAxiReadMaster  => maxilReadMaster,
               mAxiReadSlave   => maxilReadSlave,
               mAxiWriteMaster => maxilWriteMaster,
               mAxiWriteSlave  => maxilWriteSlave );
  --  Disable access to these registers to test if this is the cause for hang
  --U_EMPTY : entity work.AxiLiteEmpty
  --  port map ( axiClk     => axilClk,
  --             axiClkRst  => axilRst,
  --             axiReadMaster  => axilReadMaster,
  --             axiReadSlave   => axilReadSlave,
  --             axiWriteMaster => axilWriteMaster,
  --             axiWriteSlave  => axilWriteSlave );
  --maxilReadMaster  <= AXI_LITE_READ_MASTER_INIT_C;
  --maxilWriteMaster <= AXI_LITE_WRITE_MASTER_INIT_C;
  
  GEN_AXIL_XBAR : entity work.AxiLiteCrossbar
    generic map ( NUM_SLAVE_SLOTS_G   => 1,
                  NUM_MASTER_SLOTS_G  => AXIL_XBAR_CONFIG_C'length,
                  MASTERS_CONFIG_G    => AXIL_XBAR_CONFIG_C )
    port map ( axiClk           => clk,
               axiClkRst        => rst,
               sAxiReadMasters (0) => maxilReadMaster,
               sAxiReadSlaves  (0) => maxilReadSlave,
               sAxiWriteMasters(0) => maxilWriteMaster,
               sAxiWriteSlaves (0) => maxilWriteSlave,
               mAxiReadMasters     => maxilReadMasters,
               mAxiReadSlaves      => maxilReadSlaves,
               mAxiWriteMasters    => maxilWriteMasters,
               mAxiWriteSlaves     => maxilWriteSlaves );
               
  GEN_FIFO : entity work.AxiStreamFifoV2
    generic map ( FIFO_ADDR_WIDTH_G   => 14,
                  SLAVE_AXI_CONFIG_G  => SAXIS_CONFIG_C,
                  MASTER_AXI_CONFIG_G => MAXIS_CONFIG_C )
    port map ( -- Slave Port
               sAxisClk    => clk,
               sAxisRst    => rst,
               sAxisMaster => r.axisMaster,
               sAxisSlave  => maxisSlave,
               -- Master Port
               mAxisClk    => clk,
               mAxisRst    => rst,
               mAxisMaster => axisMaster,
               mAxisSlave  => axisSlave );

  GEN_STR : for i in 0 to NSTREAMS_C-1 generate
    l1v   (i) <= lclose(i);
    l1a   (i) <= '0';

    U_GATE : entity work.FexGate
      port map ( clk     => clk,
                 rst     => clear,
                 start   => r.start    (i),
                 handle  => r.skip     (i),
                 fbegin  => r.fexBegin (i),
                 flength => r.fexLength(i),
                 lopen   => lopen      (i),
                 lhandle => lskip      (i),
                 lclose  => lclose     (i) );

    U_FEX : entity work.hsd_fex_wrapper
      generic map ( AXIS_CONFIG_G => SAXIS_CONFIG_C,
                    ALGORITHM_G   => ALGORITHM_G(i) )
      port map ( clk               => clk,
                 rst               => clear,
                 din               => din,
                 lopen             => lopen(i),
                 lskip             => lskip(i),
                 lphase            => shift,
                 lclose            => lclose(i),
                 l1in              => r.l1in  (i),
                 l1ina             => r.l1ina (i),
                 free              => free            (i),
                 nfree             => nfree           (i),
                 axisMaster        => axisMasters     (i),
                 axisSlave         => rin.axisSlaves    (i),
                 axilReadMaster    => maxilReadMasters (i+1),
                 axilReadSlave     => maxilReadSlaves  (i+1),
                 axilWriteMaster   => maxilWriteMasters(i+1),
                 axilWriteSlave    => maxilWriteSlaves (i+1) );
  end generate;

  GEN_REM : for i in NSTREAMS_C to 3 generate
    l1v   (i) <= '0';
    l1a   (i) <= '0';
  end generate;
  
  process (r, rst, clear, start, free, nfree, l1in, l1ina,
           axisMasters, maxisSlave,
           maxilWriteMasters, maxilReadMasters) is
    variable v     : RegType;
    variable ep    : AxiLiteEndpointType;
    variable i     : integer;
  begin  -- process
    v := r;

    v.skip  := (others=>'0');
    v.start := (others=>'0');
    v.l1in  := (others=>'0');
    v.l1ina := (others=>'0');
    v.axisMaster.tKeep := genTKeep(SAXIS_CONFIG_C);
    
    -- AxiStream interface
    if maxisSlave.tReady='1' then
      v.axisMaster.tValid := '0';
    end if;

    for i in 0 to NSTREAMS_C-1 loop
      v.axisSlaves(i).tReady := '0';
    end loop;
    
    if r.fexb(r.fexn)='0' then
      if r.fexn=NSTREAMS_C-1 then
        i := conv_integer(r.nread);
        if r.ropend(i).trigd = ACCEPT_T then
          v.fexb  := r.ropend(i).streams;
          v.fexn  := 0;
          v.nread := r.nread+1;
        elsif r.ropend(i).trigd = REJECT_T then
          v.nread := r.nread+1;
        end if;
      else
        v.fexn := r.fexn+1;
      end if;
    elsif v.axisMaster.tValid='0' then
      if axisMasters(r.fexn).tValid='1' then
        v.axisSlaves(r.fexn).tReady := '1';
        v.axisMaster.tValid := '1';
        v.axisMaster.tLast  := '0';
        v.axisMaster.tData  := axisMasters(r.fexn).tData;
        if axisMasters(r.fexn).tLast='1' then
          v.fexb(r.fexn) := '0';
          if v.fexb=0 then
            v.axisMaster.tLast := '1';
          end if;
        end if;
      end if;
    end if;

    -- AxiLite accesses
    axiSlaveWaitTxn( ep,
                     maxilWriteMasters(0), maxilReadMasters(0),
                     v.axilWriteSlave, v.axilReadSlave );

    axiSlaveRegister ( ep, x"00", 0, v.fexEnable );

    for i in 0 to NSTREAMS_C-1 loop
      axiSlaveRegister ( ep, toSlv(16*i+16,8), 0, v.fexPrescale(i) );
      axiSlaveRegister ( ep, toSlv(16*i+20,8), 0, v.fexBegin (i) );
      axiSlaveRegister ( ep, toSlv(16*i+20,8),16, v.fexLength(i) );
      axiSlaveRegister ( ep, toSlv(16*i+24,8), 0, v.aFull    (i) );
      axiSlaveRegister ( ep, toSlv(16*i+24,8),16, v.aFullN   (i) );
      axiSlaveRegisterR( ep, toSlv(16*i+28,8), 0, free       (i) );
      axiSlaveRegisterR( ep, toSlv(16*i+28,8),16, nfree      (i) );
    end loop;

    axiSlaveDefault( ep, v.axilWriteSlave, v.axilReadSlave );

    if start = '1' then
      for i in 0 to NSTREAMS_C-1 loop
        if r.fexEnable(i)='1' then
          v.start      (i) := '1';
          if r.fexPreCount(i)=r.fexPrescale(i) then
            v.skip       (i) := '0';
            v.fexPreCount(i) := (others=>'0');
          else
            v.skip       (i) := '1';
            v.fexPreCount(i) := r.fexPreCount(i)+1;
          end if;
        else
          v.fexPreCount(i) := (others=>'0');
        end if;
      end loop;
      i := conv_integer(r.npend);
      v.ropend(i).streams := v.start;
      v.ropend(i).trigd   := WAIT_T;
      v.npend := r.npend+1;
    end if;

    if l1in = '1' then
      i := conv_integer(r.ntrig);
      v.l1in := r.ropend(i).streams;
      if l1ina = '1' then
        v.l1ina := r.ropend(i).streams;
        v.ropend(i).trigd := ACCEPT_T;
      else
        v.ropend(i).trigd := REJECT_T;
      end if;
      v.ntrig := r.ntrig+1;
    end if;        
    
    -- almost full interface
    for i in 0 to NSTREAMS_C-1 loop
      if (r.fexEnable(i) = '1' and
          (free (i) < r.aFull (i) or
           nfree(i) < r.aFullN(i))) then
        v.almost_full(i) := '1';
      else
        v.almost_full(i) := '0';
      end if;
    end loop;

    if clear='1' then
      v.fexPreCount := (others=>(others=>'0'));
    end if;
    
    if rst='1' then
      v := REG_INIT_C;
    end if;
    
    rin <= v;

    maxilReadSlaves (0) <= r.axilReadSlave;
    maxilWriteSlaves(0) <= r.axilWriteSlave;
    full                <= '0';
    almost_full         <= uOr(r.almost_full);
  end process;

  process (clk)
  begin  -- process
    if rising_edge(clk) then
      r <= rin;
    end if;
  end process;

end mapping;

