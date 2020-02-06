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

library lcls_timing_core;
use lcls_timing_core.TimingExtnPkg.all;
use lcls_timing_core.TimingPkg.all;
use surf.AxiLitePkg.all;
use lcls_timing_core.TPGPkg.all;

library l2si_core;
use l2si_core.XpmPkg.all;
use l2si_core.XpmMiniPkg.all;

library unisim;
use unisim.vcomponents.all;

entity XpmMiniSim is
   port (
      configI : in  slv(19 downto 0);
      txClk   : in  sl;
      txRst   : in  sl;
      txRdy   : in  sl;
      txData  : out slv(15 downto 0);
      txDataK : out slv(1 downto 0));
end XpmMiniSim;

architecture top_level_app of XpmMiniSim is

   signal timingClk   : sl;
   signal timingRst   : sl;
   signal timingBus   : TimingBusType;
   signal tpgStatus   : TPGStatusType;
   signal tpgConfig   : TPGConfigType := TPG_CONFIG_INIT_C;
   signal tpgStream   : TimingSerialType;
   signal tpgAdvance  : sl;
   signal tpgFiducial : sl;

   signal xpmConfig : XpmMiniConfigType := XPM_MINI_CONFIG_INIT_C;
   signal xpmStream : XpmStreamType     := XPM_STREAM_INIT_C;

   signal dsTx : TimingPhyType := TIMING_PHY_INIT_C;

begin

   timingClk <= txClk;
   timingRst <= txRst;

   tpgConfig.pulseIdWrEn          <= '0';
   tpgConfig.FixedRateDivisors(1) <= configI;

   process is
   begin
      xpmConfig.partition.l0Select.reset      <= '1';
      wait for 1 us;
      xpmConfig.partition.l0Select.reset      <= '0';
      xpmConfig.partition.pipeline.depth_clks <= toSlv(0, 16);
      xpmConfig.partition.pipeline.depth_fids <= toSlv(99, 8);
      wait for 10 us;
      xpmConfig.partition.l0Select.enabled    <= '1';
      xpmConfig.partition.l0Select.rateSel    <= x"0001";
      xpmConfig.partition.l0Select.destSel    <= x"8000";  -- DontCare
      wait;
   end process;

   U_TPG : entity lcls_timing_core.TPGMini
      generic map (
         NARRAYSBSA  => 1,
         STREAM_INTF => true)
      port map (
         -- Register Interface
         statusO     => tpgStatus,
         configI     => tpgConfig,
         -- TPG Interface
         txClk       => timingClk,
         txRst       => timingRst,
         txRdy       => '1',
         streams (0) => tpgStream,
         advance (0) => tpgAdvance,
         fiducial    => tpgFiducial);

   xpmStream.fiducial   <= tpgFiducial;
   xpmStream.advance(0) <= tpgAdvance;
   xpmStream.streams(0) <= tpgStream;

   tpgAdvance <= tpgStream.ready;

   U_Xpm : entity l2si_core.XpmMini
      generic map (
         NDsLinks => 1)
      port map (
         regclk       => timingClk,
         regrst       => timingRst,
         update       => '0',
         config       => xpmConfig,
         status       => open,
         dsRxClk (0)  => timingClk,
         dsRxRst (0)  => timingRst,
         dsRx (0)     => TIMING_RX_INIT_C,
         dsTx (0)     => dsTx,
         timingClk    => timingClk,
         timingRst    => timingRst,
         timingStream => xpmStream);

   txData  <= dsTx.data;
   txDataK <= dsTx.dataK;

end top_level_app;
