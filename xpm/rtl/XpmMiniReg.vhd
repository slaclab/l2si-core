-----------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : XpmMiniReg.vhd
-- Author     : Matt Weaver
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-12-14
-- Last update: 2019-03-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Software programmable register interface
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
use ieee.numeric_std.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use work.XpmPkg.all;
use work.XpmMiniPkg.all;

entity XpmMiniReg is
   port (
      axilClk          : in  sl;
      axilRst          : in  sl;
      axilWriteMaster  : in  AxiLiteWriteMasterType;  
      axilWriteSlave   : out AxiLiteWriteSlaveType;  
      axilReadMaster   : in  AxiLiteReadMasterType;  
      axilReadSlave    : out AxiLiteReadSlaveType;
      axilUpdate       : out sl;
      --
      staClk           : in  sl;
      status           : in  XpmMiniStatusType;
      config           : out XpmMiniConfigType );
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
    link           => (others=>'0'),
    linkCfg        => XPM_MINI_LINK_CONFIG_INIT_C,
    linkStat       => XPM_LINK_STATUS_INIT_C,
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
    axilRdEn       => '1' );

  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;

  signal s    : XpmMiniStatusType;
  signal linkStat, slinkStat  : XpmLinkStatusType;

  signal staUpdate : sl;
  signal pInhV     : sl;
  
