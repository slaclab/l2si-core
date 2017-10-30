-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadAdcEvent.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2017-10-28
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
use work.SsiPkg.all;
--use work.TimingPkg.all;
use work.QuadAdcPkg.all;
use work.FexAlgPkg.all;

entity QuadAdcEvent is
  generic (
    TPD_G             : time    := 1 ns;
    FIFO_ADDR_WIDTH_C : integer := 10;
    NFMC_G            : integer := 1;
    SYNC_BITS_G       : integer := 4;
    DMA_STREAM_CONFIG_G : AxiStreamConfigType;
    BASE_ADDR_C       : slv(31 downto 0) := (others=>'0') );
  port (
    axilClk         :  in sl;
    axilRst         :  in sl;
    axilReadMaster  :  in AxiLiteReadMasterType;
    axilReadSlave   : out AxiLiteReadSlaveType;
    axilWriteMaster :  in AxiLiteWriteMasterType;
    axilWriteSlave  : out AxiLiteWriteSlaveType;
    --eventClk   :  in sl;
    --eventRst   :  in sl;
    --eventId    :  in slv(127 downto 0);
    --strobe     :  in sl;
    trigArm    :  in sl;
    l1in       :  in sl;
    l1ina      :  in sl;
    --
    adcClk     :  in sl;
    adcRst     :  in sl;
    configA    :  in QuadAdcConfigType;
    trigIn     :  in Slv8Array(SYNC_BITS_G-1 downto 0);
    adc        :  in AdcDataArray(4*NFMC_G-1 downto 0);
    --
    dmaClk        :  in sl;
    dmaRst        :  in sl;
    eventHeader   :  in Slv192Array(4*NFMC_G-1 downto 0);
    eventHeaderV  :  in slv        (4*NFMC_G-1 downto 0);
    eventHeaderRd : out slv        (4*NFMC_G-1 downto 0);
    rstFifo       :  in sl;
    dmaFullThr    :  in slv(FIFO_ADDR_WIDTH_C-1 downto 0);
    dmaFullS      : out sl;
    dmaFullQ      : out slv(FIFO_ADDR_WIDTH_C-1 downto 0);
    status        : out CacheArray(MAX_OVL_C-1 downto 0);
    dmaMaster     : out AxiStreamMasterArray(3 downto 0);
    dmaSlave      : in  AxiStreamSlaveArray (3 downto 0) );
end QuadAdcEvent;

architecture mapping of QuadAdcEvent is

  constant ONE_STREAM : boolean := false;
  constant NCHAN_C : integer := 4*NFMC_G;
  
  type EventStateType is (E_IDLE, E_SYNC);
  -- wait enough timingClks for adcSync to latch and settle
  constant T_SYNC : integer := 10;

  type EventRegType is record
    state    : EventStateType;
    delay    : slv( 25 downto 0);
    hdrWr    : slv(  1 downto 0);
    hdrData  : slv(255 downto 0);
  end record;
  constant EVENT_REG_INIT_C : EventRegType := (
    state    => E_IDLE,
    delay    => (others=>'0'),
    hdrWr    => (others=>'0'),
    hdrData  => (others=>'0') );

  signal re    : EventRegType := EVENT_REG_INIT_C;
  signal re_in : EventRegType;

  type SyncStateType is (S_SHIFT_S, S_WAIT_S);

  constant TMO_VAL_C : integer := 4095;
  
  type RegType is record
    full     : sl;
    afull    : sl;
    start    : sl;
    syncState: SyncStateType;
    adcShift : slv(2 downto 0);
    trigd1   : slv(7 downto 0);
    trigd2   : slv(7 downto 0);
    trig     : Slv8Array(SYNC_BITS_G-1 downto 0);
    trigCnt  : slv(1 downto 0);
    trigArm  : sl;
    l1in     : slv(4 downto 0);
    l1ina    : slv(3 downto 0);
    tmo      : integer range 0 to TMO_VAL_C;
  end record;

  constant REG_INIT_C : RegType := (
    full      => '0',
    afull     => '0',
    start     => '0',
    syncState => S_SHIFT_S,
    adcShift  => (others=>'0'),
    trigd1    => (others=>'0'),
    trigd2    => (others=>'0'),
    trig      => (others=>(others=>'0')),
    trigCnt   => (others=>'0'),
    trigArm   => '0',
    l1in      => (others=>'0'),
    l1ina     => (others=>'0'),
    tmo       => TMO_VAL_C );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  type DmaDataArray is array (natural range <>) of Slv11Array(7 downto 0);
  signal iadc        : DmaDataArray(NCHAN_C-1 downto 0);

  type AdcShiftArray is array (natural range<>) of Slv8Array(10 downto 0);
  signal  adcs : AdcShiftArray(NCHAN_C-1 downto 0);
  signal iadcs : AdcShiftArray(NCHAN_C-1 downto 0);

  constant CHN_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(16);

  signal chmasters   : AxiStreamMasterArray(NCHAN_C-1 downto 0);
  signal chslaves    : AxiStreamSlaveArray (NCHAN_C-1 downto 0);
  signal chafull     : slv(NCHAN_C-1 downto 0);
  signal chfull      : slv(NCHAN_C-1 downto 0);
  
  signal hdrValid  : slv(NCHAN_C-1 downto 0);
  signal hdrRd     : slv(NCHAN_C-1 downto 0);

  signal pllSync   : Slv3Array  (NCHAN_C-1 downto 0);
  signal pllSyncV  : slv        (NCHAN_C-1 downto 0);
  signal eventHdr  : Slv256Array(NCHAN_C-1 downto 0);
  
  constant XPMV7 : boolean := false;

  signal r_state : slv(2 downto 0);
  signal r_syncstate : sl;
  signal r_intlv : sl;

  signal sl1in, sl1ina : sl;
  signal trigArmS  : sl;
  
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

  constant DEBUG_C : boolean := false;

  component ila_0
    port ( clk   : in sl;
           probe0: in slv(255 downto 0) );
  end component;

  signal cacheStatus : CacheStatusArray(NCHAN_C-1 downto 0);

