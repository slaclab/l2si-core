-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Firmware Target's Top Level
-- 
-- Note: Common-to-Application interface defined here (see URL below)
--       https://confluence.slac.stanford.edu/x/rLyMCw
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
use ieee.std_logic_arith.all;

library unisim;
use unisim.vcomponents.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.AxiLitePkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;
use lcls_timing_core.TPGPkg.all;

library l2si_core;
use l2si_core.XpmPkg.all;
use l2si_core.XpmMiniPkg.all;

entity XpmMiniWrapper is
   generic (
      TPD_G           : time             := 1 ns;
      NUM_DS_LINKS_G  : integer          := 1;
      AXIL_BASEADDR_G : slv(31 downto 0) := (others => '0'));
   port (
      --
      timingClk       : in  sl;
      timingRst       : in  sl;
      dsRxClk         : in  slv (NUM_DS_LINKS_G-1 downto 0);
      dsRxRst         : in  slv (NUM_DS_LINKS_G-1 downto 0);
      dsRx            : in  TimingRxArray (NUM_DS_LINKS_G-1 downto 0);
      dsTx            : out TimingPhyArray(NUM_DS_LINKS_G-1 downto 0);
      --
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end XpmMiniWrapper;

architecture top_level of XpmMiniWrapper is

   constant TPG_MINI_INDEX_C  : integer := 0;
   constant XPM_MINI_INDEX_C  : integer := 1;
   constant NUM_AXI_MASTERS_C : integer := 2;

   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) :=
      genAxiLiteConfig(NUM_AXI_MASTERS_C, AXIL_BASEADDR_G, 16, 12);

   signal mAxilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxilWriteSlaves  : AxiLiteWriteSlaveArray (NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxilReadMasters  : AxiLiteReadMasterArray (NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxilReadSlaves   : AxiLiteReadSlaveArray (NUM_AXI_MASTERS_C-1 downto 0);

   signal tpgStatus   : TPGStatusType;
   signal tpgConfig   : TPGConfigType;
   signal tpgStream   : TimingSerialType;
   signal tpgAdvance  : sl;
   signal tpgFiducial : sl;

   signal xpmStatus : XpmMiniStatusType;
   signal xpmConfig : XpmMiniConfigType;
   signal xpmStream : XpmMiniStreamType := XPM_MINI_STREAM_INIT_C;

   signal update : sl;

begin

   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => mAxilWriteMasters,
         mAxiWriteSlaves     => mAxilWriteSlaves,
         mAxiReadMasters     => mAxilReadMasters,
         mAxiReadSlaves      => mAxilReadSlaves);

   U_TPGReg : entity lcls_timing_core.TPGMiniReg
      generic map (
         TPD_G       => TPD_G,
         NARRAYS_BSA => 1,
         USE_WSTRB_G => false)
      port map (
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => mAxilReadMasters(TPG_MINI_INDEX_C),
         axiReadSlave   => mAxilReadSlaves (TPG_MINI_INDEX_C),
         axiWriteMaster => mAxilWriteMasters(TPG_MINI_INDEX_C),
         axiWriteSlave  => mAxilWriteSlaves(TPG_MINI_INDEX_C),
         irqActive      => '0',
         status         => tpgStatus,
         config         => tpgConfig);

   U_TPG : entity lcls_timing_core.TPGMini
      generic map (
         TPD_G       => TPD_G,
         NARRAYSBSA  => 1,
         STREAM_INTF => true)
      port map (
         -- Register Interface
         statusO    => tpgStatus,
         configI    => tpgConfig,
         -- TPG Interface
         txClk      => timingClk,
         txRst      => timingRst,
         txRdy      => '1',
         streams(0) => tpgStream,
         advance(0) => tpgAdvance,
         fiducial   => tpgFiducial);

   U_XpmReg : entity l2si_core.XpmMiniReg
      generic map (
         TPD_G => TPD_G)
      port map (
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => mAxilReadMasters(XPM_MINI_INDEX_C),
         axilReadSlave   => mAxilReadSlaves(XPM_MINI_INDEX_C),
         axilWriteMaster => mAxilWriteMasters(XPM_MINI_INDEX_C),
         axilWriteSlave  => mAxilWriteSlaves(XPM_MINI_INDEX_C),
         axilUpdate      => update,
         staClk          => timingClk,
         status          => xpmStatus,
         config          => xpmConfig);

   xpmStream.fiducial   <= tpgFiducial;
   xpmStream.advance(0) <= tpgAdvance;
   xpmStream.streams(0) <= tpgStream;

   tpgAdvance <= tpgStream.ready;

   U_Xpm : entity l2si_core.XpmMini
      generic map (
         TPD_G          => TPD_G,
         NUM_DS_LINKS_G => NUM_DS_LINKS_G)
      port map (
         regclk       => axilClk,
         regrst       => axilRst,
         update       => update,
         config       => xpmConfig,
         status       => xpmStatus,
         dsRxClk      => dsRxClk,
         dsRxRst      => dsRxRst,
         dsRx         => dsRx,
         dsTx         => dsTx,
         timingClk    => timingClk,
         timingRst    => timingRst,
         timingStream => xpmStream);

end top_level;

