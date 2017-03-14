-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AdcSyncCal.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2017-03-13
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

entity AdcSyncCal is
  generic (
    TPD_G         : time    := 1 ns;
    SYNC_BITS_G   : integer := 4;
    ENABLE_CAL_G  : boolean := false;
    EVR_PERIOD_G  : integer := 14;
    SYNC_PERIOD_G : integer := 147 );
  port (
    -- AXI-Lite Interface
    axiClk              : in  sl;
    axiRst              : in  sl;
    axilWriteMaster     : in  AxiLiteWriteMasterType;
    axilWriteSlave      : out AxiLiteWriteSlaveType;
    axilReadMaster      : in  AxiLiteReadMasterType;
    axilReadSlave       : out AxiLiteReadSlaveType;
    delayLd             : out slv      (SYNC_BITS_G-1 downto 0 );
    delayOut            : out Slv9Array(SYNC_BITS_G-1 downto 0 );
    delayIn             : in  Slv9Array(SYNC_BITS_G-1 downto 0 );
    --
    evrClk              : in  sl;
    trigSlot            : in  sl;
    trigSel             : in  sl;
    trigOut             : out sl;
    --
    syncClk             : in  sl;
    sync                : in  Slv8Array(SYNC_BITS_G-1 downto 0 ) );
end AdcSyncCal;

architecture mapping of AdcSyncCal is

  type HistoArray is array (natural range <>) of Slv16Array(7 downto 0);

  type EvrRegType is record
    strobe: sl;
    count : slv(3 downto 0);
  end record;
  constant EVR_REG_INIT_C : EvrRegType := (
    strobe => '0',
    count  => (others=>'0') );

  signal re    : EvrRegType := EVR_REG_INIT_C;
  signal re_in : EvrRegType;

  type StateType is (S_IDLE, S_SET_DELAY, S_TEST_DELAY);
  constant DELAY_STIME : slv(14 downto 0) := toSlv(8,15);
  type Slv512Array is array (natural range <>) of slv(511 downto 0);

  type AxiRegType is record
    state          : StateType;
    count          : slv(14 downto 0);
    matchTime      : slv(14 downto 0);
    calibrate      : sl;
    test           : sl;
    channel        : slv(1 downto 0);
    word           : slv(3 downto 0);
    match          : Slv512Array(SYNC_BITS_G-1 downto 0);
    matchw         : slv(511 downto 0);
    delayLd        : slv(SYNC_BITS_G-1 downto 0);
    delay          : Slv9Array(SYNC_BITS_G-1 downto 0);
    axilWriteSlave : AxiLiteWriteSlaveType;
    axilReadSlave  : AxiLiteReadSlaveType;
  end record;
  constant AXI_REG_INIT_C : AxiRegType := (
    state          => S_IDLE,
    count          => (others=>'0'),
    matchTime      => toSlv(2048,15),
    calibrate      => '0',
    test           => '0',
    channel        => "00",
    word           => x"0",
    match          => (others=>(others=>'0')),
    matchw         => (others=>'0'),
    delayLd        => (others=>'0'),
    delay          => (others=>(others=>'0')),
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C );

  signal ra    : AxiRegType := AXI_REG_INIT_C;
  signal ra_in : AxiRegType;
  
  signal stest     : sl;
  signal etest     : sl;
  signal match     : slv(SYNC_BITS_G-1 downto 0);
  signal amatch    : slv(SYNC_BITS_G-1 downto 0);
  signal delayInS  : Slv9Array (SYNC_BITS_G-1 downto 0);

  signal r_state : slv(2 downto 0);
  
