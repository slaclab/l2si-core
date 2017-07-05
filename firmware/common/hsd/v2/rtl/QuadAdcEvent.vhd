-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadAdcEvent.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2017-06-27
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-- Independent channel setup.  Simplified to make reasonable interface
-- for feature extraction algorithms.
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
use work.TimingPkg.all;
use work.ArbiterPkg.all;
use work.QuadAdcPkg.all;
use work.FexAlgPkg.all;

entity QuadAdcEvent is
  generic (
    TPD_G             : time    := 1 ns;
    FIFO_ADDR_WIDTH_C : integer := 10;
    NFMC_G            : integer := 1;
    SYNC_BITS_G       : integer := 4;
    BASE_ADDR_C       : slv(31 downto 0) := (others=>'0') );
  port (
    axilClk         :  in sl;
    axilRst         :  in sl;
    axilReadMaster  :  in AxiLiteReadMasterType;
    axilReadSlave   : out AxiLiteReadSlaveType;
    axilWriteMaster :  in AxiLiteWriteMasterType;
    axilWriteSlave  : out AxiLiteWriteSlaveType;
    eventClk   :  in sl;
    eventRst   :  in sl;
    configE    :  in QuadAdcConfigType;
    strobe     :  in sl;
    trigArm    :  in sl;
    eventId    :  in slv(95 downto 0);
    l1in       :  in sl;
    l1ina      :  in sl;
    --
    adcClk     :  in sl;
    adcRst     :  in sl;
    configA    :  in QuadAdcConfigType;
    trigIn     :  in Slv8Array(SYNC_BITS_G-1 downto 0);
    adc        :  in AdcDataArray(4*NFMC_G-1 downto 0);
    --
    dmaClk     :  in sl;
    dmaRst     :  in sl;
    dmaFullThr :  in slv(FIFO_ADDR_WIDTH_C-1 downto 0);
    dmaFullS   : out sl;
    dmaFullQ   : out slv(FIFO_ADDR_WIDTH_C-1 downto 0);
    dmaMaster  : out AxiStreamMasterType;
    dmaSlave   : in  AxiStreamSlaveType );
end QuadAdcEvent;

