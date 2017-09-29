-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DtiUsCore.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2017-09-29
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: DtiApp's Top Level
-- 
-- Note: Common-to-DtiApp interface defined here (see URL below)
--       https://confluence.slac.stanford.edu/x/rLyMCw
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 DAQ Software'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 DAQ Software', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.TimingPkg.all;
use work.XpmPkg.all;
use work.DtiPkg.all;
use work.ArbiterPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity DtiUsCore is
   generic (
      TPD_G               : time                := 1 ns;
      DEBUG_G             : boolean             := false );
   port (
     --  Core Interface
     sysClk          : in  sl;
     sysRst          : in  sl;
     clear           : in  sl := '0';
     update          : in  sl := '1';
     config          : in  DtiUsLinkConfigType;
     remLinkID       : in  slv(7 downto 0);
     status          : out DtiUsLinkStatusType;
     fullOut         : out slv(15 downto 0);
     --  Ethernet control interface
     --ctlClk          : in  sl;
     --ctlRst          : in  sl;
     --ctlRxMaster     : in  AxiStreamMasterType;
     --ctlRxSlave      : out AxiStreamSlaveType;
     --ctlTxMaster     : out AxiStreamMasterType;
     --ctlTxSlave      : in  AxiStreamSlaveType;
     --  Timing interface
     timingClk       : in  sl;
     timingRst       : in  sl;
     timingBus       : in  TimingBusType;
     exptBus         : in  ExptBusType;
     --  DSLinks interface
     eventClk        : in  sl;
     eventRst        : in  sl;
     eventMasters    : out AxiStreamMasterArray(MaxDsLinks-1 downto 0);
     eventSlaves     : in  AxiStreamSlaveArray (MaxDsLinks-1 downto 0);
     dsFull          : in  slv(MaxDsLinks-1 downto 0);
     --  App Interface
     --  In from detector
     ibClk           : out sl;
     ibLinkUp        : in  sl;
     ibErrs          : in  slv(31 downto 0) := (others=>'0');
     ibFull          : in  sl;
     ibMaster        : in  AxiStreamMasterType;
     ibSlave         : out AxiStreamSlaveType;
     --  Out to detector
     obClk           : out sl;
     obTrigValid     : out sl;
     obTrig          : out XpmPartitionDataType);
     --obMaster        : out AxiStreamMasterType;
     --obSlave         : in  AxiStreamSlaveType );
end DtiUsCore;

