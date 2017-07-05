-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpCore.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2017-06-28
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: DtiApp's Top Level
-- 
-- Note: Common-to-DtiApp interface defined here (see URL below)
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.Pgp2bPkg.all;

entity PgpCore is
   generic (
      TPD_G               : time                := 1 ns;
      AXI_CONFIG_G        : AxiStreamConfigType );
   port (
     coreClk         : in  sl;
     coreRst         : in  sl;
     gtRefClk        : in  sl;
     pgpRxP          : in  sl;
     pgpRxN          : in  sl;
     pgpTxP          : out sl;
     pgpTxN          : out sl;
     fifoRst         : in  sl;
     --
     axilClk         : in  sl;
     axilRst         : in  sl;
     axilReadMaster  : in  AxiLiteReadMasterType;
     axilReadSlave   : out AxiLiteReadSlaveType;
     axilWriteMaster : in  AxiLiteWriteMasterType;
     axilWriteSlave  : out AxiLiteWriteSlaveType;
     --  App Interface
     ibRst           : in  sl;
     linkUp          : out sl;
     rxErr           : out sl;
     full            : out sl;
     --
     obClk           : in  sl;
     obMaster        : in  AxiStreamMasterType;
     obSlave         : out AxiStreamSlaveType );
end PgpCore;

architecture rtl of PgpCore is

  signal pgpObMaster : AxiStreamMasterType;
  signal pgpObSlave  : AxiStreamSlaveType;

  signal pgpTxIn        : Pgp2bTxInType;
  signal pgpTxOut       : Pgp2bTxOutType;
  signal pgpRxIn        : Pgp2bRxInType;
  signal pgpRxOut       : Pgp2bRxOutType;
  signal pgpTxMasters   : AxiStreamMasterArray(3 downto 0) := (others=>AXI_STREAM_MASTER_INIT_C);
  signal pgpTxSlaves    : AxiStreamSlaveArray (3 downto 0);
  signal pgpRxMasters   : AxiStreamMasterArray(3 downto 0);
  signal pgpRxCtrls     : AxiStreamCtrlArray  (3 downto 0) := (others=>AXI_STREAM_CTRL_UNUSED_C);

  constant USER_ALMOST_FULL : integer := 0;
  
begin

  U_Fifo : entity work.AxiStreamFifo
    generic map (
      SLAVE_AXI_CONFIG_G  => AXI_CONFIG_G,
      MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C )
    port map ( 
      -- Slave Port
      sAxisClk    => obClk,
      sAxisRst    => fifoRst,
      sAxisMaster => obMaster,
      sAxisSlave  => obSlave,
      -- Master Port
      mAxisClk    => coreClk,
      mAxisRst    => fifoRst,
      mAxisMaster => pgpObMaster,
      mAxisSlave  => pgpObSlave );

  linkUp                   <= pgpRxOut.linkReady;
  rxErr                    <= pgpRxOut.frameRxErr;
  full                     <= pgpRxOut.remLinkData(USER_ALMOST_FULL);
  
  pgpTxMasters(0)          <= pgpObMaster;
  pgpObSlave               <= pgpTxSlaves(0);
  --  How to connect dmaIbSlave?
  
  U_Pgp2b : entity work.PgpFrontEnd
    port map ( pgpClk       => coreClk,
               pgpRst       => coreRst,
               stableClk    => axilClk,
               gtRefClk     => gtRefClk,
               --
               pgpTxIn      => pgpTxIn,
               pgpTxOut     => pgpTxOut,
               pgpRxIn      => pgpRxIn,
               pgpRxOut     => pgpRxOut,
               -- Frame TX Interface
               pgpTxMasters => pgpTxMasters,
               pgpTxSlaves  => pgpTxSlaves,
               -- Frame RX Interface
               pgpRxMasters => pgpRxMasters,
               pgpRxCtrl    => pgpRxCtrls,
               -- GT Pins
               gtTxP        => pgpTxP,
               gtTxN        => pgpTxN,
               gtRxP        => pgpRxP,
               gtRxN        => pgpRxN );

  U_Axi : entity work.Pgp2bAxi
    port map ( -- TX PGP Interface (pgpTxClk)
               pgpTxClk         => coreClk,
               pgpTxClkRst      => coreRst,
               pgpTxIn          => pgpTxIn,
               pgpTxOut         => pgpTxOut,
               -- RX PGP Interface (pgpRxClk)
               pgpRxClk         => coreClk,
               pgpRxClkRst      => coreRst,
               pgpRxIn          => pgpRxIn,
               pgpRxOut         => pgpRxOut,
               -- AXI-Lite Register Interface (axilClk domain)
               axilClk          => axilClk,
               axilRst          => axilRst,
               axilReadMaster   => axilReadMaster,
               axilReadSlave    => axilReadSlave,
               axilWriteMaster  => axilWriteMaster,
               axilWriteSlave   => axilWriteSlave );
          
end rtl;
