-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DtiDsPgp5Gb.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2017-06-30
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

library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.DtiPkg.all;
use work.Pgp2bPkg.all;

entity DtiDsPgp5Gb is
   generic (
      TPD_G               : time                := 1 ns;
      ID_G                : integer             := 0 );
   port (
     coreClk         : in  sl;
     coreRst         : in  sl;
     gtRefClk        : in  sl;
     amcRxP          : in  sl;
     amcRxN          : in  sl;
     amcTxP          : out sl;
     amcTxN          : out sl;
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
end DtiDsPgp5Gb;

architecture rtl of DtiDsPgp5Gb is

  constant ID_C    : slv( 7 downto 0) := toSlv(ID_G,8);

  signal amcObMaster : AxiStreamMasterType;
  signal amcObSlave  : AxiStreamSlaveType;

  signal pgpTxIn        : Pgp2bTxInType;
  signal pgpTxOut       : Pgp2bTxOutType;
  signal pgpRxIn        : Pgp2bRxInType;
  signal pgpRxOut       : Pgp2bRxOutType;
  signal pgpTxMasters   : AxiStreamMasterArray(3 downto 0) := (others=>AXI_STREAM_MASTER_INIT_C);
  signal pgpTxSlaves    : AxiStreamSlaveArray (3 downto 0);
  signal pgpRxMasters   : AxiStreamMasterArray(3 downto 0);
  signal pgpRxCtrls     : AxiStreamCtrlArray  (3 downto 0) := (others=>AXI_STREAM_CTRL_UNUSED_C);

  constant USER_ALMOST_FULL : integer := 0;

  signal pgpClk         : sl;
  signal pgpRst         : sl;

begin

  pgpRst <= ibRst;
  
  U_Fifo : entity work.AxiStreamFifo
    generic map (
      SLAVE_AXI_CONFIG_G  => US_OB_CONFIG_C,
      MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C )
    port map ( 
      -- Slave Port
      sAxisClk    => obClk,
      sAxisRst    => fifoRst,
      sAxisMaster => obMaster,
      sAxisSlave  => obSlave,
      -- Master Port
      mAxisClk    => pgpClk,
      mAxisRst    => fifoRst,
      mAxisMaster => amcObMaster,
      mAxisSlave  => amcObSlave );

  linkUp                   <= pgpRxOut.linkReady;
  rxErr                    <= pgpRxOut.frameRxErr;
  full                     <= pgpRxOut.remLinkData(USER_ALMOST_FULL);
  
  pgpTxMasters(0)          <= amcObMaster;
  amcObSlave               <= pgpTxSlaves(0);
  --  How to connect dmaIbSlave?
  
  -- assuming 156.25MHz ref clk
  --U_Pgp2b : entity work.Pgp2bGth7VarLatWrapper
  --  generic map ( CPLL_FBDIV_G    => 4,
  --                CPLL_FBDIV_45_G => 4,
  --                RXOUT_DIV_G     => 1,
  --                TXOUT_DIV_G     => 1,
  --                RXCDR_CFG_G     => x"0001107FE206021041010",
  --                NUM_VC_EN_G     => 4 )
  --  port map ( pgpClk       => amcClk,
  --             pgpRst       => amcRst,
  --             pgpTxIn      => pgpTxIn,
  --             pgpTxOut     => pgpTxOut,
  --             pgpRxIn      => pgpRxIn,
  --             pgpRxOut     => pgpRxOut,
  --             -- Frame TX Interface
  --             pgpTxMasters => pgpTxMasters,
  --             pgpTxSlaves  => pgpTxSlaves,
  --             -- Frame RX Interface
  --             pgpRxMasters => pgpRxMasters,
  --             pgpRxCtrl    => pgpRxCtrls,
  --             -- GT Pins
  --             gtTxP        => amcTxP,
  --             gtTxN        => amcTxN,
  --             gtRxP        => amcRxP,
  --             gtRxN        => amcRxN );
  U_Pgp2b : entity work.MpsPgpFrontEnd
--    generic map ( DEBUG_G => ite(ID_G>0, false, true) )
    port map ( pgpClk       => pgpClk,
               pgpRst       => pgpRst,
               stableClk    => axilClk,
               gtRefClk     => gtRefClk,
               txOutClk     => pgpClk,
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
               gtTxP        => amcTxP,
               gtTxN        => amcTxN,
               gtRxP        => amcRxP,
               gtRxN        => amcRxN );

  U_Axi : entity work.Pgp2bAxi
    generic map ( AXI_CLK_FREQ_G => 156.25E+6 )
    port map ( -- TX PGP Interface (pgpTxClk)
               pgpTxClk         => pgpClk,
               pgpTxClkRst      => pgpRst,
               pgpTxIn          => pgpTxIn,
               pgpTxOut         => pgpTxOut,
               -- RX PGP Interface (pgpRxClk)
               pgpRxClk         => pgpClk,
               pgpRxClkRst      => pgpRst,
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
