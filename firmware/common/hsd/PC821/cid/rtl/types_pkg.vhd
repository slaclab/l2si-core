--
--	Author: Luis F. Munoz
---
--  Description
----
--
--
--  Version 0.1 - Initial Release
--
--
-- How to do I declare this library for use in my VHDL code?
-- library xil_defaultlib;
--   use xil_defaultlib.types_pkg.all;
--
--
----------------------------------------------------------------------------------------------------
-- LIBRARIES
----------------------------------------------------------------------------------------------------
library IEEE;
   use IEEE.STD_LOGIC_1164.all;

----------------------------------------------------------------------------------------------------
-- PACKGE
----------------------------------------------------------------------------------------------------
package types_pkg is

type bus001  is array(natural range <>) of std_logic_vector(  0 downto 0);
type bus002  is array(natural range <>) of std_logic_vector(  1 downto 0);
type bus003  is array(natural range <>) of std_logic_vector(  2 downto 0);
type bus004  is array(natural range <>) of std_logic_vector(  3 downto 0);
type bus005  is array(natural range <>) of std_logic_vector(  4 downto 0);
type bus006  is array(natural range <>) of std_logic_vector(  5 downto 0);
type bus007  is array(natural range <>) of std_logic_vector(  6 downto 0);
type bus008  is array(natural range <>) of std_logic_vector(  7 downto 0);
type bus009  is array(natural range <>) of std_logic_vector(  8 downto 0);
type bus010  is array(natural range <>) of std_logic_vector(  9 downto 0);
type bus011  is array(natural range <>) of std_logic_vector( 10 downto 0);
type bus012  is array(natural range <>) of std_logic_vector( 11 downto 0);
type bus013  is array(natural range <>) of std_logic_vector( 12 downto 0);
type bus014  is array(natural range <>) of std_logic_vector( 13 downto 0);
type bus015  is array(natural range <>) of std_logic_vector( 14 downto 0);
type bus016  is array(natural range <>) of std_logic_vector( 15 downto 0);
type bus017  is array(natural range <>) of std_logic_vector( 16 downto 0);
type bus018  is array(natural range <>) of std_logic_vector( 17 downto 0);
type bus019  is array(natural range <>) of std_logic_vector( 18 downto 0);
type bus020  is array(natural range <>) of std_logic_vector( 19 downto 0);
type bus021  is array(natural range <>) of std_logic_vector( 20 downto 0);
type bus022  is array(natural range <>) of std_logic_vector( 21 downto 0);
type bus023  is array(natural range <>) of std_logic_vector( 22 downto 0);
type bus024  is array(natural range <>) of std_logic_vector( 23 downto 0);
type bus025  is array(natural range <>) of std_logic_vector( 24 downto 0);
type bus026  is array(natural range <>) of std_logic_vector( 25 downto 0);
type bus027  is array(natural range <>) of std_logic_vector( 26 downto 0);
type bus028  is array(natural range <>) of std_logic_vector( 27 downto 0);
type bus029  is array(natural range <>) of std_logic_vector( 28 downto 0);
type bus030  is array(natural range <>) of std_logic_vector( 29 downto 0);
type bus031  is array(natural range <>) of std_logic_vector( 30 downto 0);
type bus032  is array(natural range <>) of std_logic_vector( 31 downto 0);
type bus047  is array(natural range <>) of std_logic_vector( 46 downto 0);
type bus048  is array(natural range <>) of std_logic_vector( 47 downto 0);
type bus064  is array(natural range <>) of std_logic_vector( 63 downto 0);
type bus096  is array(natural range <>) of std_logic_vector( 95 downto 0);
type bus128  is array(natural range <>) of std_logic_vector(127 downto 0);
type bus256  is array(natural range <>) of std_logic_vector(255 downto 0);
type bus512  is array(natural range <>) of std_logic_vector(511 downto 0);