architecture mapping of QuadAdcEvent is

  constant NCHAN_C : integer := 4*NFMC_G;
  
  type EventStateType is (E_IDLE, E_SYNC);
  -- wait enough timingClks for adcSync to latch and settle
  constant T_SYNC : integer := 10;

  type EventRegType is record
    state    : EventStateType;
    delay    : slv( 25 downto 0);
    intv     : slv( 31 downto 0);
    hdrWr    : slv(  1 downto 0);
    hdrData  : slv(255 downto 0);
  end record;
  constant EVENT_REG_INIT_C : EventRegType := (
    state    => E_IDLE,
    delay    => (others=>'0'),
    intv     => (others=>'0'),
    hdrWr    => (others=>'0'),
    hdrData  => (others=>'0') );

  signal re    : EventRegType := EVENT_REG_INIT_C;
  signal re_in : EventRegType;

  type RdStateType is (S_IDLE, S_READHDR, S_WRITEHDR,
                       S_WAITCHAN, S_READCHAN, S_DUMP);
  type SyncStateType is (S_SHIFT_S, S_WAIT_S);

  constant TMO_VAL_C : integer := 4095;
  
  type RegType is record
    hdrRd    : sl;
    enable   : slv(NCHAN_C-1 downto 0);
    enableValid : sl;
    full     : sl;
    afull    : sl;
    state    : RdStateType;
    master   : AxiStreamMasterType;
    slave    : AxiStreamSlaveType;
    start    : sl;
    syncState: SyncStateType;
    adcShift : slv(2 downto 0);
    trigd1   : slv(7 downto 0);
    trigd2   : slv(7 downto 0);
    trig     : Slv8Array(SYNC_BITS_G-1 downto 0);
    trigCnt  : slv(1 downto 0);
    trigArm  : sl;
    tmo      : integer range 0 to TMO_VAL_C;
  end record;

  constant REG_INIT_C : RegType := (
    hdrRd     => '0',
    enable    => (others=>'0'),
    enableValid => '0',
    full      => '0',
    afull     => '0',
    state     => S_IDLE,
    master    => AXI_STREAM_MASTER_INIT_C,
    slave     => AXI_STREAM_SLAVE_INIT_C,
    start     => '0',
    syncState => S_SHIFT_S,
    adcShift  => (others=>'0'),
    trigd1    => (others=>'0'),
    trigd2    => (others=>'0'),
    trig      => (others=>(others=>'0')),
    trigCnt   => (others=>'0'),
    trigArm   => '0',
    tmo       => TMO_VAL_C );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  type DmaDataArray is array (natural range <>) of Slv11Array(7 downto 0);
  signal iadc        : DmaDataArray(NCHAN_C-1 downto 0);

  type AdcShiftArray is array (natural range<>) of Slv8Array(10 downto 0);
  signal  adcs : AdcShiftArray(NCHAN_C-1 downto 0);
  signal iadcs : AdcShiftArray(NCHAN_C-1 downto 0);

  signal chmasters : AxiStreamMasterArray(NCHAN_C-1 downto 0);
  signal chslaves  : AxiStreamSlaveArray (NCHAN_C-1 downto 0);
  signal chmaster  : AxiStreamMasterType;
  signal chslave   : AxiStreamSlaveType;
  signal chEnableV   : sl;
  signal chEnable    : slv(NCHAN_C-1 downto 0);
  signal chEnableAck : sl;
  signal chafull     : slv(NCHAN_C-1 downto 0);
  signal chfull      : slv(NCHAN_C-1 downto 0);
  
  signal hdrDout  : slv(127 downto 0);
  signal hdrValid : sl;
  signal hdrEmpty : sl;

  signal fullE    : sl;

  signal pllSync   : slv(2 downto 0);
  signal trigArmS  : sl;
  
  constant XPMV7 : boolean := false;

  constant DEBUG_C : boolean := true;

  component ila_0
    port ( clk : in sl;
           probe0 : in slv(255 downto 0) );
  end component;

  signal r_state : slv(2 downto 0);
  signal r_syncstate : sl;
  signal r_intlv : sl;

  signal sl1in, sl1ina : sl;
  
  constant APPLY_SHIFT_C : boolean := false;

  signal mAxilReadMasters  : AxiLiteReadMasterArray (NCHAN_C-1 downto 0);
  signal mAxilReadSlaves   : AxiLiteReadSlaveArray  (NCHAN_C-1 downto 0);
  signal mAxilWriteMasters : AxiLiteWriteMasterArray(NCHAN_C-1 downto 0);
  signal mAxilWriteSlaves  : AxiLiteWriteSlaveArray (NCHAN_C-1 downto 0);
  
  function AxilCrossbarConfig  return AxiLiteCrossbarMasterConfigArray is
    variable ret : AxiLiteCrossbarMasterConfigArray(NCHAN_C-1 downto 0);
  begin
    for i in 0 to NCHAN_C-1 loop
      ret(i) := (baseAddr => BASE_ADDR_C+toSlv(i*4096,32),
                 addrBits => 12,
                 connectivity => x"ffff");
    end loop;
    return ret;
  end function AxilCrossbarConfig;
  
  constant AXIL_XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NCHAN_C-1 downto 0) := AxilCrossbarConfig;

begin  -- mapping

  dmaMaster <= r.master;
  dmaFullS  <= r.afull;
  dmaFullQ  <= (others=>'0');

  GEN_AXIL_XBAR : entity work.AxiLiteCrossbar
    generic map ( NUM_SLAVE_SLOTS_G   => 1,
                  NUM_MASTER_SLOTS_G  => AXIL_XBAR_CONFIG_C'length,
                  MASTERS_CONFIG_G    => AXIL_XBAR_CONFIG_C )
    port map ( axiClk              => axilClk,
               axiClkRst           => axilRst,
               sAxiReadMasters (0) => axilReadMaster,
               sAxiReadSlaves  (0) => axilReadSlave,
               sAxiWriteMasters(0) => axilWriteMaster,
               sAxiWriteSlaves (0) => axilWriteSlave,
               mAxiReadMasters     => mAxilReadMasters,
               mAxiReadSlaves      => mAxilReadSlaves,
               mAxiWriteMasters    => mAxilWriteMasters,
               mAxiWriteSlaves     => mAxilWriteSlaves );
               
  U_L1IN : entity work.SynchronizerOneShot
    port map ( clk     => dmaClk,
               dataIn  => l1in,
               dataOut => sl1in );
  
  U_L1INA : entity work.SynchronizerOneShot
    port map ( clk     => dmaClk,
               dataIn  => l1ina,
               dataOut => sl1ina );
  
  U_TRIGARM : entity work.SynchronizerOneShot
    port map ( clk     => dmaClk,
               dataIn  => trigArm,
               dataOut => trigArmS );
  
  GEN_CH : for i in 0 to NCHAN_C-1 generate
    GEN_BIT : for j in 0 to 10 generate
      U_Shift : entity work.AdcShift
        port map ( clk   => adcClk,
                   rst   => adcRst,
                   shift => r.adcShift,
                   din   =>  adcs(i)(j),
                   dout  => iadcs(i)(j) );
      GEN_IADC : for k in 0 to 7 generate
        GEN_SHIFT : if APPLY_SHIFT_C generate
          adcs(i)(j)(k) <= adc(i).data(k)(j);
          iadc(i)(k)(j) <= iadcs(i)(j)(k);
        end generate GEN_SHIFT;
        GEN_NOSHIFT : if not APPLY_SHIFT_C generate
          iadc(i)(k)(j) <= adc(i).data(k)(j);
        end generate GEN_NOSHIFT;
      end generate GEN_IADC;
    end generate GEN_BIT;
  
