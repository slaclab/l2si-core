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
use l2si_core.XpmPkg.all;
use l2si_core.XpmExtensionPkg.all;

entity TriggerEventBufferReg is
   generic (
      TPD_G               : time     := 1 ns;
      COMMON_CLK_G        : boolean  := false;  -- true if axilClk = timingRxClk
      FIFO_ADDR_WIDTH_G   : positive := 5;
      EN_LCLS_I_TIMING_G  : boolean  := false;
      EN_LCLS_II_TIMING_G : boolean  := true);
   port (
      timingRxClk       : in  sl;
      timingRxRst       : in  sl;
      overflow          : in  sl;
      fifoAxisCtrl      : in  AxiStreamCtrlType;
      fifoWrCnt         : in  slv(FIFO_ADDR_WIDTH_G-1 downto 0);
      timingMode        : in  sl;
      triggerCount      : in  slv(31 downto 0);
      pause             : in  sl;
      l0Count           : in  slv(31 downto 0);
      l1AcceptCount     : in  slv(31 downto 0);
      l1RejectCount     : in  slv(31 downto 0);
      transitionCount   : in  slv(31 downto 0);
      validCount        : in  slv(31 downto 0);
      alignedXpmMessage : in  XpmMessageType;
      pauseToTrig       : in  slv(11 downto 0);
      notPauseToTrig    : in  slv(11 downto 0);
      enable            : out sl;
      fifoRst           : out sl;
      resetCounters     : out sl;
      partition         : out slv(2 downto 0);
      triggerDelay      : out slv(31 downto 0);
      fifoPauseThresh   : out slv(FIFO_ADDR_WIDTH_G-1 downto 0);
      -- AXI Lite bus for configuration and status
      axilClk           : in  sl;
      axilRst           : in  sl;
      axilReadMaster    : in  AxiLiteReadMasterType;
      axilReadSlave     : out AxiLiteReadSlaveType;
      axilWriteMaster   : in  AxiLiteWriteMasterType;
      axilWriteSlave    : out AxiLiteWriteSlaveType);
end entity TriggerEventBufferReg;

architecture rtl of TriggerEventBufferReg is

   type RegType is record
      enable          : sl;
      fifoRst         : sl;
      resetCounters   : sl;
      partition       : slv(2 downto 0);
      triggerDelay    : slv(31 downto 0);
      fifoPauseThresh : slv(FIFO_ADDR_WIDTH_G-1 downto 0);
      axilReadSlave   : AxiLiteReadSlaveType;
      axilWriteSlave  : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      enable          => '0',
      fifoRst         => '0',
      resetCounters   => '0',
      partition       => (others => '0'),
      triggerDelay    => toSlv(42, 32),
      fifoPauseThresh => toslv(16, FIFO_ADDR_WIDTH_G),
      axilReadSlave   => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal overflowSync        : sl;
   signal fifoAxisCtrlSync    : AxiStreamCtrlType;
   signal fifoWrCntSync       : slv(FIFO_ADDR_WIDTH_G-1 downto 0);
   signal timingModeSync      : sl;
   signal triggerCountSync    : slv(31 downto 0);
   signal pauseSync           : sl;
   signal l0CountSync         : slv(31 downto 0);
   signal l1AcceptCountSync   : slv(31 downto 0);
   signal l1RejectCountSync   : slv(31 downto 0);
   signal transitionCountSync : slv(31 downto 0);
   signal validCountSync      : slv(31 downto 0);
   signal partitionAddrSync   : slv(XPM_PARTITION_ADDR_LENGTH_C-1 downto 0);
   signal partitionWord0Sync  : slv(47 downto 0);
   signal pauseToTrigSync     : slv(11 downto 0);
   signal notPauseToTrigSync  : slv(11 downto 0);

