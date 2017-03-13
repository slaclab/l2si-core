--
--  This module assumes a clock ratio relationship of
--     f(clkA):f(clkB):f(clkF) = 5:4:1
--  It's expensive in number of registers but lenient on timing.  The output
--  stage could be changed to 40 wide on clkF, but 10 wide gives a beam
--  synchronous clk and 40 does not.
--
--    LCLS-II: f(clkA)=1300M*3/28, f(clkB)= 1300M*3/35, f(clkF)=1300M*3/140
--           : beam is synchronous to 1300M/1400
--    LCLS   : f(clkA)=1190M/8, f(clkB)=119M, f(clkF)=119M/4
--           : beam is synchronous to 8.5M (or 1M/14 later)
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity DDRGearBox4to5 is
   generic (
      DEBUG_G : boolean := false );
   port (
      clkF  : in  sl;
      -- Slave Port
      clkA  : in  sl;
      dataA : in  slv(7 downto 0);
      --
      clkB  : in  sl;
      rstB  : in  sl;
      dataB : out slv(9 downto 0);
      --
      strobe : in sl );
end DDRGearBox4to5;

architecture rtl of DDRGearBox4to5 is

  signal adata : slv(39 downto 0);
  signal bdata : slv(39 downto 0);
  signal fdata : slv(39 downto 0);
--  signal ld    : slv( 3 downto 0);
  signal fsync : sl := '0';
  signal ast, bst, fst : sl;
  
begin

  dataB <= bdata(9 downto 0);
  
  seqA : process ( clkA ) is
  begin
    if rising_edge(clkA) then
      adata <= dataA & adata(adata'left downto 8);
    end if;
  end process;

  seqF : process ( clkF ) is
  begin
    if rising_edge(clkF) then
      fdata <= adata;
      fsync <= not fsync;
    end if;
  end process;

  seqB : process ( clkB ) is
    variable bsync : sl := '0';
  begin
    if rising_edge(clkB) then
      --if rstB='1' then
      --  ld <= x"1";
      --else
      --  if ld(0)='1' then
      --    bdata <= fdata;
      --  else
      --    bdata <= toSlv(0,10) & bdata(39 downto 10);
      --  end if;
        
      --  ld <= ld(0) & ld(3 downto 1);
      --end if;
      if fsync/=bsync then
        bsync := fsync;
        bdata <= fdata;
      else
        bdata <= toSlv(0,10) & bdata(bdata'left downto 10);
      end if;

    end if;
  end process;

  seq: process( clkA, clkB, clkF, strobe ) is
  begin
    if strobe='1' then
      ast <= '1';
    elsif rising_edge(clkA) then
      ast <= '0';
    end if;
    if strobe='1' then
      bst <= '1';
    elsif rising_edge(clkB) then
      bst <= '0';
    end if;
    if strobe='1' then
      fst <= '1';
    elsif rising_edge(clkF) then
      fst <= '0';
    end if;
  end process seq;
end rtl;
