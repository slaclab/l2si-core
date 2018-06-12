-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AdcSyncCal.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2018-06-08
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 Timing Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 Timing Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.NUMERIC_STD.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.TimingPkg.all;

library unisim;            
use unisim.vcomponents.all;  

entity AdcSyncCal is
  generic (
    TPD_G         : time    := 1 ns;
    SYNC_BITS_G   : integer := 4;
    NFMC_G        : integer := 1 );
  port (
    -- AXI-Lite Interface
    axiClk              : in  sl;
    axiRst              : in  sl;
    axilWriteMaster     : in  AxiLiteWriteMasterType;
    axilWriteSlave      : out AxiLiteWriteSlaveType;
    axilReadMaster      : in  AxiLiteReadMasterType;
    axilReadSlave       : out AxiLiteReadSlaveType;
    --delayLd             : out slv      (SYNC_BITS_G-1 downto 0 );
    --delayOut            : out Slv9Array(SYNC_BITS_G-1 downto 0 );
    --delayIn             : in  Slv9Array(SYNC_BITS_G-1 downto 0 );
    --
    evrClk              : in  sl;
    evrRst              : in  sl;
    evrBus              : in  TimingBusType;
    pllRstIn            : in  sl;
    pllRst              : out sl;
    adcClk              : in  slv(NFMC_G-1 downto 0);
    sync_p              : out slv(NFMC_G-1 downto 0);
    sync_n              : out slv(NFMC_G-1 downto 0) );
end AdcSyncCal;

architecture mapping of AdcSyncCal is

  type SyncStateType is ( IDLE_S, WAIT_S, END_S );

  type EvrRegType is record
    pllRst : sl;
    state  : SyncStateType;
    sync   : sl;
  end record;
  constant EVR_REG_INIT_C : EvrRegType := (
    pllRst => '1',
    state  => IDLE_S,
    sync   => '0' );

  signal re    : EvrRegType := EVR_REG_INIT_C;
  signal re_in : EvrRegType;

  type AxiRegType is record
    sync           : sl;
    delayLd        : slv      (NFMC_G-1 downto 0);
    delay          : Slv9Array(NFMC_G-1 downto 0);
    axilWriteSlave : AxiLiteWriteSlaveType;
    axilReadSlave  : AxiLiteReadSlaveType;
  end record;
  constant AXI_REG_INIT_C : AxiRegType := (
    sync           => '0',
    delayLd        => (others=>'0'),
    delay          => (others=>(others=>'0')),
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C );

  signal ra    : AxiRegType := AXI_REG_INIT_C;
  signal ra_in : AxiRegType;
  
  signal sreset    : sl;
  signal ssync     : sl;
  signal qsync     : slv(NFMC_G-1 downto 0);
  signal osync     : slv(NFMC_G-1 downto 0);
  signal delayOut  : Slv9Array(NFMC_G-1 downto 0);

begin 

  axilWriteSlave <= ra.axilWriteSlave;
  axilReadSlave  <= ra.axilReadSlave;

  pllRst         <= re.pllRst;
  
  comba : process ( ra, axiRst, delayOut, axilWriteMaster, axilReadMaster ) is
    variable v  : AxiRegType;
    variable ep : AxiLiteEndpointType;
    variable iw : integer;
  begin
    v         := ra;
    v.delayLd := (others=>'0');

    v.axilReadSlave.rdata := (others=>'0');

    axiSlaveWaitTxn(ep, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

    axiSlaveRegister(ep, x"00", 0, v.sync);
    axiSlaveRegister(ep, x"00",16, v.delayLd);

    for i in 0 to NFMC_G-1 loop
      axiSlaveRegister (ep, toSlv(16+8*i,8), 0, v.delay(i));
      axiSlaveRegisterR(ep, toSlv(20+8*i,8), 0, delayOut(i));
    end loop;

    axiSlaveDefault(ep, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_OK_C);

    if axiRst='1' then
      v := AXI_REG_INIT_C;
    end if;
    
    ra_in <= v;
  end process comba;

  seqa : process ( axiClk ) is
  begin
    if rising_edge(axiClk) then
      ra <= ra_in;
    end if;
  end process seqa;

  U_SyncPllRst : entity work.RstSync
    port map ( clk      => evrClk,
               asyncRst => pllRstIn,
               syncRst  => sreset );

  U_SyncSync : entity work.Synchronizer
    port map ( clk      => evrClk,
               dataIn   => ra.sync,
               dataOut  => ssync );

  GEN_ADCSYNC : for i in 0 to NFMC_G-1 generate
    U_SyncSyncQ : entity work.Synchronizer
      port map ( clk      => adcClk(i),
                 dataIn   => re.sync,
                 dataOut  => qsync(i) );

    U_BeamSync_Delay : ODELAYE3
      generic map ( DELAY_TYPE             => "VAR_LOAD",
                    DELAY_VALUE            => 0, -- 0 to 31
                    REFCLK_FREQUENCY       => 312.5,
                    DELAY_FORMAT           => "COUNT",
                    UPDATE_MODE            => "ASYNC" )
      port map ( CASC_RETURN            => '0',
                 CASC_IN                => '0',
                 CASC_OUT               => open,
                 CE                     => '1',
                 CLK                    => axiClk,
                 INC                    => '0',
                 LOAD                   => ra.delayLd(i),
                 CNTVALUEIN             => ra.delay  (i),
                 CNTVALUEOUT            => delayOut  (i),
                 
                 ODATAIN                => qsync(i),      -- Data from FPGA logic
                 DATAOUT                => osync(i),
                 RST                    => '0',
                 EN_VTC                 => '0'
                 );

    U_OBUF : OBUFDS
      port map ( I   => osync(i),
                 O   => sync_p(i),
                 OB  => sync_n(i) );
  end generate;
  
  combe: process (re, sreset, ssync, evrBus) is
    variable v : EvrRegType;
    variable sync : sl;
  begin
    v := re;
    v.sync := '0';

    sync := evrBus.strobe and not evrBus.message.pulseId(0);
    
    if sreset = '1' then
      v.pllRst := '1';
    elsif sync='1' then
      v.pllRst := '0';
    end if;   

    case re.state is
      when IDLE_S =>
        if ssync = '1' then
          v.state := WAIT_S;
        end if;
      when WAIT_S =>
        if sync='1' then
          v.sync  := '1';
          v.state := END_S;
        end if;
      when END_S =>
        if ssync = '0' then
          v.state := IDLE_S;
        end if;
    end case;
    
    re_in <= v;
    
  end process combe;

  seqe: process ( evrClk ) is
  begin
    if rising_edge(evrClk) then
      re <= re_in;
    end if;
  end process seqe;
  
end mapping;
