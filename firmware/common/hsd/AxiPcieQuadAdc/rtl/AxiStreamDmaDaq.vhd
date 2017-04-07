-------------------------------------------------------------------------------
-- Title      : SSI Stream DMA Controller
-- Project    : General Purpose Core
-------------------------------------------------------------------------------
-- File       : AxiStreamDma.vhd
-- Author     : Ryan Herbst, rherbst@slac.stanford1.edu
-- Created    : 2014-04-25
-- Last update: 2017-04-06
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Generic AXI Stream DMA block for frame at a time transfers.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/25/2014: created.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.AxiPkg.all;
use work.AxiDmaPkg.all;

entity AxiStreamDmaDaq is
   generic (
      TPD_G             : time                       := 1 ns;
      FREE_ADDR_WIDTH_G : integer                    := 9;
      AXIL_COUNT_G      : integer range 1 to 2       := 1;
      AXIL_BASE_ADDR_G  : slv(31 downto 0)           := x"00000000";
      AXI_READY_EN_G    : boolean                    := false;
      AXIS_READY_EN_G   : boolean                    := false;
      AXIS_CONFIG_G     : AxiStreamConfigType        := AXI_STREAM_CONFIG_INIT_C;
      AXI_CONFIG_G      : AxiConfigType              := AXI_CONFIG_INIT_C;
      AXI_BURST_G       : slv(1 downto 0)            := "01";
      AXI_CACHE_G       : slv(3 downto 0)            := "1111";
      MAX_PEND_G        : integer range 0 to (2**24) := 0
   );
   port (

      -- Clock/Reset
      axiClk          : in  sl;
      axiRst          : in  sl;

      -- Register Access & Interrupt
      axilReadMaster  : in  AxiLiteReadMasterArray(AXIL_COUNT_G-1 downto 0);
      axilReadSlave   : out AxiLiteReadSlaveArray(AXIL_COUNT_G-1 downto 0);
      axilWriteMaster : in  AxiLiteWriteMasterArray(AXIL_COUNT_G-1 downto 0);
      axilWriteSlave  : out AxiLiteWriteSlaveArray(AXIL_COUNT_G-1 downto 0);
      interrupt       : out sl;
      online          : out sl;
      acknowledge     : out sl;
      interruptAck    : in  sl;
      
      -- SSI 
      sAxisMaster     : in  AxiStreamMasterType;
      sAxisSlave      : out AxiStreamSlaveType;
      mAxisMaster     : out AxiStreamMasterType;
      mAxisSlave      : in  AxiStreamSlaveType;
      mAxisCtrl       : in  AxiStreamCtrlType;

      -- AXI Interface
      axiReadMaster   : out AxiReadMasterType;
      axiReadSlave    : in  AxiReadSlaveType;
      axiWriteMaster  : out AxiWriteMasterType;
      axiWriteSlave   : in  AxiWriteSlaveType;
      axiWriteCtrl    : in  AxiCtrlType
   );
end AxiStreamDmaDaq;

architecture structure of AxiStreamDmaDaq is

   constant PUSH_ADDR_WIDTH_C : integer := FREE_ADDR_WIDTH_G;
   constant POP_ADDR_WIDTH_C  : integer := FREE_ADDR_WIDTH_G;

   constant POP_FIFO_PFULL_C  : integer := (2**POP_ADDR_WIDTH_C) - 10;

   constant POP_FIFO_COUNT_C  : integer := 2;
   constant PUSH_FIFO_COUNT_C : integer := 2;