begin  -- mapping

  status <= cacheStatus(0);
  
  GEN_DEBUG: if DEBUG_C generate
    U_ILA : ila_0
      port map ( clk     => dmaClk,
                 probe0 ( 0 ) => dmaRst, 
                 probe0 ( 1 ) => r.start,
                 probe0 ( 2 ) => sl1in,
                 probe0 ( 3 ) => sl1ina,
                 probe0 ( 4 ) => chafull(0),                 
                 probe0 ( 5 ) => chfull(0),
                 probe0 ( 6 ) => chmasters(0).tValid,
                 probe0 ( 7 ) => chmasters(0).tLast,
                 probe0 (  9 downto  8 ) => chmasters(0).tUser( 1 downto 0),
                 probe0 ( 41 downto 10 ) => chmasters(0).tData(31 downto 0),
                 probe0 ( 42 ) => chslaves(0).tReady,
                 probe0 ( 255 downto 43 ) => (others=>'0') );
  end generate;

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
  
  U_L1INA : entity work.RstSync
    port map ( clk      => dmaClk,
               asyncRst => l1ina,
               syncRst  => sl1ina );
  
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

    eventHdr     (i) <= toSlv(0,29) & pllSync(i) &
                        configA.enable & toSlv(0,6) &
                        configA.samples(17 downto 4) & x"0" &
                        eventHeader(i);
    hdrValid     (i) <= eventHeaderV(i) and pllSyncV(i);
    eventHeaderRd(i) <= hdrRd(i);
    

    U_PllSyncF : entity work.FifoSync
      generic map ( ADDR_WIDTH_G => 5,
                    DATA_WIDTH_G => 3,
                    FWFT_EN_G    => true )
      port map ( rst    => rstFifo,
                 clk    => dmaClk,
                 wr_en  => r.start,
                 din    => r.adcShift,
                 rd_en  => hdrRd   (i),
                 dout   => pllSync (i),
                 valid  => pllSyncV(i) );