architecture rtl of DtiUsCore is

  constant MAX_BIT : integer := bitSize(MaxDsLinks)-1;

  type StateType is (S_IDLE, S_EVHDR1, S_EVHDR2, S_EVHDR3, S_EVHDR4, S_FIRST_PAYLOAD, S_PAYLOAD, S_DUMP);
  
  type RegType is record
    ena     : sl;
    state   : StateType;
    msg     : sl;
    dest    : slv(MAX_BIT downto 0);
    mask    : slv(MaxDsLinks-1 downto 0);
    ack     : slv(MaxDsLinks-1 downto 0);
    full    : slv(15 downto 0);
    hdrRd   : sl;
    master  : AxiStreamMasterType;
    slave   : AxiStreamSlaveType;
    rxFull  : slv(31 downto 0);
    rxFullO : slv(31 downto 0);
    ibRecv  : slv(47 downto 0);
    ibRecvO : slv(47 downto 0);
    ibEvt   : slv(31 downto 0);
    ibDump  : slv(31 downto 0);
  end record;
  
  constant REG_INIT_C : RegType := (
    ena     => '0',
    state   => S_IDLE,
    msg     => '0',
    dest    => toSlv(MaxDsLinks-1,MAX_BIT+1),
    mask    => (others=>'0'),
    ack     => (others=>'0'),
    full    => (others=>'0'),
    hdrRd   => '0',
    master  => AXI_STREAM_MASTER_INIT_C,
    slave   => AXI_STREAM_SLAVE_INIT_C,
    rxFull  => (others=>'0'),
    rxFullO => (others=>'0'),
    ibRecv  => (others=>'0'),
    ibRecvO => (others=>'0'),
    ibEvt   => (others=>'0'),
    ibDump  => (others=>'0') );
  
  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  type TRegType is record
    full    : Slv16Array(3 downto 0);
    ninh    : slv(31 downto 0);
  end record;

  constant TREG_INIT_C : TRegType := (
    full    => (others=>(others=>'0')),
    ninh    => (others=>'0') );

  signal t   : TRegType := TREG_INIT_C;
  signal tin : TRegType;

  signal eventTag : slv(4 downto 0);
  signal pmsg     : sl;
  signal pdata    : XpmPartitionDataType;
  signal pdataV   : sl;
  signal eventHeader : DtiEventHeaderType;
  
  signal configV, configSV, configTV : slv(DTI_US_LINK_CONFIG_BITS_C-1 downto 0);
  signal configS, configT : DtiUsLinkConfigType;

  signal ibEvtMaster  : AxiStreamMasterType;
  signal ibEvtSlave   : AxiStreamSlaveType;
  
  signal tMaster      : AxiStreamMasterType;
  signal tSlave       : AxiStreamSlaveType;

  signal urst    : sl;
  signal supdate : sl := '0';
  signal sclear  : sl;
  signal tclear  : sl;
  signal senable : sl;
  signal tfull   : slv(15 downto 0);

  component ila_0
    port ( clk    : sl;
           probe0 : slv(255 downto 0) );
  end component;

  signal r_state : slv(2 downto 0);
  