--   constant PUSH_FIFO_PFULL_C : integer := (2**PUSH_ADDR_WIDTH_C) - 2;
   constant PUSH_FIFO_PFULL_C : integer := 510;
   
   constant IB_FIFO_C : integer := 0;
   constant OB_FIFO_C : integer := 1;

   constant CROSSBAR_CONN_C : slv(15 downto 0) := x"FFFF";

   constant LOC_INDEX_C       : natural          := 0;
   constant LOC_BASE_ADDR_C   : slv(31 downto 0) := AXIL_BASE_ADDR_G(31 downto 12) & x"000";
   constant LOC_NUM_BITS_C    : natural          := 10;

   constant FIFO_INDEX_C     : natural          := 1;
   constant FIFO_BASE_ADDR_C : slv(31 downto 0) := AXIL_BASE_ADDR_G(31 downto 12) & x"400";
   constant FIFO_NUM_BITS_C  : natural          := 10;

   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(1 downto 0) := (
      LOC_INDEX_C => (
         baseAddr     => LOC_BASE_ADDR_C,
         addrBits     => LOC_NUM_BITS_C,
         connectivity => CROSSBAR_CONN_C),
      FIFO_INDEX_C => (
         baseAddr     => FIFO_BASE_ADDR_C,
         addrBits     => FIFO_NUM_BITS_C,
         connectivity => CROSSBAR_CONN_C));

   type StateType   is (S_IDLE_C, S_WAIT_C, S_FIFO_0_C, S_FIFO_1_C);
   type IbStateType is (S_INIT_C, S_ACK_C, S_REWRITE_C, S_RACK_C, S_FIFO_C);

   type RegType is record
      maxRxSize     : slv(23 downto 0);
      sizeInHdr     : sl;
      interrupt     : sl;
      interruptU    : sl;
      intRequest    : sl;
      intEnable     : sl;
      intAck        : sl;
      acknowledge   : sl;
      online        : sl;
      rxEnable      : sl;
      txEnable      : sl;
      fifoClear     : sl;
      pushThres     : slv(PUSH_ADDR_WIDTH_C-1 downto 0);
      intReqCount   : slv(31 downto 0);
      intAckCount   : slv(31 downto 0);
      intHoldoff    : slv(15 downto 0);
      intDelay      : slv(15 downto 0);
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      maxRxSize     => (others=>'0'),
      sizeInHdr     => '0',
      interrupt     => '0',
      interruptU    => '0',
      intRequest    => '0',
      intEnable     => '0',
      intAck        => '0',
      acknowledge   => '0',
      online        => '0',
      rxEnable      => '0',
      txEnable      => '0',
      fifoClear     => '0',
      pushThres     => (others=>'0'),
      intReqCount   => (others=>'0'),
      intAckCount   => (others=>'0'),
      intHoldoff    => (others=>'0'),
      intDelay      => (others=>'0'),
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C
      );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   type IbType is record
      state        : IbStateType;
      intPending   : sl;
      ibReq        : AxiWriteDmaReqType;
      popFifoWrite : sl;
      popFifoDin   : slv(31 downto 0);
      pushFifoRead : sl;
      dmaCount     : slv(31 downto 0);
      tData        : slv(31 downto 0);
      master       : AxiStreamMasterType;
      slave        : AxiStreamSlaveType;
      latch        : sl;
   end record IbType;

   constant IB_INIT_C : IbType := (
      state        => S_INIT_C,
      intPending   => '0',
      ibReq        => AXI_WRITE_DMA_REQ_INIT_C,
      popFifoWrite => '0',
      popFifoDin   => (others=>'0'),
      pushFifoRead => '0',
      dmaCount     => (others=>'0'),
      tData        => (others=>'0'),
      master       => AXI_STREAM_MASTER_INIT_C,
      slave        => AXI_STREAM_SLAVE_INIT_C,
      latch        => '1'
      );

   signal ib   : IbType := IB_INIT_C;
   signal ibin : IbType;

   type ObType is record
      state        : StateType;
      intPending   : sl;
      obReq        : AxiReadDmaReqType;
      popFifoWrite : sl;
      popFifoDin   : slv(31 downto 0);
      pushFifoRead : sl;
   end record ObType;

   constant OB_INIT_C : ObType := (
      state        => S_IDLE_C,
      intPending   => '0',
      obReq        => AXI_READ_DMA_REQ_INIT_C,
      popFifoWrite => '0',
      popFifoDin   => (others=>'0'),
      pushFifoRead => '0'
      );

   signal ob   : ObType := OB_INIT_C;
   signal obin : ObType;

   signal intReadMasters     : AxiLiteReadMasterArray(1 downto 0);
   signal intReadSlaves      : AxiLiteReadSlaveArray(1 downto 0);
   signal intWriteMasters    : AxiLiteWriteMasterArray(1 downto 0);
   signal intWriteSlaves     : AxiLiteWriteSlaveArray(1 downto 0);

   signal popFifoClk         : slv(POP_FIFO_COUNT_C-1 downto 0);
   signal popFifoRst         : slv(POP_FIFO_COUNT_C-1 downto 0);
   signal popFifoValid       : slv(POP_FIFO_COUNT_C-1 downto 0);
   signal popFifoWrite       : slv(POP_FIFO_COUNT_C-1 downto 0);
   signal popFifoPFull       : slv(POP_FIFO_COUNT_C-1 downto 0);
   signal popFifoDin         : Slv32Array(POP_FIFO_COUNT_C-1 downto 0);
   signal pushFifoClk        : slv(POP_FIFO_COUNT_C-1 downto 0);
   signal pushFifoRst        : slv(POP_FIFO_COUNT_C-1 downto 0);
   signal pushFifoValid      : slv(PUSH_FIFO_COUNT_C-1 downto 0);
   signal pushFifoDout       : Slv36Array(PUSH_FIFO_COUNT_C-1 downto 0);
   signal pushFifoRead       : slv(PUSH_FIFO_COUNT_C-1 downto 0);
   signal pushFifoCount      : SlVectorArray(PUSH_FIFO_COUNT_C-1 downto 0,PUSH_ADDR_WIDTH_C-1 downto 0);
   
   signal obAck              : AxiReadDmaAckType;
   signal obReq              : AxiReadDmaReqType;
   signal ibAck              : AxiWriteDmaAckType;
   signal ibReq              : AxiWriteDmaReqType;

   signal intAxisMasters     : AxiStreamMasterArray(1 downto 0);
   signal intAxisSlaves      : AxiStreamSlaveArray (1 downto 0);
   signal ibsMaster          : AxiStreamMasterType;
   signal ibsSlave           : AxiStreamSlaveType;

