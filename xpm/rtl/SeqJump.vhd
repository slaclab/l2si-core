-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Calculates automated jumps in sequencer instruction RAM.
--   Reacts to BCS fault state change, MPS state change, and manual reset.
--   The manual reset is highest priority, followed by BCS, and MPS.
--   Any state change that isn't acted upon because of a higher priority reaction
--   will be enacted on the following cycle.
-------------------------------------------------------------------------------
-- This file is part of 'L2SI Core'. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'L2SI Core', including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

library surf;
use surf.StdRtlPkg.all;

library lcls_timing_core;
use lcls_timing_core.TPGPkg.all;

entity SeqJump is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and reset
      clk      : in  sl;
      rst      : in  sl;
      config   : in  TPGJumpConfigType;
      manReset : in  sl;
      bcsFault : in  sl;
      mpsFault : in  sl;
      mpsClass : in  slv(3 downto 0);
      jumpEn   : in  sl;
      jumpReq  : out sl;
      jumpAddr : out SeqAddrType;
      bcsLatch : out sl;
      mpsLatch : out slv(3 downto 0);   -- current mps class
      mpsLimit : out sl;                -- assert when MPS is limiting;
      -- clear when recovering
      outClass : out slv(3 downto 0)    -- respected class
      );
end SeqJump;

-- Define architecture for top level module
architecture mapping of SeqJump is

   type RegType is record
      config   : TPGJumpConfigType;
      manLatch : sl;
      bcsLatch : sl;
      mpsLatch : slv(3 downto 0);
      limit    : sl;
      jump     : sl;
      addr     : SeqAddrType;
      class    : slv(3 downto 0);
   end record;
   constant REG_INIT_C : RegType := (
      config   => TPG_JUMPCONFIG_INIT_C,
      manLatch => '0',
      bcsLatch => '0',
      mpsLatch => (others => '1'),
      limit    => '0',
      jump     => '0',
      addr     => (others => '0'),
      class    => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   jumpReq  <= r.jump;
   jumpAddr <= r.addr;
   bcsLatch <= r.bcsLatch;
   mpsLatch <= r.mpsLatch;
   mpsLimit <= r.limit;
   outClass <= r.class;

   comb : process (bcsFault, config, jumpEn, manReset, mpsClass, mpsFault, r)
      variable v : RegType;
   begin  -- process
      v      := r;
      v.jump := '0';

      if (manReset = '1' and r.manLatch = '0') then
         v.manLatch := '1';
      end if;

      if r.mpsLatch < config.syncClass then
         v.limit := '1';
      end if;

      --  Activate new jump if any state has changed
      if (jumpEn = '1') then
         --  Highest priority
         if ((r.manLatch = '1' or manReset = '1') and not (r.mpsLatch < config.syncClass)) then
            v.jump  := '1';
            v.addr  := config.syncJump;
            v.class := config.syncClass;
            v.limit := '0';
         elsif (r.bcsLatch = '1') then
            v.jump  := '1';
            v.addr  := r.config.bcsJump;
            v.class := r.config.bcsClass;
         elsif (r.mpsLatch < r.class) then
            v.jump  := '1';
            v.addr  := r.config.mpsJump (conv_integer(r.mpsLatch));
            v.class := r.config.mpsClass(conv_integer(r.mpsLatch));
         end if;
         --  Always clear the latches
         if (r.manLatch = '1' or manReset = '1') then
            v.manLatch := '0';
         end if;
         if (r.bcsLatch = '1') then
            v.bcsLatch := '0';
         end if;
      end if;

      if (mpsFault = '1') then
         v.mpsLatch := mpsClass;
      end if;

      if (bcsFault = '1' and r.bcsLatch = '0') then
         v.bcsLatch := '1';
      end if;

      --  Read in the new configuration on manual reset
      if (manReset = '1') then
         v.config := config;
      end if;

      rin <= v;
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end mapping;
