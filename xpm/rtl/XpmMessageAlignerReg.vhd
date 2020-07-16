-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: This module produces a realigned timing bus and XPM partition words
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

library l2si_core;
use l2si_core.XpmPkg.all;
use l2si_core.XpmExtensionPkg.all;

library unisim;
use unisim.vcomponents.all;

entity XpmMessageAlignerReg is
   generic (
      TPD_G        : time    := 1 ns;
      COMMON_CLK_G : boolean := false);  -- true if axilClk = timingClk
   port (
      timingRxClk     : in  sl;
      timingRxRst     : in  sl;
      partitionDelays : in  Slv7Array(XPM_PARTITIONS_C-1 downto 0);
      rxId            : in  slv(31 downto 0);
      txId            : out slv(31 downto 0);
      -- Axi Lite bus for reading back current partitionDelays
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end XpmMessageAlignerReg;

architecture rtl of XpmMessageAlignerReg is

   type RegType is record
      txId           : slv(31 downto 0);
      axilWriteSlave : AxiLiteWriteSlaveType;
      axilReadSlave  : AxiLiteReadSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      txId           => (others => '0'),
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxIdSync    : slv(31 downto 0);
   signal partDlySync : Slv7Array(XPM_PARTITIONS_C-1 downto 0);

begin

   U_rxId : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => 32)
      port map (
         rst    => timingRxRst,
         wr_clk => timingRxClk,
         din    => rxId,
         rd_clk => axilClk,
         dout   => rxIdSync);

   GEN_VEC : for i in XPM_PARTITIONS_C-1 downto 0 generate
      U_SyncFifo : entity surf.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            COMMON_CLK_G => COMMON_CLK_G,
            DATA_WIDTH_G => 7)
         port map (
            rst    => timingRxRst,
            wr_clk => timingRxClk,
            din    => partitionDelays(i),
            rd_clk => axilClk,
            dout   => partDlySync(i));
   end generate GEN_VEC;

   comb : process(axilReadMaster, axilRst, axilWriteMaster, partDlySync, r,
                  rxIdSync) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      v := r;

      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      for i in 0 to XPM_PARTITIONS_C-1 loop
         axiSlaveRegisterR(axilEp, X"00"+ toSlv(i*4, 8), 0, partDlySync(i));
      end loop;

      axiSlaveRegister(axilEp, X"20", 0, v.txId);

      axiSlaveRegisterR(axilEp, X"24", 0, rxIdSync);

      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      if axilRst = '1' then
         v := REG_INIT_C;
         if (COMMON_CLK_G = false) then
            v.txId := r.txId;           -- can this survive a reset
         end if;
      end if;

      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;

      rin <= v;
   end process;

   seq : process (axilClk) is
   begin
      if rising_edge(axilClk) then
         r <= rin after TPD_G;
      end if;
   end process;

   U_txId : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => 32)
      port map (
         rst    => timingRxRst,
         wr_clk => axilClk,
         din    => r.txId,
         rd_clk => timingRxClk,
         dout   => txId);

end rtl;
