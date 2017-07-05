-------------------------------------------------------------------------------
-- File       : XpmBp.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-04
-- Last update: 2017-06-30
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
   generic ( TPD_G    : time    := 1 ns;
             NBpLinks : integer := 14 );
   port (
      ----------------------
      -- Top Level Interface
      ----------------------
      ref125MHzClk    : in  sl;
      ref125MHzRst    : in  sl;
      rxFull          : out Slv16Array        (NBpLinks downto 1);
      rxLinkUp        : out slv               (NBpLinks downto 1);
      monClk          : out sl;
      ----------------
      -- Core Ports --
      ----------------
      -- Backplane Ports
      bpClkIn         : in  sl;
      bpClkOut        : out sl;
      bpBusRxP        : in  slv(NBpLinks downto 1);
      bpBusRxN        : in  slv(NBpLinks downto 1) );
end XpmBp;

architecture mapping of XpmBp is

   signal bp100MHzClk : sl;
   signal bp100MHzRst : sl;
   signal bp250MHzClk : sl;
   signal bp250MHzRst : sl;
   signal bp500MHzClk : sl;
   signal bp500MHzRst : sl;
   signal bpPllLocked : sl;

   constant BP_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(2);
   
   signal bpMaster : AxiStreamMasterArray(NBpLinks downto 1);

   signal iDelayCtrlRdy : sl;
   signal linkUp        : slv(NBpLinks downto 1);

begin

  monClk <= bp100MHzClk;
  
   ------------------------------
   -- Backplane Clocks and Resets
   ------------------------------
   U_Clk : entity work.XpmBpClk
      generic map (
         TPD_G         => TPD_G,
         MPS_SLOT_G    => true )
      port map (
         -- Stable Clock and Reset 
         refClk       => ref125MHzClk,
         refRst       => ref125MHzRst,
         -- BP Clocks and Resets
         mps100MHzClk => bp100MHzClk,
         mps100MHzRst => bp100MHzRst,
         mps250MHzClk => bp250MHzClk,
         mps250MHzRst => bp250MHzRst,
         mps500MHzClk => bp500MHzClk,
         mps500MHzRst => bp500MHzRst,
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
       refClk        => bp500MHzClk,
       refRst        => bp500MHzRst);

   GEN_VEC :
   for i in NBpLinks downto 1 generate
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
         clk125MHz     => bp100MHzClk,
         rst125MHz     => bp100MHzRst,
         clk312MHz     => bp250MHzClk,
         clk625MHz     => bp500MHzClk,
         iDelayCtrlRdy => iDelayCtrlRdy,
         linkUp        => rxLinkUp(i),
         -- Slave Port
         sAxisClk      => ref125MHzClk,
         sAxisRst      => ref125MHzRst,
         sAxisMaster   => AXI_STREAM_MASTER_INIT_C,
         sAxisSlave    => open,
         -- Master Port
         mAxisClk      => ref125MHzClk,
         mAxisRst      => ref125MHzRst,
         mAxisMaster   => bpMaster(i),
         mAxisSlave    => AXI_STREAM_SLAVE_FORCE_C );

   end generate GEN_VEC;

   seq: process (ref125MHzClk) is
   begin
     if rising_edge(ref125MHzClk) then
       for i in 1 to NBpLinks loop
         if ref125MHzRst='1' then
           rxFull(i) <= (others=>'0');
         elsif bpMaster(i).tValid='1' then
           rxFull(i) <= bpMaster(i).tData(15 downto 0);
         end if;
       end loop;
     end if;
   end process;

end mapping;
