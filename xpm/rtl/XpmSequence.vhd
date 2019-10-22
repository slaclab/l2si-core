-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : XpmSequence.vhd
-- Author     : Matt Weaver  <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-25
-- Last update: 2019-05-20
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 Timing Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 Timing Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use work.TimingPkg.all;
use work.TPGPkg.all;
use work.XpmSeqPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.EthMacPkg.all;

entity XpmSequence is
   generic (
      AXIL_BASEADDR_G  : slv(31 downto 0) := (others=>'0') );
   port (
      -- AXI-Lite Interface (on axiClk domain)
      axilClk          : in  sl;
      axilRst          : in  sl;
      axilReadMaster   : in  AxiLiteReadMasterType;
      axilReadSlave    : out AxiLiteReadSlaveType;
      axilWriteMaster  : in  AxiLiteWriteMasterType;
      axilWriteSlave   : out AxiLiteWriteSlaveType;
      obAppMaster      : out AxiStreamMasterType;
      obAppSlave       : in  AxiStreamSlaveType;
      -- Configuration/Status (on clk domain)
      timingClk        : in  sl;
      timingRst        : in  sl;
      timingAdvance    : in  sl;
      timingDataIn     : in  slv(15 downto 0);
      timingDataOut    : out slv(15 downto 0) );
end XpmSequence;

architecture mapping of XpmSequence is

  signal status      : XpmSeqStatusType;
  signal config      : XpmSeqConfigType;
  signal seqData     : Slv17Array  (XPMSEQDEPTH-1 downto 0);
  signal seqDataValid: slv         (XPMSEQDEPTH-1 downto 0);
  signal seqReset    : slv         (XPMSEQDEPTH-1 downto 0);
  signal seqJump     : slv         (XPMSEQDEPTH-1 downto 0);
  signal seqJumpAddr : SeqAddrArray(XPMSEQDEPTH-1 downto 0);
  signal seqAddr     : SeqAddrArray(XPMSEQDEPTH-1 downto 0);
  signal frameSlv    : slv(TIMING_MESSAGE_BITS_C-1 downto 0);
  signal frame       : TimingMessageType;
  signal tframeSlv    : slv(TIMING_MESSAGE_BITS_C-1 downto 0);
  signal tframe       : TimingMessageType;
  
  constant S0 : integer := 12;
  constant SN : integer := S0+46;
  
  type RegType is record
    advance : sl;
    frame   : slv(207 downto 0); -- Really 64b
    framel  : slv(207 downto 0);
    strobe  : slv(SN downto 0);
    data    : slv(15 downto 0);
    invalid : Slv32Array(XPMSEQDEPTH-1 downto 0);
    master  : AxiStreamMasterType;
    ack     : slv       (XPMSEQDEPTH-1 downto 0);
  end record RegType;

  constant REG_INIT_C : RegType := (
    advance => '0',
    frame   => (others=>'0'),
    framel  => (others=>'0'),
    strobe  => (others=>'0'),
    data    => (others=>'0'),
    invalid => (others=>(others=>'0')),
    master  => axiStreamMasterInit(EMAC_AXIS_CONFIG_C),
    ack     => (others=>'0') );

  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;

  signal seqNotifyValid : slv         (XPMSEQDEPTH-1 downto 0);
  signal seqNotify      : SeqAddrArray(XPMSEQDEPTH-1 downto 0);

  signal axisSlave      : AxiStreamSlaveType;
    
