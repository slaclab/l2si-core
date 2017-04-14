-------------------------------------------------------------------------------
-- File       : XpmBp.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-04
-- Last update: 2017-03-31
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
use work.XpmPkg.all;

entity XpmBp is
   generic ( TPD_G : time := 1 ns );
   port (
      ----------------------
      -- Top Level Interface
      ----------------------
      ref156MHzClk    : in  sl;
      ref156MHzRst    : in  sl;
      rxFull          : out Slv16Array        (14 downto 1);
      rxLinkUp        : out slv               (14 downto 1);
      ----------------
      -- Core Ports --
      ----------------
      -- Backplane Ports
      bpClkIn         : in  sl;
      bpClkOut        : out sl;
      bpBusRxP        : in  slv(14 downto 1);
      bpBusRxN        : in  slv(14 downto 1) );
end XpmBp;

architecture mapping of XpmBp is

   signal bp125MHzClk : sl;
   signal bp125MHzRst : sl;
   signal bp312MHzClk : sl;
   signal bp312MHzRst : sl;
   signal bp625MHzClk : sl;
   signal bp625MHzRst : sl;
   signal bpPllLocked : sl;

   constant BP_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(2);
   
   signal bpMaster : AxiStreamMasterArray(14 downto 1);

   signal iDelayCtrlRdy : sl;
   signal linkUp        : slv(14 downto 1);

begin

   ------------------------------
   -- Backplane Clocks and Resets
   ------------------------------
   U_Clk : entity work.AppMpsClk
      generic map (
         TPD_G         => TPD_G,
         MPS_SLOT_G    => true )
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

   U_SaltDelayCtrl : entity work.SaltDelayCtrl
     generic map (
       TPD_G           => TPD_G,
       SIM_DEVICE_G    => "ULTRASCALE",
       IODELAY_GROUP_G => "BP_IODELAY_GRP")
     port map (
       iDelayCtrlRdy => iDelayCtrlRdy,
       refClk        => bp625MHzClk,
       refRst        => bp625MHzRst);

   GEN_VEC :
   for i in 14 downto 1 generate
     U_SaltUltraScale : entity work.SaltUltraScale
       generic map (
         TPD_G               => TPD_G,
         TX_ENABLE_G         => false,
         RX_ENABLE_G         => true,
         COMMON_TX_CLK_G     => false,
         COMMON_RX_CLK_G     => false,
         SLAVE_AXI_CONFIG_G  => BP_CONFIG_C,
         MASTER_AXI_CONFIG_G => BP_CONFIG_C)
       port map (
         -- TX Serial Stream
         txP           => open,
         txN           => open,
         -- RX Serial Stream
         rxP           => bpBusRxP(i),
         rxN           => bpBusRxN(i),
         -- Reference Signals
         clk125MHz     => bp125MHzClk,
         rst125MHz     => bp125MHzRst,
         clk312MHz     => bp312MHzClk,
         clk625MHz     => bp625MHzClk,
         iDelayCtrlRdy => iDelayCtrlRdy,
         linkUp        => rxLinkUp(i),
         -- Slave Port
         sAxisClk      => ref156MHzClk,
         sAxisRst      => ref156MHzRst,
         sAxisMaster   => AXI_STREAM_MASTER_INIT_C,
         sAxisSlave    => open,
         -- Master Port
         mAxisClk      => ref156MHzClk,
         mAxisRst      => ref156MHzRst,
         mAxisMaster   => bpMaster(i),
         mAxisSlave    => AXI_STREAM_SLAVE_FORCE_C );

   end generate GEN_VEC;

   seq: process (ref156MHzClk) is
   begin
     if rising_edge(ref156MHzClk) then
       for i in 1 to 14 loop
         if ref156MHzRst='1' then
           rxFull(i) <= (others=>'0');
         elsif bpMaster(i).tValid='1' then
           rxFull(i) <= bpMaster(i).tData(15 downto 0);
         end if;
       end loop;
     end if;
   end process;

end mapping;
