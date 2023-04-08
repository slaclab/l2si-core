-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

library lcls_timing_core;
use lcls_timing_core.TPGPkg.all;

library l2si_core;
use l2si_core.XpmSeqPkg.all;

entity XpmSeqXbar is
   generic (
      TPD_G            : time             := 1 ns;
      AXIL_BASEADDR_G  : slv(31 downto 0) := (others=>'0');
      AXIL_ASYNC_G     : boolean          := true );
   port (
      -- AXI-Lite Interface (on axiClk domain)
      axiClk          : in  sl;
      axiRst          : in  sl;
      axiReadMaster   : in  AxiLiteReadMasterType;
      axiReadSlave    : out AxiLiteReadSlaveType;
      axiWriteMaster  : in  AxiLiteWriteMasterType;
      axiWriteSlave   : out AxiLiteWriteSlaveType;
      -- Configuration/Status (on clk domain)
      clk             : in  sl;
      rst             : in  sl;
      status          : in  XpmSeqStatusType;
      config          : out XpmSeqConfigType );
end XpmSeqXbar;

architecture xbar of XpmSeqXbar is

   constant SEQSTATE_INDEX_C  : natural := 0;
   constant SEQJUMP_INDEX_C   : natural := 1;
   constant SEQMEM_INDEX_C    : natural := 2;
   constant NUM_AXI_MASTERS_C : natural := 3;

   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(0 to 2) := (
      0                  => (baseAddr     => X"00000000" + AXIL_BASEADDR_G,
                             addrBits     => 14,
                             connectivity => X"FFFF"),
      1                  => (baseAddr     => X"00004000" + AXIL_BASEADDR_G,
                             addrBits     => 14,
                             connectivity => X"FFFF"),
      2                  => (baseAddr     => X"00008000" + AXIL_BASEADDR_G,
                             addrBits     => 15,
                             connectivity => X"FFFF"));

   signal mAxilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxilWriteSlaves  : AxiLiteWriteSlaveArray (NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxilReadMasters  : AxiLiteReadMasterArray (NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxilReadSlaves   : AxiLiteReadSlaveArray  (NUM_AXI_MASTERS_C-1 downto 0);

   signal syncWriteMaster : AxiLiteWriteMasterType;
   signal syncWriteSlave  : AxiLiteWriteSlaveType;
   signal syncReadMaster  : AxiLiteReadMasterType;
   signal syncReadSlave   : AxiLiteReadSlaveType;

   signal statusS    : XpmSeqStatusType;
   signal statusSlv  : slv(XPM_SEQ_STATUS_BITS_C-1 downto 0);
   signal statusSlvS : slv(XPM_SEQ_STATUS_BITS_C-1 downto 0);
   
   signal mConfig     : XpmSeqConfigArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal mConfigS    : XpmSeqConfigArray(NUM_AXI_MASTERS_C-1 downto 0);

   type XpmSeqConfigSlvArray is array (natural range <>) of slv(XPM_SEQ_CONFIG_BITS_C-1 downto 0);   
   signal mConfigSlv  : XpmSeqConfigSlvArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal mConfigSlvS : XpmSeqConfigSlvArray(NUM_AXI_MASTERS_C-1 downto 0);
   
   signal regclk : sl;
   signal regrst : sl;
begin

   --------------------------
   -- AXI-Lite: Crossbar Core
   --------------------------
   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
      port map (
         axiClk              => regclk,
         axiClkRst           => regrst,
         sAxiWriteMasters(0) => syncWriteMaster,
         sAxiWriteSlaves(0)  => syncWriteSlave,
         sAxiReadMasters(0)  => syncReadMaster,
         sAxiReadSlaves(0)   => syncReadSlave,
         mAxiWriteMasters    => mAxilWriteMasters,
         mAxiWriteSlaves     => mAxilWriteSlaves,
         mAxiReadMasters     => mAxilReadMasters,
         mAxiReadSlaves      => mAxilReadSlaves);

   U_SeqJumpReg : entity l2si_core.XpmSeqJumpReg
      port map (
         axiReadMaster  => mAxilReadMasters (SEQJUMP_INDEX_C),
         axiReadSlave   => mAxilReadSlaves  (SEQJUMP_INDEX_C),
         axiWriteMaster => mAxilWriteMasters(SEQJUMP_INDEX_C),
         axiWriteSlave  => mAxilWriteSlaves (SEQJUMP_INDEX_C),
         status         => statusS,
         config         => mConfigS         (SEQJUMP_INDEX_C),
         axiClk         => regclk,
         axiRst         => regrst);

   U_SeqStateReg : entity l2si_core.XpmSeqStateReg
      port map (
         axiReadMaster  => mAxilReadMasters (SEQSTATE_INDEX_C),
         axiReadSlave   => mAxilReadSlaves  (SEQSTATE_INDEX_C),
         axiWriteMaster => mAxilWriteMasters(SEQSTATE_INDEX_C),
         axiWriteSlave  => mAxilWriteSlaves (SEQSTATE_INDEX_C),
         status         => statusS,
         config         => mConfigS         (SEQSTATE_INDEX_C),
         axiClk         => regclk,
         axiRst         => regrst);

   U_SeqMemReg : entity l2si_core.XpmSeqMemReg
      generic map (
         ADDR_BITS_G => 15 )
      port map (
         axiReadMaster  => mAxilReadMasters (SEQMEM_INDEX_C),
         axiReadSlave   => mAxilReadSlaves  (SEQMEM_INDEX_C),
         axiWriteMaster => mAxilWriteMasters(SEQMEM_INDEX_C),
         axiWriteSlave  => mAxilWriteSlaves (SEQMEM_INDEX_C),
         status         => statusS,
         config         => mConfigS         (SEQMEM_INDEX_C),
         axiClk         => regclk,
         axiRst         => regrst);

   GEN_ASYNC : if AXIL_ASYNC_G generate
     regclk     <= clk;
     regrst     <= rst;
     statusS    <= status;
     mConfig    <= mConfigS;

     U_AxiLiteAsync : entity surf.AxiLiteAsync
       generic map (
         TPD_G        => TPD_G )
       port map (
         sAxiClk         => axiClk,
         sAxiClkRst      => axiRst,
         sAxiReadMaster  => axiReadMaster,
         sAxiReadSlave   => axiReadSlave,
         sAxiWriteMaster => axiWriteMaster,
         sAxiWriteSlave  => axiWriteSlave,
         mAxiClk         => clk,
         mAxiClkRst      => rst,
         mAxiReadMaster  => syncReadMaster,
         mAxiReadSlave   => syncReadSlave,
         mAxiWriteMaster => syncWriteMaster,
         mAxiWriteSlave  => syncWriteSlave );
   end generate;
   
   GEN_SYNC : if not AXIL_ASYNC_G generate
     regclk     <= axiClk;
     regrst     <= axiRst;
     
     syncReadMaster  <= axiReadMaster;
     axiReadSlave    <= syncReadSlave;
     syncWriteMaster <= axiWriteMaster;
     axiWriteSlave   <= syncWriteSlave;
     
     statusSlv  <= toSlv(status);
     statusS    <= toXpmSeqStatusType(statusSlvS);

     U_StatusSync : entity surf.SynchronizerVector
       generic map (
         WIDTH_G => XPM_SEQ_STATUS_BITS_C)
       port map (
         clk     => regclk,
         dataIn  => statusSlv,
         dataOut => statusSlvS);

     GEN_MEMCONFIG: for i in 0 to NUM_AXI_MASTERS_C-1 generate
       mConfigSlvS(i) <= toSlv(mConfigS(i));
       mConfig    (i) <= toXpmSeqConfigType(mConfigSlv(i));
       U_ConfigSync : entity surf.SynchronizerVector
         generic map (
           WIDTH_G => XPM_SEQ_CONFIG_BITS_C)
         port map (
           clk     => clk,
           dataIn  => mConfigSlvS(i),
           dataOut => mConfigSlv (i));
     end generate GEN_MEMCONFIG;
   end generate;
   
   -------------------------------
   -- Configuration Register
   -------------------------------
   comb : process (mConfig) is
      variable v : XpmSeqConfigType;
   begin
      v               := mConfig(SEQMEM_INDEX_C  );
      v.seqJumpConfig := mConfig(SEQJUMP_INDEX_C ).seqJumpConfig;
      v.seqEnable     := mConfig(SEQSTATE_INDEX_C).seqEnable;
      v.seqRestart    := mConfig(SEQSTATE_INDEX_C).seqRestart;
      config          <= v;
   end process comb;

end xbar;
