-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EventRealign.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2019-09-18
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

-- lcls-timing-core
use work.TimingPkg.all;

-- L2Si
use work.L2SiPkg.all;


library unisim;
use unisim.vcomponents.all;

entity EventRealign is
   generic (
      TPD_G      : time            := 1 ns;
      TF_DELAY_G : slv(6 downto 0) := toSlv(100, 7));
   port (
      rst                      : in  sl;
      clk                      : in  sl;
      promptTimingHeader       : in  TimingHeaderType;                                -- prompt
      promptExperimentMessage  : in  ExperimentMessageType;                           -- prompt
      alignedTimingHeader      : out TimingHeaderType;                                -- delayed
      alignedExperimentMessage : out ExperimentMessageType;                           -- delayed
      partitionDelays          : out Slv7Array(EXPERIMENT_PARTITIONS_C-1 downto 0));  -- 8 partitions
end EventRealign;

architecture rtl of EventRealign is


   type RegType is record
      rden   : sl;
      rdaddr : Slv7Array(EXPERIMENT_PARTITIONS_C downto 0);
      pdelay : Slv7Array(EXPERIMENT_PARTITIONS_C-1 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      rden   => '0',
      rdaddr => (others => (others => '0')),
      pdelay => (others => (others => '0')));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   constant EXPT_INIT_C : slv(47 downto 0) := x"000000008000";

begin

   delay <= r.pdelay;

   -- Write each timing header into ram buffer
   U_Ram : entity work.SimpleDualPortRam
      generic map (
         DATA_WIDTH_G => 129,
         ADDR_WIDTH_G => 7)
      port map (
         clka                 => clk,
         ena                  => '1',
         wea                  => promptTimingHeader.strobe,
         addra                => promptTimingHeader.pulseId(6 downto 0),
         dina(63 downto 0)    => promptTimingHeader.pulseId,
         dina(127 downto 64)  => promptTimingHeader.timeStamp,
         dina(128)            => promptExperimentMessage.valid,
         clkb                 => clk,
         rstb                 => rst,
         enb                  => r.rden,
         addrb                => r.rdaddr(EXPERIMENT_PARTITIONS_C),
         doutb(63 downto 0)   => alignedTimingHeader.pulseId,
         doutb(127 downto 64) => alignedTimingHeader.timeStamp,
         doutb(128)           => alignedExperimentMessage.valid);
   alignedTimingHeader.strobe <= r.rden;

   -- Write each experiment message partition word into ram buffer
   GEN_PART : for i in 0 to EXPERIMENT_PARTITIONS_C-1 generate
      U_Ram : entity work.SimpleDualPortRam
         generic map (
            DATA_WIDTH_G => 48,
            ADDR_WIDTH_G => 7,
            INIT_G       => EXPT_INIT_C)
         port map (
            clka  => clk,
            ena   => '1',
            wea   => promptTimingHeader.strobe,
            addra => promptTimingHeader.pulseId(6 downto 0),
            dina  => promptExperimentMessage.partitionWord(i),
            clkb  => clk,
            enb   => '1',
            addrb => r.rdaddr(i),
            doutb => alignedExperimentMessage.partitionWord(i));
   end generate;
   alignedExperimentMessage.partitionAddr <= promptExperimentMessage.partitionAddr;

   comb : process(r, rst, promptTimingHeader, promptExperimentMessage) is
      variable v            : RegType;
      variable delayMessage : ExperimentDelayDataType;
   begin
      v := r;

      v.rden := '0';

      if promptTimingHeader.strobe = '1' then
         v.rden                            := '1';
         v.rdaddr(EXPERIMENT_PARTITIONS_C) := promptTimingHeader.pulseId(6 downto 0) - TF_DELAY_G;
         for ip in 0 to EXPERIMENT_PARTITIONS_C-1 loop
            -- partition words delayed by additional pdelay
            v.rdaddr(ip) := promptTimingHeader.pulseId(6 downto 0) - TF_DELAY_G + r.pdelay(ip);
         end loop;

         -- Update pdelay values when partitionAddr indicates new PDELAYs
         delayMessage := toExperimentDelayType(promptExperimentMessage.partitionAddr);
         if (delayMessage.valid = '1') then
            v.pdelay(delayMessage.index) := delayMessage.data
         end if;
      end if;

      if rst = '1' then
         v := REG_INIT_C;
      end if;

      rin <= v;
   end process;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process;

end rtl;
