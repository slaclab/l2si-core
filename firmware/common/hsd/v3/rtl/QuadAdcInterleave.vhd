-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadAdcInterleave.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2018-01-05
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

entity QuadAdcInterleave is
  generic ( BASE_ADDR_C   : slv(31 downto 0) := x"00000000";
            AXIS_CONFIG_G : AxiStreamConfigType;
            ALGORITHM_G   : StringArray;
            AXIS_SIZE_G   : integer := 1;
            IFMC_G        : integer := 0;
            DEBUG_G       : boolean := false );
  port (
    clk             :  in sl;
    rst             :  in sl;
    clear           :  in sl;
    start           :  in sl;
    shift           :  in slv       (2 downto 0);
    din0            :  in Slv11Array(7 downto 0);
    din1            :  in Slv11Array(7 downto 0);
    din2            :  in Slv11Array(7 downto 0);
    din3            :  in Slv11Array(7 downto 0);
    l1in            :  in sl;
    l1ina           :  in sl;
    l1a             : out slv       (3 downto 0);
    l1v             : out slv       (3 downto 0);
    --
    config          :  in QuadAdcConfigType;
    pllSync         :  in slv(  2 downto 0);
    hdr             :  in slv(191 downto 0);
    hdrV            :  in sl;
    msgV            :  in sl;
    hdrRd           : out sl;
    --
    almost_full     : out sl;
    full            : out sl;
    status          : out CacheArray(MAX_OVL_C-1 downto 0);
    -- readout interface
    axisMaster      : out AxiStreamMasterArray(AXIS_SIZE_G-1 downto 0);
    axisSlave       :  in AxiStreamSlaveArray (AXIS_SIZE_G-1 downto 0);
    -- RAM interface (4x?)
    bramWriteMaster : out BRamWriteMasterArray(4*ALGORITHM_G'length-1 downto 0);
    bramReadMaster  : out BRamReadMasterArray (4*ALGORITHM_G'length-1 downto 0);
    bramReadSlave   : in  BRamReadSlaveArray  (4*ALGORITHM_G'length-1 downto 0);
    -- configuration interface
    axilClk         :  in sl;
    axilRst         :  in sl;
    axilReadMaster  :  in AxiLiteReadMasterType;
    axilReadSlave   : out AxiLiteReadSlaveType;
    axilWriteMaster :  in AxiLiteWriteMasterType;
    axilWriteSlave  : out AxiLiteWriteSlaveType;
    streams         : out slv(3 downto 0) );
end QuadAdcInterleave;

architecture mapping of QuadAdcInterleave is

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

  type AxisStateType is ( SHIFT_S, READ_S );
  
  type AxisRegType is record
    fexb       : slv(NSTREAMS_C-1 downto 0);
    fexn       : integer range 0 to NSTREAMS_C-1;
    axisState  : AxisStateType;
    axisMaster : AxiStreamMasterType;
    axisSlaves : AxiStreamSlaveArray(NSTREAMS_C-1 downto 0);
  end record;

  constant AXIS_REG_INIT_C : AxisRegType := (
    fexb       => (others=>'0'),
    fexn       => NSTREAMS_C-1,
    axisState  => READ_S,
    axisMaster => AXI_STREAM_MASTER_INIT_C,
    axisSlaves => (others=>AXI_STREAM_SLAVE_INIT_C) );
  
  type AxisRegArray is array (natural range<>) of AxisRegType;
  
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
    nhdr       : slv       ( 3 downto 0);
    hdrV       : slv       (15 downto 0);
    hdr        : Slv192Array(15 downto 0);
    hdrRd      : sl;
    aFull      : Slv16Array(NSTREAMS_C-1 downto 0);
    aFullN     : Slv5Array (NSTREAMS_C-1 downto 0);
    almost_full: slv       (NSTREAMS_C-1 downto 0);
    axisReg    : AxisRegArray(AXIS_SIZE_G-1 downto 0);
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
    nhdr       => (others=>'0'),
    hdr        => (others=>(others=>'0')),
    hdrV       => (others=>'0'),
    hdrRd      => '0',
    aFull      => (others=>(others=>'0')),
    aFullN     => (others=>(others=>'0')),
    almost_full=> (others=>'0'),
    axisReg    => (others=>AXIS_REG_INIT_C),
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

  signal axisMasters       : AxiStreamMasterArray   (AXIS_SIZE_G*NSTREAMS_C-1 downto 0);
  signal axisSlaves        : AxiStreamSlaveArray    (AXIS_SIZE_G*NSTREAMS_C-1 downto 0);
 
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

  signal din : Slv44Array(7 downto 0);
  
  constant DEBUG_C : boolean := DEBUG_G;
  
  component ila_0
    port ( clk : in sl;
           probe0 : in slv(255 downto 0) );
  end component;

  signal cacheStatus : CacheStatusArray(NSTREAMS_C-1 downto 0);
  
begin  -- mapping

  status  <= cacheStatus(0);
  streams <= resize(r.fexEnable,4);
  hdrRd   <= rin.hdrRd;
  
  GEN_DIN : for i in 0 to 7 generate
    din(i) <= din3(i) & din2(i) & din1(i) & din0(i);
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

  GEN_STR : for i in 0 to NSTREAMS_C-1 generate
    l1v   (i) <= lclose(i);
    l1a   (i) <= '0';

    U_GATE : entity work.FexGate
      port map ( clk     => clk,
                 rst     => rst,
                 start   => r.start    (i),
                 handle  => r.skip     (i),
                 fbegin  => r.fexBegin (i),
                 flength => r.fexLength(i),
                 lopen   => lopen      (i),
                 lhandle => lskip      (i),
                 lclose  => lclose     (i) );

    U_FEX : entity work.hsd_fex_interleave
      generic map ( AXIS_CONFIG_G => AXIS_CONFIG_G,
                    ALG_ID_G      => i,
                    ALGORITHM_G   => ALGORITHM_G(i),
                    AXIS_SIZE_G   => AXIS_SIZE_G,
                    DEBUG_G       => ite(i>1,false,true) )
--                    DEBUG_G       => false )
--                    DEBUG_G       => DEBUG_G )
      port map ( clk               => clk,
                 rst               => rst,
                 clear             => clear,
                 din               => din,
                 lopen             => lopen(i),
                 lskip             => lskip(i),
                 lphase            => shift,
                 lclose            => lclose(i),
                 l1in              => r.l1in  (i),
                 l1ina             => r.l1ina (i),
                 free              => free            (i),
                 nfree             => nfree           (i),
                 status            => cacheStatus     (i),
                 axisMaster        => axisMasters     ((i+1)*AXIS_SIZE_G-1 downto i*AXIS_SIZE_G),
                 axisSlave         => axisSlaves      ((i+1)*AXIS_SIZE_G-1 downto i*AXIS_SIZE_G),
                 -- BRAM interface
                 bramWriteMaster   => bramWriteMaster (4*i+3 downto 4*i),
                 bramReadMaster    => bramReadMaster  (4*i+3 downto 4*i),
                 bramReadSlave     => bramReadSlave   (4*i+3 downto 4*i),
                 --
                 axilReadMaster    => maxilReadMasters (i+1),
                 axilReadSlave     => maxilReadSlaves  (i+1),
                 axilWriteMaster   => maxilWriteMasters(i+1),
                 axilWriteSlave    => maxilWriteSlaves (i+1) );
  end generate;

  GEN_REM : for i in NSTREAMS_C to 3 generate
    l1v   (i) <= '0';
    l1a   (i) <= '0';
  end generate;
  
  process (r, rst, start, free, nfree, l1in, l1ina, hdr, hdrV, msgV,
           config, pllSync,
           axisMasters, axisSlave,
           maxilWriteMasters, maxilReadMasters) is
    variable v     : RegType;
    variable ep    : AxiLiteEndpointType;
    variable q     : AxisRegType;
    variable am    : AxiStreamMasterArray(NSTREAMS_C-1 downto 0);
    variable i,j   : integer;
  begin  -- process
    v := r;

    v.skip  := (others=>'0');
    v.start := (others=>'0');
    v.l1in  := (others=>'0');
    v.l1ina := (others=>'0');
    v.hdrRd := '0';
    
    -- AxiStream interface : mux in STREAMS
    for j in 0 to AXIS_SIZE_G-1 loop
      
      q  := r.axisReg(j);

      axisMaster(j) <= q.axisMaster;

      q.axisMaster.tKeep  := genTKeep(AXIS_CONFIG_G);
      
      --  process acknowledgement
      if axisSlave(j).tReady='1' then
        q.axisMaster.tValid := '0';
      end if;

      for i in 0 to NSTREAMS_C-1 loop
        am(i) := axisMasters(i*AXIS_SIZE_G+j);
      end loop;

      for i in 0 to NSTREAMS_C-1 loop
        q.axisSlaves(i).tReady := '0';
      end loop;

      if q.axisMaster.tValid='0' then
        --  Set default start and end bits
        ssiSetUserSof( AXIS_CONFIG_G, q.axisMaster, '0');
        q.axisMaster.tLast  := '0';
        
        if q.fexb(q.fexn)='0' then
          if q.fexn=NSTREAMS_C-1 then
            i := conv_integer(r.nread);
            --  Handle next event round robin in AxiStreams
            if i mod AXIS_SIZE_G = j then
              if msgV = '1' then  -- first priority is to forward msg
                q.axisMaster.tValid := '1';
                if q.axisState = READ_S then
                  q.axisState := SHIFT_S;
                  q.axisMaster.tData(127 downto 0) := hdr(127 downto 0);
                  ssiSetUserSof( AXIS_CONFIG_G, q.axisMaster, '1');
                else
                  v.hdrRd     := '1';
                  q.axisState := READ_S;
                  q.axisMaster.tLast  := '1';
                  q.axisMaster.tData( 63 downto  0) := hdr(191 downto 128);
                  q.axisMaster.tData( 95 downto 64) := toSlv(IFMC_G,8) & toSlv(0,24);
                  q.axisMaster.tData(127 downto 96) := (others=>'0');
                end if;
              elsif r.ropend(i).trigd = ACCEPT_T and r.hdrV(i) = '1' then
                q.fexb  := r.ropend(i).streams;
                q.fexn  := 0;
                v.nread := r.nread+1;
                q.axisMaster.tValid := '1';
                q.axisMaster.tData(191 downto   0) := r.hdr(i);
                q.axisMaster.tData(223 downto 192) := toSlv(IFMC_G,8) & toSlv(0,4) &
                                                      config.samples(17 downto 4) & toSlv(0,6);
                q.axisMaster.tData(255 downto 224) := toSlv(0,29) & pllSync;
                ssiSetUserSof( AXIS_CONFIG_G, q.axisMaster, '1');
                q.axisState := SHIFT_S;
                v.hdrV(i) := '0';
              elsif r.ropend(i).trigd = REJECT_T then
                v.nread := r.nread+1;
              end if;
            end if;
          else
            q.fexn := q.fexn+1;
            q.axisState := READ_S;
          end if;
        elsif q.axisState = SHIFT_S then
          q.axisMaster.tValid := '1';
          q.axisMaster.tData(127 downto 0) := q.axisMaster.tData(255 downto 128);
          q.axisState := READ_S;
        elsif am(q.fexn).tValid='1' then
          q.axisSlaves(q.fexn).tReady := '1';
          q.axisMaster.tValid := '1';
          q.axisMaster.tLast  := '0';
          q.axisMaster.tData  := am(q.fexn).tData;
          if am(q.fexn).tLast='1' then
            q.fexb(q.fexn) := '0';
            if q.fexb=0 then
              q.axisMaster.tLast := '1';
            end if;
          end if;
        end if;
      end if;
      v.axisReg(j) := q;

      for i in 0 to NSTREAMS_C-1 loop
        axisSlaves(i*AXIS_SIZE_G+j) <= q.axisSlaves(i);
      end loop;
    end loop;
      
    -- AxiLite accesses
    axiSlaveWaitTxn( ep,
                     maxilWriteMasters(0), maxilReadMasters(0),
                     v.axilWriteSlave, v.axilReadSlave );

    v.axilReadSlave.rdata := (others=>'0');
      
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

    if hdrV = '1' then
      i := conv_integer(r.nhdr);
      v.hdr (i) := hdr;
      v.hdrV(i) := '1';
      v.nhdr    := r.nhdr + 1;
      v.hdrRd   := '1';
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