begin

   U_SyncVecIn : entity surf.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G,
         WIDTH_G       => 5)
      port map (
         clk        => axilClk,
         -- Input
         dataIn(0)  => overflow,
         dataIn(1)  => fifoAxisCtrl.pause,
         dataIn(2)  => fifoAxisCtrl.overflow,
         dataIn(3)  => timingMode,
         dataIn(4)  => pause,
         -- Output
         dataOut(0) => overflowSync,
         dataOut(1) => fifoAxisCtrlSync.pause,
         dataOut(2) => fifoAxisCtrlSync.overflow,
         dataOut(3) => timingModeSync,
         dataOut(4) => pauseSync);

   U_fifoWrCnt : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => FIFO_ADDR_WIDTH_G)
      port map (
         rst    => timingRxRst,
         wr_clk => timingRxClk,
         din    => fifoWrCnt,
         rd_clk => axilClk,
         dout   => fifoWrCntSync);

   U_triggerCount : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => 32)
      port map (
         rst    => timingRxRst,
         wr_clk => timingRxClk,
         din    => triggerCount,
         rd_clk => axilClk,
         dout   => triggerCountSync);

   GEN_LCLS_II_TIMING_G : if (EN_LCLS_II_TIMING_G) generate

      U_l0Count : entity surf.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            COMMON_CLK_G => COMMON_CLK_G,
            DATA_WIDTH_G => 32)
         port map (
            rst    => timingRxRst,
            wr_clk => timingRxClk,
            din    => l0Count,
            rd_clk => axilClk,
            dout   => l0CountSync);

      U_l1AcceptCount : entity surf.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            COMMON_CLK_G => COMMON_CLK_G,
            DATA_WIDTH_G => 32)
         port map (
            rst    => timingRxRst,
            wr_clk => timingRxClk,
            din    => l1AcceptCount,
            rd_clk => axilClk,
            dout   => l1AcceptCountSync);

      U_l1RejectCount : entity surf.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            COMMON_CLK_G => COMMON_CLK_G,
            DATA_WIDTH_G => 32)
         port map (
            rst    => timingRxRst,
            wr_clk => timingRxClk,
            din    => l1RejectCount,
            rd_clk => axilClk,
            dout   => l1RejectCountSync);

      U_transitionCount : entity surf.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            COMMON_CLK_G => COMMON_CLK_G,
            DATA_WIDTH_G => 32)
         port map (
            rst    => timingRxRst,
            wr_clk => timingRxClk,
            din    => transitionCount,
            rd_clk => axilClk,
            dout   => transitionCountSync);

      U_validCount : entity surf.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            COMMON_CLK_G => COMMON_CLK_G,
            DATA_WIDTH_G => 32)
         port map (
            rst    => timingRxRst,
            wr_clk => timingRxClk,
            din    => validCount,
            rd_clk => axilClk,
            dout   => validCountSync);

      U_partitionAddr : entity surf.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            COMMON_CLK_G => COMMON_CLK_G,
            DATA_WIDTH_G => XPM_PARTITION_ADDR_LENGTH_C)
         port map (
            rst    => timingRxRst,
            wr_clk => timingRxClk,
            wr_en  => alignedXpmMessage.valid,
            din    => alignedXpmMessage.partitionAddr,
            rd_clk => axilClk,
            dout   => partitionAddrSync);

      U_partitionWord0 : entity surf.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            COMMON_CLK_G => COMMON_CLK_G,
            DATA_WIDTH_G => 48)
         port map (
            rst    => timingRxRst,
            wr_clk => timingRxClk,
            wr_en  => alignedXpmMessage.valid,
            din    => alignedXpmMessage.partitionWord(0),
            rd_clk => axilClk,
            dout   => partitionWord0Sync);

      U_pauseToTrig : entity surf.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            COMMON_CLK_G => COMMON_CLK_G,
            DATA_WIDTH_G => 32)
         port map (
            rst    => timingRxRst,
            wr_clk => timingRxClk,
            din    => pauseToTrig,
            rd_clk => axilClk,
            dout   => pauseToTrigSync);

      U_notPauseToTrig : entity surf.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            COMMON_CLK_G => COMMON_CLK_G,
            DATA_WIDTH_G => 32)
         port map (
            rst    => timingRxRst,
            wr_clk => timingRxClk,
            din    => notPauseToTrig,
            rd_clk => axilClk,
            dout   => notPauseToTrigSync);

   end generate;

   comb : process (axilReadMaster, axilRst, axilWriteMaster, fifoAxisCtrlSync,
                   fifoWrCntSync, l0CountSync, l1AcceptCountSync,
                   l1RejectCountSync, notPauseToTrigSync, overflowSync,
                   partitionAddrSync, partitionWord0Sync, pauseSync,
                   pauseToTrigSync, r, timingModeSync, transitionCountSync,
                   triggerCountSync, validCountSync) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      v := r;

      -- Pulsed for 1 cycle
      v.fifoRst       := '0';
      v.resetCounters := '0';

      --------------------------------------------
      -- Axi lite interface
      --------------------------------------------
      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Common Registers
      axiSlaveRegister(axilEp, x"00", 0, v.enable);
      axiSlaveRegisterR(axilEp, x"10", 0, overflowSync);
      axiSlaveRegisterR(axilEp, X"10", 2, fifoAxisCtrlSync.overflow);
      axiSlaveRegisterR(axilEp, X"10", 3, fifoAxisCtrlSync.pause);
      axiSlaveRegisterR(axilEp, X"10", 4, fifoWrCntSync);
      axiSlaveRegisterR(axilEp, X"10", 16, timingModeSync);
      axiSlaveRegisterR(axilEp, X"10", 17, toSl(EN_LCLS_I_TIMING_G));
      axiSlaveRegisterR(axilEp, X"10", 18, toSl(EN_LCLS_II_TIMING_G));
      axiSlaveRegister(axilEp, X"10", 31, v.fifoRst);
      axiSlaveRegisterR(axilEp, X"28", 0, triggerCountSync);
      axiSlaveRegister(axilEp, X"40", 0, v.resetCounters);

      -- LCLS-II only registers
      if (EN_LCLS_II_TIMING_G) then
         axiSlaveRegister(axilEp, x"04", 0, v.partition);
         axiSlaveRegister(axilEp, X"0C", 0, v.triggerDelay);
         axiSlaveRegister(axilEp, X"08", 0, v.fifoPauseThresh);
         axiSlaveRegisterR(axilEp, X"10", 1, pauseSync);
         axiSlaveRegisterR(axilEp, x"14", 0, l0CountSync);
         axiSlaveRegisterR(axilEp, x"18", 0, l1AcceptCountSync);
         axiSlaveRegisterR(axilEp, x"1C", 0, l1RejectCountSync);
         axiSlaveRegisterR(axilEp, X"20", 0, transitionCountSync);
         axiSlaveRegisterR(axilEp, X"24", 0, validCountSync);
         axiSlaveRegisterR(axilEp, X"2C", 0, partitionAddrSync);
         axiSlaveRegisterR(axilEp, X"30", 0, partitionWord0Sync);
         axiSlaveRegisterR(axilEp, X"38", 0, pauseToTrigSync);
         axiSlaveRegisterR(axilEp, X"3C", 0, notPauseToTrigSync);
      end if;

      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      -- outputs
      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;

   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_SyncVecOut : entity surf.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G,
         WIDTH_G       => 1)
      port map (
         clk        => timingRxClk,
         dataIn(0)  => r.enable,
         dataOut(0) => enable);

   U_fifoRst : entity surf.SynchronizerOneShot
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G)
      port map (
         clk     => timingRxClk,
         dataIn  => r.fifoRst,
         dataOut => fifoRst);

   U_resetCounters : entity surf.SynchronizerOneShot
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G)
      port map (
         clk     => timingRxClk,
         dataIn  => r.resetCounters,
         dataOut => resetCounters);

   U_partition : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => 3)
      port map (
         rst    => timingRxRst,
         wr_clk => axilClk,
         din    => r.partition,
         rd_clk => timingRxClk,
         dout   => partition);

   U_triggerDelay : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => 32)
      port map (
         rst    => timingRxRst,
         wr_clk => axilClk,
         din    => r.triggerDelay,
         rd_clk => timingRxClk,
         dout   => triggerDelay);

   U_fifoPauseThresh : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => FIFO_ADDR_WIDTH_G)
      port map (
         rst    => timingRxRst,
         wr_clk => axilClk,
         din    => r.fifoPauseThresh,
         rd_clk => timingRxClk,
         dout   => fifoPauseThresh);

end architecture rtl;
