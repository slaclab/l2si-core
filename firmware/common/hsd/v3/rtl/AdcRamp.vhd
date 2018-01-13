-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AdcRamp.vhd
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

use STD.textio.all;
use ieee.std_logic_textio.all;

use work.StdRtlPkg.all;
use work.QuadAdcPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AdcRamp is
  port ( phyClk      : in  sl;
         dmaClk      : out sl;
         ready       : in  sl;
         adcOut      : out AdcDataArray(3 downto 0);
         trigSel     : in  sl;
         trigOut     : out Slv8Array(3 downto 0)
    );
end AdcRamp;

architecture behavior of AdcRamp is
  signal adcClk           : sl;
  signal adcI,adcO        : AdcDataArray (3 downto 0);

  signal trigIn  : Slv8Array(3 downto 0) := (others=>(others=>'0'));
   
begin

  dmaClk  <= adcClk;
  adcOut  <= adcO;
  trigOut <= trigIn;

   process(phyClk) is
     variable v : slv(3 downto 0) := (others=>'0');
   begin
     if rising_edge(phyClk) then
       v := v+1;
     end if;
     adcClk <= v(2);
   end process;
  
  process (phyClk) is
     variable s : slv(10 downto 0) := (others=>'0');
     variable d : slv( 2 downto 0) := (others=>'0');
     variable t : integer          := 0;
--     constant PERIOD_C : integer := 1348;
     constant PERIOD_C : integer := 13480;
   begin
     if rising_edge(phyClk) then
       adcI(0).data(7) <= s+0;
       adcI(2).data(7) <= s+1;
       adcI(1).data(7) <= s+2;
       adcI(3).data(7) <= s+3;
       for ch in 0 to 3 loop
         adcI(ch).data(6 downto 0) <= adcI(ch).data(7 downto 1);
       end loop;
       
       --if t = PERIOD_C-1 then
       --  adcI(2).data(7)(10) <= '1';
       --else
       --  adcI(2).data(7)(10) <= '0';
       --end if;

       --for ch in 0 to 1 loop
       --  adcI(ch).data(7)(10) <= adcI(ch+1).data(0)(10);
       --end loop;
       
       if t = PERIOD_C-1 then
         t := 0;
       else
         t := t+1;
       end if;
       trigIn(0) <= d(0) & trigIn(0)(7 downto 1);
       d := trigSel & d(2 downto 1);
       --
       --  Ramp the signal (let it slip by one each cycle)
       --
       if s = toSlv(2044,11) then
         s := (others=>'0');
       else
         s := s+4;
       end if;
     end if;
   end process;

   process (adcClk) is
   begin
     if rising_edge(adcClk) then
       adcO <= adcI;
     end if;
   end process;
     
end behavior;
     