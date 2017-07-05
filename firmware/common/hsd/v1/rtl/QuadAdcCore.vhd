-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrQuadAdcCore.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2017-06-26
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
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
use work.EvrV2Pkg.all;
use work.SsiPkg.all;
use work.QuadAdcPkg.all;

entity QuadAdcCore is
  generic (
    TPD_G       : time    := 1 ns;
    LCLSII_G    : boolean := TRUE;
    NFMC_G      : integer := 1;
    SYNC_BITS_G : integer := 4;
    BASE_ADDR_C : slv(31 downto 0) := (others=>'0') );
  port (
    -- AXI-Lite and IRQ Interface
    axiClk              : in  sl;
    axiRst              : in  sl;
    axilWriteMasters    : in  AxiLiteWriteMasterArray(1 downto 0);
    axilWriteSlaves     : out AxiLiteWriteSlaveArray (1 downto 0);
    axilReadMasters     : in  AxiLiteReadMasterArray (1 downto 0);
    axilReadSlaves      : out AxiLiteReadSlaveArray  (1 downto 0);
    -- DMA
    dmaClk              : in  sl;
    dmaRst              : out sl;
    dmaRxIbMaster       : out AxiStreamMasterType;
    dmaRxIbSlave        : in  AxiStreamSlaveType;
    -- EVR Ports
    evrClk              : in  sl;
    evrRst              : in  sl;
    evrBus              : in  TimingBusType;
    exptBus             : in  ExptBusType;
    ready               : out sl;
    -- ADC
    gbClk               : in  sl;
    adcClk              : in  sl;
    adcRst              : in  sl;
    adc                 : in  AdcDataArray(4*NFMC_G-1 downto 0);
    --
    trigSlot            : out sl;
    trigOut             : out sl;
    trigIn              : in  Slv8Array(SYNC_BITS_G-1 downto 0);
    adcSyncRst          : out sl;
    adcSyncLocked       : in  sl );
end QuadAdcCore;

architecture mapping of QuadAdcCore is

  constant FIFO_ADDR_WIDTH_C : integer := 14;

  signal config              : QuadAdcConfigType;
  signal configE             : QuadAdcConfigType; -- evrClk domain
  signal configA             : QuadAdcConfigType; -- adcClk domain
  signal vConfig, vConfigE, vConfigA   : slv(QADC_CONFIG_TYPE_LEN_C-1 downto 0);
  
  signal oneHz               : sl;
  signal dmaHistEna          : sl;
  signal dmaHistEnaS         : sl;
  signal dmaHistDump         : sl;
  signal dmaHistDumpS        : sl;
  signal eventId             : slv(95 downto 0);
  
  signal eventSel            : sl;
  signal eventSelQ           : sl;
  signal eventCount          : SlVectorArray(1 downto 0,31 downto 0);
  signal rstCount            : sl;

  signal dmaCtrlC            : slv(31 downto 0);
  signal dmaCtrlCount        : slv(31 downto 0);
  
  signal intRxIbMasters      : AxiStreamMasterArray(1 downto 0);
  signal intRxIbSlaves       : AxiStreamSlaveArray (1 downto 0);
  
  signal histMaster          : AxiStreamMasterType;
  signal histSlave           : AxiStreamSlaveType;
  
  signal irqRequest          : sl;

  signal partitionAddr       : slv(PADDR_LEN-1 downto 0);
  signal dmaFifoDepth        : slv( 9 downto 0);

  signal dmaFullThr, dmaFullThrS : slv(23 downto 0) := (others=>'0');
  signal dmaFullQ            : slv(FIFO_ADDR_WIDTH_C-1 downto 0);
  signal dmaFullS            : sl;
  signal dmaFullQS           : slv(31 downto 0) := (others=>'0');
  signal iready              : sl;

  signal adcQ, adc_test      : AdcDataArray(4*NFMC_G-1 downto 0);
  signal adcSyncReg          : slv(31 downto 0);
  signal idmaRst             : sl;
  signal dmaRstS             : sl;
  signal dmaStrobe           : sl;

  constant HIST_STREAM_CONFIG_C : AxiStreamConfigType := (
    TSTRB_EN_C    => false,
    TDATA_BYTES_C => 4,
    TDEST_BITS_C  => 0,
    TID_BITS_C    => 0,
    TKEEP_MODE_C  => TKEEP_NORMAL_C,
    TUSER_BITS_C  => 0,
    TUSER_MODE_C  => TUSER_NONE_C );

  constant DMA_STREAM_CONFIG_C : AxiStreamConfigType := (
    TSTRB_EN_C    => false,
    TDATA_BYTES_C => 32,
    TDEST_BITS_C  => 0,
    TID_BITS_C    => 0,
    TKEEP_MODE_C  => TKEEP_NORMAL_C,
    TUSER_BITS_C  => 0,
    TUSER_MODE_C  => TUSER_NONE_C );

  constant HIST_DMA : boolean := false;
  
