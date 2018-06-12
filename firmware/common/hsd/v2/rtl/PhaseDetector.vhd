-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PhaseDetector.vhd
-- Author     : Matt Weaver
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-12-14
-- Last update: 2018-06-06
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Interface to sensor link MGT
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

use work.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;


entity PhaseDetector is
  generic ( WIDTH_G : integer := 21 );
  port (
    stableClk      : in  sl;
    latch          : in  sl;
    refClk         : in  sl;
    refClkRst      : in  sl;
    testClk        : in  sl;
    testClkRst     : in  sl;
    testSync       : in  sl;
    testId         : in  sl;
    ready          : out sl;
    phase0         : out slv(WIDTH_G-1 downto 0);
    phase1         : out slv(WIDTH_G-1 downto 0);
    count0         : out slv(WIDTH_G-1 downto 0);
    count1         : out slv(WIDTH_G-1 downto 0);
    valid          : out slv(WIDTH_G-1 downto 0) );
end PhaseDetector;

architecture rtl of PhaseDetector is

  type RegType is record
    phase0 : slv(WIDTH_G-1 downto 0);
    phase1 : slv(WIDTH_G-1 downto 0);
    count0 : slv(WIDTH_G-1 downto 0);
    count1 : slv(WIDTH_G-1 downto 0);
    valid  : slv(WIDTH_G-1 downto 0);
    ready  : sl;
  end record;

  constant REG_INIT_C : RegType := (
    phase0 => (others=>'0'),
    phase1 => (others=>'0'),
    count0 => (others=>'0'),
    count1 => (others=>'0'),
    valid  => (others=>'0'),
    ready  => '0' );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal q   : RegType := REG_INIT_C;
  signal qin : RegType;

  signal testS   : sl;
  signal testIdS : sl;
  signal a,b,c : sl;
  signal sa, sc, id : sl;
  signal refCount : slv(1 downto 0);
  signal refCountOut : SlVectorArray(1 downto 0, WIDTH_G-1 downto 0);
  
  signal crossDomainSyncReg : slv(1 downto 0);
  
   -------------------------------
   -- XST/Synplify Attributes
   -------------------------------

   -- ASYNC_REG require for Vivado but breaks ISE/XST synthesis
   attribute ASYNC_REG                       : string;
   attribute ASYNC_REG of crossDomainSyncReg : signal is "TRUE";

   -- Synplify Pro: disable shift-register LUT (SRL) extraction
   attribute syn_srlstyle                       : string;
   attribute syn_srlstyle of crossDomainSyncReg : signal is "registers";

   -- These attributes will stop timing errors being reported on the target flip-flop during back annotated SDF simulation.
   attribute MSGON                       : string;
   attribute MSGON of crossDomainSyncReg : signal is "FALSE";

   -- These attributes will stop XST translating the desired flip-flops into an
   -- SRL based shift register.
   attribute shreg_extract                       : string;
   attribute shreg_extract of crossDomainSyncReg : signal is "no";

   -- Don't let register balancing move logic between the register chain
   attribute register_balancing                       : string;
   attribute register_balancing of crossDomainSyncReg : signal is "no";

   -------------------------------
   -- Altera Attributes 
   ------------------------------- 
   attribute altera_attribute                       : string;
   attribute altera_attribute of crossDomainSyncReg : signal is "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF";
   
  
begin

  aseq : process ( testClk ) is
  begin
    if rising_edge(testClk) then
      a <= testSync;
      if testSync='1' then
        testIdS <= testId;
      end if;
    end if;
  end process aseq;

  bseq : process ( refClk ) is
  begin
    if rising_edge(refClk) then
      if crossDomainSyncReg = "01" then
        refCount <= "01";
      elsif crossDomainSyncReg = "11" then
        refCount <= "10";
      else
        refCount <= "00";
      end if;
      
      crossDomainSyncReg <= testIdS & a;
    end if;
  end process;

  b  <= crossDomainSyncReg(0);
  c  <= a and b;

  U_SYNC_ID : entity work.Synchronizer
    generic map ( TPD_G => 0 ns )
    port map ( clk     => stableClk,
               dataIn  => testIdS,
               dataOut => id );    
  U_SYNC_PHASE : entity work.Synchronizer
    generic map ( TPD_G => 0 ns )
    port map ( clk     => stableClk,
               dataIn  => c,
               dataOut => sc );
  
  U_SYNC_VALID : entity work.Synchronizer
    generic map ( TPD_G => 0 ns )
    port map ( clk     => stableClk,
               dataIn  => a,
               dataOut => sa );
  U_SYNC_COUNT : entity work.SynchronizerOneShotCntVector
    generic map ( CNT_WIDTH_G => WIDTH_G,
                  WIDTH_G     => 2 )
    port map ( wrClk      => refClk,
               wrRst      => refClkRst,
               dataIn     => refCount,
               rdClk      => stableClk,
               rdRst      => '0',
               rollOverEn => (others=>'0'),
               cntRst     => r.valid(r.valid'left),
               dataOut    => open,
               cntOut     => refCountOut );
  
  comb : process ( r, q, latch, sc, sa, id, refCountOut ) is
    variable v : RegType;
    variable w : RegType;
  begin
    v := r;
    w := q;

    if sc = '1' then
      if id = '0' then
        v.phase0 := r.phase0+1;
      else
        v.phase1 := r.phase1+1;
      end if;
    end if;

    v.count0 := muxSlVectorArray(refCountOut,0);
    v.count1 := muxSlVectorArray(refCountOut,1);
      
    if sa = '1' then
      v.valid := r.valid+1;
    end if;

    w.ready := '0';
    if r.valid(r.valid'left) = '1' then
      v := REG_INIT_C;
      if latch = '0' then
        w.ready := '1';
        w := r;
      end if;
    end if;

    rin <= v;
    qin <= w;

    phase0 <= q.phase0;
    phase1 <= q.phase1;
    count0 <= q.count0;
    count1 <= q.count1;
    valid  <= q.valid;
    ready  <= q.ready;
  end process;

  seq : process (stableClk) is
  begin
    if rising_edge(stableClk) then
      r <= rin;
      q <= qin;
    end if;
  end process;

end rtl;
