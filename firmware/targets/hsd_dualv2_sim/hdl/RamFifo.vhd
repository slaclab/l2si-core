----------------------------------------------------------------
-- File       : RamFifo.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-10-26
-- Last update: 2018-01-09
-------------------------------------------------------------------------------
-- Description: Application File
-------------------------------------------------------------------------------
-- This file is part of 'axi-pcie-core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'axi-pcie-core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;

use work.AxiPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.AxiDmaPkg.all;
use work.AxiPciePkg.all;
use work.SsiPkg.all;

entity RamFifo is
   generic ( TPD_G        : time             := 1 ns;
             LANE_G       : integer          := 0;
             DMA_AXIS_CONFIG_C : AxiStreamConfigType;
             DEBUG_G      : boolean          := false );
   port (
      -- AXI-Lite Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- DMA Interface (ibClk domain)
      ibClk           : in  sl;
      ibRst           : in  sl;
      ibMasters       : in  AxiStreamMasterType;
      ibSlaves        : out AxiStreamSlaveType;
      ibFull          : out sl;
      obMasters       : out AxiStreamMasterType;
      obSlaves        : in  AxiStreamSlaveType;
      -- Application AXI Interface (memClk domain)
      memClk          : in  sl;
      memRst          : in  sl;
      memReady        : in  sl;
      memWriteMasters : out AxiWriteMasterArray(1 downto 0);
      memWriteSlaves  : in  AxiWriteSlaveArray (1 downto 0);
      memReadMasters  : out AxiReadMasterArray (1 downto 0);
      memReadSlaves   : in  AxiReadSlaveArray  (1 downto 0) );
end RamFifo;

architecture mapping of RamFifo is

  constant BUFFER_ORDER : integer := 21;
  constant INDEX_BITS_C : integer := 32-BUFFER_ORDER;
  constant START_ADDR_G : slv(31 downto 0) := toSlv(LANE_G mod 2,1) & toSlv(0,31);

  constant MEM_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(16);
  constant MEM_AXI_CONFIG_C  : AxiConfigType       := axiConfig(32,16);
  
  type RegType is record
    minBuffers  : slv(INDEX_BITS_C-1 downto 0);
    axilWriteS  : AxiLiteWriteSlaveType;
    axilReadS   : AxiLiteReadSlaveType;
  end record;

  constant REG_INIT_C : RegType := (
    minBuffers  => toSlv(32,INDEX_BITS_C),
    axilWriteS  => AXI_LITE_WRITE_SLAVE_INIT_C,
    axilReadS   => AXI_LITE_READ_SLAVE_INIT_C );

  signal r    : RegType := REG_INIT_C;
  signal rin  : RegType;

  type AxiWriteStateType is (IDLE_W, WAIT_W);
  type AxiReadStateType is (IDLE_R, WAIT_R);
  
  type AxiRegType is record
    rdBuffer    : slv(INDEX_BITS_C-1 downto 0);
    wrBuffer    : slv(INDEX_BITS_C-1 downto 0);
    freeBuffers : slv(INDEX_BITS_C-1 downto 0);
    ibFull      : sl;
    wrState     : AxiWriteStateType;
    rdState     : AxiReadStateType;
    wrreq       : AxiWriteDmaReqType;
    rdreq       : AxiReadDmaReqType;
  end record;

  constant AXI_REG_INIT_C : AxiRegType := (
    rdBuffer    => (others=>'0'),
    wrBuffer    => (others=>'0'),
    freeBuffers => (others=>'0'),
    ibFull      => '1',
    wrState     => IDLE_W,
    rdState     => IDLE_R,
    wrreq       => AXI_WRITE_DMA_REQ_INIT_C,
    rdreq       => AXI_READ_DMA_REQ_INIT_C );

  signal a    : AxiRegType := AXI_REG_INIT_C;
  signal ain  : AxiRegType;
  
  signal intMinBuffers : slv(INDEX_BITS_C-1 downto 0);
  signal intFreeBuffers: slv(INDEX_BITS_C-1 downto 0);
  signal intRdBuffer   : slv(INDEX_BITS_C-1 downto 0);
  signal intWrBuffer   : slv(INDEX_BITS_C-1 downto 0);
  signal dout          : slv(23 downto 0);
  signal intWrAck       : AxiWriteDmaAckType;
  signal intRdAck       : AxiReadDmaAckType;
  signal intReadMaster  : AxiStreamMasterType;
  signal intReadSlave   : AxiStreamSlaveType;
  signal intWriteMaster : AxiStreamMasterType;
  signal intWriteSlave  : AxiStreamSlaveType;

  component ila_1
    port ( clk          : in  sl;
           trig_out     : out sl;
           trig_out_ack : in  sl;
           probe0       : in  slv(255 downto 0) );
  end component;

  signal trig_out  : sl;
  signal rdState_r : sl;
  signal wrState_r : sl;