begin

   U_CrossEnGen: if AXIL_COUNT_G = 1 generate
      U_AxiCrossbar : entity work.AxiLiteCrossbar 
         generic map (
            TPD_G              => TPD_G,
            NUM_SLAVE_SLOTS_G  => 1,
            NUM_MASTER_SLOTS_G => 2,
            DEC_ERROR_RESP_G   => AXI_RESP_OK_C,
            MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C 
         ) port map (
            axiClk              => axiClk,
            axiClkRst           => axiRst,
            sAxiWriteMasters    => axilWriteMaster,
            sAxiWriteSlaves     => axilWriteSlave,
            sAxiReadMasters     => axilReadMaster,
            sAxiReadSlaves      => axilReadSlave,
            mAxiWriteMasters    => intWriteMasters,
            mAxiWriteSlaves     => intWriteSlaves,
            mAxiReadMasters     => intReadMasters,
            mAxiReadSlaves      => intReadSlaves
         );
   end generate;

   U_CrossDisGen: if AXIL_COUNT_G = 2 generate
      intWriteMasters <= axilWriteMaster;
      axilWriteSlave  <= intWriteSlaves;
      intReadMasters  <= axilReadMaster;
      axilReadSlave   <= intReadSlaves;
   end generate;

   U_SwFifos : entity work.AxiLiteFifoPushPop 
      generic map (
         TPD_G              => TPD_G,
         POP_FIFO_COUNT_G   => 2,
         POP_SYNC_FIFO_G    => true,
         POP_BRAM_EN_G      => true,
         POP_ADDR_WIDTH_G   => POP_ADDR_WIDTH_C,
         POP_FULL_THRES_G   => POP_FIFO_PFULL_C,
         LOOP_FIFO_EN_G     => false,
         LOOP_FIFO_COUNT_G  => 1,
         LOOP_BRAM_EN_G     => false,
         LOOP_ADDR_WIDTH_G  => 9,
         PUSH_FIFO_COUNT_G  => 2,
         PUSH_SYNC_FIFO_G   => true,
         PUSH_BRAM_EN_G     => true,
         PUSH_ADDR_WIDTH_G  => PUSH_ADDR_WIDTH_C, 
         PUSH_FULL_THRES_G  => PUSH_FIFO_PFULL_C,
         RANGE_LSB_G        => 8,
         VALID_POSITION_G   => 31,
         VALID_POLARITY_G   => '1',
         ALTERA_SYN_G       => false,
         ALTERA_RAM_G       => "M9K",
         USE_BUILT_IN_G     => false,
         XIL_DEVICE_G       => "7SERIES"
      ) port map (
         axiClk             => axiClk,
         axiClkRst          => axiRst,
         axiReadMaster      => intReadMasters(1),
         axiReadSlave       => intReadSlaves(1),
         axiWriteMaster     => intWriteMasters(1),
         axiWriteSlave      => intWriteSlaves(1),
         pushFifoCount      => pushFifoCount,
         popFifoValid       => popFifoValid,
         popFifoClk         => popFifoClk,
         popFifoRst         => popFifoRst,
         popFifoWrite       => popFifoWrite,
         popFifoDin         => popFifoDin,
         popFifoFull        => open,
         popFifoAFull       => open,
         popFifoPFull       => popFifoPFull,
         pushFifoClk        => pushFifoClk,
         pushFifoRst        => pushFifoRst,
         pushFifoValid      => pushFifoValid,
         pushFifoDout       => pushFifoDout,
         pushFifoRead       => pushFifoRead
      );

   U_ClkRstGen: for i in 0 to 1 generate
      popFifoClk(i)  <= axiClk;
      popFifoRst(i)  <= r.fifoClear; 
      pushFifoClk(i) <= axiClk;
      pushFifoRst(i) <= r.fifoClear; 
   end generate;


   -------------------------------------
   -- Local Register Space
   -------------------------------------

   -- Sync
   process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process;

   -- Async
   process (r, axiRst, intReadMasters, intWriteMasters, popFifoValid, ib, ob, interruptAck ) is
      variable v         : RegType;
      variable axiStatus : AxiLiteStatusType;
   begin
      v := r;

      v.intAck := '0';

      axiSlaveWaitTxn(intWriteMasters(0), intReadMasters(0), v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Write
      if (axiStatus.writeEnable = '1') then

         case intWriteMasters(0).awaddr(5 downto 2) is
            when x"0" =>
               v.rxEnable := intWriteMasters(0).wdata(0);
            when x"1" =>
               v.txEnable := intWriteMasters(0).wdata(0);
            when x"2" =>
               v.fifoClear := intWriteMasters(0).wdata(0);
            when x"3" =>
               v.intEnable := intWriteMasters(0).wdata(0);
            when x"4" =>
               v.pushThres := intWriteMasters(0).wdata(PUSH_ADDR_WIDTH_C-1 downto 0);
            when x"5" =>
               v.maxRxSize := intWriteMasters(0).wdata(23 downto 0);
               v.sizeInHdr := intWriteMasters(0).wdata(31);
            when x"6" =>
               v.online      := intWriteMasters(0).wdata(0);
               v.acknowledge := intWriteMasters(0).wdata(1);
            when x"7" =>
               v.intAck := intWriteMasters(0).wdata(0);
            when x"8" =>
               v.intReqCount := (others=>'0');
            when x"9" =>
               v.intAckCount := (others=>'0');
            when x"A" =>
               v.intHoldOff  := intWriteMasters(0).wdata(15 downto 0);
            when others =>
               null;
         end case;

         axiSlaveWriteResponse(v.axiWriteSlave);
      end if;

      -- Read
      if (axiStatus.readEnable = '1') then
         v.axiReadSlave.rdata := (others=>'0');

         case intReadMasters(0).araddr(5 downto 2) is
            when x"0" =>
               v.axiReadSlave.rdata(0) := r.rxEnable;
            when x"1" =>
               v.axiReadSlave.rdata(0) := r.txEnable;
            when x"2" =>
               v.axiReadSlave.rdata(0) := r.fifoClear;
            when x"3" =>
               v.axiReadSlave.rdata(0) := r.intEnable;
            when x"4" =>
               v.axiReadSlave.rdata(0) := popFifoValid(IB_FIFO_C);
               v.axiReadSlave.rdata(1) := popFifoValid(OB_FIFO_C);
            when x"5" =>
               v.axiReadSlave.rdata(23 downto 0) := r.maxRxSize;
               v.axiReadSlave.rdata(31)          := r.sizeInHdr;
            when x"6" =>
               v.axiReadSlave.rdata(0) := r.online;
               v.axiReadSlave.rdata(1) := r.acknowledge;
            when x"7" =>
               v.axiReadSlave.rdata(0) := ib.intPending;
               v.axiReadSlave.rdata(1) := ob.intPending;
            when x"8" =>
               v.axiReadSlave.rdata    := r.intReqCount;
            when x"9" =>
               v.axiReadSlave.rdata    := r.intAckCount;
            when x"A" =>
               v.axiReadSlave.rdata(15 downto 0) := r.intHoldOff;
            when x"B" =>
               v.axiReadSlave.rdata    := ib.dmaCount;
            when others =>
               null;
         end case;

         -- Send Axi Response
         axiSlaveReadResponse(v.axiReadSlave);

      end if;

      v.interruptU := (ib.intPending or ob.intPending) and r.intEnable;

      if r.interruptU='0' then
        v.interrupt   := '0';
      elsif r.intDelay=0 then
        v.interrupt   := '1';
      end if;
        
      if r.intDelay/=0 then
        v.intDelay    := r.intDelay-1;
      end if;

      if v.interrupt='1' and r.interrupt='0' then
        v.intDelay    := r.intHoldOff;
        v.intReqCount := r.intReqCount+1;
        v.intRequest  := '1';
      elsif interruptAck='1' then
        v.intAckCount := r.intAckCount+1;
        v.intRequest  := '0';
      end if;
      
      -- Reset
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Next register assignment
      rin <= v;

      -- Outputs
      interrupt         <= r.interrupt;
      acknowledge       <= r.acknowledge;
      online            <= r.online;
      intReadSlaves(0)  <= r.axiReadSlave;
      intWriteSlaves(0) <= r.axiWriteSlave;

   end process;

   -------------------------------------
   -- Inbound Controller
   -------------------------------------
   U_IbDma : entity work.AxiStreamDmaWrite
      generic map (
         TPD_G             => TPD_G,
         AXI_READY_EN_G    => AXI_READY_EN_G,
         AXIS_CONFIG_G     => AXIS_CONFIG_G,
         AXI_CONFIG_G      => AXI_CONFIG_G,
         AXI_BURST_G       => AXI_BURST_G,
         AXI_CACHE_G       => AXI_CACHE_G,
         AXI_BURST_BYTES_G => 256 -- set to negotiated MaxPayload
      ) port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         dmaReq          => ibReq,
         dmaAck          => ibAck,
         axisMaster      => ibsMaster,
         axisSlave       => ibsSlave,
         axiWriteMaster  => axiWriteMaster,
         axiWriteSlave   => axiWriteSlave,
         axiWriteCtrl    => axiWriteCtrl
      );

   -- Sync
   process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         ib <= ibin after TPD_G;
      end if;
   end process;

   -- Async
   process (ib, r, axiRst, ibAck, pushFifoValid, pushFifoDout, ibsSlave, sAxisMaster, pushFifoCount ) is
      variable v : IbType;
   begin
      v := ib;

      v.pushFifoRead := '0';
      v.popFifoWrite := '0';

      if ib.latch='1' and saxisMaster.tValid='1' then
        v.latch := '0';
        v.tData := '1' & sAxisMaster.tData(102 downto 96) & sAxisMaster.tData(23 downto 0);
      elsif ib.latch='0' and ib.state=S_FIFO_C then
        v.latch := '1';
      end if;
        
      v.slave.tReady := '0';
      
      case ib.state is

         when S_INIT_C =>
            v.ibReq.address(31 downto 0) := pushFifoDout(IB_FIFO_C)(31 downto 0);
            v.ibReq.maxSize := r.sizeInHdr & toSlv(0,7) & r.maxRxSize;
            v.slave  := ibsSlave;
            v.master := sAxisMaster;   
            if pushFifoValid(IB_FIFO_C) = '1' then
               v.ibReq.request := '1';
               v.state         := S_ACK_C;
            end if;

         when S_ACK_C =>
            v.slave  := ibsSlave;
            v.master := sAxisMaster;
            if ibAck.done = '1' then
               v.state         := S_REWRITE_C;
               v.ibReq.request := '0';
            end if;

         when S_REWRITE_C =>
           v.master.tValid := '1';
           v.master.tData(31 downto 0) := ib.tData;
           v.master.tLast  := '1';
           v.master.tKeep  := toSlv(15,v.master.tKeep'length);
           v.ibReq.request := '1';
           v.state         := S_RACK_C;

         when S_RACK_C =>
           
            if ibAck.done = '1' then
              v.ibReq.request  := '0';
              v.pushFifoRead   := '1';
              v.dmaCount       := ib.dmaCount+1;
              v.state          := S_FIFO_C;
            end if;

        when S_FIFO_C =>
           v.state := S_INIT_C;
           
      end case;

      -- Interrupt when DMA queued
      if muxSlVectorArray(pushFifoCount,IB_FIFO_C) < r.pushThres then
         v.intPending := '1';
      else
         v.intPending := '0';
      end if;

      -- Reset
      if axiRst = '1' or r.rxEnable = '0' then
         v := IB_INIT_C;
      end if;

      -- Next register assignment
      ibin <= v;

      -- Outputs
      ibReq                   <= ib.ibReq;
      popFifoWrite(IB_FIFO_C) <= '0';
      pushFifoRead(IB_FIFO_C) <= ib.pushFifoRead;
      ---
      --  Rewrite the header word after a transfer is complete
      ---
      ibsMaster               <= v.master;
      sAxisSlave              <= v.slave;

   end process;


   -------------------------------------
   -- Outbound Controller
   -------------------------------------
   U_ObDma : entity work.AxiStreamDmaRead 
      generic map (
         TPD_G            => TPD_G,
         AXIS_READY_EN_G  => AXIS_READY_EN_G,
         AXIS_CONFIG_G    => AXIS_CONFIG_G,
         AXI_CONFIG_G     => AXI_CONFIG_G,
         AXI_BURST_G      => AXI_BURST_G,
         AXI_CACHE_G      => AXI_CACHE_G,
         MAX_PEND_G       => MAX_PEND_G 
      ) port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         dmaReq          => obReq,
         dmaAck          => obAck,
         axisMaster      => mAxisMaster,
         axisSlave       => mAxisSlave,
         axisCtrl        => mAxisCtrl,
         axiReadMaster   => axiReadMaster,
         axiReadSlave    => axiReadSlave
      );

   -- Sync
   process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         ob <= obin after TPD_G;
      end if;
   end process;

   -- Async
   process (ob, r, axiRst, obAck, pushFifoValid, pushFifoDout ) is
      variable v : ObType;
   begin
      v := ob;

      v.pushFifoRead := '0';
      v.popFifoWrite := '0';

      case ob.state is

         when S_IDLE_C =>
            v.obReq.address(31 downto 0) := pushFifoDout(OB_FIFO_C)(31 downto 0);

            if pushFifoValid(OB_FIFO_C) = '1' then
               v.pushFifoRead  := '1';

               if pushFifoDout(OB_FIFO_C)(35 downto 32) = 3 then
                  v.popFifoDin    := "1" & pushFifoDout(OB_FIFO_C)(30 downto 0);
                  v.popFifoWrite  := '1';

               elsif pushFifoDout(OB_FIFO_C)(35 downto 32) = 0 then
                  v.state := S_FIFO_0_C;
               end if;
            end if;

         when S_FIFO_0_C =>
            v.obReq.size := x"00" & pushFifoDout(OB_FIFO_C)(23 downto 0);

            if pushFifoValid(OB_FIFO_C) = '1' then
               v.pushFifoRead  := '1';
               
               if pushFifoDout(OB_FIFO_C)(35 downto 32) /= 1 then
                  v.state := S_IDLE_C;
               else
                  v.state := S_FIFO_1_C;
               end if;
            end if;

         when S_FIFO_1_C =>
            v.obReq.lastUser  := pushFifoDout(OB_FIFO_C)(23 downto 16);
            v.obReq.firstUser := pushFifoDout(OB_FIFO_C)(15 downto  8);
            v.obReq.dest      := pushFifoDout(OB_FIFO_C)(7  downto  0);
            v.obReq.id        := (others=>'0');

            if pushFifoValid(OB_FIFO_C) = '1' then
               v.pushFifoRead  := '1';

               if pushFifoDout(OB_FIFO_C)(35 downto 32) /= 2 then
                  v.state := S_IDLE_C;
               else
                  v.obReq.request := '1';
                  v.state         := S_WAIT_C;
               end if;
            end if;

         when S_WAIT_C =>
            if obAck.done = '1' then
               v.obReq.request := '0';
               v.popFifoDin    := "1" & ob.obReq.address(30 downto 0);
               v.popFifoWrite  := '1';
               v.intPending    := '1';
               v.state         := S_IDLE_C;
            end if;

      end case;

      -- Interrupt Ack
      if r.intAck = '1' then
         v.intPending := '0';
      end if;

      -- Reset
      if axiRst = '1' or r.txEnable = '0' then
         v := OB_INIT_C;
      end if;

      -- Next register assignment
      obin <= v;

      -- Outputs
      obReq                   <= ob.obReq;
      popFifoWrite(OB_FIFO_C) <= ob.popFifoWrite;
      popFifoDin(OB_FIFO_C)   <= ob.popFifoDin;
      pushFifoRead(OB_FIFO_C) <= v.pushFifoRead;

   end process;

end structure;

