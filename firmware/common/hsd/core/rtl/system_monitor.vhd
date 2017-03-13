-------------------------------------------------------------------------------------
-- FILE NAME : .vhd
-- AUTHOR    : I. van Klink
-- COMPANY   : 4DSP
-- UNITS     : Entity       - toplevel_template
--             Architecture - Behavioral
-- LANGUAGE  : VHDL
-- DATE      : July 21, 2015
-------------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------------
-- DESCRIPTION
-- ===========
-- This entity wraps the Xilinx Sys Management IP and provides a bridge to access
-- the Sys Management block with StellarIP CMD IF
--
-- A StellarIP command has the following format
-- [ Command word (4-bits) | Address  (28-bits) | Data (32-bits) ]
--
-------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------
-- LIBRARIES
-------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.std_logic_unsigned.all;
    use ieee.std_logic_misc.all;
    use ieee.std_logic_arith.all;

library work;
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

-------------------------------------------------------------------------------------
-- ENTITY
-------------------------------------------------------------------------------------
entity system_monitor is
port (
   axilClk          : in  sl;
   axilRst          : in  sl;
   axilWriteMaster  : in  AxiLiteWriteMasterType;
   axilWriteSlave   : out AxiLiteWriteSlaveType;
   axilReadMaster   : in  AxiLiteReadMasterType;
   axilReadSlave    : out AxiLiteReadSlaveType
);
end system_monitor;

-------------------------------------------------------------------------------------
-- ARCHITECTURE
-------------------------------------------------------------------------------------
architecture Behavioral of system_monitor is

-------------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------
-- SIGNALS
-----------------------------------------------------------------------------------

signal drpDi     : slv(15 downto 0);
signal drpAddr   : slv( 7 downto 0);
signal drpEn     : sl;
signal drpWe     : sl;
signal drpRdy    : sl;
signal drpDo     : slv(15 downto 0);
signal vp                   : std_logic := '0';
signal vn                   : std_logic := '1';

--***********************************************************************************
begin

  U_Drp : entity work.AxiLiteToDrp
    generic map ( ADDR_WIDTH_G    => 8,
                  DATA_WIDTH_G    => 16 )
    port map ( axilClk         => axilClk,
               axilRst         => axilRst,
               axilReadMaster  => axilReadMaster,
               axilReadSlave   => axilReadSlave,
               axilWriteMaster => axilWriteMaster,
               axilWriteSlave  => axilWriteSlave,
               drpClk          => axilClk,
               drpRst          => axilRst,
               drpRdy          => drpRdy,
               drpEn           => drpEn,
               drpWe           => drpWe,
               drpUsrRst       => drpUsrRst,
               drpAddr         => drpAddr,
               drpDi           => drpDi,
               drpDo           => drpDo );
               
U_SysMan : entity work.system_management_wiz_0
  port map (
    di_in                 => drpDin,
    daddr_in              => drpAddr,
    den_in                => drpEn,
    dwe_in                => drpWe,
    drdy_out              => drpRdy,
    do_out                => drpDo,
    dclk_in               => axilClk,
    reset_in              => axilRst,
    vp                    => vp,
    vn                    => vn,
    user_temp_alarm_out   => open,
    ot_out                => open,
    channel_out           => open,
    eoc_out               => open,
    alarm_out             => open,
    eos_out               => open,
    busy_out              => open,
    sysmon_slave_sel      => open );


--***********************************************************************************
end architecture Behavioral;
--***********************************************************************************