-- AXI-Lite 32-bit
type axi32_s is record
	araddr      : std_logic_vector(31  downto 0);
	arvalid     : std_logic;
	awaddr      : std_logic_vector(31 downto 0);
	awvalid     : std_logic;
	bready      : std_logic;
	rready      : std_logic;
	wvalid      : std_logic;
	wstrb       : std_logic_vector(3  downto 0);
	wdata       : std_logic_vector(31  downto 0);
end record;

type axi32_r is record
	arready     : std_logic;
	awready     : std_logic;
	wready      : std_logic;
	bresp       : std_logic_vector(1 downto 0);
	bvalid      : std_logic;
	rdata       : std_logic_vector(31 downto 0);
	rresp       : std_logic_vector(1 downto 0);
	rvalid      : std_logic;
end record;

-- AXI-Stream 16-bit
type axis16_s is record
   tdata   : std_logic_vector(15 downto 0);
   tstrb   : std_logic_vector(1 downto 0);
   tuser   : std_logic_vector(31 downto 0);
   tvalid  : std_logic;
   tlast   : std_logic;
end record;

type axis16_r is record
   tready  : std_logic;
end record;

-- AXI-Stream 32-bit
type axis32_s is record
   tdata   : std_logic_vector(31 downto 0);
   tstrb   : std_logic_vector(3 downto 0);
   tuser   : std_logic_vector(31 downto 0);
   tvalid  : std_logic;
   tlast   : std_logic;
end record;

type axis32_r is record
   tready  : std_logic;
end record;

-- AXI-Stream 64-bit
type axis64_s is record
   tdata   : std_logic_vector(63 downto 0);
   tstrb   : std_logic_vector(7 downto 0);
   tuser   : std_logic_vector(31 downto 0);
   tvalid  : std_logic;
   tlast   : std_logic;
end record;

type axis64_r is record
   tready  : std_logic;
end record;

-- AXI-Stream 128-bit
type axis128_s is record
   tdata   : std_logic_vector(127 downto 0);
   tstrb   : std_logic_vector(15 downto 0);
   tuser   : std_logic_vector(31 downto 0);
   tvalid  : std_logic;
   tlast   : std_logic;
end record;

type axis128_r is record
   tready  : std_logic;
end record;

-- AXI-Stream 256-bit
type axis256_s is record
   tdata   : std_logic_vector(255 downto 0);
   tstrb   : std_logic_vector(31 downto 0);
   tuser   : std_logic_vector(31 downto 0);
   tvalid  : std_logic;
   tlast   : std_logic;
end record;

type axis256_r is record
   tready  : std_logic;
end record;

-- AXI-Stream 512-bit
type axis512_s is record
   tdata   : std_logic_vector(511 downto 0);
   tstrb   : std_logic_vector(63 downto 0);
   tuser   : std_logic_vector(31 downto 0);
   tvalid  : std_logic;
   tlast   : std_logic;
end record;

type axis512_r is record
   tready  : std_logic;
end record;


type axi32_sbus   is array(natural range <>) of axi32_s;
type axi32_rbus   is array(natural range <>) of axi32_r;
type axis16_sbus  is array(natural range <>) of axis16_s;
type axis16_rbus  is array(natural range <>) of axis16_r;
type axis32_sbus  is array(natural range <>) of axis32_s;
type axis32_rbus  is array(natural range <>) of axis32_r;
type axis64_sbus  is array(natural range <>) of axis64_s;
type axis64_rbus  is array(natural range <>) of axis64_r;
type axis128_sbus is array(natural range <>) of axis128_s;
type axis128_rbus is array(natural range <>) of axis128_r;
type axis256_sbus is array(natural range <>) of axis256_s;
type axis256_rbus is array(natural range <>) of axis256_r;
type axis512_sbus is array(natural range <>) of axis512_s;
type axis512_rbus is array(natural range <>) of axis512_r;

--***************************************************************************************************
end types_pkg;
--***************************************************************************************************

----------------------------------------------------------------------------------------------------
-- PACKGE BODY
----------------------------------------------------------------------------------------------------
package body types_pkg is

 --**************************************************************************************************
end types_pkg;
--***************************************************************************************************