begin

  timingDataOut <= r_in.data;

  U_FIFO : entity surf.AxiStreamFifoV2
    generic map ( SLAVE_AXI_CONFIG_G  => EMAC_AXIS_CONFIG_C,
                  MASTER_AXI_CONFIG_G => EMAC_AXIS_CONFIG_C,
                  FIFO_ADDR_WIDTH_G   => 4 )
    port map ( sAxisClk    => timingClk,
               sAxisRst    => timingRst,
               sAxisMaster => r.master,
               sAxisSlave  => axisSlave,
               mAxisClk    => axilClk,
               mAxisRst    => axilRst,
               mAxisMaster => obAppMaster,
               mAxisSlave  => obAppSlave );
  
  U_XBar : entity work.XpmSeqXbar
    generic map ( AXIL_BASEADDR_G => AXIL_BASEADDR_G )
    port map ( axiClk         => axilClk,
               axiRst         => axilRst,
               axiReadMaster  => axilReadMaster,
               axiReadSlave   => axilReadSlave,
               axiWriteMaster => axilWriteMaster,
               axiWriteSlave  => axilWriteSlave,
               clk            => timingClk,
               rst            => timingRst,
               status         => status,
               config         => config );

  frameSlv <= toSlv(0, TIMING_MESSAGE_BITS_C-r.framel'length) &
              r.framel;
  frame    <= toTimingMessageType( frameSlv );

  tframeSlv <= toSlv(0, TIMING_MESSAGE_BITS_C-r.frame'length) &
               r.frame;
  tframe    <= toTimingMessageType( tframeSlv );
  
  GEN_SEQ : for i in 0 to XPMSEQDEPTH-1 generate
    U_SeqRst : entity work.SeqReset
      port map (
        clk      => timingClk,
        rst      => timingRst,
        config   => config.seqJumpConfig(i),
        frame    => frame,
        strobe   => r.strobe(S0),
        resetReq => config.seqRestart(i),
        resetO   => seqReset(i));
    U_Jump_i : entity work.SeqJump
      port map (
        clk      => timingClk,
        rst      => timingRst,
        config   => config.seqJumpConfig(i),
        manReset => seqReset(i),
        bcsFault => '0',
        mpsFault => '0',
        mpsClass => (others=>'0'),
        jumpEn   => r.strobe(S0),
        jumpReq  => seqJump(i),
        jumpAddr => seqJumpAddr(i));

    U_Seq : entity work.Sequence
      port map (
        clkA         => timingClk,
        rstA         => timingRst,
        wrEnA        => config.seqWrEn     (i),
        indexA       => config.seqAddr,
        rdStepA      => status.seqRdData   (i),
        wrStepA      => config.seqWrData,
        clkB         => timingClk,
        rstB         => timingRst,
        rdEnB        => r.strobe(S0+1),
        waitB        => r.strobe(S0+4),
        acTS         => frame.acTimeSlot,
        acRate       => frame.acRates,
        fixedRate    => frame.fixedRates,
        seqReset     => seqJump            (i),
        startAddr    => seqJumpAddr        (i),
        seqState     => status.seqState    (i),
        seqNotify    => seqNotify          (i),
        seqNotifyWr  => seqNotifyValid     (i),
        seqNotifyAck => r.ack              (i),
        dataO        => seqData            (i),
        dataValid    => seqDataValid       (i),
        monReset     => seqReset           (i),
        monCount     => status.countRequest(i) );
  end generate;

  --
  --  Replace words in the timing frame.  Skip recalculating the CRC
  --  in the frame, since it will be done on transmission.
  --
  comb: process ( timingRst, r, config, timingDataIn, timingAdvance,
                  seqReset, seqData, seqDataValid, seqNotify, seqNotifyValid, axisSlave ) is
    variable v : RegType;
  begin
    v := r;

    v.advance := timingAdvance;
    v.strobe := r.strobe(r.strobe'left-1 downto 0) & (timingAdvance and not r.advance);
    v.frame  := timingDataIn & r.frame(r.frame'left downto 16);

    if v.strobe(S0)='1' then
      v.framel := v.frame;
    end if;
    
    v.data   := timingDataIn;

    for i in 0 to XPMSEQDEPTH-1 loop
      if (config.seqEnable(i) = '1' and
          r.strobe(SN-XPMSEQDEPTH+i) = '1') then
        v.data := seqData(i)(15 downto 0);
        if seqDataValid(i) = '0' then
          v.invalid(i) := r.invalid(i)+1;
        end if;
      end if;
      if seqReset(i) = '1' then
        v.invalid(i) := (others=>'0');
      end if;
      status.countInvalid(i) <= r.invalid(i);
    end loop;

    v.master.tLast  := '1';
    v.master.tKeep  := genTKeep(XPMSEQDEPTH*2+2);
    
    if axisSlave.tReady = '1' then
      v.master.tValid := '0';
    end if;

    if v.master.tValid = '0' and seqNotifyValid /= 0 then
      v.ack           := seqNotifyValid;
      ssiSetUserSof (EMAC_AXIS_CONFIG_C, v.master, '1');
      ssiSetUserEofe(EMAC_AXIS_CONFIG_C, v.master, '0');
      v.master.tValid := '1';
      v.master.tData(15 downto 0) := resize(seqNotifyValid,16);
      for i in 0 to XPMSEQDEPTH-1 loop
        if seqNotifyValid(i) = '1' then
          v.master.tData(16*i+31 downto 16*i+16) := resize(slv(seqNotify(i)),16);
        end if;
      end loop;
    end if;
    
    if timingRst = '1' then
      v := REG_INIT_C;
    end if;

    r_in <= v;
  end process comb;

  seq : process ( timingClk ) is
  begin
    if rising_edge(timingClk) then
      r <= r_in;
    end if;
  end process seq;
  
end mapping;
