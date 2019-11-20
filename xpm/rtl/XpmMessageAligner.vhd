-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EventRealign.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2019-11-20
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- This module produces a realigned timing header and expt bus.
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
      TPD_G      : time    := 1 ns;
      TF_DELAY_G : integer := 100);
   port (
      clk : in sl;
      rst : in sl;

      -- Axi Lite bus for reading back current partitionDelays
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


   type RegType is record
      xpmId           : slv(31 downto 0);
      partitionDelays : Slv7Array(XPM_PARTITIONS_C-1 downto 0);
      axilWriteSlave  : AxiLiteWriteSlaveType;
      axilReadSlave   : AxiLiteReadSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      xpmId           => (others => '0'),
      partitionDelays => (others => (others => '0')),
      axilWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave   => AXI_LITE_READ_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal promptTimingMessageSlv  : slv(TIMING_MESSAGE_BITS_NO_BSA_C-1 downto 0);
   signal alignedTimingMessageSlv : slv(TIMING_MESSAGE_BITS_NO_BSA_C-1 downto 0);
   signal alignedXpmMessageValid  : slv(XPM_PARTITIONS_C-1 downto 0);

begin


   -----------------------------------------------
   -- Timing message delay
   -- Delay timing message by 100 (us) (nominal)
   -----------------------------------------------
   promptTimingMessageSlv <= toSlvNoBsa(promptTimingMessage);

   U_SlvDelayRam_1 : entity surf.SlvDelayRam
      generic map (
         TPD_G            => TPD_G,
         VECTOR_WIDTH_G   => TIMING_MESSAGE_BITS_NO_BSA_C,
         BASE_DELAY_G     => TF_DELAY_G,
         RAM_ADDR_WIDTH_G => 7,
         MEMORY_TYPE_G    => "block")
      port map (
         rst          => rst,                                      -- [in]
         clk          => clk,                                      -- [in]
         delay        => (others => '0'),                          -- [in]
         inputValid   => promptTimingStrobe,                       -- [in]
         inputVector  => promptTimingMessageSlv,                   -- [in]         
         inputAddr    => promptTimingMessage.pulseId(6 downto 0),  -- [in]
         outputValid  => alignedTimingStrobe,                      -- [out]
         outputVector => alignedTimingMessageSlv);                 -- [out]

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
      U_SlvDelayRam_2 : entity surf.SlvDelayRam
         generic map (
            TPD_G            => TPD_G,
            VECTOR_WIDTH_G   => 49,
            BASE_DELAY_G     => TF_DELAY_G,
            RAM_ADDR_WIDTH_G => 7,
            MEMORY_TYPE_G    => "block")
         port map (
            rst                       => rst,   -- [in]
            clk                       => clk,   -- [in]
            delay                     => r.partitionDelays(i),    -- [in]
            inputValid                => promptTimingStrobe,      -- [in]
            inputVector(47 downto 0)  => promptXpmMessage.partitionWord(i),        -- [in]
            inputVector(48)           => promptXpmMessage.valid,  -- [in]            
            inputAddr                 => promptTimingMessage.pulseId(6 downto 0),  -- [in]
            outputValid               => open,  -- [in] (in theory will always be the same as alignedTimingStrobe
            outputVector(47 downto 0) => alignedXpmMessage.partitionWord(i),       -- [out]
            outputVector(48)          => alignedXpmMessageValid(i));               -- [out]
   end generate;

   -- Maybe zero this out?
   alignedXpmMessage.partitionAddr <= promptXpmMessage.partitionAddr;

   -- This never happens during normal running but could happen breifly after switching delays   
   alignedXpmMessage.valid <= uAnd(alignedXpmMessageValid);

   comb : process(axilReadMaster, axilWriteMaster, promptXpmMessage, promptTimingStrobe, r, rst) is
      variable v                : RegType;
      variable axilEp           : AxiLiteEndpointType;
      variable broadcastMessage : XpmBroadcastType;
   begin
      v := r;

      if promptTimingStrobe = '1' then
         -- Update partitionDelays values when partitionAddr indicates new PDELAYs
         broadcastMessage := toXpmBroadcastType(promptXpmMessage.partitionAddr);
         if (broadcastMessage.btype = XPM_BROADCAST_PDELAY_C) then
            v.partitionDelays(broadcastMessage.index) := broadcastMessage.value;
         end if;
      end if;

      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      for i in 0 to XPM_PARTITIONS_C-1 loop
         axiSlaveRegisterR(axilEp, X"00"+ toSlv(i*4, 8), 0, r.partitionDelays(i));
      end loop;

      axiSlaveRegister(axilEp, X"20", 0, v.xpmId);

      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      if rst = '1' then
         v := REG_INIT_C;
      end if;

      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;
      xpmId          <= r.xpmId;

      rin <= v;
   end process;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process;

end rtl;
