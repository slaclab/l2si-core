------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DtiReg.vhd
-- Author     : Matt Weaver
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-12-14
-- Last update: 2017-04-12
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
      config           : out DtiConfigType );
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
  signal usLinkUp : slv(MaxUsLinks-1 downto 0);
  signal dsLinkUp : slv(MaxDsLinks-1 downto 0);
  signal bpLinkUp : sl;
  
begin

  config         <= r.config;
  axilReadSlave  <= r.axilReadSlave;
  axilWriteSlave <= r.axilWriteSlave;
  axilClear      <= r.clear;
  axilUpdate     <= r.update;

  iusStatus      <= status.usLink(conv_integer(r.usLink));
  idsStatus      <= status.dsLink(conv_integer(r.dsLink));

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
               dataIn  => status.bpLinkUp,
               dataOut => bpLinkUp );

  U_UsRxErrs : entity work.SynchronizerVector
    generic map ( WIDTH_G => 32 )
    port map ( clk     => axilClk,
               dataIn  => iusStatus.rxErrs,
               dataOut => usStatus.rxErrs );
  
  U_UsRxFull : entity work.SynchronizerVector
    generic map ( WIDTH_G => 32 )
    port map ( clk     => axilClk,
               dataIn  => iusStatus.rxFull,
               dataOut => usStatus.rxFull );
  
  U_UsIbReceived : entity work.SynchronizerVector
    generic map ( WIDTH_G => 48 )
    port map ( clk     => axilClk,
               dataIn  => iusStatus.ibReceived,
               dataOut => usStatus.ibReceived );
  
  U_DsRxErrs : entity work.SynchronizerVector
    generic map ( WIDTH_G => 32 )
    port map ( clk     => axilClk,
               dataIn  => idsStatus.rxErrs,
               dataOut => dsStatus.rxErrs );
  
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
  
  comb : process (r, axilRst, axilReadMaster, axilWriteMaster,
                  usLinkUp, dsLinkUp, usStatus, dsStatus, bpLinkUp ) is
    variable v          : RegType;
    variable axilStatus : AxiLiteStatusType;

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
      axilRegRW (toSlv(  16*i+0,12),  4, v.config.usLink(i).partition );
      axilRegRW (toSlv(  16*i+0,12),  8, v.config.usLink(i).trigDelay );
      axilRegRW (toSlv(  16*i+0,12), 16, v.config.usLink(i).fwdMask );
      axilRegRW (toSlv(  16*i+0,12), 31, v.config.usLink(i).fwdMode );
      axilRegRW (toSlv(  16*i+4,12),  0, v.config.usLink(i).dataSrc );
      axilRegRW (toSlv(  16*i+8,12),  0, v.config.usLink(i).dataType );
    end loop;

    for i in 0 to MaxUsLinks-1 loop
      axilRegR (toSlv( 16*7+0,12),  i, usLinkUp(i) );
    end loop;    
    axilRegR (toSlv( 16*7+0,12),  15, bpLinkUp);
    for i in 0 to MaxDsLinks-1 loop
      axilRegR (toSlv( 16*7+0,12), 16+i, dsLinkUp(i) );
    end loop;    

    axilRegRW (toSlv( 16*7+4,12),  0, v.usLink);
    axilRegRW (toSlv( 16*7+4,12), 16, v.dsLink);
    axilRegRW (toSlv( 16*7+4,12), 30, v.clear );
    axilRegRW (toSlv( 16*7+4,12), 31, v.update);

    axilRegR (toSlv( 16*8+0 ,12),  0, usStatus.rxErrs );
    axilRegR (toSlv( 16*8+4 ,12),  0, usStatus.rxFull );
    axilRegR (toSlv( 16*8+8 ,12),  0, usStatus.ibReceived(31 downto 0));
    axilRegR (toSlv( 16*8+12,12),  0, usStatus.ibReceived(47 downto 32));

    axilRegR (toSlv( 16*9+0 ,12),  0, dsStatus.rxErrs);
    axilRegR (toSlv( 16*9+4 ,12),  0, dsStatus.rxFull);
    axilRegR (toSlv( 16*9+8 ,12),  0, dsStatus.obSent(31 downto 0));
    axilRegR (toSlv( 16*9+12,12),  0, dsStatus.obSent(47 downto 32));

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
