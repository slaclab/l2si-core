-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadAdcEvent.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2018-04-27
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-- Independent channel setup.  Simplified to make reasonable interface
-- for feature extraction algorithms.
-- BRAM interface factored out.
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
    NFMC_G            : integer := 2;
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
    --
    eventClk   :  in sl;
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
    eventHeader   :  in Slv192Array(NFMC_G-1 downto 0);
    eventHeaderV  :  in slv        (NFMC_G-1 downto 0);
    noPayload     :  in slv        (NFMC_G-1 downto 0);
    eventHeaderRd : out slv        (NFMC_G-1 downto 0);
    rstFifo       :  in sl;
    dmaFullThr    :  in slv(FIFO_ADDR_WIDTH_C-1 downto 0);
    dmaFullS      : out sl;
    dmaFullQ      : out slv(FIFO_ADDR_WIDTH_C-1 downto 0);
    status        : out CacheArray(MAX_OVL_C-1 downto 0);
    dmaMaster     : out AxiStreamMasterArray(NFMC_G-1 downto 0);
    dmaSlave      : in  AxiStreamSlaveArray (NFMC_G-1 downto 0) );
end QuadAdcEvent;

architecture mapping of QuadAdcEvent is

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
    syncState: SyncStateType;
    adcShift : slv(2 downto 0);
    trigd1   : slv(7 downto 0);
    trigd2   : slv(7 downto 0);
    trig     : Slv8Array(SYNC_BITS_G-1 downto 0);
    trigCnt  : slv(1 downto 0);
    trigArm  : sl;
    --iaxis    : integer range 0 to DMA_SIZE_G-1;
    clear    : sl;
    start    : sl;
    l1inacc  : slv(3 downto 0);
    l1inrej  : slv(3 downto 0);
    tmo      : integer range 0 to TMO_VAL_C;
  end record;

  constant REG_INIT_C : RegType := (
    full      => '0',
    afull     => '0',
    syncState => S_SHIFT_S,
    adcShift  => (others=>'0'),
    trigd1    => (others=>'0'),
    trigd2    => (others=>'0'),
    trig      => (others=>(others=>'0')),
    trigCnt   => (others=>'0'),
    trigArm   => '0',
    --iaxis     => 0,
    clear     => '1',
    start     => '0',
    l1inacc   => (others=>'0'),
    l1inrej   => (others=>'0'),
    tmo       => TMO_VAL_C );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  type DmaDataArray is array (natural range <>) of Slv11Array(7 downto 0);
  signal iadc        : DmaDataArray(NCHAN_C-1 downto 0);

  type AdcShiftArray is array (natural range<>) of Slv8Array(10 downto 0);
  signal  adcs : AdcShiftArray(NCHAN_C-1 downto 0);
  signal iadcs : AdcShiftArray(NCHAN_C-1 downto 0);

  constant CHN_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(32);
  
  -- interleave payload
  signal ilvmasters  : AxiStreamMasterArray(NFMC_G-1 downto 0) := (others=>AXI_STREAM_MASTER_INIT_C);
  signal ilvslaves   : AxiStreamSlaveArray (NFMC_G-1 downto 0) := (others=>AXI_STREAM_SLAVE_INIT_C);
  signal ilvafull       : slv(NFMC_G-1 downto 0);
  signal ilvfull        : slv(NFMC_G-1 downto 0);

  signal hdrValid  : slv(NFMC_G-1 downto 0);
  signal hdrRd     : slv(NFMC_G-1 downto 0);
  
  signal pllSync   : Slv3Array  (NFMC_G-1 downto 0);
  signal pllSyncV  : slv        (NFMC_G-1 downto 0);
  signal eventHdr  : Slv256Array(NFMC_G-1 downto 0);

  signal l1inacc, sl1inacc : sl;
  signal l1inrej, sl1inrej : sl;
  signal l1q, l1aq : sl;
  signal trigArmS  : sl;
  
  constant APPLY_SHIFT_C : boolean := false;
  constant NAXIL_C    : integer := NFMC_G;
  
  signal mAxilReadMasters  : AxiLiteReadMasterArray (NAXIL_C-1 downto 0);
  signal mAxilReadSlaves   : AxiLiteReadSlaveArray  (NAXIL_C-1 downto 0);
  signal mAxilWriteMasters : AxiLiteWriteMasterArray(NAXIL_C-1 downto 0);
  signal mAxilWriteSlaves  : AxiLiteWriteSlaveArray (NAXIL_C-1 downto 0);

  constant AXIL_XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NAXIL_C-1 downto 0) := genAxiLiteConfig(NAXIL_C, BASE_ADDR_C, 15, 12);

  constant NSTREAMS_C : integer := FEX_ALGORITHMS(0)'length;
  constant NRAM_C     : integer := 4 * NFMC_G * NSTREAMS_C;
  signal bramWr    : BRamWriteMasterArray(NRAM_C-1 downto 0);
  signal bramRd    : BRamReadMasterArray (NRAM_C-1 downto 0);
  signal bRamSl    : BRamReadSlaveArray  (NRAM_C-1 downto 0);

  signal cacheStatus : CacheStatusArray(NFMC_G-1 downto 0);
  signal ilvstreams  : Slv4Array       (NFMC_G-1 downto 0);

