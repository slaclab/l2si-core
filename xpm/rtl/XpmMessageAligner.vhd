-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: This module produces a realigned timing bus and XPM partition words
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

library l2si_core;
use l2si_core.XpmPkg.all;
use l2si_core.XpmExtensionPkg.all;

library unisim;
use unisim.vcomponents.all;

entity XpmMessageAligner is
   generic (
      TPD_G        : time    := 1 ns;
      COMMON_CLK_G : boolean := false;  -- true if axilClk = timingRxClk
      TF_DELAY_G   : integer := 100);   -- this is defunct
   port (
      timingRxClk : in sl;
      timingRxRst : in sl;

      -- Axi Lite bus for reading back current partitionDelays
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;

      xpmId : out slv(31 downto 0);

      -- Prompt timing data
      promptTimingStrobe  : in sl;
      promptTimingMessage : in TimingMessageType;  -- prompt
      promptXpmMessage    : in XpmMessageType;     -- prompt

      -- Aligned timing data
      alignedTimingStrobe  : out sl;
      alignedTimingMessage : out TimingMessageType;  -- delayed
      alignedXpmMessage    : out XpmMessageType);    -- delayed

end XpmMessageAligner;

architecture rtl of XpmMessageAligner is

   constant MAX_DELAY_C : integer := 120;

   type RegType is record
      txId            : slv(31 downto 0);
      rxId            : slv(31 downto 0);
      delayRst        : slv(3 downto 0);
      timingMsgDelay  : slv(6 downto 0);
      timingMsgIndex  : integer;
      partitionDelays : Slv7Array(XPM_PARTITIONS_C-1 downto 0);
      axilWriteSlave  : AxiLiteWriteSlaveType;
      axilReadSlave   : AxiLiteReadSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      txId            => (others => '0'),
      rxId            => (others => '1'),
      delayRst        => (others => '1'),
      timingMsgDelay  => toSlv(0, 7),
      timingMsgIndex  => 0,
      partitionDelays => (others => (others => '0')),
      axilWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave   => AXI_LITE_READ_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal promptTimingMessageSlv  : slv(TIMING_MESSAGE_BITS_NO_BSA_C-1 downto 0);
   signal alignedTimingMessageSlv : slv(TIMING_MESSAGE_BITS_NO_BSA_C-1 downto 0);
   signal alignedXpmMessageValid  : slv(XPM_PARTITIONS_C-1 downto 0);

   -- partition delay with TF_DELAY_G offset applied
   signal partitionDelays : Slv7Array(XPM_PARTITIONS_C-1 downto 0);

begin


   -----------------------------------------------
   -- Timing message delay
   -- Delay timing message by 100 (us) (nominal)
   -----------------------------------------------
   promptTimingMessageSlv <= toSlvNoBsa(promptTimingMessage);