begin 

  ready   <= iready;
  iready  <= not dmaFullS;
  dmaRst  <= idmaRst;
  
  eventSelQ <= eventSel and (iready or not configE.inhibit);

  axilWriteSlaves(1) <= AXI_LITE_WRITE_SLAVE_INIT_C;
  axilReadSlaves (1) <= AXI_LITE_READ_SLAVE_INIT_C;
  
  GEN_EV1 : if not LCLSII_G generate
    U_EventSel : entity work.QuadAdcEventV1Select
      port map ( evrClk     => evrClk,
                 evrRst     => evrRst,
                 enabled    => configE.acqEnable,
                 eventCode  => configE.rateSel(7 downto 0),
                 delay      => configE.offset,
                 evrBus     => evrBus,
                 strobe     => trigSlot,
                 oneHz      => open,
                 eventSel   => eventSel,
                 eventId    => eventId );
    dmaHistDump <= '0';
  end generate GEN_EV1;

  GEN_EV2 : if LCLSII_G generate
    U_EventSel : entity work.QuadAdcEventV2Select
      port map ( evrClk     => evrClk,
                 evrRst     => evrRst,
                 config     => configE,
                 evrBus     => evrBus,
                 exptBus    => exptBus,
                 strobe     => trigSlot,
                 oneHz      => oneHz,
                 eventSel   => eventSel,
                 eventId    => eventId );

    dmaHistDump <= oneHz and dmaHistEnaS;

    Sync_dmaHistDump : entity work.SynchronizerOneShot
      port map ( clk     => dmaClk,
                 dataIn  => dmaHistDump,
                 dataOut => dmaHistDumpS );
  end generate GEN_EV2;

  adcQ <= adc_test when configA.dmaTest='1' else
          adc;
  
  GEN_TP : for i in 0 to 4*NFMC_G-1 generate
    U_DATA : entity work.QuadAdcChannelTestPattern
      generic map ( CHANNEL_C => i )
      port map ( clk   => adcClk,
                 rst   => eventSelQ,
                 data  => adc_test(i).data );
  end generate;

  U_EventDma : entity work.QuadAdcEvent
    generic map ( TPD_G             => TPD_G,
                  FIFO_ADDR_WIDTH_C => FIFO_ADDR_WIDTH_C,
                  NFMC_G            => NFMC_G,
                  SYNC_BITS_G       => SYNC_BITS_G )
    port map (    eventClk   => evrClk,
                  eventRst   => evrRst,
                  configE    => configE,
                  strobe     => eventSelQ,
                  eventId    => eventId,
                  --
                  adcClk     => adcClk,
                  adcRst     => adcRst,
                  configA    => configA,
                  adc        => adcQ,
                  trigArm    => eventSelQ,
                  trigIn     => trigIn,
                  dmaClk     => dmaClk,
                  dmaRst     => dmaRstS,
                  dmaFullThr => dmaFullThrS(FIFO_ADDR_WIDTH_C-1 downto 0),
                  dmaFullS   => dmaFullS,
                  dmaFullQ   => dmaFullQ,
                  dmaMaster  => intRxIbMasters(0),
                  dmaSlave   => intRxIbSlaves (0) );

  GEN_HIST_DMA : if HIST_DMA generate
    U_FifoDepthH : entity work.HistogramDma
      generic map ( TPD_G             => TPD_G,
                    INPUT_DEPTH_G     => FIFO_ADDR_WIDTH_C,
                    OUTPUT_DEPTH_G    => 6 )
      port map ( clk      => dmaClk,
                 rst      => idmaRst,
                 valid    => dmaStrobe,
                 push     => dmaHistDumpS,
                 data     => dmaFullQ,
                 master   => histMaster,
                 slave    => histSlave );

    U_FIFO : entity work.AxiStreamFifoV2
      generic map ( FIFO_ADDR_WIDTH_G   => 4,
                    GEN_SYNC_FIFO_G     => true,
                    SLAVE_AXI_CONFIG_G  => HIST_STREAM_CONFIG_C,
                    MASTER_AXI_CONFIG_G => DMA_STREAM_CONFIG_C )
      port map ( sAxisClk    => dmaClk,
                 sAxisRst    => idmaRst,
                 sAxisMaster => histMaster,
                 sAxisSlave  => histSlave,
                 mAxisClk    => dmaClk,
                 mAxisRst    => idmaRst,
                 mAxisMaster => intRxIbMasters(1),
                 mAxisSlave  => intRxIbSlaves (1) );
    
    U_StreamMux : entity work.AxiStreamMux
      generic map ( NUM_SLAVES_G => 2 )
      port map ( sAxisMasters => intRxIbMasters,
                 sAxisSlaves  => intRxIbSlaves,
                 mAxisMaster  => dmaRxIbMaster,
                 mAxisSlave   => dmaRxIbSlave,
                 axisClk      => dmaClk,
                 axisRst      => idmaRst );
  end generate;

  NOGEN_HIST_DMA : if not HIST_DMA generate
    dmaRxIbMaster <= intRxIbMasters(0);
    intRxIbSlaves(0) <= dmaRxIbSlave;
  end generate;
    
  Sync_EvtCount : entity work.SyncStatusVector
    generic map ( TPD_G   => TPD_G,
                  WIDTH_G => 2 )
    port map    ( statusIn(1)  => evrBus.strobe,
                  statusIn(0)  => eventSel,
                  cntRstIn     => rstCount,
                  rollOverEnIn => (others=>'1'),
                  cntOut       => eventCount,
                  wrClk        => evrClk,
                  wrRst        => '0',
                  rdClk        => axiClk,
                  rdRst        => axiRst );

  U_DSReg : entity work.DSReg
    generic map ( TPD_G               => TPD_G )
    port map (    axiClk              => axiClk,
                  axiRst              => axiRst,
                  axilWriteMaster     => axilWriteMasters(0),
                  axilWriteSlave      => axilWriteSlaves (0),
                  axilReadMaster      => axilReadMasters (0),
                  axilReadSlave       => axilReadSlaves  (0),
                  -- configuration
                  irqEnable           => open      ,
                  config              => config    ,
                  dmaFullThr          => dmaFullThr,
                  dmaHistEna          => dmaHistEna,
                  adcSyncRst          => adcSyncRst,
                  dmaRst              => idmaRst   ,
                  -- status
                  irqReq              => irqRequest   ,
                  partitionAddr       => partitionAddr,
                  rstCount            => rstCount     ,
                  eventCount          => eventCount   ,
                  dmaCtrlCount        => dmaCtrlCount ,
                  dmaFullQ            => dmaFullQS,
                  adcSyncReg          => adcSyncReg );

  -- Synchronize configurations to evrClk
  vConfig <= toSlv       (config);
  configE <= toQadcConfig(vConfigE);
  configA <= toQadcConfig(vConfigA);
  U_ConfigE : entity work.SynchronizerVector
    generic map ( WIDTH_G => QADC_CONFIG_TYPE_LEN_C )
    port map (    clk     => evrClk,
                  rst     => evrRst,
                  dataIn  => vConfig,
                  dataOut => vConfigE );
  U_ConfigA : entity work.SynchronizerVector
    generic map ( WIDTH_G => QADC_CONFIG_TYPE_LEN_C )
    port map (    clk     => adcClk,
                  rst     => adcRst,
                  dataIn  => vConfig,
                  dataOut => vConfigA );

  Sync_dmaFullThr : entity work.SynchronizerVector
    generic map ( TPD_G   => TPD_G,
                  WIDTH_G => 24 )
    port map (    clk     => dmaClk,
                  rst     => idmaRst,
                  dataIn  => dmaFullThr,
                  dataOut => dmaFullThrS );

  Sync_partAddr : entity work.SynchronizerVector
    generic map ( TPD_G   => TPD_G,
                  WIDTH_G => partitionAddr'length )
    port map  ( clk     => axiClk,
                dataIn  => exptBus.message.partitionAddr,
                dataOut => partitionAddr );
  
  Sync_dmaEnable : entity work.Synchronizer
    generic map ( TPD_G   => TPD_G )
    port map (    clk     => evrClk,
                  rst     => evrRst,
                  dataIn  => dmaHistEna,
                  dataOut => dmaHistEnaS );

  Sync_dmaFullQ : entity work.SynchronizerVector
    generic map ( TPD_G   => TPD_G,
                  WIDTH_G => dmaFullQ'length )
    port map  ( clk     => axiClk,
                dataIn  => dmaFullQ,
                dataOut => dmaFullQS(dmaFullQ'range) );
  
  seq: process (evrClk) is
  begin
    if rising_edge(evrClk) then
      trigOut <= eventSelQ ;
      if dmaFullS='1' then
        dmaCtrlC <= dmaCtrlC+1;
      end if;
    end if;
  end process seq;

  Sync_dmaCtrlCount : entity work.SynchronizerFifo
    generic map ( TPD_G        => TPD_G,
                  DATA_WIDTH_G => 32 )
    port map    ( wr_clk       => evrClk,
                  din          => dmaCtrlC,
                  rd_clk       => axiClk,
                  dout         => dmaCtrlCount );

  --
  --  Synchronize reset to timing strobe to fix phase for gearbox
  --
  Sync_dmaStrobe : entity work.SynchronizerOneShot
    port map ( clk     => dmaClk,
               dataIn  => evrBus.strobe,
               dataOut => dmaStrobe );

  Sync_dmaRst : process (idmaRst, dmaClk, dmaStrobe, adcSyncLocked) is
  begin
    adcSyncReg(31) <= adcSyncLocked;
    adcSyncReg(30 downto 0) <= (others=>'0');
    if idmaRst='1' then
      dmaRstS <= '1';
    elsif rising_edge(dmaClk) then
      if dmaStrobe='1' then
        dmaRstS <= '0';
      end if;
    end if;
  end process;
      
end mapping;