--      This is the large buffer.
    U_FIFO : entity work.QuadAdcChannelFifo
      generic map ( BASE_ADDR_C => AXIL_XBAR_CONFIG_C(i).baseAddr,
                    ALGORITHM_G => FEX_ALGORITHMS(i) )
      port map ( clk      => dmaClk,
                 rst      => dmaRst,
                 clear    => dmaRst,
                 start    => r.start,
                 shift    => r.adcShift,
                 din      => iadc(i),
                 l1in     => sl1in,
                 l1ina    => sl1ina,
                 l1a      => open,
                 l1v      => open,
                 almost_full     => chafull  (i),
                 full            => chfull   (i),
                 axisMaster      => chmasters(i),
                 axisSlave       => chslaves (i),
                 axilClk         => axilClk,
                 axilRst         => axilRst,
                 axilReadMaster  => mAxilReadMasters (i),
                 axilReadSlave   => mAxilReadSlaves  (i),
                 axilWriteMaster => mAxilWriteMasters(i),
                 axilWriteSlave  => mAxilWriteSlaves (i) );
  end generate;

  U_HDR : entity work.FifoAsync
    generic map ( DATA_WIDTH_G  => 128,
                  ADDR_WIDTH_G  =>   8 )
    port map ( rst      => dmaRst,
               wr_clk   => eventClk,
               wr_en    => re.hdrWr  (0),
               din      => re.hdrData(127 downto 0),
               rd_clk   => dmaClk,
               rd_en    => rin.hdrRd,
               dout     => hdrDout,
               valid    => hdrValid,
               empty    => hdrEmpty );

  U_PLL_SYNC : entity work.SynchronizerVector
    generic map ( WIDTH_G => pllSync'length )
    port map ( clk      => eventClk,
               rst      => eventRst,
               dataIn   => r.adcShift,
               dataOut  => pllSync );

  U_AXISMUX : entity work.AxiStreamOrderedMux
    generic map ( NUM_SLAVES_G => NCHAN_C )
    port map ( clk          => dmaClk,
               rst          => dmaRst,
               enableValid  => chEnableV,
               enableSel    => chEnable,
               enableAck    => chEnableAck,
               sAxisMasters => chmasters,
               sAxisSlaves  => chslaves,
               mAxisMaster  => chmaster,
               mAxisSlave   => chslave );
  
  process (re, eventRst, eventId, strobe, fullE, configE, pllSync) is
    variable v  : EventRegType;
    variable sz : slv(31 downto 0);
  begin
    v := re;

    v.hdrWr   := '0' & re.hdrWr(1);
    v.intv    := re.intv+1;
    sz := toSlv(8+8*conv_integer(onesCount(configE.enable))*conv_integer(configE.samples(configE.samples'left downto 4)),32);

    case re.state is
      when E_IDLE =>
        if strobe='1' and fullE='0' then
          v.delay   := (others=>'0');
          v.hdrData(159 downto 0) := eventId &
                                     x"00" & configE.enable &
                                     "00" & configE.samples(17 downto 4) &
                                     sz;
          v.state   := E_SYNC;
        else
          v.hdrData := toSlv(0,128) & re.hdrData(re.hdrData'left downto 128);
        end if;
      when E_SYNC =>
        if re.delay=toSlv(T_SYNC,re.delay'length) then
          v.intv  := toSlv(1,re.intv'length);
          v.hdrData(255 downto 160) := toSlv(0,32) & -- space for trigIn
                                       re.intv &
                                       toSlv(0,29) & pllSync;
          v.delay := (others=>'0');
          v.hdrWr := (others=>'1');
          v.state := E_IDLE;
        else
          v.delay := re.delay+1;
        end if;
      when others => NULL;
    end case;
    
    if eventRst='1' then
      v := EVENT_REG_INIT_C;
    end if;

    re_in <= v;
  end process;

  process(eventClk) is
  begin
    if rising_edge(eventClk) then
      re <= re_in;
    end if;
  end process;
    
  process (r, dmaRst, configA, hdrValid, hdrEmpty, hdrDout, dmaSlave, dmaFullThr, trigArmS, trigIn,
           chfull, chafull, chmaster, chEnableAck)
    variable v   : RegType;
  begin  -- process
    v := r;

    v.hdrRd   := '0';
    v.trigd1  := trigIn(0);
--    v.trigd2  := (r.trigd1 and configA.trigShift) or (trigIn(0) and not configA.trigShift);
    v.trigd2  := r.trigd1;

    v.enableValid  := '0';
    v.slave.tReady := '0';
    v.full         := uOr(chfull);
    v.afull        := uOr(chafull);
    
    if dmaSlave.tReady='1' then
      v.master.tValid := '0';
    end if;

    if r.state = S_READCHAN and r.master.tValid='0' then
      v.tmo := r.tmo-1;
    else
      v.tmo := TMO_VAL_C;
    end if;
    
    case r.state is
      when S_IDLE =>
        v.enable  := configA.enable;
        if hdrEmpty='0' then
          v.hdrRd := '1';
          v.state := S_READHDR;
          v.tmo   := TMO_VAL_C;
        end if;
      when S_READHDR =>
        if v.master.tValid='0' then
          v.master.tData(127 downto 0) := hdrDout;
          if hdrEmpty='0' then
            v.hdrRd := '1';
            v.state := S_WRITEHDR;
          end if;
        end if;
      when S_WRITEHDR =>
        if r.master.tValid='0' or dmaSlave.tReady='1' then
          v.master.tData(255 downto 224) := r.trig(3) & r.trig(2) & r.trig(1) & r.trig(0);
          v.master.tData(223 downto 128) := hdrDout(95 downto 0);
          v.master.tKeep                 := genTKeep(32);
          v.master.tValid                := '1';
          v.master.tLast                 := '0';
          v.state := S_WAITCHAN;
          v.enableValid := '1';
          v.state       := S_WAITCHAN;
        end if;
      when S_WAITCHAN =>
        if chEnableAck = '0' then
          v.enableValid := '1';
        end if;
        if v.master.tValid = '0' then
          v.master       := chmaster;
          v.slave.tReady := '1';
        end if;
      when S_DUMP =>
        if v.master.tValid='0' then
          v.state := S_IDLE;
        end if;
      when others => NULL;
    end case;

    if r.tmo = 0 then
      v.state := S_DUMP;
      v.master.tValid := '1';
      v.master.tLast  := '1';
    end if;
    
    if r.trigCnt/="11" then
      v.trig    := r.trigd2 & r.trig(r.trig'left downto 1);
      v.trigCnt := r.trigCnt+1;
    end if;
    
   v.start := '0';
    case (r.syncState) is
      when S_SHIFT_S =>
        if trigArmS = '1' then
          v.trigArm := '1';
        end if;
        if r.trigd2/=toSlv(0,8) then
          v.start := configA.acqEnable;
          for i in 7 downto 0 loop
            if r.trigd2(i)='1' then
              v.adcShift := toSlv(i,3);
            end if;
          end loop;
          if r.trigArm='1' then
            v.trig      := r.trigd2 & r.trig(r.trig'left downto 1);
            v.trigArm   := '0';
            v.trigCnt   := (others=>'0');
          end if;
          v.syncState := S_WAIT_S;
        end if;
      when S_WAIT_S =>
        if r.trigd2=toSlv(0,8) then
          v.syncState := S_SHIFT_S;
        end if;
      when others => NULL;
    end case;

    if dmaRst='1' then
      v := REG_INIT_C;
    end if;

    rin <= v;

    chEnableV <= r.enableValid;
    chEnable  <= r.enable;
    chslave   <= v.slave;
  end process;

  process (dmaClk)
  begin  -- process
    if rising_edge(dmaClk) then
      r <= rin;
    end if;
  end process;

  U_Full : entity work.Synchronizer
    generic map ( TPD_G   => TPD_G )
    port map (    clk     => eventClk,
                  rst     => eventRst,
                  dataIn  => r.full,
                  dataOut => fullE );
  
  
end mapping;