--    U_SlvDelayRam_1 : entity surf.SlvDelayRam
--       generic map (
--          TPD_G            => TPD_G,
--          VECTOR_WIDTH_G   => TIMING_MESSAGE_BITS_NO_BSA_C,
--          RAM_ADDR_WIDTH_G => 7,
--          MEMORY_TYPE_G    => "block")
--       port map (
--          rst          => timingRxRst,                              -- [in]
--          clk          => timingRxClk,                              -- [in]
--          delay        => TF_DELAY_SLV_C,                           -- [in]
--          inputValid   => promptTimingStrobe,                       -- [in]
--          inputVector  => promptTimingMessageSlv,                   -- [in]
--          inputAddr    => promptTimingMessage.pulseId(6 downto 0),  -- [in]
--          outputValid  => alignedTimingStrobe,                      -- [out]
--          outputVector => alignedTimingMessageSlv);                 -- [out]

   U_SlvDelay_1 : entity surf.SlvDelay
      generic map (
         TPD_G        => TPD_G,
         SRL_EN_G     => true,
         DELAY_G      => MAX_DELAY_C+1,
         REG_OUTPUT_G => false,
         WIDTH_G      => TIMING_MESSAGE_BITS_NO_BSA_C)
      port map (
         clk   => timingRxClk,               -- [in]
         rst   => r.delayRst(0),             -- [in]
         en    => promptTimingStrobe,        -- [in]
         delay => r.timingMsgDelay,          -- [in]
         din   => promptTimingMessageSlv,    -- [in]
         dout  => alignedTimingMessageSlv);  -- [out]

   U_RegisterVector_1 : entity surf.RegisterVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 1)
      port map (
         clk      => timingRxClk,           -- [in]
         sig_i(0) => promptTimingStrobe,    -- [in]
         reg_o(0) => alignedTimingStrobe);  -- [out]

   alignedTimingMessage <= toTimingMessageType(alignedTimingMessageSlv);

   -----------------------------------------------
   -- Partition word delay
   -- Each of the 8 partition words is delayed by
   -- 100 - (r.partitionDelay(i))
   -- Partition words may arrive later than their
   -- corresponding timing message so this gets
   -- them back into alignment
   -----------------------------------------------

   GEN_PART : for i in 0 to XPM_PARTITIONS_C-1 generate

      partitionDelays(i) <= r.timingMsgDelay - r.partitionDelays(i);

      U_SlvDelay_2 : entity surf.SlvDelay
         generic map (
            TPD_G        => TPD_G,
            SRL_EN_G     => true,
            DELAY_G      => MAX_DELAY_C+1,
            REG_OUTPUT_G => false,
            WIDTH_G      => 49)
         port map (
            clk               => timingRxClk,                         -- [in]
            rst               => r.delayRst(0),                       -- [in]
            en                => promptTimingStrobe,                  -- [in]
            delay             => partitionDelays(i),                  -- [in]
            din(47 downto 0)  => promptXpmMessage.partitionWord(i),   -- [in]
            din(48)           => promptXpmMessage.valid,              -- [in]
            dout(47 downto 0) => alignedXpmMessage.partitionWord(i),  -- [out]
            dout(48)          => alignedXpmMessageValid(i));          -- [out]
   end generate;

   alignedXpmMessage.partitionAddr <= promptXpmMessage.partitionAddr;

   -- This never happens during normal running but could happen breifly after switching delays
   alignedXpmMessage.valid <= uAnd(alignedXpmMessageValid);

   comb : process(promptTimingStrobe, promptXpmMessage, r, timingRxRst) is
      variable v                : RegType;
      variable broadcastMessage : XpmBroadcastType;
   begin
      v := r;

      v.delayRst := '0' & r.delayRst(r.delayRst'left downto 1);

      if promptTimingStrobe = '1' then
         -- Update partitionDelays values when partitionAddr indicates new PDELAYs
         broadcastMessage := toXpmBroadcastType(promptXpmMessage.partitionAddr);
         if (broadcastMessage.btype = XPM_BROADCAST_PDELAY_C) then
            v.partitionDelays(broadcastMessage.index) := broadcastMessage.value;
            if (r.partitionDelays(broadcastMessage.index) /= broadcastMessage.value) then
               v.delayRst := (others => '1');
            end if;
            if (broadcastMessage.value > v.timingMsgDelay or
                broadcastMessage.index = v.timingMsgIndex) then
               v.timingMsgIndex := broadcastMessage.index;
               v.timingMsgDelay := broadcastMessage.value;
            end if;
         elsif (broadcastMessage.btype = XPM_BROADCAST_XADDR_C) then
            v.rxId := promptXpmMessage.partitionAddr;
         end if;
      end if;

      if timingRxRst = '1' then
         v := REG_INIT_C;
      end if;

      rin <= v;
   end process;

   seq : process (timingRxClk) is
   begin
      if rising_edge(timingRxClk) then
         r <= rin after TPD_G;
      end if;
   end process;

   U_XpmMessageAlignerReg : entity l2si_core.XpmMessageAlignerReg
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G)
      port map (
         timingRxClk     => timingRxClk,
         timingRxRst     => timingRxRst,
         partitionDelays => r.partitionDelays,
         rxId            => r.rxId,
         txId            => xpmId,
         -- Axi Lite bus for reading back current partitionDelays
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

end rtl;
