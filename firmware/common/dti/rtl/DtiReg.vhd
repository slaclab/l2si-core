------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DtiReg.vhd
-- Author     : Matt Weaver
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-12-14
-- Last update: 2017-11-17
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Software programmable register interface
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
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.AmcCarrierPkg.all;  -- ETH_AXIS_CONFIG_C
use work.DtiPkg.all;

entity DtiReg is
   port (
      axilClk          : in  sl;
      axilRst          : in  sl;
      axilClear        : out sl;
      axilUpdate       : out sl;
      axilWriteMaster  : in  AxiLiteWriteMasterType;  
      axilWriteSlave   : out AxiLiteWriteSlaveType;  
      axilReadMaster   : in  AxiLiteReadMasterType;  
      axilReadSlave    : out AxiLiteReadSlaveType;
      --
      status           : in  DtiStatusType;
      config           : out DtiConfigType;
      monclk           : in  slv(3 downto 0) );
end DtiReg;

architecture rtl of DtiReg is

  type StateType is (IDLE_S, READING_S);
  
  type RegType is record
    update         : sl;
    clear          : sl;
    config         : DtiConfigType;
    usLink         : slv(3 downto 0);
    dsLink         : slv(3 downto 0);
    axilReadSlave  : AxiLiteReadSlaveType;
    axilWriteSlave : AxiLiteWriteSlaveType;
  end record RegType;

  constant REG_INIT_C : RegType := (
    update         => '1',
    clear          => '0',
    config         => DTI_CONFIG_INIT_C,
    usLink         => (others=>'0'),
    dsLink         => (others=>'0'),
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C );

  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;

  signal usStatus, iusStatus : DtiUsLinkStatusType;
  signal dsStatus, idsStatus : DtiDsLinkStatusType;
  signal usApp   , iusApp    : DtiUsAppStatusType;
  signal usLinkUp : slv(MaxUsLinks-1 downto 0);
  signal dsLinkUp : slv(MaxDsLinks-1 downto 0);
  signal bpStatus : DtiBpLinkStatusType;
  signal qplllock : slv(status.qplllock'range);

  signal monClkRate : Slv32Array(3 downto 0);
  signal monClkLock : slv       (3 downto 0);
  signal monClkFast : slv       (3 downto 0);
  signal monClkSlow : slv       (3 downto 0);

  signal pllStat     : slv(3 downto 0);
  signal pllCount    : SlVectorArray(3 downto 0, 2 downto 0);
begin

  config         <= r.config;
  axilReadSlave  <= r.axilReadSlave;
  axilWriteSlave <= r.axilWriteSlave;
  axilClear      <= r.clear;
  axilUpdate     <= r.update;

  iusStatus      <= status.usLink(conv_integer(r.usLink));
  idsStatus      <= status.dsLink(conv_integer(r.dsLink));
  iusApp         <= status.usApp (conv_integer(r.usLink));

  GEN_USLINKUP : for i in 0 to MaxUsLinks-1 generate
    U_SYNC : entity work.Synchronizer
      port map ( clk     => axilClk,
                 dataIn  => status.usLink(i).linkUp,
                 dataOut => usLinkUp(i) );
  end generate;
  
  GEN_DSLINKUP : for i in 0 to MaxDsLinks-1 generate
    U_SYNC : entity work.Synchronizer
      port map ( clk     => axilClk,
                 dataIn  => status.dsLink(i).linkUp,
                 dataOut => dsLinkUp(i) );
  end generate;

  U_BPLINKUP : entity work.Synchronizer
    port map ( clk     => axilClk,
               dataIn  => status.bpLink.linkUp,
               dataOut => bpStatus.linkUp );

  U_BPSent : entity work.SynchronizerVector
    generic map ( WIDTH_G => 32 )
    port map ( clk     => axilClk,
               dataIn  => status.bpLink.obSent,
               dataOut => bpStatus.obSent );

  usStatus.rxErrs  <= iusStatus.rxErrs;

  U_UsRxInh : entity work.SynchronizerVector
    generic map ( WIDTH_G => 32 )
    port map ( clk     => axilClk,
               dataIn  => iusStatus.rxInh,
               dataOut => usStatus.rxInh );
  
  U_UsRemLinkID : entity work.SynchronizerVector
    generic map ( WIDTH_G => 8 )
    port map ( clk     => axilClk,
               dataIn  => iusStatus.remLinkID,
               dataOut => usStatus.remLinkID );
  
  U_UsRxFull : entity work.SynchronizerVector
    generic map ( WIDTH_G => 32 )
    port map ( clk     => axilClk,
               dataIn  => iusStatus.rxFull,
               dataOut => usStatus.rxFull );
  
  U_UsIbReceived : entity work.SynchronizerVector
    generic map ( WIDTH_G => 48 )
    port map ( clk     => axilClk,
               dataIn  => iusStatus.ibRecv,
               dataOut => usStatus.ibRecv );
  
  U_UsIbEvt : entity work.SynchronizerVector
    generic map ( WIDTH_G => 32 )
    port map ( clk     => axilClk,
               dataIn  => iusStatus.ibEvt,
               dataOut => usStatus.ibEvt );
  
  U_UsIbDump : entity work.SynchronizerVector
    generic map ( WIDTH_G => 32 )
    port map ( clk     => axilClk,
               dataIn  => iusStatus.ibDump,
               dataOut => usStatus.ibDump );
  
  U_UsObL0 : entity work.SynchronizerVector
    generic map ( WIDTH_G => 20 )
    port map ( clk     => axilClk,
               dataIn  => iusStatus.obL0,
               dataOut => usStatus.obL0 );
  
  U_UsObL1A : entity work.SynchronizerVector
    generic map ( WIDTH_G => 20 )
    port map ( clk     => axilClk,
               dataIn  => iusStatus.obL1A,
               dataOut => usStatus.obL1A );
  
  U_UsObL1R : entity work.SynchronizerVector
    generic map ( WIDTH_G => 20 )
    port map ( clk     => axilClk,
               dataIn  => iusStatus.obL1R,
               dataOut => usStatus.obL1R );

  U_UsWrFifoD : entity work.SynchronizerVector
    generic map ( WIDTH_G => 4 )
    port map ( clk     => axilClk,
               dataIn  => iusStatus.wrFifoD,
               dataOut => usStatus.wrFifoD );

  U_UsRdFifoD : entity work.SynchronizerVector
    generic map ( WIDTH_G => 4 )
    port map ( clk     => axilClk,
               dataIn  => iusStatus.rdFifoD,
               dataOut => usStatus.rdFifoD );
  
  dsStatus.rxErrs <= idsStatus.rxErrs;
  
  U_DsRemLinkID : entity work.SynchronizerVector
    generic map ( WIDTH_G => 8 )
    port map ( clk     => axilClk,
               dataIn  => idsStatus.remLinkID,
               dataOut => dsStatus.remLinkID );
  
  U_DsRxFull : entity work.SynchronizerVector
    generic map ( WIDTH_G => 32 )
    port map ( clk     => axilClk,
               dataIn  => idsStatus.rxFull,
               dataOut => dsStatus.rxFull );
  
  U_DsObSent : entity work.SynchronizerVector
    generic map ( WIDTH_G => 48 )
    port map ( clk     => axilClk,
               dataIn  => idsStatus.obSent,
               dataOut => dsStatus.obSent );
  
  U_AppObRecd : entity work.SynchronizerVector
    generic map ( WIDTH_G => 32 )
    port map ( clk     => axilClk,
               dataIn  => iusApp.obReceived,
               dataOut => usApp.obReceived );
  
  U_AppObSent : entity work.SynchronizerVector
    generic map ( WIDTH_G => 32 )
    port map ( clk     => axilClk,
               dataIn  => iusApp.obSent,
               dataOut => usApp.obSent );

  U_QpllLock : entity work.SynchronizerVector
    generic map ( WIDTH_G => status.qplllock'length )
    port map ( clk     => axilClk,
               dataIn  => status.qplllock,
               dataOut => qplllock );

  GEN_MONCLK : for i in 0 to 3 generate
    U_SYNC : entity work.SyncClockFreq
      generic map ( REF_CLK_FREQ_G => 156.25E+6,
                    CLK_LOWER_LIMIT_G =>  95.0E+6,
                    CLK_UPPER_LIMIT_G => 186.0E+6 )
      port map ( freqOut     => monClkRate(i),
                 freqUpdated => open,
                 locked      => monClkLock(i),
                 tooFast     => monClkFast(i),
                 tooSlow     => monClkSlow(i),
                 clkIn       => monClk(i),
                 locClk      => axilClk,
                 refClk      => axilClk );
  end generate;

  U_StatLol : entity work.SyncStatusVector
    generic map ( COMMON_CLK_G => true,
                  WIDTH_G      => 4,
                  CNT_WIDTH_G  => 3 )
    port map ( statusIn(0) => status.amcPll(0).los,
               statusIn(1) => status.amcPll(0).lol,
               statusIn(2) => status.amcPll(1).los,
               statusIn(3) => status.amcPll(1).lol,
               statusOut => pllStat,
               cntRstIn  => '0',
               rollOverEnIn => (others=>'1'),
               cntOut    => pllCount,
               wrClk     => axilClk,
               rdClk     => axilClk );

  comb : process (r, axilRst, axilReadMaster, axilWriteMaster, usApp,
                  usLinkUp, dsLinkUp, usStatus, dsStatus, bpStatus, qplllock,
                  monClkRate, monClkLock, monClkFast, monClkSlow,
                  pllStat, pllCount) is
    variable v          : RegType;
    variable axilStatus : AxiLiteStatusType;
    variable ra         : integer;

    -- Shorthand procedures for read/write register
    procedure axilRegRW(addr : in slv; offset : in integer; reg : inout slv) is
    begin
      axiSlaveRegister(axilWriteMaster, axilReadMaster,
                       v.axilWriteSlave, v.axilReadSlave, axilStatus,
                       addr, offset, reg, false, "0");
    end procedure;
    procedure axilRegRW(addr : in slv; offset : in integer; reg : inout sl) is
    begin
      axiSlaveRegister(axilWriteMaster, axilReadMaster,
                       v.axilWriteSlave, v.axilReadSlave, axilStatus,
                       addr, offset, reg, false, '0');
    end procedure;
    -- Shorthand procedures for read only registers
    procedure axilRegR (addr : in slv; offset : in integer; reg : in slv) is
    begin
      axiSlaveRegister(axilReadMaster, v.axilReadSlave, axilStatus,
                       addr, offset, reg);
    end procedure;
    procedure axilRegR (addr : in slv; offset : in integer; reg : in sl) is
    begin
      axiSlaveRegister(axilReadMaster, v.axilReadSlave, axilStatus,
                       addr, offset, reg);
    end procedure;

  begin
    v := r;

    -- Determine the transaction type
    axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);
    v.axilReadSlave.rdata := (others=>'0');

    for i in 0 to MaxUsLinks-1 loop
      axilRegRW (toSlv(  16*i+0,12),  0, v.config.usLink(i).enable );
      axilRegRW (toSlv(  16*i+0,12),  1, v.config.usLink(i).tagEnable );
      axilRegRW (toSlv(  16*i+0,12),  2, v.config.usLink(i).l1Enable );
      axilRegRW (toSlv(  16*i+0,12),  3, v.config.usLink(i).hdrOnly );
      axilRegRW (toSlv(  16*i+0,12),  4, v.config.usLink(i).partition );
--      axilRegRW (toSlv(  16*i+0,12),  8, v.config.usLink(i).trigDelay );
      axilRegRW (toSlv(  16*i+0,12), 16, v.config.usLink(i).fwdMask );
      axilRegRW (toSlv(  16*i+0,12), 31, v.config.usLink(i).fwdMode );
      axilRegRW (toSlv(  16*i+4,12),  0, v.config.usLink(i).dataSrc );
      axilRegRW (toSlv(  16*i+8,12),  0, v.config.usLink(i).dataType );
    end loop;

    for i in 0 to MaxUsLinks-1 loop
      axilRegR (toSlv( 16*7+0,12),  i, usLinkUp(i) );
    end loop;    
    axilRegR (toSlv( 16*7+0,12),  15, bpStatus.linkUp);
    for i in 0 to MaxDsLinks-1 loop
      axilRegR (toSlv( 16*7+0,12), 16+i, dsLinkUp(i) );
    end loop;    

    axilRegRW (toSlv( 16*7+4,12),  0, v.usLink);
    axilRegRW (toSlv( 16*7+4,12), 16, v.dsLink);
    axilRegRW (toSlv( 16*7+4,12), 30, v.clear );
    axilRegRW (toSlv( 16*7+4,12), 31, v.update);

    axilRegR (toSlv( 16*7+8,12), 0, bpStatus.obSent);
    
    axilRegR (toSlv( 16*8+0 ,12),  0, usStatus.rxErrs(23 downto 0) );
    axilRegR (toSlv( 16*8+0 ,12), 24, usStatus.remLinkID);
    axilRegR (toSlv( 16*8+4 ,12),  0, usStatus.rxFull );
--    axilRegR (toSlv( 16*8+8 ,12),  0, usStatus.ibRecv (31 downto 0));
    axilRegR (toSlv( 16*8+8 ,12),  0, usStatus.rxInh(23 downto 0) );
    axilRegR (toSlv( 16*8+8 ,12), 24, usStatus.wrFifoD );
    axilRegR (toSlv( 16*8+8 ,12), 28, usStatus.rdFifoD );
    axilRegR (toSlv( 16*8+12,12),  0, usStatus.ibEvt );

    axilRegR (toSlv( 16*9+0 ,12),  0, dsStatus.rxErrs(23 downto 0));
    axilRegR (toSlv( 16*9+0 ,12), 24, dsStatus.remLinkID);
    axilRegR (toSlv( 16*9+4 ,12),  0, dsStatus.rxFull);
    axilRegR (toSlv( 16*9+8 ,12),  0, dsStatus.obSent(31 downto 0));
    axilRegR (toSlv( 16*9+12,12),  0, dsStatus.obSent(47 downto 32));

    axilRegR (toSlv( 16*10+0 ,12),  0, usApp.obReceived);
    axilRegR (toSlv( 16*10+8 ,12),  0, usApp.obSent);

    axilRegR (toSlv( 16*11+0, 12),  0, qplllock);
    axilRegRW(toSlv( 16*11+0 ,12), 16, v.config.bpPeriod );
    
    for i in 0 to 3 loop
      axilRegR (toSlv( 16*11+4*i+4, 12),  0, monClkRate(i)(28 downto 0));
      axilRegR (toSlv( 16*11+4*i+4, 12), 29, monClkSlow(i));
      axilRegR (toSlv( 16*11+4*i+4, 12), 30, monClkFast(i));
      axilRegR (toSlv( 16*11+4*i+4, 12), 31, monClkLock(i));
    end loop;

    for i in 0 to 1 loop
      ra := 208+i*4;
      axilRegRW(toSlv(ra,12),  0, v.config.amcPll(i).bwSel);
      axilRegRW(toSlv(ra,12),  4, v.config.amcPll(i).frqTbl);
      axilRegRW(toSlv(ra,12),  8, v.config.amcPll(i).frqSel);
      axilRegRW(toSlv(ra,12), 16, v.config.amcPll(i).rate);
      axilRegRW(toSlv(ra,12), 20, v.config.amcPll(i).inc);
      axilRegRW(toSlv(ra,12), 21, v.config.amcPll(i).dec);
      axilRegRW(toSlv(ra,12), 22, v.config.amcPll(i).bypass);
      axilRegRW(toSlv(ra,12), 23, v.config.amcPll(i).rstn);
      axilRegR (toSlv(ra,12), 24, muxSlVectorArray( pllCount, 2*i+0));
      axilRegR (toSlv(ra,12), 27, pllStat(2*i+0));
      axilRegR (toSlv(ra,12), 28, muxSlVectorArray( pllCount, 2*i+1));
      axilRegR (toSlv(ra,12), 31, pllStat(2*i+1));
    end loop;
      
    -- Set the status
    axiSlaveDefault(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, AXI_RESP_OK_C);

    ----------------------------------------------------------------------------------------------
    -- Reset
    ----------------------------------------------------------------------------------------------
    if (axilRst = '1') then
      v := REG_INIT_C;
    end if;

    r_in <= v;
  end process;

  seq : process (axilClk) is
  begin
    if rising_edge(axilClk) then
      r <= r_in;
    end if;
  end process;
end rtl;
