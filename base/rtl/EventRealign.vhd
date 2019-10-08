-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EventRealign.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2019-10-08
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
use ieee.std_logic_unsigned.all;

-- SURF
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

-- lcls-timing-core
use work.TimingPkg.all;

-- L2Si
use work.L2SiPkg.all;


library unisim;
use unisim.vcomponents.all;

entity EventRealign is
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
      promptTimingStrobe      : in sl;
      promptTimingMessage     : in TimingMessageType;      -- prompt
      promptExperimentMessage : in ExperimentMessageType;  -- prompt

      -- Aligned timing data
      alignedTimingStrobe      : out sl;
      alignedTimingMessage     : out TimingMessageType;       -- delayed
      alignedExperimentMessage : out ExperimentMessageType);  -- delayed

end EventRealign;

architecture rtl of EventRealign is


   type RegType is record
      xpmId           : slv(31 downto 0);
      partitionDelays : Slv7Array(EXPERIMENT_PARTITIONS_C-1 downto 0);
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

   signal promptTimingMessageSlv        : slv(TIMING_MESSAGE_BITS_NO_BSA_C-1 downto 0);
   signal alignedTimingMessageSlv       : slv(TIMING_MESSAGE_BITS_NO_BSA_C-1 downto 0);
   signal alignedExperimentMessageValid : slv(EXPERIMENT_PARTITIONS_C-1 downto 0);

begin


   -----------------------------------------------
   -- Timing message delay
   -- Delay timing message by 100 (us) (nominal)
   -----------------------------------------------
   promptTimingMessageSlv <= toSlvNoBsa(promptTimingMessage);

   U_SlvDelayRam_1 : entity work.SlvDelayRam
      generic map (
         TPD_G            => TPD_G,
         VECTOR_WIDTH_G   => TIMING_MESSAGE_BITS_NO_BSA_C,
         BASE_DELAY_G     => TF_DELAY_G,
         RAM_ADDR_WIDTH_G => 7,
         BRAM_EN_G        => true)
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
   GEN_PART : for i in 0 to EXPERIMENT_PARTITIONS_C-1 generate
      U_SlvDelayRam_2 : entity work.SlvDelayRam
         generic map (
            TPD_G            => TPD_G,
            VECTOR_WIDTH_G   => 49,
            BASE_DELAY_G     => TF_DELAY_G,
            RAM_ADDR_WIDTH_G => 7,
            BRAM_EN_G        => true)
         port map (
            rst                       => rst,                                        -- [in]
            clk                       => clk,                                        -- [in]
            delay                     => r.partitionDelays(i),                       -- [in]
            inputValid                => promptTimingStrobe,                         -- [in]
            inputVector(47 downto 0)  => promptExperimentMessage.partitionWord(i),   -- [in]
            inputVector(48)           => promptExperimentMessage.valid,              -- [in]            
            inputAddr                 => promptTimingMessage.pulseId(6 downto 0),    -- [in]
            outputValid               => open,                                       -- [in] (in theory will always be the same as alignedTimingStrobe
            outputVector(47 downto 0) => alignedExperimentMessage.partitionWord(i),  -- [out]
            outputVector(48)          => alignedExperimentMessageValid(i));          -- [out]
   end generate;

   -- Maybe zero this out?
   alignedExperimentMessage.partitionAddr <= promptExperimentMessage.partitionAddr;

   -- This never happens during normal running but could happen breifly after switching delays   
   alignedExperimentMessage.valid <= uAnd(alignedExperimentMessageValid);

   comb : process(axilReadMaster, axilWriteMaster, promptExperimentMessage, promptTimingStrobe, r, rst) is
      variable v            : RegType;
      variable axilEp       : AxiLiteEndpointType;
      variable delayMessage : ExperimentDelayType;
   begin
      v := r;

      if promptTimingStrobe = '1' then
         -- Update partitionDelays values when partitionAddr indicates new PDELAYs
         delayMessage := toExperimentDelayType(promptExperimentMessage.partitionAddr);
         if (delayMessage.valid = '1') then
            v.partitionDelays(delayMessage.index) := delayMessage.value;
         end if;
      end if;

      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      for i in 0 to EXPERIMENT_PARTITIONS_C-1 loop
         axiSlaveRegisterR(axilEp, X"00"+ i*4, 0, r.partitionDelays(i));
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
