-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DtiPgpFb.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2017-07-06
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: DtiApp's Top Level
-- 
-- Note: Common-to-DtiApp interface defined here (see URL below)
--       https://confluence.slac.stanford.edu/x/rLyMCw
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
use ieee.std_logic_unsigned.all;

library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.DtiPkg.all;
use work.Pgp2bPkg.all;

entity DtiPgpFb is
   port (
     pgpClk          : in  sl;
     pgpRst          : in  sl;
     pgpRxOut        : in  Pgp2bRxOutType;
     rxAlmostFull    : out sl;
     txAlmostFull    : out sl );
end DtiPgpFb;

architecture rtl of DtiPgpFb is

  -- Tx Opcodes
  constant NAF_OPCODE   : slv(7 downto 0) := x"00";
  constant AF_OPCODE    : slv(7 downto 0) := x"01";
  constant TXNAF_OPCODE : slv(7 downto 0) := x"02";
  constant TXAF_OPCODE  : slv(7 downto 0) := x"03";

  type RegType is record
    rx_almost_full : sl;
    tx_almost_full : sl;
    tmo            : slv(8 downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    rx_almost_full => '1',
    tx_almost_full => '1',
    tmo            => (others=>'0') );

  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;
  
begin

  comb : process ( r, pgpRst, pgpRxOut ) is
    variable v : RegType;
  begin
    v := r;

    v.tmo := r.tmo + 1;
    
    if pgpRxOut.opCodeEn = '1' then
      v.tmo            := (others=>'0');
      case (pgpRxOut.opCode) is
        when NAF_OPCODE =>
          v.rx_almost_full := '0';
        when AF_OPCODE => 
          v.rx_almost_full := '1';
        when TXNAF_OPCODE => 
          v.tx_almost_full := '1';
        when TXAF_OPCODE => 
          v.tx_almost_full := '1';
        when others =>
          null;
      end case;
    end if;

    if r.tmo(r.tmo'left) = '1' then
      v.rx_almost_full := '1';
      v.tx_almost_full := '1';
    end if;
    
    if pgpRst = '1' then
      v := REG_INIT_C;
    end if;
    
    r_in <= v;
  end process;

  seq : process (pgpClk) is
  begin
    if rising_edge(pgpClk) then
      r <= r_in;
    end if;
  end process;
  
end rtl;
