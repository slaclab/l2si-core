-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : XpmGthUltrascaleTWrapper.vhd
-- Author     : Matt Weaver
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-12-14
-- Last update: 2018-12-01
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Interface to sensor link MGT
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 XPM Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 XPM Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.TimingPkg.all;
use work.XpmPkg.all;

library unisim;
use unisim.vcomponents.all;


entity XpmGthUltrascaleTWrapper is
   generic ( GTGCLKRX   : boolean := true;
             USE_IBUFDS : boolean := true );
   port (
      gtTxP            : out sl;
      gtTxN            : out sl;
      gtRxP            : in  sl;
      gtRxN            : in  sl;
      --  Transmit clocking
      devClkP          : in  sl := '0';
      devClkN          : in  sl := '0';
      devClkIn         : in  sl := '0';
      devClkOut        : out sl;
      --  Receive clocking
      timRefClkP       : in  sl;
      timRefClkN       : in  sl;
      --
      stableClk        : in  sl;
      txData           : in  slv(15 downto 0);
      txDataK          : in  slv( 1 downto 0);
      rxData           : out TimingRxType;
      rxClk            : out sl;
      rxRst            : out sl;
      txClk            : out sl;
      txClkIn          : in  sl;
      config           : in  XpmLinkConfigType;
      status           : out XpmLinkStatusType );
end XpmGthUltrascaleTWrapper;

architecture rtl of XpmGthUltrascaleTWrapper is

COMPONENT gt_xpm_timing
  PORT (
    gtwiz_userclk_tx_active_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_active_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_tx_reset_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_tx_start_user_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_tx_done_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_tx_error_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_rx_reset_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_rx_start_user_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_rx_done_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_rx_error_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_clk_freerun_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_all_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_pll_and_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_pll_and_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_cdr_stable_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_done_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_done_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userdata_tx_in : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    gtwiz_userdata_rx_out : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    gtrefclk01_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll1outclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll1outrefclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    drpclk_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthrxn_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthrxp_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtrefclk0_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rx8b10ben_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxcommadeten_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxmcommaalignen_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxpcommaalignen_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxusrclk_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxusrclk2_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    tx8b10ben_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txctrl0_in : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    txctrl1_in : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    txctrl2_in : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    txusrclk_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txusrclk2_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthtxn_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthtxp_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtpowergood_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxbyteisaligned_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxbyterealign_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxcommadet_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxctrl0_out : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    rxctrl1_out : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    rxctrl2_out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    rxctrl3_out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    rxoutclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxpmaresetdone_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    txoutclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    txpmaresetdone_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
  );
END COMPONENT;

  type RegType is record
    clkcnt  : slv(5 downto 0);
    errdet  : sl;
    reset   : sl;
  end record;
  constant REG_INIT_C : RegType := (
    clkcnt  => (others=>'0'),
    errdet  => '0',
    reset   => '0' );

  constant ERR_INTVL : slv(5 downto 0) := (others=>'1');
  
  signal r    : RegType := REG_INIT_C;
  signal rin  : RegType;
  
  signal txCtrl2In  : slv( 7 downto 0);
  signal rxCtrl0Out : slv(15 downto 0);
  signal rxCtrl1Out : slv(15 downto 0);
  signal rxCtrl3Out : slv( 7 downto 0);

  signal txOutClk   : sl;
  signal txUsrClk   : sl;
  signal gtTxRefClk : sl;
  signal gtRxRefClk : sl;
  signal drpClk, idrpClk : sl;
  
  signal rxErrL    : sl;
  signal rxErrS    : sl;
  signal rxErrCnts : slv(15 downto 0);

  signal rxOutClk  : sl;
  signal rxUsrClk  : sl;
  signal rxFifoRst : sl;
  signal rxErrIn   : sl;

  signal rxReset      : sl;
  signal rxResetDone  : sl;
 
  signal rxbypassrst  : sl;
  signal txbypassrst  : sl;

  signal loopback  : slv(2 downto 0);