begin  -- mapping

  status <= cacheStatus(0);
  
  dmaFullS  <= r.afull;
  dmaFullQ  <= (others=>'0');

  l1q       <= r.l1inacc(0) or r.l1inrej(0);
  l1aq      <= r.l1inacc(0);
  
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
               
  process ( eventClk ) is
  begin
    if rising_edge(eventClk) then
      l1inacc <= l1in and l1ina;
      l1inrej <= l1in and not l1ina;
    end if;
  end process;

  U_L1INACC : entity work.SynchronizerOneShot
    port map ( clk     => dmaClk,
               dataIn  => l1inacc,
               dataOut => sl1inacc );

  U_L1INREJ : entity work.SynchronizerOneShot
    port map ( clk      => dmaClk,
               dataIn   => l1inrej,
               dataOut  => sl1inrej );

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
          adcs(i)(j)(k) <= '0'; -- suppress warnings
          iadc(i)(k)(j) <= adc(i).data(k)(j);
        end generate GEN_NOSHIFT;
      end generate GEN_IADC;
    end generate GEN_BIT;

  end generate;
    
--      This is the large buffer.
  GEN_RAM : for i in 0 to NFMC_G-1 generate
    GEN_FMC : for j in 0 to NSTREAMS_C-1 generate
      GEN_CHAN : for k in 0 to 3 generate
        U_RAM : entity work.SimpleDualPortRam
          generic map ( DATA_WIDTH_G => 16*ROW_SIZE,   -- 64*ROW_SIZE? or 4x RAMs
                        ADDR_WIDTH_G => RAM_ADDR_WIDTH_C )
          port map ( clka   => dmaClk,
                     ena    => '1',
                     wea    => bramWr(k+4*j+4*NSTREAMS_C*i).en,
                     addra  => bramWr(k+4*j+4*NSTREAMS_C*i).addr,
                     dina   => bramWr(k+4*j+4*NSTREAMS_C*i).data,
                     clkb   => dmaClk,
                     enb    => bramRd(k+4*j+4*NSTREAMS_C*i).en,
                     rstb   => dmaRst,
                     addrb  => bramRd(k+4*j+4*NSTREAMS_C*i).addr,
                     doutb  => bramSl(k+4*j+4*NSTREAMS_C*i).data );
      end generate;
    end generate;
  end generate;

  GEN_FMC : for i in 0 to NFMC_G-1 generate

    U_PllSyncF : entity work.FifoSync
      generic map ( ADDR_WIDTH_G => 5,
                    DATA_WIDTH_G => 3,
                    FWFT_EN_G    => true )
      port map ( rst    => rstFifo,
                 clk    => dmaClk,
                 wr_en  => r.start,
                 din    => r.adcShift,
                 rd_en  => hdrRd   (0),
                 dout   => pllSync (i),
                 valid  => pllSyncV(i) );

    eventHdr     (i) <= toSlv(0,29) & pllSync(i) &
                        toSlv(0,7) & configA.enable(4*i) & toSlv(0,6) &
                        configA.samples(17 downto 4) & x"0" &
                        eventHeader(i);
    
    hdrValid     (i) <= eventHeaderV(i) and (pllSyncV(i) or noPayload(i));
    eventHeaderRd(i) <= hdrRd(i);

  
    U_INTLV : entity work.QuadAdcInterleave
      generic map ( BASE_ADDR_C    => AXIL_XBAR_CONFIG_C(i).baseAddr,
                    AXIS_SIZE_G    => 1,
                    AXIS_CONFIG_G  => CHN_AXIS_CONFIG_C,
                    IFMC_G         => i,
                    ALGORITHM_G    => FEX_ALGORITHMS(i) )
      port map ( clk             => dmaClk,
                 rst             => dmaRst,
                 clear           => r.clear,
                 start           => r.start,
                 shift           => r.adcShift,
                 din0            => iadc(0+i*4),
                 din1            => iadc(2+i*4),
                 din2            => iadc(1+i*4),
                 din3            => iadc(3+i*4),
                 l1in            => l1q,
                 l1ina           => l1aq,
                 l1a             => open,
                 l1v             => open,
                 --  Unique to Interleave?
                 --config          => configA,
                 --pllSync         => pllSync(i*4),
                 --hdr             => eventHeader,
                 --hdrV            => hdrValid,
                 --msgV            => eventMsgV,
                 --hdrRd           => hdrRd(i),
                 --
                 almost_full     => ilvafull      (i),
                 full            => ilvfull       (i),
                 status          => cacheStatus   (i),
                 axisMaster      => ilvmasters    (i),
                 axisSlave       => ilvslaves     (i),
                 -- BRAM Interface (dmaClk domain)
                 bramWriteMaster => bramWr((i+1)*4*NSTREAMS_C-1 downto i*4*NSTREAMS_C),
                 bramReadMaster  => bramRd((i+1)*4*NSTREAMS_C-1 downto i*4*NSTREAMS_C),
                 bramReadSlave   => bramSl((i+1)*4*NSTREAMS_C-1 downto i*4*NSTREAMS_C),
                 -- AXI-Lite Interface
                 axilClk         => axilClk,
                 axilRst         => axilRst,
                 axilReadMaster  => mAxilReadMasters (i),
                 axilReadSlave   => mAxilReadSlaves  (i),
                 axilWriteMaster => mAxilWriteMasters(i),
                 axilWriteSlave  => mAxilWriteSlaves (i),
                 streams         => ilvstreams       (i) );

    U_DATA : entity work.QuadAdcChannelData
      generic map ( SAXIS_CONFIG_G => CHN_AXIS_CONFIG_C,
                    MAXIS_CONFIG_G => DMA_STREAM_CONFIG_G )
      port map ( dmaClk      => dmaClk,
                 dmaRst      => dmaRst,
                 --
                 eventHdrV   => hdrValid (i),
                 eventHdr    => eventHdr (i),
                 noPayload   => noPayload(i),
                 eventHdrRd  => hdrRd    (i),
                 --
                 eventTrig(31 downto 24) => r.trig(3),
                 eventTrig(23 downto 16) => r.trig(2),
                 eventTrig(15 downto  8) => r.trig(1),
                 eventTrig( 7 downto  0) => r.trig(0),
                 chnMaster   => ilvmasters(i),
                 chnSlave    => ilvslaves (i),
                 dmaMaster   => dmaMaster(i),
                 dmaSlave    => dmaSlave (i) );

  end generate;

  process (r, dmaRst, dmaFullThr, trigArmS, trigIn, ilvfull, ilvafull, configA,
           sl1inacc, sl1inrej) is
    variable v   : RegType;
  begin  -- process
    v := r;

    v.trigd1  := trigIn(0);
--    v.trigd2  := (r.trigd1 and configA.trigShift) or (trigIn(0) and not configA.trigShift);
    v.trigd2  := r.trigd1;

    v.full         := uOr(ilvfull);
    v.afull        := uOr(ilvafull);

    v.l1inacc := sl1inacc & r.l1inacc(r.l1inacc'left downto 1);
    v.l1inrej := sl1inrej & r.l1inrej(r.l1inrej'left downto 1);
    
    if r.trigCnt/="11" then
      v.trig    := r.trigd2 & r.trig(r.trig'left downto 1);
      v.trigCnt := r.trigCnt+1;
    end if;

    v.clear := not configA.acqEnable;
    
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

end mapping;
