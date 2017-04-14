-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DtiUsCore.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2017-04-12
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

entity DtiUsCore is
   generic (
      TPD_G               : time                := 1 ns );
   port (
     --  Core Interface
     sysClk          : in  sl;
     sysRst          : in  sl;
     clear           : in  sl := '0';
     update          : in  sl := '1';
     config          : in  DtiUsLinkConfigType;
     status          : out DtiUsLinkStatusType;
     fullOut         : out slv(15 downto 0);
     --  Ethernet control interface
     ctlClk          : in  sl;
     ctlRst          : in  sl;
     ctlRxMaster     : in  AxiStreamMasterType;
     ctlRxSlave      : out AxiStreamSlaveType;
     ctlTxMaster     : out AxiStreamMasterType;
     ctlTxSlave      : in  AxiStreamSlaveType;
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
     full            : in  slv(MaxDsLinks-1 downto 0);
     --  App Interface
     --  In from detector
     ibClk           : out sl;
     ibLinkUp        : in  sl;
     ibErrs          : in  slv(31 downto 0) := (others=>'0');
     ibMaster        : in  AxiStreamMasterType;
     ibSlave         : out AxiStreamSlaveType;
     --  Out to detector
     obClk           : out sl;
     obTrig          : out XpmPartitionDataType;
     obMaster        : out AxiStreamMasterType;
     obSlave         : in  AxiStreamSlaveType );
end DtiUsCore;

architecture rtl of DtiUsCore is

  constant MAX_BIT : integer := bitSize(MaxDsLinks)-1;

  type StateType is (S_IDLE, S_EVHDR1, S_EVHDR2, S_EVHDR3, S_EVHDR4, S_PAYLOAD);
  
  type RegType is record
    ena    : sl;
    state  : StateType;
    dest   : slv(MAX_BIT downto 0);
    mask   : slv(MaxDsLinks-1 downto 0);
    ack    : slv(MaxDsLinks-1 downto 0);
    full   : slv(15 downto 0);
    hdrRd  : sl;
    master : AxiStreamMasterType;
    slave  : AxiStreamSlaveType;
    status : DtiUsLinkStatusType;
    statusO : DtiUsLinkStatusType;
  end record;
  
  constant REG_INIT_C : RegType := (
    ena    => '0',
    state  => S_IDLE,
    dest   => toSlv(MaxDsLinks-1,MAX_BIT+1),
    mask   => (others=>'0'),
    ack    => (others=>'0'),
    full   => (others=>'0'),
    hdrRd  => '0',
    master => AXI_STREAM_MASTER_INIT_C,
    slave  => AXI_STREAM_SLAVE_INIT_C,
    status => DTI_US_LINK_STATUS_INIT_C,
    statusO => DTI_US_LINK_STATUS_INIT_C );
  
  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal eventTag : slv(4 downto 0);
  signal pdata    : XpmPartitionDataType;
  signal eventHeader : DtiEventHeaderType;
  
  signal configV, configSV : slv(DTI_US_LINK_CONFIG_BITS_C-1 downto 0);
  signal configS : DtiUsLinkConfigType;
  
  signal tMaster      : AxiStreamMasterType;
  signal tSlave       : AxiStreamSlaveType;
  
  signal ictlTxMaster : AxiStreamMasterType;
  signal ictlTxSlave  : AxiStreamSlaveType;

  signal linkUpS  : sl;
  signal linkErrS : slv(31 downto 0);
  signal urst : sl;
  signal supdate : sl;
  signal sclear  : sl;
