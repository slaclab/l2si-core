-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : ClkSim.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2018-01-05
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
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
use IEEE.NUMERIC_STD.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity ClkSim is
  generic ( SELECT_G : string := "LCLSII" );
  port ( phyClk      : out sl;
         evrClk      : out sl );
end ClkSim;

architecture behavior of ClkSim is
  signal vco : sl;
  constant HALF_PERIOD : time := 4 ps;  -- 15.978087
  signal iphyClk : sl := '0';
  signal ievrClk : sl := '0';
begin

  process is
  begin
    vco <= '1';
    wait for HALF_PERIOD;
    vco <= '0';
    wait for HALF_PERIOD;
  end process;

  process (vco) is
    variable ievrCnt : integer := 0;
    variable ievrClk : sl := '0';
    variable iphyCnt : integer := 0;
    variable iphyClk : sl := '0';
  begin
    if rising_edge(vco) then
      ievrCnt := ievrCnt + 1;
      if ievrCnt = 337 then
        ievrCnt := 0;
        ievrClk := not ievrClk;
      end if;
      iphyCnt := iphyCnt + 1;
      if iphyCnt = 50 then
        iphyCnt := 0;
        iphyClk := not iphyClk;
      end if;
    end if;
    evrClk <= ievrClk;
    phyClk <= iphyClk;
  end process;
end behavior;
