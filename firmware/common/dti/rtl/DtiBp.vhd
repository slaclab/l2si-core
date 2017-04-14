-------------------------------------------------------------------------------
-- File       : DtiBp.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-04
-- Last update: 2017-04-13
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Note: Do not forget to configure the ATCA crate to drive the clock from the slot#2 MPS link node
-- For the 7-slot crate:
--    $ ipmitool -I lan -H ${SELF_MANAGER} -t 0x84 -b 0 -A NONE raw 0x2e 0x39 0x0a 0x40 0x00 0x00 0x00 0x31 0x01
-- For the 16-slot crate:
--    $ ipmitool -I lan -H ${SELF_MANAGER} -t 0x84 -b 0 -A NONE raw 0x2e 0x39 0x0a 0x40 0x00 0x00 0x00 0x31 0x01
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.DtiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity DtiBp is
   generic ( TPD_G : time := 1 ns );
   port (
      ----------------------
      -- Top Level Interface
      ----------------------
      ref156MHzClk    : in  sl;
      ref156MHzRst    : in  sl;
      rxFull          : in  Slv16Array(0 downto 0);
      linkUp          : out sl;
      ----------------
      -- Core Ports --
      ----------------
      -- Backplane Ports
      bpClkIn         : in  sl;
      bpClkOut        : out sl;
      bpBusRxP        : in  sl;
      bpBusRxN        : in  sl;
      bpBusTxP        : out sl;
      bpBusTxN        : out sl );
end DtiBp;

architecture mapping of DtiBp is

   type RegType is record
     master : AxiStreamMasterType;
     full   : slv(31 downto 0);
     sent   : slv(47 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
     master => AXI_STREAM_MASTER_INIT_C,
     full   => (others=>'0'),
     sent   => (others=>'0') );

   signal r     : RegType := REG_INIT_C;
   signal rin   : RegType;
   
   signal bp125MHzClk : sl;
   signal bp125MHzRst : sl;
   signal bp312MHzClk : sl;
   signal bp312MHzRst : sl;
   signal bp625MHzClk : sl;
   signal bp625MHzRst : sl;
   signal bpPllLocked : sl;

   constant BP_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(2);
   
   signal bpSlave  : AxiStreamSlaveType;

begin

   ------------------------------
   -- Backplane Clocks and Resets
   ------------------------------
   U_Clk : entity work.AppMpsClk
      generic map (
         TPD_G         => TPD_G,
         MPS_SLOT_G    => false )
      port map (
         -- Stable Clock and Reset 
         axilClk      => ref156MHzClk,
         axilRst      => ref156MHzRst,
         -- BP Clocks and Resets
         mps125MHzClk => bp125MHzClk,
         mps125MHzRst => bp125MHzRst,
         mps312MHzClk => bp312MHzClk,
         mps312MHzRst => bp312MHzRst,
         mps625MHzClk => bp625MHzClk,
         mps625MHzRst => bp625MHzRst,
         mpsPllLocked => bpPllLocked,
         ----------------
         -- Core Ports --
         ----------------   
         -- Backplane BP Ports
         mpsClkIn     => bpClkIn,
         mpsClkOut    => bpClkOut);

   U_SaltUltraScale : entity work.SaltUltraScale
     generic map (
       TPD_G               => TPD_G,
       TX_ENABLE_G         => true,
       RX_ENABLE_G         => false,
       COMMON_TX_CLK_G     => false,
       COMMON_RX_CLK_G     => false,
       SLAVE_AXI_CONFIG_G  => BP_CONFIG_C,
       MASTER_AXI_CONFIG_G => BP_CONFIG_C)
     port map (
       -- TX Serial Stream
       txP           => bpBusTxP,
       txN           => bpBusTxN,
       -- RX Serial Stream
       rxP           => '1',
       rxN           => '0',
       -- Reference Signals
       clk125MHz     => bp125MHzClk,
       rst125MHz     => bp125MHzRst,
       clk312MHz     => bp312MHzClk,
       clk625MHz     => bp625MHzClk,
       iDelayCtrlRdy => '1',
       linkUp        => linkUp,
       -- Slave Port
       sAxisClk      => ref156MHzClk,
       sAxisRst      => ref156MHzRst,
       sAxisMaster   => r.master,
       sAxisSlave    => bpSlave,
       -- Master Port
       mAxisClk      => ref156MHzClk,
       mAxisRst      => ref156MHzRst,
       mAxisMaster   => open,
       mAxisSlave    => AXI_STREAM_SLAVE_FORCE_C );

   U_IBUFDS : IBUFDS
     generic map (
       DIFF_TERM => true)
     port map(
       I  => bpBusRxP,
       IB => bpBusRxN,
       O  => open);

   comb: process ( r, ref156MHzRst, rxFull ) is
     variable v : RegType;
   begin
     v := r;

     v.master.tValid := '1';
     v.master.tLast  := '1';
     v.master.tData  := rxFull(0);

     if ref156MHzRst='1' then
       v := REG_INIT_C;
     end if;
     
     rin <= v;
   end process;
   
   seq: process (ref156MHzClk) is
   begin
     if rising_edge(ref156MHzClk) then
       r <= rin;
     end if;
   end process;

end mapping;
