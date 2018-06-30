-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadAdcEvent.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2018-06-27
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
    dmaFullCnt    : out slv(31 downto 0);
    status        : out CacheArray(MAX_OVL_C-1 downto 0);
    debug         : out Slv8Array           (NFMC_G-1 downto 0);
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

  signal afull  : sl;
  signal afullCnt  : slv(31 downto 0);
  signal ql1in  : sl;
  signal ql1ina : sl;
  signal shift  : slv(2 downto 0);
  signal clear  : sl;
  signal start  : sl;
  signal trig   : Slv8Array(1 downto 0);

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
  
  signal pllSync   : Slv32Array (NFMC_G-1 downto 0);
  signal pllSyncV  : slv        (NFMC_G-1 downto 0);
  signal eventHdr  : Slv256Array(NFMC_G-1 downto 0);

  signal l1inacc, sl1inacc : sl;
  signal l1inrej, sl1inrej : sl;
  signal sl1in, sl1ina : sl;
  
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

  status     <= cacheStatus(0);
  dmaFullS   <= afull;
  dmaFullCnt <= afullCnt;

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

  sl1in  <= sl1inacc or sl1inrej;
  sl1ina <= sl1inacc; 

  GEN_CH : for i in 0 to NCHAN_C-1 generate
    GEN_BIT : for j in 0 to 10 generate
      GEN_IADC : for k in 0 to 7 generate
        adcs(i)(j)(k) <= '0'; -- suppress warnings
        iadc(i)(k)(j) <= adc(i).data(k)(j);
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

    eventHdr     (i) <= pllSync(i) &
                        toSlv(1,8) & ilvstreams(i) &
                        configA.samples(17 downto 4) & toSlv(0,6) &
                        eventHeader(i);
    
    hdrValid     (i) <= eventHeaderV(i) and (pllSyncV(i) or noPayload(i));
    eventHeaderRd(i) <= hdrRd(i);

    U_PllSyncF : entity work.FifoSync
      generic map ( ADDR_WIDTH_G => 4,
                    DATA_WIDTH_G => 32,
                    FWFT_EN_G    => true )
      port map ( rst    => rstFifo,
                 clk    => dmaClk,
                 wr_en  => start,
                 din(31 downto 24) => trig(1),
                 din(23 downto 16) => trig(0),
                 din(15 downto  3) => (others=>'0'),
                 din( 2 downto  0) => shift,
                 rd_en  => hdrRd   (i),
                 dout   => pllSync (i),
                 valid  => pllSyncV(i) );

    U_INTLV : entity work.QuadAdcInterleave
      generic map ( BASE_ADDR_C    => AXIL_XBAR_CONFIG_C(i).baseAddr,
                    AXIS_CONFIG_G  => CHN_AXIS_CONFIG_C,
                    IFMC_G         => i,
                    ALGORITHM_G    => FEX_ALGORITHMS(i) )
      port map ( clk             => dmaClk,
                 rst             => dmaRst,
                 clear           => clear,
                 start           => start,
                 shift           => shift,
                 din0            => iadc(0+i*4),
                 din1            => iadc(2+i*4),
                 din2            => iadc(1+i*4),
                 din3            => iadc(3+i*4),
                 l1in            => ql1in,
                 l1ina           => ql1ina,
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
                 debug           => debug         (i),
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
                 chnMaster   => ilvmasters(i),
                 chnSlave    => ilvslaves (i),
                 dmaMaster   => dmaMaster(i),
                 dmaSlave    => dmaSlave (i) );

  end generate;
  
  U_Trigger : entity work.QuadAdcTrigger
    port map ( clk       => dmaClk,
               rst       => dmaRst,
               trigIn    => trigIn(0),  
               afullIn   => ilvafull,
               config    => configA,
               l1in      => sl1in,
               l1ina     => sl1ina,
               --
               afullOut  => afull,
               afullCnt  => afullCnt,
               ql1in     => ql1in,
               ql1ina    => ql1ina,
               shift     => shift,
               clear     => clear,
               start     => start,
               trig      => trig );


end mapping;