begin 

  trigOut        <= re.strobe;
  delayOut       <= ra.delay;
  delayLd        <= ra.delayLd;
  axilWriteSlave <= ra.axilWriteSlave;
  axilReadSlave  <= ra.axilReadSlave;

  GEN_DelayIn : for i in 0 to SYNC_BITS_G-1 generate
    U_SyncDelayIn : entity work.SynchronizerVector
      generic map ( WIDTH_G => 9 )
      port map ( clk     => axiClk,
                 dataIn  => delayIn(i),
                 dataOut => delayInS(i) );
  end generate GEN_DelayIn;

  comba : process ( ra, axiRst, delayInS, match, axilWriteMaster, axilReadMaster ) is
    variable v  : AxiRegType;
    variable axilStatus : AxiLiteStatusType;
    variable iw : integer;
  begin
    v         := ra;
    v.delayLd := (others=>'0');
    v.count   := ra.count+1;
    v.matchw  := ra.match(conv_integer(ra.channel));
    v.axilReadSlave.rdata := (others=>'0');

    iw := 32*conv_integer(ra.word);
    
    axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

    axiSlaveRegister(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, x"00", 0, v.calibrate);
    axiSlaveRegister(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, x"00", 1, v.matchTime);
    axiSlaveRegister(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, x"00",16, v.delayLd);
    axiSlaveRegister(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, x"04", 0, v.channel);
    axiSlaveRegister(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, x"04", 4, v.word);
    axiSlaveRegister(axilReadMaster, v.axilReadSlave, axilStatus, x"08", 0, v.matchw(iw+31 downto iw));

    for i in 0 to SYNC_BITS_G-1 loop
      axiSlaveRegister(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, toSlv(16+8*i,8), 0, v.delay(i));
      axiSlaveRegister(axilReadMaster, v.axilReadSlave, axilStatus, toSlv(20+8*i,8), 0, delayInS(i));
    end loop;

    axiSlaveDefault(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, AXI_RESP_OK_C);

    if ENABLE_CAL_G then
      case ra.state is
        when S_IDLE =>
          if v.calibrate='1' and ra.calibrate='0' then
            v.match   := (others=>(others=>'0'));
            v.delay   := (others=>(others=>'0'));
            v.delayLd := (others=>'1');
            v.state   := S_SET_DELAY;
          end if;
        when S_SET_DELAY =>
          if ra.count=DELAY_STIME then
            v.count    := (others=>'0');
            v.test     := '1';
            v.state    := S_TEST_DELAY;
          end if;
        when S_TEST_DELAY =>
          if ra.count=ra.matchTime then
            v.count    := (others=>'0');
            v.test     := '0';
            for i in 0 to SYNC_BITS_G-1 loop
              v.match(i)(conv_integer(ra.delay(i))) := match(i);
            end loop;
            if ra.delay(0)=toSlv(511,9) then
              v.state := S_IDLE;
            else
              for i in 0 to SYNC_BITS_G-1 loop
                v.delay(i) := ra.delay(0)+1;
              end loop;
              v.delayLd := (others=>'1');
              v.state := S_SET_DELAY;
            end if;
          end if;
        when others => null;
      end case;
    end if;
    
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

  GEN_CAL : if ENABLE_CAL_G generate
    GEN_CALBIT : for i in 0 to SYNC_BITS_G-1 generate
      U_CALBIT : entity work.AdcSyncCalBit
        generic map ( SYNC_PERIOD_G => SYNC_PERIOD_G,
                      DEBUG_G       => false )
        port map ( syncClk => syncClk,
                   enable  => stest,
                   sync    => sync(i),
                   match   => match(i) );
    end generate GEN_CALBIT;
  end generate;
    
  combe: process (re, trigSlot, trigSel, etest   ) is
    variable v : EvrRegType;
  begin
    v := re;

    v.strobe := '0';
    
    if etest='1' then
      if trigSlot='1' or re.count=toSlv(EVR_PERIOD_G-1,re.count'length) then
        v.strobe := '1';
        v.count := (others=>'0');
      else
        v.count := re.count+1;
      end if;
    else
      v.strobe := trigSlot and trigSel;
      v.count  := (others=>'0');
    end if;
    
    re_in <= v;
  end process combe;

  seqe: process ( evrClk ) is
  begin
    if rising_edge(evrClk) then
      re <= re_in;
    end if;
  end process seqe;
  
  U_SYNC_ECalibrate : entity work.Synchronizer
    port map ( clk     => evrClk,
               dataIn  => ra.test,
               dataOut => etest );
  
  U_SYNC_SCalibrate : entity work.Synchronizer
    port map ( clk     => syncClk,
               dataIn  => ra.test,
               dataOut => stest );
  
  U_SYNC_Match    : entity work.SynchronizerVector
    generic map ( WIDTH_G => SYNC_BITS_G )
    port map ( clk     => axiClk,
               dataIn  => match   ,
               dataOut => amatch    );
  
end mapping;
