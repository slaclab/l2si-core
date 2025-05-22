-----------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Software programmable register interface
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
use ieee.numeric_std.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;

library l2si_core;
use l2si_core.XpmPkg.all;
use l2si_core.XpmMiniPkg.all;

entity XpmMiniReg is
   generic (
      TPD_G : time := 1 ns);
   port (
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilUpdate      : out sl;
      --
      staClk          : in  sl;
      staRst          : in  sl;
      status          : in  XpmMiniStatusType;
      config          : out XpmMiniConfigType);
end XpmMiniReg;

architecture rtl of XpmMiniReg is

   type RegType is record
      load           : sl;
      config         : XpmMiniConfigType;
      link           : slv(3 downto 0);
      linkCfg        : XpmMiniLinkConfigType;
      linkStat       : XpmLinkStatusType;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      axilRdEn       : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      load           => '1',
      config         => XPM_MINI_CONFIG_INIT_C,
      link           => (others => '0'),
      linkCfg        => XPM_MINI_LINK_CONFIG_INIT_C,
      linkStat       => XPM_LINK_STATUS_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilRdEn       => '1');

   signal r    : RegType := REG_INIT_C;
   signal r_in : RegType;

   signal s         : XpmMiniStatusType;
   signal linkStat  : XpmLinkStatusType;
   signal slinkStat : XpmLinkStatusType;

   signal staUpdate : sl;
   signal pInhV     : sl;

