-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadAdcEvent.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2018-01-05
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-- Independent channel setup.  Simplified to make reasonable interface
-- for feature extraction algorithms.
-- BRAM interface factored out.
-- Many generics...
--   DMA_SIZE_G : 1 (PCIe DMA one FMC)
--                2 (PCIe DMA two FMC)
--                4 (PGP one FMC)
--                8 (PGP one FMC) (Only if ADC in secondary FMC)
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
    DMA_SIZE_G        : integer := 1;
    BASE_ADDR_C       : slv(31 downto 0) := (others=>'0') );
  port (
    axilClk         :  in sl;
    axilRst         :  in sl;
    axilReadMaster  :  in AxiLiteReadMasterType;
    axilReadSlave   : out AxiLiteReadSlaveType;
    axilWriteMaster :  in AxiLiteWriteMasterType;
    axilWriteSlave  : out AxiLiteWriteSlaveType;
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
    eventHeader   :  in slv(191 downto 0);
    eventTrgV     :  in sl;
    eventMsgV     :  in sl;
    eventHeaderRd : out sl;
    rstFifo       :  in sl;
    dmaFullThr    :  in slv(FIFO_ADDR_WIDTH_C-1 downto 0);
    dmaFullS      : out sl;
    dmaFullQ      : out slv(FIFO_ADDR_WIDTH_C-1 downto 0);
    status        : out CacheArray(MAX_OVL_C-1 downto 0);
    dmaMaster     : out AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
    dmaSlave      : in  AxiStreamSlaveArray (DMA_SIZE_G-1 downto 0) );
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
    iaxis    : integer range 0 to DMA_SIZE_G-1;
    clear    : sl;
    start    : sl;
    l1in     : slv(4 downto 0);
    l1ina    : slv(3 downto 0);
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
    iaxis     => 0,
    clear     => '1',
    start     => '0',
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

--  constant CHN_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(16);
  constant CHN_AXIS_CONFIG_C : AxiStreamConfigType := ILV_AXIS_CONFIG_C;
  constant AXIS_SIZE_C : integer := ite(DMA_SIZE_G > NFMC_G, DMA_SIZE_G, 1);
  
  -- interleave payload
  signal ilvmasters  : AxiStreamMasterArray(DMA_SIZE_G-1 downto 0) := (others=>AXI_STREAM_MASTER_INIT_C);
  signal ilvslaves   : AxiStreamSlaveArray (DMA_SIZE_G-1 downto 0) := (others=>AXI_STREAM_SLAVE_INIT_C);

  signal ilvafull       : slv(NFMC_G-1 downto 0);
  signal ilvfull        : slv(NFMC_G-1 downto 0);
  signal ilvCacheStatus : CacheStatusArray (NFMC_G-1 downto 0);
  
  signal pllSync   : Slv3Array  (NCHAN_C-1 downto 0);
  signal pllSyncV  : slv        (NCHAN_C-1 downto 0);

  signal hdrRd     : slv(NFMC_G-1 downto 0);
  signal hdrValid  : sl;
  
  signal sl1in, sl1ina : sl;
  signal trigArmS  : sl;
  
  constant APPLY_SHIFT_C : boolean := false;
  constant NSTREAMS_C : integer := FEX_ALGORITHMS(0)'length;
  constant NAXIL_C    : integer := NFMC_G;
  
  signal mAxilReadMasters  : AxiLiteReadMasterArray (NAXIL_C-1 downto 0);
  signal mAxilReadSlaves   : AxiLiteReadSlaveArray  (NAXIL_C-1 downto 0);
  signal mAxilWriteMasters : AxiLiteWriteMasterArray(NAXIL_C-1 downto 0);
  signal mAxilWriteSlaves  : AxiLiteWriteSlaveArray (NAXIL_C-1 downto 0);

  function AxilCrossbarConfig  return AxiLiteCrossbarMasterConfigArray is
    variable ret : AxiLiteCrossbarMasterConfigArray(NAXIL_C-1 downto 0);
  begin
    for i in 0 to NFMC_G-1 loop
        ret(i) := (baseAddr => BASE_ADDR_C+toSlv(i*4096,32),
                   addrBits => 12,
                   connectivity => x"ffff");
    end loop;
    return ret;
  end function AxilCrossbarConfig;
  
  constant AXIL_XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NAXIL_C-1 downto 0) := AxilCrossbarConfig;

  signal bramWr    : BRamWriteMasterArray(4*NSTREAMS_C*NFMC_G-1 downto 0);
  signal bramRd    : BRamReadMasterArray (4*NSTREAMS_C*NFMC_G-1 downto 0);
  signal bRamSl    : BRamReadSlaveArray  (4*NSTREAMS_C*NFMC_G-1 downto 0);

  signal cacheStatus : CacheStatusArray(NFMC_G-1 downto 0);
  signal ilvstreams  : Slv4Array       (NFMC_G-1 downto 0);