begin

  GEN_DEBUG : if DEBUG_G generate
    rdState_r <= '0' when a.rdState = IDLE_R else '1';
    wrState_r <= '0' when a.wrState = IDLE_W else '1';
    U_ILA : ila_1
      port map ( clk          => memClk,
                 trig_out     => trig_out,
                 trig_out_ack => trig_out,
                 probe0(0)    => rdState_r,
                 probe0(1)    => wrState_r,
                 probe0(2)    => intWrAck.done,
                 probe0(3)    => intRdAck.done,
                 probe0(4)    => a.wrReq.request,
                 probe0(5)    => a.rdReq.request,
                 probe0( 16 downto  6) => a.wrBuffer,
                 probe0( 27 downto 17) => a.rdBuffer,
                 probe0(255 downto 28) => (others=>'0') );
  end generate;
  
  U_Sync_RdB : entity work.SynchronizerVector
    generic map ( WIDTH_G => INDEX_BITS_C )
    port map ( clk     => memClk,
               dataIn  => a.rdBuffer,
               dataOut => intRdBuffer );
  
  U_Sync_WrB : entity work.SynchronizerVector
    generic map ( WIDTH_G => INDEX_BITS_C )
    port map ( clk     => memClk,
               dataIn  => a.wrBuffer,
               dataOut => intWrBuffer );
  
  U_Sync_FreeB : entity work.SynchronizerVector
    generic map ( WIDTH_G => INDEX_BITS_C )
    port map ( clk     => memClk,
               dataIn  => a.freeBuffers,
               dataOut => intFreeBuffers );
  
  U_Sync_MinB : entity work.SynchronizerVector
    generic map ( WIDTH_G => INDEX_BITS_C )
    port map ( clk     => memClk,
               dataIn  => r.minBuffers,
               dataOut => intMinBuffers );

  U_SyncFull : entity work.Synchronizer
    port map ( clk     => ibClk,
               dataIn  => a.ibFull,
               dataOut => ibFull );
  
  U_SyncWrite : entity work.AxiStreamFifo
    generic map ( FIFO_ADDR_WIDTH_G   => 9,
                  SLAVE_AXI_CONFIG_G  => DMA_AXIS_CONFIG_C,
                  MASTER_AXI_CONFIG_G => MEM_AXIS_CONFIG_C )
    port map ( sAxisClk    => ibClk,
               sAxisRst    => ibRst,
               sAxisMaster => ibMasters,
               sAxisSlave  => ibSlaves,
               mAxisClk    => memClk,
               mAxisRst    => memRst,
               mAxisMaster => intWriteMaster,
               mAxisSlave  => intWriteSlave );
  
  U_SyncRead : entity work.AxiStreamFifo
    generic map ( FIFO_ADDR_WIDTH_G   => 9,
                  SLAVE_AXI_CONFIG_G  => MEM_AXIS_CONFIG_C,
                  MASTER_AXI_CONFIG_G => DMA_AXIS_CONFIG_C )
    port map ( sAxisClk    => memClk,
               sAxisRst    => memRst,
               sAxisMaster => intReadMaster,
               sAxisSlave  => intReadSlave,
               mAxisClk    => ibClk,
               mAxisRst    => ibRst,
               mAxisMaster => obMasters,
               mAxisSlave  => obSlaves );
  
  memReadMasters (0) <= AXI_READ_MASTER_INIT_C;
  memWriteMasters(1) <= AXI_WRITE_MASTER_INIT_C;
 
  U_DmaWrite : entity work.AxiStreamDmaWrite
    generic map ( TPD_G => TPD_G,
                  AXIS_CONFIG_G => MEM_AXIS_CONFIG_C,
                  AXI_CONFIG_G  => MEM_AXI_CONFIG_C )
    port map ( axiClk         => memClk,
               axiRst         => memRst,
               dmaReq         => a.wrreq,
               dmaAck         => intWrAck,
               axisMaster     => intWriteMaster,
               axisSlave      => intWriteSlave,
               axiWriteMaster => memWriteMasters(0),
               axiWriteSlave  => memWriteSlaves (0) );

  U_DmaRead : entity work.AxiStreamDmaRead
    generic map ( TPD_G => TPD_G,
                  AXIS_CONFIG_G => MEM_AXIS_CONFIG_C,
                  AXI_CONFIG_G  => MEM_AXI_CONFIG_C )
    port map ( axiClk         => memClk,
               axiRst         => memRst,
               dmaReq         => a.rdreq,
               dmaAck         => intRdAck,
               axisMaster     => intReadMaster,
               axisSlave      => intReadSlave,
               axisCtrl       => AXI_STREAM_CTRL_UNUSED_C,
               axiReadMaster  => memReadMasters(1),
               axiReadSlave   => memReadSlaves (1) );

  U_OOB : entity work.SimpleDualPortRam
    generic map ( DATA_WIDTH_G => 24,
                  ADDR_WIDTH_G => INDEX_BITS_C )
    port map ( clka  => memClk,
               wea   => a.wrReq.request,
               addra => a.wrBuffer,
               dina( 7 downto  0) => intWrAck.firstUser,
               dina(15 downto  8) => intWrAck.lastUser,
               dina(23 downto 16) => intWrAck.dest,
               clkb  => memClk,
               addrb => a.rdBuffer,
               doutb => dout );
  
  mcomb : process ( memRst, a, intWrAck, intRdAck, intMinBuffers, dout ) is
    variable v : AxiRegType;
    variable ir : integer;
    variable iw : integer;
  begin
    v := a;

    iw := conv_integer(a.wrBuffer);
    ir := conv_integer(a.rdBuffer);

    v.freeBuffers := a.wrBuffer + 1 - a.rdBuffer;
    if ( a.freeBuffers < intMinBuffers ) then
      v.ibFull := '1';
    else
      v.ibFull := '0';
    end if;
    
    case a.wrState is
      when IDLE_W =>
        v.wrReq.address(31 downto 0)  := START_ADDR_G +
                                         resize(a.wrBuffer,INDEX_BITS_C);
        v.wrReq.maxSize               := (others=>'0');
        v.wrReq.maxSize(BUFFER_ORDER) := '1';
        if a.wrBuffer+1 /= a.rdBuffer then
          v.wrReq.request             := '1';
          v.wrState                   := WAIT_W;
        end if;
      when WAIT_W =>
        if intWrAck.done = '1' then
          v.wrReq.request := '0';
          v.wrBuffer      := a.wrBuffer + 1;
          v.wrState       := IDLE_W;
        end if;
    end case;

    case a.rdState is
      when IDLE_R =>
        v.rdReq.address(31 downto 0) := START_ADDR_G +
                                         resize(a.rdBuffer,INDEX_BITS_C);
        if a.rdBuffer /= a.wrBuffer then
          v.rdReq.firstUser := dout( 7 downto  0);
          v.rdReq.lastUser  := dout(15 downto  8);
          v.rdReq.dest      := dout(23 downto 16);
          v.rdReq.request   := '1';
          v.rdState         := WAIT_R;
        end if;
      when WAIT_R =>
        if intRdAck.done = '1' then
          v.rdReq.request := '0';
          v.rdBuffer      := a.rdBuffer + 1;
          v.rdState       := IDLE_R;
        end if;
    end case;
    
    if memRst = '1' then
      v := AXI_REG_INIT_C;
    end if;

    ain <= v;
  end process;

  mseq : process (memClk) is
  begin
    if rising_edge(memClk) then
      a <= ain;
    end if;
  end process;
 
  axilWriteSlave <= r.axilWriteS;
  axilReadSlave  <= r.axilReadS;

  comb : process ( axilRst, r, axilWriteMaster, axilReadMaster,
                   intFreeBuffers, intRdBuffer, intWrBuffer ) is
    variable v  : RegType;
    variable ep : AxiLiteEndPointType;
  begin
    v := r;

    axiSlaveWaitTxn(ep, axilWriteMaster, axilReadMaster, v.axilWriteS, v.axilReadS);
    axiSlaveRegister (ep, x"000", 0, v.minBuffers);
    axiSlaveRegisterR(ep, x"004", 0, intFreeBuffers);
    axiSlaveRegisterR(ep, x"008", 0, intRdBuffer);
    axiSlaveRegisterR(ep, x"00C", 0, intWrBuffer);

    axiSlaveDefault(ep, v.axilWriteS, v.axilReadS, AXI_RESP_OK_C);

    if axilRst = '1' then
      v := REG_INIT_C;
    end if;

    rin <= v;
  end process;

  seq : process ( axilClk ) is
  begin
    if rising_edge(axilClk) then
      r <= rin;
    end if;
  end process;
  
end mapping;