begin

   config         <= r.config;
   axilReadSlave  <= r.axilReadSlave;
   axilWriteSlave <= r.axilWriteSlave;
   axilUpdate     <= r.axilRdEn;

   U_Sync64_ena : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => XPM_LCTR_DEPTH_C)
      port map (
         wr_clk => staClk,
         wr_en  => staUpdate,
         rd_clk => axilClk,
         rd_en  => r.axilRdEn,
         din    => status.partition.l0Select.enabled,
         dout   => s.partition.l0Select.enabled);

   U_Sync64_inh : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => XPM_LCTR_DEPTH_C)
      port map (
         wr_clk => staClk,
         wr_en  => staUpdate,
         rd_clk => axilClk,
         rd_en  => r.axilRdEn,
         din    => status.partition.l0Select.inhibited,
         valid  => pInhV,
         dout   => s.partition.l0Select.inhibited);

   U_Sync64_num : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => XPM_LCTR_DEPTH_C)
      port map (
         wr_clk => staClk,
         wr_en  => staUpdate,
         rd_clk => axilClk,
         rd_en  => r.axilRdEn,
         din    => status.partition.l0Select.num,
         dout   => s.partition.l0Select.num);

   U_Sync64_nin : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => XPM_LCTR_DEPTH_C)
      port map (
         wr_clk => staClk,
         wr_en  => staUpdate,
         rd_clk => axilClk,
         rd_en  => r.axilRdEn,
         din    => status.partition.l0Select.numInh,
         dout   => s.partition.l0Select.numInh);

   U_Sync64_nac : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => XPM_LCTR_DEPTH_C)
      port map (
         wr_clk => staClk,
         wr_en  => staUpdate,
         rd_clk => axilClk,
         rd_en  => r.axilRdEn,
         din    => status.partition.l0Select.numAcc,
         dout   => s.partition.l0Select.numAcc);

   GEN_LINKSTAT_SYNC : for i in XPM_MAX_DS_LINKS_C-1 downto 0 generate
      U_Sync_dslink_rxId : entity surf.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => XPM_LCTR_DEPTH_C)
         port map (
            wr_clk => staClk,
            wr_en  => staUpdate,
            rd_clk => axilClk,
            rd_en  => r.axilRdEn,
            din    => status.dsLink(i).rxId,
            dout   => s.dsLink(i).rxId);

      U_Sync_dslink_rxRcvCnts : entity surf.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => XPM_LCTR_DEPTH_C)
         port map (
            wr_clk => staClk,
            wr_en  => staUpdate,
            rd_clk => axilClk,
            rd_en  => r.axilRdEn,
            din    => status.dsLink(i).rxRcvCnts,
            dout   => s.dsLink(i).rxRcvCnts);
   end generate GEN_LINKSTAT_SYNC;

   comb : process (axilReadMaster, axilRst, axilWriteMaster, r, s) is
      variable v  : RegType;
      variable ep : AxiLiteEndPointType;
      variable il : integer;
   begin
      v                                 := r;
      -- reset strobing signals
      v.config.partition.l0Select.reset := '0';
      v.config.partition.message.insert := '0';

      il := conv_integer(r.link(3 downto 0));

      if r.load = '1' then
         v.linkCfg := r.config.dsLink (il);
      else
         v.config.dsLink (il) := r.linkCfg;
      end if;

      v.linkStat := s.dsLink (il);

      -- Determine the transaction type
      axiSlaveWaitTxn(ep, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Read/write to the configuration registers
      -- Read only from status registers

      axiSlaveRegister(ep, X"00", 0, v.link);

      v.load := '0';
      axiWrDetect(ep, X"00", v.load);

      axiSlaveRegister(ep, X"04", 18, v.linkCfg.txPllReset);
      axiSlaveRegister(ep, X"04", 19, v.linkCfg.rxPllReset);
      axiSlaveRegister(ep, X"04", 28, v.linkCfg.loopback);
      axiSlaveRegister(ep, X"04", 29, v.linkCfg.txReset);
      axiSlaveRegister(ep, X"04", 30, v.linkCfg.rxReset);
      axiSlaveRegister(ep, X"04", 31, v.linkCfg.enable);

      axiSlaveRegisterR(ep, X"08", 0, r.linkStat.rxErrCnts);
      axiSlaveRegisterR(ep, X"08", 16, r.linkStat.txResetDone);
      axiSlaveRegisterR(ep, X"08", 17, r.linkStat.txReady);
      axiSlaveRegisterR(ep, X"08", 18, r.linkStat.rxResetDone);
      axiSlaveRegisterR(ep, X"08", 19, r.linkStat.rxReady);
      axiSlaveRegisterR(ep, X"08", 20, r.linkStat.rxIsXpm);

      axiSlaveRegisterR(ep, X"0C", 0, r.linkStat.rxId);
      axiSlaveRegisterR(ep, X"10", 0, r.linkStat.rxRcvCnts);

      axiSlaveRegister (ep, X"14", 0, v.config.partition.l0Select.reset);
      axiSlaveRegister (ep, X"14", 16, v.config.partition.l0Select.enabled);
      axiSlaveRegister (ep, X"14", 31, v.axilRdEn);

      axiSlaveRegister (ep, X"18", 0, v.config.partition.l0Select.rateSel);
      axiSlaveRegister (ep, X"18", 16, v.config.partition.l0Select.destSel);

      axiSlaveRegisterR(ep, X"20", 0, s.partition.l0Select.enabled);
      axiSlaveRegisterR(ep, X"28", 0, s.partition.l0Select.inhibited);
      axiSlaveRegisterR(ep, X"30", 0, s.partition.l0Select.num);
      axiSlaveRegisterR(ep, X"38", 0, s.partition.l0Select.numInh);
      axiSlaveRegisterR(ep, X"40", 0, s.partition.l0Select.numAcc);

      axiSlaveRegister (ep, X"48", 0, v.config.partition.pipeline.depth_clks);
      axiSlaveRegister (ep, X"48", 16, v.config.partition.pipeline.depth_fids);

      axiSlaveRegister (ep, X"4C", 15, v.config.partition.message.insert);
      axiSlaveRegister (ep, X"4C", 0, v.config.partition.message.header);

      -- Set the status
      axiSlaveDefault(ep, v.axilWriteSlave, v.axilReadSlave);

      ----------------------------------------------------------------------------------------------
      -- Reset
      ----------------------------------------------------------------------------------------------
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      r_in <= v;
   end process;

   seq : process (axilClk) is
   begin
      if rising_edge(axilClk) then
         r <= r_in after TPD_G;
      end if;
   end process;


   rseq : process (staClk, staRst) is
      constant STATUS_INTERVAL_C : slv(19 downto 0) := toSlv(910000-1, 20);
      variable cnt               : slv(19 downto 0) := (others => '0');
   begin
      if staRst = '1' then
         cnt       := (others => '0');
         staUpdate <= '0' after TPD_G;
      elsif rising_edge(staClk) then
         if cnt = STATUS_INTERVAL_C then
            cnt       := (others => '0');
            staUpdate <= '1' after TPD_G;
         else
            cnt       := cnt+1 after TPD_G;
            staUpdate <= '0'   after TPD_G;
         end if;
      end if;
   end process rseq;

end rtl;
