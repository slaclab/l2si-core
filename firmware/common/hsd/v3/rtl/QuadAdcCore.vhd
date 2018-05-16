-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadAdcCore.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2018-04-28
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

library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.TimingPkg.all;
use work.XpmPkg.all;
use work.EventPkg.all;
use work.SsiPkg.all;
use work.XpmPkg.all;
use work.QuadAdcPkg.all;

entity QuadAdcCore is
  generic (
    TPD_G       : time    := 1 ns;
    LCLSII_G    : boolean := TRUE; -- obsolete
    DMA_SIZE_G  : integer := 1;
    NFMC_G      : integer := 1;
    SYNC_BITS_G : integer := 4;
    DMA_STREAM_CONFIG_G : AxiStreamConfigType;
    BASE_ADDR_C : slv(31 downto 0) := (others=>'0') );
  port (
    -- AXI-Lite and IRQ Interface
    axiClk              : in  sl;
    axiRst              : in  sl;
    axilWriteMasters    : in  AxiLiteWriteMasterArray(2 downto 0);
    axilWriteSlaves     : out AxiLiteWriteSlaveArray (2 downto 0);
    axilReadMasters     : in  AxiLiteReadMasterArray (2 downto 0);
    axilReadSlaves      : out AxiLiteReadSlaveArray  (2 downto 0);
    -- DMA
    dmaClk              : in  sl;
    dmaRst              : out sl;
    dmaRxIbMaster       : out AxiStreamMasterArray(NFMC_G-1 downto 0);
    dmaRxIbSlave        : in  AxiStreamSlaveArray (NFMC_G-1 downto 0);
    -- EVR Ports
    evrClk              : in  sl;
    evrRst              : in  sl;
    evrBus              : in  TimingBusType;
    exptBus             : in  ExptBusType;
--    ready               : out sl;
    timingFbClk         : in  sl;
    timingFbRst         : in  sl;
    timingFb            : out TimingPhyType;
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

  type RegType is record
    axilWriteSlave : AxiLiteWriteSlaveType;
    axilReadSlave  : AxiLiteReadSlaveType;
  end record;

  constant REG_INIT_C : RegType := (
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C );

  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;

  constant FIFO_ADDR_WIDTH_C : integer := 14;
  constant NCHAN_C           : integer := 4*NFMC_G;
  
  signal config              : QuadAdcConfigType;
  signal configE             : QuadAdcConfigType; -- evrClk domain
  signal configA             : QuadAdcConfigType; -- adcClk domain
  signal vConfig, vConfigE, vConfigA   : slv(QADC_CONFIG_TYPE_LEN_C-1 downto 0);
  
  signal oneHz               : sl := '0';
  signal dmaHistEna          : sl;
  signal dmaHistEnaS         : sl;
  signal dmaHistDump         : sl;
  signal dmaHistDumpS        : sl;
--  signal eventId             : slv(191 downto 0);
  
  signal eventSel            : sl;
  signal eventSelQ           : sl;
  signal rstCount            : sl;

  signal dmaCtrlC            : slv(31 downto 0);
  
  signal histMaster          : AxiStreamMasterType;
  signal histSlave           : AxiStreamSlaveType;
  
  signal irqRequest          : sl;

  signal dmaFifoDepth        : slv( 9 downto 0);

  signal dmaFullThr, dmaFullThrS : slv(23 downto 0) := (others=>'0');
  signal dmaFullQ            : slv(FIFO_ADDR_WIDTH_C-1 downto 0);
  signal dmaFullS            : sl;
  signal dmaFullV            : slv(NPartitions-1 downto 0);
  signal iready              : sl;
  
  signal idmaRst             : sl;
  signal dmaRstI             : slv(2 downto 0);
  signal dmaRstS             : sl;
  signal dmaStrobe           : sl;

  signal l1in, l1ina         : sl;

  constant HIST_STREAM_CONFIG_C : AxiStreamConfigType := (
    TSTRB_EN_C    => false,
    TDATA_BYTES_C => 4,
    TDEST_BITS_C  => 0,
    TID_BITS_C    => 0,
    TKEEP_MODE_C  => TKEEP_NORMAL_C,
    TUSER_BITS_C  => 0,
    TUSER_MODE_C  => TUSER_NONE_C );

  signal adcSyncReg : slv(31 downto 0);
  
  signal timingHeader_prompt  : TimingHeaderType;
  signal timingHeader_aligned : TimingHeaderType;
  signal exptBus_aligned      : ExptBusType;


  signal trigData             : XpmPartitionDataArray(NFMC_G-1 downto 0);
  signal trigDataV            : slv             (NFMC_G-1 downto 0);
  signal eventHdr             : EventHeaderArray(NFMC_G-1 downto 0);
  signal eventHdrD            : Slv192Array     (NFMC_G-1 downto 0);
  signal eventHdrV            : slv             (NFMC_G-1 downto 0);
  signal eventHdrRd           : slv             (NFMC_G-1 downto 0);
  signal phdr                 : slv             (NFMC_G-1 downto 0);
  signal pmsg                 : slv             (NFMC_G-1 downto 0);
  signal rstFifo              : slv             (NFMC_G-1 downto 0);
  signal wrFifoCnt            : Slv4Array       (NFMC_G-1 downto 0);
  signal rdFifoCnt            : Slv4Array       (NFMC_G-1 downto 0);
  signal fbPllRst             : sl;
  signal fbPhyRst             : sl;
  
  signal status : QuadAdcStatusType;
  signal axisMaster : AxiStreamMasterArray(NFMC_G-1 downto 0);
  signal axisSlave  : AxiStreamSlaveArray (NFMC_G-1 downto 0);

begin  

  --ready   <= iready;
  iready  <= not dmaFullS;
  dmaRst  <= idmaRst;

  dmaRxIbMaster <= axisMaster;
  axisSlave     <= dmaRxIbSlave;
  
  U_TimingFb : entity work.XpmTimingFb
    generic map ( DEBUG_G => true )
    port map ( clk        => timingFbClk,
               rst        => timingFbRst,
               pllReset   => fbPllRst,
               phyReset   => fbPhyRst,
               l1input    => (others=>XPM_L1_INPUT_INIT_C),
               full       => dmaFullV,
               phy        => timingFb );

  eventSelQ <= eventSel and (iready or not configE.inhibit);

  timingHeader_prompt.strobe    <= evrBus.strobe;
  timingHeader_prompt.pulseId   <= evrBus.message.pulseId;
  timingHeader_prompt.timeStamp <= evrBus.message.timeStamp;
  U_Realign  : entity work.EventRealign
    port map ( rst           => evrRst,
               clk           => evrClk,
               timingI       => timingHeader_prompt,
               exptBusI      => exptBus,
               timingO       => timingHeader_aligned,
               exptBusO      => exptBus_aligned );
  
  dmaHistDump <= oneHz and dmaHistEnaS;

  Sync_dmaHistDump : entity work.SynchronizerOneShot
    port map ( clk     => dmaClk,
               dataIn  => dmaHistDump,
               dataOut => dmaHistDumpS );

  GEN_FMC : for i in 0 to NFMC_G-1 generate
    U_EventSel : entity work.EventHeaderCache
      port map ( rst            => evrRst,
                 wrclk          => evrClk,
                 enable         => configE.acqEnable,
                 partition      => configE.partition(2 downto 0),
                 timing_prompt  => timingHeader_prompt,
                 expt_prompt    => exptBus,
                 timing_aligned => timingHeader_aligned,
                 expt_aligned   => exptBus_aligned,
                 pdata          => trigData (i),
                 pdataV         => trigDataV(i),
                 cntWrFifo      => wrFifoCnt(i),
                 rstFifo        => rstFifo  (i),
                 --
                 rdclk          => dmaClk,
                 advance        => eventHdrRd(i),
                 valid          => eventHdrV (i),
                 pmsg           => pmsg      (i),
                 phdr           => phdr      (i),
                 cntRdFifo      => rdFifoCnt (i),
                 hdrOut         => eventHdr  (i));

    eventHdrD(i)    <= toSlv(eventHdr(i));
  end generate;
  
  trigSlot     <= trigDataV(0);
  eventSel     <= trigData (0).l0a and trigDataV(0);
  l1in         <= trigData (0).l1e and trigDataV(0);
--  l1ina        <= trigData (0).l1a;
  l1ina        <= '1';
  
  U_EventDma : entity work.QuadAdcEvent
    generic map ( TPD_G               => TPD_G,
                  FIFO_ADDR_WIDTH_C   => FIFO_ADDR_WIDTH_C,
                  NFMC_G              => NFMC_G,
                  SYNC_BITS_G         => SYNC_BITS_G,
                  DMA_STREAM_CONFIG_G => DMA_STREAM_CONFIG_G,
                  BASE_ADDR_C         => BASE_ADDR_C )
    port map (    axilClk         => axiClk,
                  axilRst         => axiRst,
                  axilReadMaster  => axilReadMasters (1),
                  axilReadSlave   => axilReadSlaves  (1),
                  axilWriteMaster => axilWriteMasters(1),
                  axilWriteSlave  => axilWriteSlaves (1),
                  --
                  eventClk   => evrClk,
                  trigArm    => eventSelQ,
                  l1in       => l1in,
                  l1ina      => l1ina,
                  --
                  adcClk     => adcClk,
                  adcRst     => adcRst,
                  configA    => configA,
                  adc        => adc,
                  trigIn     => trigIn,
                  --
                  dmaClk     => dmaClk,
                  dmaRst     => dmaRstS,
                  eventHeader   => eventHdrD,
                  eventHeaderV  => eventHdrV,
                  noPayload     => pmsg,
                  eventHeaderRd => eventHdrRd,
                  rstFifo    => rstFifo(0),
                  dmaFullThr => dmaFullThrS(FIFO_ADDR_WIDTH_C-1 downto 0),
                  dmaFullS   => dmaFullS,
                  dmaFullQ   => dmaFullQ,
                  dmaMaster  => axisMaster,
                  dmaSlave   => axisSlave ,
                  status     => status.eventCache );

  Sync_EvtCount : entity work.SyncStatusVector
    generic map ( TPD_G   => TPD_G,
                  WIDTH_G => 2 )
    port map    ( statusIn(1)  => evrBus.strobe,
                  statusIn(0)  => eventSel,
                  cntRstIn     => rstCount,
                  rollOverEnIn => (others=>'1'),
                  cntOut       => status.eventCount,
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
                  fbRst               => fbPhyRst  ,
                  fbPLLRst            => fbPllRst  ,
                  -- status
                  irqReq              => irqRequest   ,
                  rstCount            => rstCount     ,
                  dmaClk              => dmaClk,
                  status              => status );

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
                  WIDTH_G => status.partitionAddr'length )
    port map  ( clk     => axiClk,
                dataIn  => exptBus.message.partitionAddr,
                dataOut => status.partitionAddr );
  
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
                dataOut => status.dmaFullQ(dmaFullQ'range) );
  
  seq: process (evrClk) is
  begin
    if rising_edge(evrClk) then
      trigOut <= eventSelQ ;
      if dmaFullS='1' then
        dmaCtrlC <= dmaCtrlC+1;
      end if;
      dmaFullV <= (others=>'0');
      dmaFullV(conv_integer(configE.partition)) <= dmaFullS;
    end if;
  end process seq;

  Sync_dmaCtrlCount : entity work.SynchronizerFifo
    generic map ( TPD_G        => TPD_G,
                  DATA_WIDTH_G => 32 )
    port map    ( wr_clk       => evrClk,
                  din          => dmaCtrlC,
                  rd_clk       => axiClk,
                  dout         => status.dmaCtrlCount );

  --
  --  Synchronize reset to timing strobe to fix phase for gearbox
  --
  Sync_dmaStrobe : entity work.SynchronizerOneShot
    port map ( clk     => dmaClk,
               dataIn  => evrBus.strobe,
               dataOut => dmaStrobe );

  Sync_dmaRst : process ( dmaClk, adcSyncLocked) is
    variable v : slv(dmaRstI'range);
  begin
    adcSyncReg(31) <= adcSyncLocked;
    adcSyncReg(30 downto 0) <= (others=>'0');
    if rising_edge(dmaClk) then
      dmaRstI <= dmaRstI(dmaRstI'left-1 downto 0) & dmaRstI(0);
      if idmaRst='1' then
        dmaRstI(0) <= '1';
      elsif dmaStrobe='1' then
        dmaRstI(0) <= '0';
      end if;
    end if;
  end process;

  U_DMARST : BUFG
    port map ( O => dmaRstS,
               I => dmaRstI(2) );

  Sync_adcSyncReg : entity work.SynchronizerVector
    generic map ( WIDTH_G => 32 )
    port map ( clk     => axiClk,
               dataIn  => adcSyncReg,
               dataOut => status.adcSyncReg );

  comb : process ( axiRst, r, wrFifoCnt, rdFifoCnt,
                   axilWriteMasters(2), axilReadMasters(2) ) is
    variable v  : RegType;
    variable ep : AxiLiteEndPointType;
  begin
    v := r;

    axiSlaveWaitTxn( ep,
                     axilWriteMasters(2), axilReadMasters(2),
                     v.axilWriteSlave, v.axilReadSlave );

    for i in 0 to NFMC_G-1 loop
      axiSlaveRegisterR ( ep, toSlv(i*8+0,8), 0, wrFifoCnt(i) );
      axiSlaveRegisterR ( ep, toSlv(i*8+4,8), 0, rdFifoCnt(i) );
    end loop;

    axiSlaveDefault( ep, v.axilWriteSlave, v.axilReadSlave );

    axilWriteSlaves(2) <= r.axilWriteSlave;
    axilReadSlaves (2) <= r.axilReadSlave;
    
    if axiRst = '1' then
      v := REG_INIT_C;
    end if;

    r_in <= v;
  end process comb;

  aseq : process ( axiClk ) is
  begin
    if rising_edge(axiClk) then
      r <= r_in;
    end if;
  end process aseq;
  
end mapping;