begin

  config         <= r.config;
  axilReadSlave  <= r.axilReadSlave;
  axilWriteSlave <= r.axilWriteSlave;
  axilUpdate     <= r.axilRdEn;

  U_Sync64_ena : entity surf.SynchronizerFifo
    generic map ( DATA_WIDTH_G => LCtrDepth )
    port map ( wr_clk => staClk, wr_en => staUpdate,
               rd_clk => axilClk, rd_en=> r.axilRdEn,
               din  => status.partition.l0Select.enabled  ,
               dout => s.partition.l0Select.enabled);
  U_Sync64_inh : entity surf.SynchronizerFifo
    generic map ( DATA_WIDTH_G => LCtrDepth )
    port map ( wr_clk => staClk, wr_en => staUpdate,
               rd_clk => axilClk, rd_en=> r.axilRdEn,
               din  => status.partition.l0Select.inhibited  ,
               valid => pInhV,
               dout => s.partition.l0Select.inhibited);
  U_Sync64_num : entity surf.SynchronizerFifo
    generic map ( DATA_WIDTH_G => LCtrDepth )
    port map ( wr_clk => staClk, wr_en => staUpdate,
               rd_clk => axilClk, rd_en=> r.axilRdEn,
               din  => status.partition.l0Select.num  ,
               dout => s.partition.l0Select.num);
  U_Sync64_nin : entity surf.SynchronizerFifo
    generic map ( DATA_WIDTH_G => LCtrDepth )
    port map ( wr_clk => staClk, wr_en => staUpdate,
               rd_clk => axilClk, rd_en=> r.axilRdEn,
               din  => status.partition.l0Select.numInh  ,
               dout => s.partition.l0Select.numInh);
  U_Sync64_nac : entity surf.SynchronizerFifo
    generic map ( DATA_WIDTH_G => LCtrDepth )
    port map ( wr_clk => staClk, wr_en => staUpdate,
               rd_clk => axilClk, rd_en=> r.axilRdEn,
               din  => status.partition.l0Select.numAcc  ,
               dout => s.partition.l0Select.numAcc);
  
  comb : process (r, axilReadMaster, axilWriteMaster, status, s, axilRst) is
    variable v          : RegType;
    variable ep         : AxiLiteEndPointType;
    variable il         : integer;
    -- Shorthand procedures for read/write register
    procedure axilRegR64 (addr : in slv; reg : in slv) is
    begin
      axiSlaveRegisterR(ep, addr+0,0,reg(31 downto  0));
      axiSlaveRegisterR(ep, addr+4,0,resize(reg(reg'left downto 32),32));
    end procedure;
  begin
    v := r;
    -- reset strobing signals
    v.axilReadSlave.rdata := (others=>'0');
    v.config.partition.l0Select.reset := '0';
    v.config.partition.message.insert := '0';
    
    il := conv_integer(r.link(3 downto 0));
    
    if r.load='1' then
      v.linkCfg      := r.config.dsLink   (il);
    else
      v.config.dsLink   (il)      := r.linkCfg;
    end if;

    v.linkStat         := status.dsLink (il);  -- clock-domain?

    -- Determine the transaction type
    axiSlaveWaitTxn(ep, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);
    v.axilReadSlave.rdata := (others=>'0');
    
    -- Read/write to the configuration registers
    -- Read only from status registers

    axiSlaveRegister(ep, toSlv( 0,12), 0, v.link);
    
    v.load := '0';
    axiWrDetect(ep, toSlv(0,12), v.load);

    axiSlaveRegister(ep, toSlv( 4,12),   18, v.linkCfg.txPllReset);
    axiSlaveRegister(ep, toSlv( 4,12),   19, v.linkCfg.rxPllReset);
    axiSlaveRegister(ep, toSlv( 4,12),   28, v.linkCfg.loopback);
    axiSlaveRegister(ep, toSlv( 4,12),   29, v.linkCfg.txReset);
    axiSlaveRegister(ep, toSlv( 4,12),   30, v.linkCfg.rxReset);
    axiSlaveRegister(ep, toSlv( 4,12),   31, v.linkCfg.enable);

    axiSlaveRegisterR(ep, toSlv( 8,12),   0, r.linkStat.rxErrCnts);
    axiSlaveRegisterR(ep, toSlv( 8,12),  16, r.linkStat.txResetDone);
    axiSlaveRegisterR(ep, toSlv( 8,12),  17, r.linkStat.txReady);
    axiSlaveRegisterR(ep, toSlv( 8,12),  18, r.linkStat.rxResetDone);
    axiSlaveRegisterR(ep, toSlv( 8,12),  19, r.linkStat.rxReady);
    axiSlaveRegisterR(ep, toSlv( 8,12),  20, r.linkStat.rxIsXpm);

    axiSlaveRegisterR(ep, toSlv(12,12),  0, r.linkStat.rxId);
    axiSlaveRegisterR(ep, toSlv(16,12),  0, r.linkStat.rxRcvCnts);

    axiSlaveRegister (ep, toSlv(20,12), 0, v.config.partition.l0Select.reset);
    axiSlaveRegister (ep, toSlv(20,12),16, v.config.partition.l0Select.enabled);
    axiSlaveRegister (ep, toSlv(20,12),31, v.axilRdEn);

    axiSlaveRegister (ep, toSlv(24,12), 0, v.config.partition.l0Select.rateSel);
    axiSlaveRegister (ep, toSlv(24,12),16, v.config.partition.l0Select.destSel);

    axilRegR64(toSlv(32,12), s.partition.l0Select.enabled);
    axilRegR64(toSlv(40,12), s.partition.l0Select.inhibited);
    axilRegR64(toSlv(48,12), s.partition.l0Select.num);
    axilRegR64(toSlv(56,12), s.partition.l0Select.numInh);
    axilRegR64(toSlv(64,12), s.partition.l0Select.numAcc);

    axiSlaveRegister (ep, toSlv(72,12), 0, v.config.partition.pipeline.depth_clks);
    axiSlaveRegister (ep, toSlv(72,12),16, v.config.partition.pipeline.depth_fids);

    axiSlaveRegister (ep, toSlv(76,12),15, v.config.partition.message.insert);
    axiSlaveRegister (ep, toSlv(76,12), 0, v.config.partition.message.hdr);
    axiSlaveRegister (ep, toSlv(80,12), 0, v.config.partition.message.payload);

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
      r <= r_in;
    end if;
  end process;

  rseq : process (staClk, axilRst) is
    constant STATUS_INTERVAL_C : slv(19 downto 0) := toSlv(910000-1,20);
    variable cnt : slv(19 downto 0) := (others=>'0');
  begin
    if axilRst = '1' then
      cnt       := (others=>'0');
      staUpdate <= '0';
    elsif rising_edge(staClk) then
      if cnt = STATUS_INTERVAL_C then
        cnt       := (others=>'0');
        staUpdate <= '1';
      else
        cnt       := cnt+1;
        staUpdate <= '0';
      end if;
    end if;
  end process rseq;
  
end rtl;
