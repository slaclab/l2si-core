-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'L2SI Core'. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'L2SI Core', including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

library l2si_core;
use l2si_core.L2SiPkg.all;

entity EvrTriggerEventBuffer is

   generic (
      TPD_G                        : time                := 1 ns;
      TRIGGER_INDEX_C              : natural             := 0;
      EVENT_AXIS_CONFIG_G          : AxiStreamConfigType := EVENT_AXIS_CONFIG_C;
      EVENT_CLK_IS_TIMING_RX_CLK_G : boolean             := false);
   port (
      timingRxClk : in sl;
      timingRxRst : in sl;

      -- AXI Lite bus for configuration and status
      -- This needs to be sync'd to timingRxClk
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;

      evrTriggers : in TimingPkg.TimingTrigType;

      -- Trigger output
--       triggerClk  : in  sl;
--       triggerRst  : in  sl;
--       triggerData : out TriggerEventDataType;

      -- Event/Transition output
      eventClk           : in  sl;
      eventRst           : in  sl;
      eventTimingMessage : out TimingMessageType;
      eventAxisMaster    : out AxiStreamMasterType;
      eventAxisSlave     : in  AxiStreamSlaveType;
      eventAxisCtrl      : in  AxiStreamCtrlType);

end entity EvrTriggerEventBuffer;

architecture rtl of EvrTriggerEventBuffer is

   constant FIFO_ADDR_WIDTH_C : integer := 5;

   type RegType is record
      enable          : sl;
      fifoPauseThresh : slv(FIFO_ADDR_WIDTH_C-1 downto 0);
      overflow        : sl;
      fifoRst         : sl;
      triggerCount    : slv(31 downto 0);
      resetCounters   : sl;
      fifoAxisMaster  : AxiStreamMasterType;
      -- outputs
      axilReadSlave   : AxiLiteReadSlaveType;
      axilWriteSlave  : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      enable          => '0',
      fifoPauseThresh => toslv(16, FIFO_ADDR_WIDTH_C),
      overflow        => '0',
      fifoRst         => '0',
      triggerCount    => (others => '0'),
      resetCounters   => '0',
      fifoAxisMaster  => axiStreamMasterInit(EVENT_AXIS_CONFIG_C),
      -- outputs
      axilReadSlave   => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal fifoAxisSlave : AxiStreamSlaveType;
   signal fifoAxisCtrl  : AxiStreamCtrlType;
   signal fifoWrCnt     : slv(FIFO_ADDR_WIDTH_C-1 downto 0);

   signal eventAxisCtrlPauseSync : sl;

begin

   -- Event AXIS bus pause is the application pause signal
   -- It needs to be synchronizer to timingRxClk
   U_Synchronizer_1 : entity surf.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => timingRxClk,              -- [in]
         rst     => timingRxRst,              -- [in]
         dataIn  => eventAxisCtrl.pause,      -- [in]
         dataOut => eventAxisCtrlPauseSync);  -- [out]


   comb : process (axilReadMaster, axilWriteMaster, fifoAxisCtrl, fifoWrCnt, r, timingRxRst) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      v := r;

      v.fifoRst               := '0';
      v.fifoAxisMaster.tValid := '0';

      if (evrTriggers.trigPulse(TRIGGER_INDEX_C) = '1') then
         v.triggerCount                        := r.triggerCount + 1;
         v.fifoAxisMaster.tValid               := '1';
         v.fifoAxisMaster.tdata(63 downto 0)   := (others => '0');
         v.fifoAxisMaster.tdata(127 downto 64) := evrTriggers.timeStamp;
         v.fifoAxisMaster.tLast                := '1';
      end if;

      if (fifoAxisCtrl.overflow = '1') then
         v.overflow := '1';
      end if;

      --------------------------------------------
      -- Axi lite interface
      --------------------------------------------
      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      axiSlaveRegister(axilEp, x"00", 0, v.enable);
      axiSlaveRegister(axilEp, x"04", 0, v.partition);
      axiSlaveRegister(axilEp, X"08", 0, v.fifoPauseThresh);
      axiSlaveRegister(axilEp, X"0C", 0, v.triggerDelay);
      axiSlaveRegisterR(axilEp, x"10", 0, r.overflow);
      axiSlaveRegisterR(axilEp, X"10", 1, r.pause);
      axiSlaveRegisterR(axilEp, X"10", 2, fifoAxisCtrl.overflow);
      axiSlaveRegisterR(axilEp, X"10", 3, fifoAxisCtrl.pause);
      axiSlaveRegisterR(axilEp, X"10", 4, fifoWrCnt);
      axiSlaveRegister(axilEp, X"14", 0, v.fifoRst);
      axiSlaveRegisterR(axilEp, X"28", 0, r.triggerCount);
      axiSlaveRegister(axilEp, X"40", 0, v.resetCounters);

      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      if (timingRxRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      -- outputs
      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;

   end process comb;

   seq : process (timingRxClk) is
   begin
      if (rising_edge(timingRxClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;


   -----------------------------------------------
   -- Buffer event data in a fifo
   -----------------------------------------------
   U_AxiStreamFifoV2_1 : entity surf.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => 1,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => false,
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => EVENT_CLK_IS_TIMING_RX_CLK_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_C,
         FIFO_FIXED_THRESH_G => false,
         FIFO_PAUSE_THRESH_G => 16,
         SLAVE_AXI_CONFIG_G  => EVENT_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => EVENT_AXIS_CONFIG_G)
      port map (
         sAxisClk        => timingRxClk,        -- [in]
         sAxisRst        => r.fifoRst,          -- [in]
         sAxisMaster     => r.fifoAxisMaster,   -- [in]
         sAxisSlave      => fifoAxisSlave,      -- [out]
         sAxisCtrl       => fifoAxisCtrl,       -- [out]
         fifoPauseThresh => r.fifoPauseThresh,  -- [in]
         fifoWrCnt       => fifoWrCnt,          -- [out]
         mAxisClk        => eventClk,           -- [in]
         mAxisRst        => eventRst,           -- [in]
         mAxisMaster     => eventAxisMaster,    -- [out]
         mAxisSlave      => eventAxisSlave);    -- [in]


end architecture rtl;

