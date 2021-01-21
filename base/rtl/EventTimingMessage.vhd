-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Converts eventTimingMessages into an AXI Stream bus
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
use surf.AxiStreamPkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

entity EventTimingMessage is
   generic (
      TPD_G               : time                 := 1 ns;
      PIPE_STAGES_G       : natural              := 0;
      NUM_DETECTORS_G     : integer range 1 to 8 := 8;
      EVENT_AXIS_CONFIG_G : AxiStreamConfigType);
   port (
      -- Clock and Reset
      eventClk                 : in  sl;
      eventRst                 : in  sl;
      -- Input Streams
      eventTimingMessagesValid : in  slv(NUM_DETECTORS_G-1 downto 0);
      eventTimingMessages      : in  TimingMessageArray(NUM_DETECTORS_G-1 downto 0);
      eventTimingMessagesRd    : out slv(NUM_DETECTORS_G-1 downto 0);
      -- Output Streams
      eventTimingMsgMasters    : out AxiStreamMasterArray(NUM_DETECTORS_G-1 downto 0);
      eventTimingMsgSlaves     : in  AxiStreamSlaveArray(NUM_DETECTORS_G-1 downto 0));
end entity EventTimingMessage;

architecture mapping of EventTimingMessage is

   constant TIM_AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 48,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 0,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   function toSlvFormatted(msg : TimingMessageType) return slv is
      variable v : slv(383 downto 0) := (others => '0');
      variable i : integer           := 0;
   begin
      assignSlv(i, v, msg.pulseId);                  -- [63:0]
      assignSlv(i, v, msg.fixedRates(9 downto 0));   -- [73:64]
      assignSlv(i, v, msg.acRates(5 downto 0));      -- [79:74]
      assignSlv(i, v, resize(msg.acTimeSlot, 8));    -- [87:80]
      assignSlv(i, v, msg.beamRequest(7 downto 0));  -- [95:88]
      for j in msg.control'range loop                -- [383:96]
         assignSlv(i, v, msg.control(j));
      end loop;
      return v;
   end function;

   signal axisMasters : AxiStreamMasterType := axiStreamMasterInit(TIM_AXIS_CONFIG_C);
   signal axisSlaves  : AxiStreamSlaveType;

begin

   GEN_DETECTORS : for i in NUM_DETECTORS_G-1 downto 0 generate

      axisMasters(i).tValid              <= eventTimingMessagesValid(i);
      axisMasters(i).tData(383 downto 0) <= toSlvFormatted(eventTimingMessages(i));
      axisMasters(i).tLast               <= '1';
      eventTimingMessagesRd(i)           <= axisSlaves(i).tReady;

      U_Resize : entity surf.AxiStreamGearbox
         generic map (
            TPD_G               => TPD_G,
            PIPE_STAGES_G       => PIPE_STAGES_G,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => TIM_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => EVENT_AXIS_CONFIG_G)
         port map (
            axisClk     => eventClk,
            axisRst     => eventRst,
            -- Slave Port
            sAxisMaster => axisMasters(i),
            sAxisSlave  => axisSlaves(i),
            -- Master Port
            mAxisMaster => eventTimingMsgMasters(i),
            mAxisSlave  => eventTimingMsgSlaves(i));

   end generate GEN_DETECTORS;

end mapping;