begin

  GEN_DEBUG : if DEBUG_G generate
    U_ILA : ila_0
      port map ( clk   => timingClk,
                 probe0(0) => timingBus.strobe,
                 probe0(1) => toPartitionWord(exptBus.message.partitionWord(0)).l0r,
                 probe0(17 downto 2) => tfull,
                 probe0(33 downto 18) => t.full(0),
                 probe0(49 downto 34) => t.full(1),
                 probe0(81 downto 50) => t.ninh,
                 probe0(129 downto 82) => exptBus.message.partitionWord(0),
                 probe0(255 downto 130) => (others=>'0') );
  end generate;
  
  obClk         <= timingClk;
  ibClk         <= eventClk;
  obTrig        <= pdata;
  obTrigValid   <= pdataV;
  fullOut       <= r.full;
  urst          <= clear and not r.ena;

  status.linkUp     <= ibLinkUp;
  status.remLinkID  <= remLinkID;
  status.rxErrs     <= ibErrs;
  status.rxFull     <= r.rxFull;
  status.ibRecv     <= r.ibRecv;
  status.ibEvt      <= r.ibEvt;
  status.ibDump     <= r.ibDump;
  status.rxInh      <= t.ninh;
  
  eventTag        <= ibMaster.tId(eventTag'range);
  
  U_Mux : entity work.DtiStreamDeMux
    generic map ( NUM_MASTERS_G  => MaxDsLinks,
                  TDEST_HIGH_G   => MAX_BIT,
                  TDEST_LOW_G    => 0 )
    port map ( sAxisMaster  => tMaster,
               sAxisSlave   => tSlave,
               sFlood       => r.msg,
               mAxisMasters => eventMasters,
               mAxisSlaves  => eventSlaves,
               axisClk      => eventClk,
               axisRst      => eventRst );

  U_HdrCache : entity work.DtiHeaderCache
    port map ( rst       => urst,
               wrclk     => timingClk,
               enable    => senable,
               timingBus => timingBus,
               exptBus   => exptBus,
               partition => config.partition(2 downto 0),
               l0delay   => config.trigDelay,
               pdata     => pdata,
               pdataV    => pdataV,
               cntL0     => status.obL0,
               cntL1A    => status.obL1A,
               cntL1R    => status.obL1R,
               cntWrFifo => status.wrFifoD,
               rdclk     => eventClk,
               entag     => config.tagEnable,
               l0tag     => eventTag,
               advance   => r.hdrRd,
               pmsg      => pmsg,
               cntRdFifo => status.rdFifoD,
               hdrOut    => eventHeader );

  configV <= toSlv(config);
  
  U_SyncConfig : entity work.SynchronizerVector
    generic map ( WIDTH_G => configV'length )
    port map ( clk     => eventClk,
               dataIn  => configV,
               dataOut => configSV );

  configS <= toUsLinkConfig(configSV);

  U_SyncConfigT : entity work.SynchronizerVector
    generic map ( WIDTH_G => configV'length )
    port map ( clk     => timingClk,
               dataIn  => configV,
               dataOut => configTV );

  configT <= toUsLinkConfig(configTV);

  U_ClearS : entity work.Synchronizer
    port map ( clk     => eventClk,
               dataIn  => clear,
               dataOut => sclear );
  
  U_ClearT : entity work.Synchronizer
    port map ( clk     => timingClk,
               dataIn  => clear,
               dataOut => tclear );
  
  U_FullT : entity work.SynchronizerVector
    generic map ( WIDTH_G => 16 )
    port map ( clk     => timingClk,
               dataIn  => r.full,
               dataOut => tfull );
  
  U_EnableS : entity work.Synchronizer
    port map ( clk     => timingClk,
               dataIn  => config.enable,
               dataOut => senable );
  
  --
  --  For event traffic:
  --    Arbitrate through forwarding mask
  --    Add event header
  --
  comb : process ( r, ibMaster, tSlave, configS, eventRst, sclear, supdate, eventHeader, dsfull, ibFull, pmsg, rin) is
    variable v : RegType;
    variable selv : sl;
    variable fwd  : slv(MAX_BIT downto 0);
    variable isFull : sl;
  begin
    v := r;

    v.slave.tReady := '0';
    v.ena  := configS.enable;
    v.hdrRd          := '0';
    
    arbitrate(r.mask, r.dest, fwd, selv, v.ack);

    if tSlave.tReady='1' then
      v.master.tValid := '0';
    end if;

    case r.state is
      when S_IDLE =>
        if v.master.tValid='0' then
          v.msg         := '0';
          if pmsg='1' then
            v.msg          := '1';
            v.state        := S_EVHDR1;
            v.ibEvt        := r.ibEvt+1;
          elsif ibMaster.tValid='1' then
            if selv = '0' then
              v.state        := S_DUMP;
              v.ibDump       := r.ibDump+1;
            else
              v.state        := S_EVHDR1;
              v.ibEvt        := r.ibEvt+1;
            end if;
          end if;
        end if;
      when S_EVHDR1 =>
        if v.master.tValid='0' then
          v.dest          := fwd;
          v.master.tValid := '1';
          v.master.tData(63 downto 0) := eventHeader.pulseId;
          v.master.tKeep  := genTKeep(US_IB_CONFIG_C);
          v.master.tLast  := '0';
          if r.msg = '1' then
            --  how to broadcast? - just unicast for now
            v.master.tDest  := resize(fwd,r.master.tDest'length);
            ssiSetUserSof(US_IB_CONFIG_C, v.master, '1');
          else
            v.master.tDest  := resize(fwd,r.master.tDest'length);
            v.master.tId    := ibMaster.tId;
            v.master.tUser  := ibMaster.tUser;  -- SOF sometimes goes here
          end if;
          v.state         := S_EVHDR2;
        end if;
      when S_EVHDR2 =>
        if v.master.tValid='0' then
          v.master.tValid := '1';
          v.master.tData(63 downto 0) := eventHeader.timeStamp;
          v.master.tUser  := (others=>'0');
          v.state         := S_EVHDR3;
        end if;
      when S_EVHDR3 =>
        if v.master.tValid='0' then
          v.master.tValid := '1';
          v.master.tData(63 downto 0) := eventHeader.evttag(47 downto 16) &
                                         toSlv(0,16) &
                                         eventHeader.evttag(15 downto 0);
          v.hdrRd         := not r.msg; -- Don't advance the fifo for messages
          v.state         := S_EVHDR4;
        end if;
      when S_EVHDR4 =>
        if v.master.tValid='0' then
          v.master.tValid := '1';
          v.master.tData(63 downto 0) := configS.dataSrc & configS.dataType;
          if r.msg = '1' then
            v.master.tLast := '1';
            ssiSetUserEofe(US_IB_CONFIG_C, v.master, '0');
            v.state       := S_IDLE;
          else
            v.state       := S_FIRST_PAYLOAD;
          end if;
        end if;
      when S_FIRST_PAYLOAD =>
        if v.master.tValid='0' and ibMaster.tValid='1' then
          -- preserve tDest
          v.slave.tReady  := '1';
          v.master        := ibMaster;
          v.master.tUser  := (others=>'0');  -- already in EVHDR1
          v.master.tDest  := r.master.tDest;
          v.state         := S_PAYLOAD;
          if ibMaster.tLast='1' then -- maybe missing EOFE
            v.state  := S_IDLE;
          end if;
        end if;
      when S_PAYLOAD =>
        if v.master.tValid='0' and ibMaster.tValid='1' then
          -- preserve tDest
          v.slave.tReady  := '1';
          v.master        := ibMaster;
          v.master.tDest  := r.master.tDest;
          if ibMaster.tLast='1' then
            v.state  := S_IDLE;
          end if;
        end if;
      when S_DUMP =>
        if ibMaster.tValid='1' then
          v.slave.tReady := '1';
          if ibMaster.tLast='1' then
            v.state  := S_IDLE;
          end if;
        end if;
      when others =>
        null;
    end case;

    v.full := (others=>'0');
    if configS.fwdMode = '0' then    -- Round robin mode
      v.mask := configS.fwdMask;
      isFull := dsFull(conv_integer(fwd)) or not selv;
    else                             -- Next not full
      v.mask := configS.fwdMask and not dsFull;
      isFull := not selv;
    end if;
    isFull := isFull or ibFull;
    
    if isFull='1' and r.ena='1' then
      v.full(conv_integer(configS.partition)) := isFull;
      v.rxFull  := r.rxFull+1;
    end if;

    if r.slave.tReady='1' and r.state/=S_IDLE then
      v.ibRecv := r.ibRecv+1;
    end if;

    if sclear = '1' then
      v.rxFull := (others=>'0');
      v.ibRecv := (others=>'0');
      v.ibEvt  := (others=>'0');
      v.ibDump := (others=>'0');
    end if;
    
    if eventRst = '1' then
      v := REG_INIT_C;
    end if;

    if supdate = '1' then
      v.rxFullO := r.rxFull;
      v.ibRecvO := r.ibRecv;
    end if;
    
    rin <= v;

    tMaster    <= r.master;
    ibSlave    <= rin.slave;
  end process;
  
  seq : process (eventClk) is
  begin
    if rising_edge(eventClk) then
      r <= rin;
    end if;
  end process;

  tcomb: process (t, timingRst, timingBus, tclear, tfull, configT, exptBus) is
    variable v : TRegType;
    variable ip : integer;
  begin
    v := t;

    ip := conv_integer(configT.partition);

    if timingBus.strobe = '1' then
      if (toPartitionWord(exptBus.message.partitionWord(ip)).l0r = '1' and
          t.full(t.full'left)(ip)='1') then
        v.ninh := t.ninh+1;
      end if;
      v.full := t.full(t.full'left-1 downto 0) & toSlv(0,16);
    else
      v.full(0) := t.full(0) or tfull;
    end if;
    
    if timingRst='1' then
      v := TREG_INIT_C;
    end if;
    
    tin <= v;
  end process;

  tseq : process (timingClk) is
  begin
    if rising_edge(timingClk) then
      t <= tin;
    end if;
  end process;
  
end rtl;