begin

  rxClk   <= rxUsrClk;
  rxRst   <= rxFifoRst;
  txClk   <= txUsrClk;

  GEN_IBUFDS : if USE_IBUFDS generate
    DEVCLK_IBUFDS_GTE3 : IBUFDS_GTE3
      generic map (
        REFCLK_EN_TX_PATH  => '0',
        REFCLK_HROW_CK_SEL => "01",    -- 2'b01: ODIV2 = Divide-by-2 version of O
        REFCLK_ICNTL_RX    => "00")
      port map (
        I     => devClkP,
        IB    => devClkN,
        CEB   => '0',
        ODIV2 => open,
        O     => gtTxRefClk);
  end generate;

  NO_GEN_IBUFDS : if not USE_IBUFDS generate
    gtTxRefClk <= devClkIn;
  end generate;

  TIMREFCLK_IBUFDS_GTE3 : IBUFDS_GTE3
    generic map (
      REFCLK_EN_TX_PATH  => '0',
      REFCLK_HROW_CK_SEL => "00",    -- 2'b01: ODIV2 = Divide-by-2 version of O
      REFCLK_ICNTL_RX    => "00")
    port map (
      I     => timRefClkP,
      IB    => timRefClkN,
      CEB   => '0',
      ODIV2 => idrpClk,
      O     => gtRxRefClk);

  U_BUFG_GT : BUFG_GT
    port map ( O       => drpClk,
               CE      => '1',
               CEMASK  => '1',
               CLR     => '0',
               CLRMASK => '1',
               DIV     => "000",           -- Divide-by-1
               I       => idrpClk );

  devClkOut  <= gtTxRefClk;
  
  txCtrl2In  <= "000000" & txDataK;
  rxData.decErr <= rxCtrl3Out(1 downto 0);
  rxData.dspErr <= rxCtrl1Out(1 downto 0);
  rxErrL        <= '1' when (rxCtrl1Out(1 downto 0)/="00" or rxCtrl3Out(1 downto 0)/="00") else '0';
  rxFifoRst  <= not rxResetDone;
  loopback   <= "0" & config.loopback & "0";
  status    .rxErr       <= rxErrS;
  status    .rxErrCnts   <= rxErrCnts;
  status    .rxReady     <= rxResetDone;
  rxReset    <= config.rxReset or r.reset;
    
  U_STATUS : entity work.SynchronizerOneShotCnt
    generic map ( CNT_WIDTH_G => 16 )
    port map ( dataIn       => rxErrL,
               dataOut      => rxErrS,
               rollOverEn   => '1',
               cntOut       => rxErrCnts,
               wrClk        => rxUsrClk ,
               rdClk        => stableClk );

  U_BUFG  : BUFG_GT
    port map (  I       => rxOutClk,
                CE      => '1',
                CEMASK  => '1',
                CLR     => '0',
                CLRMASK => '1',
                DIV     => "000",
                O       => rxUsrClk );

  --U_TXBUFG  : BUFG_GT
  --  port map (  I       => txOutClk(0),
  --              CE      => '1',
  --              CEMASK  => '1',
  --              CLR     => '0',
  --              CLRMASK => '1',
  --              DIV     => "000",
  --              O       => txUsrClk );
  txUsrClk <= txClkIn;
  
  rxErrL   <= rxErrIn;
  rxClk    <= rxUsrClk;
  rxRst    <= rxFifoRst;

  rxData.dataK  <= rxCtrl0Out(1 downto 0);

  U_RstSyncTx : entity work.RstSync
    port map ( clk      => txUsrClk,
               asyncRst => config.txReset,
               syncRst  => txbypassrst );

  U_RstSyncRx : entity work.RstSync
    port map ( clk      => rxUsrClk,
               asyncRst => rxReset,
               syncRst  => rxbypassrst );

  U_GthCore : gt_xpm_timing
    PORT MAP (
      gtwiz_userclk_tx_active_in           => "1",
      gtwiz_userclk_rx_active_in           => "1",
      gtwiz_buffbypass_tx_reset_in     (0) => txbypassrst,
      gtwiz_buffbypass_tx_start_user_in    => "0",
      gtwiz_buffbypass_tx_done_out     (0) => status.txResetDone,
      gtwiz_buffbypass_tx_error_out        => open,
      gtwiz_buffbypass_rx_reset_in     (0) => rxbypassrst,
      gtwiz_buffbypass_rx_start_user_in    => "0",
      gtwiz_buffbypass_rx_done_out     (0) => status.rxResetDone,
      gtwiz_buffbypass_rx_error_out        => open,  -- Might need this
      gtwiz_reset_clk_freerun_in       (0) => drpClk,
      gtwiz_reset_all_in                   => "0",
      gtwiz_reset_tx_pll_and_datapath_in(0)=> config.txPllReset,
      gtwiz_reset_tx_datapath_in        (0)=> config.txReset,
      gtwiz_reset_rx_pll_and_datapath_in(0)=> config.rxPllReset,
      gtwiz_reset_rx_datapath_in        (0)=> rxReset,
      gtwiz_reset_rx_cdr_stable_out        => open,
      gtwiz_reset_tx_done_out           (0)=> status.txReady,
      gtwiz_reset_rx_done_out           (0)=> rxResetDone,
      gtwiz_userdata_tx_in                 => txData,
      gtwiz_userdata_rx_out                => rxData.data,
      -- QPLL
      gtrefclk01_in                     (0)=> gtRxRefClk,
      qpll1outclk_out                      => open,
      qpll1outrefclk_out                   => open,
      -- CPLL
      gtrefclk0_in                      (0)=> gtTxRefClk,
      drpclk_in                         (0)=> drpClk,
      gthrxn_in                         (0)=> gtRxN,
      gthrxp_in                         (0)=> gtRxP,
--      loopback_in                       (0)=> loopback,
      rx8b10ben_in                         => (others=>'1'),
      rxcommadeten_in                      => (others=>'1'),
      rxmcommaalignen_in                   => (others=>'1'),
      rxpcommaalignen_in                   => (others=>'1'),
      rxusrclk_in                       (0)=> rxUsrClk,
      rxusrclk2_in                      (0)=> rxUsrClk,
      tx8b10ben_in                         => (others=>'1'),
      txctrl0_in                           => (others=>'0'),
      txctrl1_in                           => (others=>'0'),
      txctrl2_in                           => txCtrl2In,
      txusrclk_in                       (0)=> txUsrClk,
      txusrclk2_in                      (0)=> txUsrClk,
      gthtxn_out                        (0)=> gtTxN,
      gthtxp_out                        (0)=> gtTxP,
      rxbyteisaligned_out                  => open,
      rxbyterealign_out                    => open,
      rxcommadet_out                       => open,
      rxctrl0_out                          => rxCtrl0Out,
      rxctrl1_out                          => rxCtrl1Out,
      rxctrl2_out                          => open,
      rxctrl3_out                          => rxCtrl3Out,
      rxoutclk_out                      (0)=> rxOutClk,
      rxpmaresetdone_out                   => open,
      txoutclk_out                      (0)=> txOutClk,
      txpmaresetdone_out                   => open
      );

  comb : process ( r, rxResetDone, rxErrIn ) is
    variable v : RegType;
  begin
    v := r;

    if rxErrIn='1' then
      if r.errdet='1' then
        v.reset := '1';
      else
        v.errdet := '1';
      end if;
    end if;

    if r.reset='0' then
      v.clkcnt := r.clkcnt+1;
      if r.clkcnt=ERR_INTVL then
        v.errdet := '0';
        v.clkcnt := (others=>'0');
      end if;
    end if;

    if rxResetDone='0' then
      v := REG_INIT_C;
    end if;
    
    rin <= v;
  end process comb;

  seq : process ( rxUsrClk ) is
  begin
    if rising_edge(rxUsrClk) then
      r <= rin;
    end if;
  end process seq;

end rtl;
