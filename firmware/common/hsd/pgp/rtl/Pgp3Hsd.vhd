------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Pgp3Hsd.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2017-12-24
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: DtiApp's Top Level
-- 
--   Application interface to JungFrau.  Uses 10GbE.  Trigger is external TTL
--   (L0 only?). Control register access is external 1GbE link.
--
--   Intercept out-bound messages as register transactions for 10GbE core.
--   Use simulation embedding: ADDR(31:1) & RNW & DATA(31:0).
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.XpmPkg.all;
use work.DtiPkg.all;
use work.Pgp3Pkg.all;
use work.SsiPkg.all;

entity Pgp3Hsd is
   generic (
      TPD_G               : time                := 1 ns;
      ID_G                : slv(7 downto 0)     := (others=>'0');
      ENABLE_TAG_G        : boolean             := false ;
      DEBUG_G             : boolean             := false ;
      AXIL_BASE_ADDR_G    : slv(31 downto 0)    := (others=>'0');
      AXIS_CONFIG_G       : AxiStreamConfigType );
   port (
     coreClk         : in  sl;
     coreRst         : in  sl;
     pgpRxP          : in  sl;
     pgpRxN          : in  sl;
     pgpTxP          : out sl;
     pgpTxN          : out sl;
     fifoRst         : in  sl;
     -- Quad PLL Ports
     qplllock        : in  sl;
     qplloutclk      : in  sl;
     qplloutrefclk   : in  sl;
     qpllRst         : out sl;
     --
     axilClk         : in  sl;
     axilRst         : in  sl;
     axilReadMaster  : in  AxiLiteReadMasterType;
     axilReadSlave   : out AxiLiteReadSlaveType;
     axilWriteMaster : in  AxiLiteWriteMasterType;
     axilWriteSlave  : out AxiLiteWriteSlaveType;
     --
     ibRst           : in  sl;
     linkUp          : out sl;
     rxErr           : out sl;
     --
     obClk           : in  sl;
     obMaster        : in  AxiStreamMasterType;
     obSlave         : out AxiStreamSlaveType );
end Pgp3Hsd;

architecture top_level_app of Pgp3Hsd is

  signal pgpObMaster : AxiStreamMasterType;
  signal pgpObSlave  : AxiStreamSlaveType;

  signal pgpTxIn        : Pgp3TxInType := PGP3_TX_IN_INIT_C;
  signal pgpTxOut       : Pgp3TxOutType;
  signal pgpRxIn        : Pgp3RxInType := PGP3_RX_IN_INIT_C;
  signal pgpRxOut       : Pgp3RxOutType;
  signal pgpTxMasters   : AxiStreamMasterArray(NUM_DTI_VC_C-1 downto 0) := (others=>AXI_STREAM_MASTER_INIT_C);
  signal pgpTxSlaves    : AxiStreamSlaveArray (NUM_DTI_VC_C-1 downto 0);
  signal pgpRxMasters   : AxiStreamMasterArray(NUM_DTI_VC_C-1 downto 0);
  signal pgpRxCtrls     : AxiStreamCtrlArray  (NUM_DTI_VC_C-1 downto 0) := (others=>AXI_STREAM_CTRL_UNUSED_C);

  signal pgpClk         : sl;
  signal pgpRst         : sl;

  signal iqpllRst       : sl;
  signal full           : sl;
begin

  U_Fifo : entity work.AxiStreamFifoV2
    generic map (
      SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G,
      MASTER_AXI_CONFIG_G => PGP3_AXIS_CONFIG_C,
      FIFO_ADDR_WIDTH_G   => 9,
      PIPE_STAGES_G       => 2 )
    port map ( 
      -- Slave Port
      sAxisClk    => obClk,
      sAxisRst    => fifoRst,
      sAxisMaster => obMaster,
      sAxisSlave  => obSlave,
      -- Master Port
      mAxisClk    => pgpClk,
      mAxisRst    => fifoRst,
      mAxisMaster => pgpObMaster,
      mAxisSlave  => pgpObSlave );

  linkUp                   <= pgpRxOut.linkReady;
  rxErr                    <= pgpRxOut.frameRxErr;
  qpllRst                  <= iqpllRst;
  
  process (pgpObMaster, full) is
  begin
    pgpTxMasters(0)          <= pgpObMaster;
    pgpTxMasters(0).tValid   <= pgpObMaster.tValid and not full;
  end process;

  pgpObSlave               <= pgpTxSlaves(0);

  U_PgpFb : entity work.DtiPgp3Fb
    port map ( pgpClk       => pgpClk,
               pgpRst       => pgpRst,
               pgpRxOut     => pgpRxOut,
               rxAlmostFull => full );

  U_Pgp3 : entity work.Pgp3GthUs
    generic map ( NUM_VC_G     => NUM_DTI_VC_C,
                  EN_DRP_G     => false,
                  EN_PGP_MON_G => false,
                  AXIL_BASE_ADDR_G => AXIL_BASE_ADDR_G )
    port map ( -- Stable Clock and Reset
               stableClk    => axilClk,
               stableRst    => axilRst,
               -- QPLL Interface
               qpllLock  (0)=> qplllock,
               qpllLock  (1)=> '0',
               qpllclk   (0)=> qplloutclk,
               qpllclk   (1)=> '0',
               qpllrefclk(0)=> qplloutrefclk,
               qpllrefclk(1)=> '0',
               qpllRst   (0)=> iqpllRst,
               qpllRst   (1)=> open,
               -- Gt Serial IO
               pgpGtTxP     => pgpTxP,
               pgpGtTxN     => pgpTxN,
               pgpGtRxP     => pgpRxP,
               pgpGtRxN     => pgpRxN,
               -- Clocking
               pgpClk       => pgpClk,
               pgpClkRst    => pgpRst,
               -- Non VC Tx Signals
               pgpTxIn      => pgpTxIn,
               pgpTxOut     => pgpTxOut,
               -- Non VC Rx Signals
               pgpRxIn      => pgpRxIn,
               pgpRxOut     => pgpRxOut,
               -- Frame TX Interface
               pgpTxMasters => pgpTxMasters,
               pgpTxSlaves  => pgpTxSlaves,
               -- Frame RX Interface
               pgpRxMasters => pgpRxMasters,
               pgpRxCtrl    => pgpRxCtrls,
               -- AXI-Lite Register Interface
               axilClk         => axilClk,
               axilRst         => axilRst,
               axilReadMaster  => axilReadMaster,
               axilReadSlave   => axilReadSlave,
               axilWriteMaster => axilWriteMaster,
               axilWriteSlave  => axilWriteSlave );

  end top_level_app;
