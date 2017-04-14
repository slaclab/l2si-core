-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DtiFbLink.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-04
-- Last update: 2017-01-11
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 Common Carrier Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 Common Carrier Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.XpmPkg.all;

library unisim;
use unisim.vcomponents.all;

entity DtiFbLink is
   port (
      -- SALT Reference clocks
      ref125MHzClk      : in  sl;
      ref125MHzRst      : in  sl;
      ref312MHzClk      : in  sl;
      ref312MHzRst      : in  sl;
      ref625MHzClk      : in  sl;
      ref625MHzRst      : in  sl;
      ----------------------
      -- Application Interface
      ----------------------
      appClk            : in  sl;
      appRst            : in  sl;
      full              : in  slv(NPartitions-1 downto 0);
      obMaster          : out AxiStreamMasterType;
      obSlave           : in  AxiStreamSlaveType );
end DtiFbLink;

architecture mapping of DtiFbLink is

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal iDelayCtrlRdy : sl;

begin


   comb : process( 
   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end mapping;