begin  -- mapping

  assert (DMA_SIZE_G=1 or NFMC_G=1) report "Multi channel DMA only allowed for one FMC";
    
  status <= cacheStatus(0);
  
  dmaFullS  <= r.afull;
  dmaFullQ  <= (others=>'0');

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

  hdrValid      <= eventTrgV and pllSyncV(0);
  eventHeaderRd <= hdrRd(0);

  --
  --  Reformat the ADC data structure
  --
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

  --
  --  One mezzanine card allows either one axi stream (PCIe DMA) or many axi
  --  streams (PGP)
  --
  GEN_ONE_FMC : if NFMC_G = 1 generate
    mAxilWriteMasters(0) <= axilWriteMaster;
    axilWriteSlave       <= mAxilWriteSlaves(0);
    mAxilReadMasters (0) <= axilReadMaster;
    axilReadSlave        <= mAxilReadSlaves(0);
    
    U_INTLV : entity work.QuadAdcInterleave
      generic map ( BASE_ADDR_C     => AXIL_XBAR_CONFIG_C(0).baseAddr,
                    AXIS_SIZE_G     => AXIS_SIZE_C,
                    AXIS_CONFIG_G   => CHN_AXIS_CONFIG_C,
                    IFMC_G          => 0,
                    ALGORITHM_G     => FEX_ALGORITHMS(0) )
      port map ( clk             => dmaClk,
                 rst             => dmaRst,
                 clear           => r.clear,
                 start           => r.start,
                 shift           => r.adcShift,
                 din0            => iadc(0),
                 din1            => iadc(2),
                 din2            => iadc(1),
                 din3            => iadc(3),
                 l1in            => r.l1in (0),
                 l1ina           => r.l1ina(0),
                 l1a             => open,
                 l1v             => open,
                 config          => configA,
                 pllSync         => pllSync(0),
                 hdr             => eventHeader,
                 hdrV            => hdrValid,
                 msgV            => eventMsgV,
                 hdrRd           => hdrRd  (0),
                 almost_full     => ilvafull      (0),
                 full            => ilvfull       (0),
                 status          => ilvCacheStatus(0),
                 axisMaster      => dmaMaster,
                 axisSlave       => dmaSlave,
                 -- BRAM Interface (dmaClk domain)
                 bramWriteMaster => bramWr,
                 bramReadMaster  => bramRd,
                 bramReadSlave   => bramSl,
                 -- AXI-Lite Interface
                 axilClk         => axilClk,
                 axilRst         => axilRst,
                 axilReadMaster  => mAxilReadMasters (0),
                 axilReadSlave   => mAxilReadSlaves  (0),
                 axilWriteMaster => mAxilWriteMasters(0),
                 axilWriteSlave  => mAxilWriteSlaves (0),
                 streams         => ilvstreams       (0) );
  end generate GEN_ONE_FMC;

  --
  --  Two mezzanine cards allow only one axi stream (PCIe DMA)
  --
  GEN_TWO_FMC : if NFMC_G = 2 generate

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
               
    GEN_FMC : for i in 0 to NFMC_G-1 generate
      U_INTLV : entity work.QuadAdcInterleave
        generic map ( BASE_ADDR_C    => AXIL_XBAR_CONFIG_C(0).baseAddr,
                      AXIS_SIZE_G    => AXIS_SIZE_C,
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
                   l1in            => r.l1in (0),
                   l1ina           => r.l1ina(0),
                   l1a             => open,
                   l1v             => open,
                   config          => configA,
                   pllSync         => pllSync(i*4),
                   hdr             => eventHeader,
                   hdrV            => hdrValid,
                   msgV            => eventMsgV,
                   hdrRd           => hdrRd(i),
                   almost_full     => ilvafull      (i),
                   full            => ilvfull       (i),
                   status          => ilvCacheStatus(i),
                   axisMaster      => ilvmasters    (i downto i),
                   axisSlave       => ilvslaves     (i downto i),
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
    end generate;

    U_ILV_MUX : entity work.AxiStreamMux
      generic map ( NUM_SLAVES_G => NFMC_G )
      port map ( axisClk      => dmaClk,
                 axisRst      => dmaRst,
                 sAxisMasters => ilvmasters,
                 sAxisSlaves  => ilvslaves,
                 mAxisMaster  => dmaMaster(0),
                 mAxisSlave   => dmaSlave (0) );
  end generate;
  
  process (r, dmaRst, dmaFullThr, trigArmS, trigIn, ilvfull, ilvafull, configA,
           sl1in, sl1ina) is
    variable v   : RegType;
  begin  -- process
    v := r;

    v.trigd1  := trigIn(0);
--    v.trigd2  := (r.trigd1 and configA.trigShift) or (trigIn(0) and not configA.trigShift);
    v.trigd2  := r.trigd1;

    v.full         := uOr(ilvfull);
    v.afull        := uOr(ilvafull);

    v.l1in    := sl1in  & r.l1in (r.l1in 'left downto 1);
    v.l1ina   := sl1ina & r.l1ina(r.l1ina'left downto 1);
    
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