--      This is the large buffer.
    U_FIFO : entity work.QuadAdcChannelFifo
      generic map ( BASE_ADDR_C => AXIL_XBAR_CONFIG_C(i).baseAddr,
                    AXIS_CONFIG_G => CHN_AXIS_CONFIG_C,
                    ALGORITHM_G => FEX_ALGORITHMS(i),
--                    DEBUG_G     => ite(i>0, false, true) )
                    DEBUG_G     => false )
      port map ( clk      => dmaClk,
                 rst      => dmaRst,
                 clear    => dmaRst,
                 start    => r.start,
                 shift    => r.adcShift,
                 din      => iadc(i),
                 l1in     => r.l1in (0),
                 l1ina    => r.l1ina(0),
                 l1a      => open,
                 l1v      => open,
                 almost_full     => chafull  (i),
                 full            => chfull   (i),
                 status          => cacheStatus(i),
                 axisMaster      => chmasters(i),
                 axisSlave       => chslaves (i),
                 axilClk         => axilClk,
                 axilRst         => axilRst,
                 axilReadMaster  => mAxilReadMasters (i),
                 axilReadSlave   => mAxilReadSlaves  (i),
                 axilWriteMaster => mAxilWriteMasters(i),
                 axilWriteSlave  => mAxilWriteSlaves (i) );

    GEN_DATA : if ONE_STREAM=false generate
      U_DATA : entity work.QuadAdcChannelData
        generic map ( DMA_STREAM_CONFIG_G => DMA_STREAM_CONFIG_G )
        port map ( --eventClk    => eventClk,
                   --eventRst    => eventRst,
                   --eventWr     => re.hdrWr(0),
                   --eventDin    => re.hdrData(127 downto 0),
                   dmaClk      => dmaClk,
                   dmaRst      => dmaRst,
                   --
                   eventHdrV   => hdrValid(i),
                   eventHdr    => eventHdr(i),
                   eventHdrRd  => hdrRd   (i),
                   --
                   eventTrig(31 downto 24) => r.trig(3),
                   eventTrig(23 downto 16) => r.trig(2),
                   eventTrig(15 downto  8) => r.trig(1),
                   eventTrig( 7 downto  0) => r.trig(0),
                   chnMaster   => chmasters(i),
                   chnSlave    => chslaves (i),
                   dmaMaster   => dmaMaster(i),
                   dmaSlave    => dmaSlave (i) );

    end generate GEN_DATA;
  end generate;

  GEN_ONE : if ONE_STREAM=true generate
    U_DATA : entity work.QuadAdcChannelMux
      generic map ( NCHAN_C             => NCHAN_C,
                    DMA_STREAM_CONFIG_G => DMA_STREAM_CONFIG_G )
      port map ( --eventClk    => eventClk,
                 --eventRst    => eventRst,
                 --eventWr     => re.hdrWr(0),
                 --eventDin    => re.hdrData(127 downto 0),
                 --
                 dmaClk      => dmaClk,
                 dmaRst      => dmaRst,
                 --
                 eventHdrV   => hdrValid(0),
                 eventHdr    => eventHdr(0),
                 eventHdrRd  => hdrRd   (0),
                 --
                 eventTrig(31 downto 24) => r.trig(3),
                 eventTrig(23 downto 16) => r.trig(2),
                 eventTrig(15 downto  8) => r.trig(1),
                 eventTrig( 7 downto  0) => r.trig(0),
                 chenable    => configA.enable,
                 chmasters   => chmasters,
                 chslaves    => chslaves,
                 dmaMaster   => dmaMaster(0),
                 dmaSlave    => dmaSlave (0) );
    dmaMaster(dmaMaster'left downto 1) <= (others=>AXI_STREAM_MASTER_INIT_C);
  end generate;

  --U_PLL_SYNC : entity work.SynchronizerVector
  --  generic map ( WIDTH_G => pllSync'length )
  --  port map ( clk      => eventClk,
  --             rst      => eventRst,
  --             dataIn   => r.adcShift,
  --             dataOut  => pllSync );

  --process (re, eventRst, eventId, strobe, fullE, configE, pllSync) is
  --  variable v  : EventRegType;
  --begin
  --  v := re;

  --  v.hdrWr   := '0' & re.hdrWr(1);

  --  case re.state is
  --    when E_IDLE =>
  --      if strobe='1' and fullE='0' then
  --        v.delay   := (others=>'0');
  --        v.hdrData(191 downto 0) := eventId;
  --        v.state   := E_SYNC;
  --      else
  --        v.hdrData := toSlv(0,128) & re.hdrData(re.hdrData'left downto 128);
  --      end if;
  --    when E_SYNC =>
  --      if re.delay=toSlv(T_SYNC,re.delay'length) then
  --        v.hdrData(255 downto 192) := toSlv(0,29) & pllSync &
  --                                     configE.enable & toSlv(0,6) &
  --                                     configE.samples(17 downto 4) & x"0";
  --        v.delay := (others=>'0');
  --        v.hdrWr := (others=>'1');
  --        v.state := E_IDLE;
  --      else
  --        v.delay := re.delay+1;
  --      end if;
  --    when others => NULL;
  --  end case;
    
  --  if eventRst='1' then
  --    v := EVENT_REG_INIT_C;
  --  end if;

  --  re_in <= v;
  --end process;

  --process(eventClk) is
  --begin
  --  if rising_edge(eventClk) then
  --    re <= re_in;
  --  end if;
  --end process;
    
  process (r, dmaRst, dmaFullThr, trigArmS, trigIn, chfull, chafull, configA,
           sl1in, sl1ina) is
    variable v   : RegType;
  begin  -- process
    v := r;

    v.trigd1  := trigIn(0);
--    v.trigd2  := (r.trigd1 and configA.trigShift) or (trigIn(0) and not configA.trigShift);
    v.trigd2  := r.trigd1;

    v.full         := uOr(chfull);
    v.afull        := uOr(chafull);

    v.l1in    := sl1in  & r.l1in (r.l1in 'left downto 1);
    v.l1ina   := sl1ina & r.l1ina(r.l1ina'left downto 1);
    
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
  end process;

  process (dmaClk)
  begin  -- process
    if rising_edge(dmaClk) then
      r <= rin;
    end if;
  end process;

  --U_Full : entity work.Synchronizer
  --  generic map ( TPD_G   => TPD_G )
  --  port map (    clk     => eventClk,
  --                rst     => eventRst,
  --                dataIn  => r.full,
  --                dataOut => fullE );
  
  
end mapping;