begin

  obClk         <= timingClk;
  ibClk         <= eventClk;
  obTrig        <= pdata;
  status        <= r.statusO;
  fullOut       <= r.full;
  urst          <= clear and not r.ena;

  eventTag      <= ibMaster.tId(eventTag'range);
  
  U_CtlRxStreamFifo : entity work.AxiStreamFifo
    generic map ( SLAVE_AXI_CONFIG_G  => CTLS_CONFIG_C,
                  MASTER_AXI_CONFIG_G => US_OB_CONFIG_C )
    port map ( sAxisClk    => ctlClk,
               sAxisRst    => ctlRst,
               sAxisMaster => ctlRxMaster,
               sAxisSlave  => ctlRxSlave,
               mAxisClk    => timingClk,
               mAxisRst    => timingRst,
               mAxisMaster => obMaster,
               mAxisSlave  => obSlave );
  
  U_CtlTxStreamFifo : entity work.AxiStreamFifo
    generic map ( SLAVE_AXI_CONFIG_G  => US_IB_CONFIG_C,
                  MASTER_AXI_CONFIG_G => CTLS_CONFIG_C )
    port map ( sAxisClk    => eventClk,
               sAxisRst    => eventRst,
               sAxisMaster => ictlTxMaster,
               sAxisSlave  => ictlTxSlave,
               mAxisClk    => ctlClk,
               mAxisRst    => ctlRst,
               mAxisMaster => ctlTxMaster,
               mAxisSlave  => ctlTxSlave );
  
  U_Mux : entity work.AxiStreamDeMux
    generic map ( NUM_MASTERS_G  => MaxDsLinks+1,
                  TDEST_HIGH_G   => MAX_BIT,
                  TDEST_LOW_G    => 0 )
    port map ( sAxisMaster   => tMaster,
               sAxisSlave    => tSlave,
               mAxisMasters(MaxDsLinks-1 downto 0) => eventMasters,
               mAxisMasters(MaxDsLinks) => ictlTxMaster,
               mAxisSlaves (MaxDsLinks-1 downto 0) => eventSlaves,
               mAxisSlaves (MaxDsLinks) => ictlTxSlave,
               axisClk       => eventClk,
               axisRst       => eventRst );

  U_HdrCache : entity work.DtiHeaderCache
    port map ( rst       => urst,
               wrclk     => timingClk,
               timingBus => timingBus,
               exptBus   => exptBus,
               partition => config.partition(2 downto 0),
               l0delay   => config.trigDelay,
               pdata     => pdata,
               rdclk     => eventClk,
               entag     => config.tagEnable,
               l0tag     => eventTag,
               advance   => r.hdrRd,
               hdrOut    => eventHeader );

  configV <= toSlv(config);
  
  U_SyncConfig : entity work.SynchronizerVector
    generic map ( WIDTH_G => configV'length )
    port map ( clk     => eventClk,
               dataIn  => configV,
               dataOut => configSV );

  configS <= toUsLinkConfig(configSV);

  U_LinkUpS : entity work.Synchronizer
    port map ( clk     => eventClk,
               dataIn  => ibLinkUp,
               dataOut => linkUpS );
  
  U_LinkErrs : entity work.SynchronizerVector
    generic map ( WIDTH_G => 32 )
    port map ( clk     => eventClk,
               dataIn  => ibErrs,
               dataOut => linkErrS );
  
  --
  --  For event traffic:
  --    Arbitrate through forwarding mask
  --    Add event header
  --
  comb : process ( r, ibMaster, tSlave, configS, eventRst, sclear, supdate, eventHeader, linkUpS, linkErrS, full ) is
    variable v : RegType;
    variable selv : sl;
    variable fwd  : slv(MAX_BIT downto 0);
    variable isFull : sl;
  begin
    v := r;

    v.ena  := configS.enable;
    v.slave.tReady := '0';
    v.status.linkUp  := linkUpS;
    v.status.rxErrs  := linkErrS;
    v.hdrRd          := '0';
    
    arbitrate(r.mask, r.dest, fwd, selv, v.ack);

    if tSlave.tReady='1' then
      v.master.tValid := '0';
    end if;

    case r.state is
      when S_IDLE =>
        if v.master.tValid='0' and ibMaster.tValid='1' then
          if ibMaster.tDest(0)='1' then
            v.master       := ibMaster;
            v.master.tDest := toSlv(MaxDsLinks,r.master.tDest'length);
            v.slave.tReady := '1';
            if ibMaster.tLast='1' then
              v.state      := S_IDLE;
            else
              v.state      := S_PAYLOAD;
            end if;
          else
            v.state        := S_EVHDR1;
          end if;
        end if;
      when S_EVHDR1 =>
        if v.master.tValid='0' and ibMaster.tValid='1' then
          v.dest          := fwd;
          v.master.tDest  := resize(fwd,r.master.tDest'length);
          v.master.tId    := ibMaster.tId;
          v.master.tValid := '1';
          v.master.tLast  := '0';
          v.master.tData(63 downto 0) := eventHeader.timeStamp;
          v.state         := S_EVHDR2;
        end if;
      when S_EVHDR2 =>
        if v.master.tValid='0' then
          v.master.tValid := '1';
          v.master.tLast  := '0';
          v.master.tData(63 downto 0) := eventHeader.pulseId;
          v.hdrRd         := '1';
          v.state         := S_EVHDR3;
        end if;
      when S_EVHDR3 =>
        if v.master.tValid='0' then
          v.master.tValid := '1';
          v.master.tLast  := '0';
          v.master.tData(63 downto 0) := eventHeader.evttag & toSlv(0,32);
          v.state         := S_EVHDR4;
        end if;
      when S_EVHDR4 =>
        if v.master.tValid='0' then
          v.master.tValid := '1';
          v.master.tLast  := '0';
          v.master.tData(63 downto 0) := configS.dataSrc & configS.dataType;
          v.state         := S_PAYLOAD;
        end if;
      when S_PAYLOAD =>
        if v.master.tValid='0' then
          -- preserve tDest
          v.master.tValid := ibMaster.tValid;
          v.master.tLast  := ibMaster.tLast;
          v.master.tData  := ibMaster.tData;
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
      isFull := full(conv_integer(fwd)) or not selv;
    else                             -- Next not full
      v.mask := configS.fwdMask and not full;
      isFull := not selv;
    end if;

    if isFull='1' and r.ena='1' then
      v.full(conv_integer(configS.partition)) := isFull;
      v.status.rxFull  := r.status.rxFull+1;
    end if;

    if r.slave.tReady='1' then
      v.status.ibReceived := r.status.ibReceived+1;
    end if;

    if sclear = '1' then
      v.status.rxFull := (others=>'0');
      v.status.ibReceived := (others=>'0');
    end if;
    
    if eventRst = '1' then
      v := REG_INIT_C;
    end if;

    if supdate = '1' then
      v.statusO := r.status;
    end if;
    
    rin <= v;

    tMaster <= r.master;
    ibSlave <= v.slave;
  end process;
  
  seq : process (eventClk) is
  begin
    if rising_edge(eventClk) then
      r <= rin;
    end if;
  end process;
  
end rtl;
