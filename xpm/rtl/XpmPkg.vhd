-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: XPM VHDL Package File
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

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

package XpmPkg is

   -----------------------------------------------------------
   -- Application: Configurations, Constants and Records Types
   -----------------------------------------------------------
   constant XPM_PARTITIONS_C            : integer := 8;
   constant XPM_PARTITION_ADDR_LENGTH_C : integer := 32;
   constant XPM_PARTITION_WORD_LENGTH_C : integer := 48;

   constant XPM_NUM_AMCS_C     : integer := 2;
   constant XPM_MAX_DS_LINKS_C : integer := 14;
   constant XPM_MAX_BP_LINKS_C : integer := 6;

   constant XPM_NUM_TAG_BYTES_C   : integer := 4;
   constant XPM_NUM_L1_TRIGGERS_C : integer := 1;
   constant XPM_LCTR_DEPTH_C      : integer := 40;

   --  Async ethernet message types
   constant XPM_MESSAGE_SEQUENCE_DONE : slv(15 downto 0) := toSlv(0,16);
   constant XPM_MESSAGE_STEP_DONE     : slv(15 downto 0) := toSlv(1,16);

   -- This doesn't belong here but not sure where to move it
   constant NSTREAMS_C : integer := 3;

   type XpmStreamType is record
      fiducial : sl;
      streams  : TimingSerialArray(NSTREAMS_C-1 downto 0);
      advance  : slv (NSTREAMS_C-1 downto 0);
   end record;

   constant XPM_STREAM_INIT_C : XpmStreamType := (
      fiducial => '0',
      streams  => (others => TIMING_SERIAL_INIT_C),
      advance  => (others => '0'));

   type XpmTxSerialType is record
      data  : slv(15 downto 0);
      dataK : slv(1 downto 0);
      sof   : sl;
      eof   : sl;
      addr  : sl;
      valid : sl;
   end record;
   constant XPM_TX_SERIAL_INIT_C : XpmTxSerialType := (
      data  => (others => '0'),
      dataK => (others => '0'),
      sof   => '0',
      eof   => '0',
      addr  => '0',
      valid => '0');

   --  Status of AMC Card jitter cleaner PLL
   type XpmPllStatusType is record
      lol : sl;
      los : sl;
   end record;
   constant XPM_PLL_STATUS_INIT_C : XpmPllStatusType := (lol => '1', los => '1');
   type XpmPllStatusArray is array(natural range<>) of XpmPllStatusType;

   --  Status of downstream links
   type XpmLinkStatusType is record
      txResetDone : sl;                 -- Downstream link transmit initialization status
      txReady     : sl;
      rxResetDone : sl;                 -- Downstream link receive initialization status
      rxReady     : sl;
      rxErr       : sl;
      rxErrCnts   : slv(15 downto 0);
      rxRcvCnts   : slv(31 downto 0);
      rxIsXpm     : sl;
      rxId        : slv(31 downto 0);
   end record;
   type XpmLinkStatusArray is array (natural range<>) of XpmLinkStatusType;
   constant XPM_LINK_STATUS_INIT_C : XpmLinkStatusType := (
      txResetDone => '0',
      txReady     => '0',
      rxResetDone => '0',
      rxReady     => '0',
      rxErr       => '0',
      rxErrCnts   => (others => '0'),
      rxRcvCnts   => (others => '0'),
      rxIsXpm     => '0',
      rxId        => (others => '0'));

   type XpmBpLinkStatusType is record
      linkUp : sl;
      ibRecv : slv(31 downto 0);
      rxErrs : slv(15 downto 0);
      rxLate : slv(15 downto 0);
   end record;
   type XpmBpLinkStatusArray is array (natural range<>) of XpmBpLinkStatusType;
   constant XPM_BP_LINK_STATUS_INIT_C : XpmBpLinkStatusType := (
      linkUp => '0',
      ibRecv => (others => '0'),
      rxErrs => (others => '0'),
      rxLate => (others => '0'));

   --
   --  Partition status
   --
   --    L0 Inhibit
   type XpmInhibitStatusType is record
      evcounts : Slv32Array(31 downto 0);
      tmcounts : Slv32Array(31 downto 0);
   end record;
   constant XPM_INHIBIT_STATUS_INIT_C : XpmInhibitStatusType := (
      evcounts => (others => (others => '0')),
      tmcounts => (others => (others => '0')));

   --    L0 Selection
   type XpmL0SelectStatusType is record
      enabled   : slv(XPM_LCTR_DEPTH_C-1 downto 0);
      inhibited : slv(XPM_LCTR_DEPTH_C-1 downto 0);
      num       : slv(XPM_LCTR_DEPTH_C-1 downto 0);
      numInh    : slv(XPM_LCTR_DEPTH_C-1 downto 0);
      numAcc    : slv(XPM_LCTR_DEPTH_C-1 downto 0);
   end record;
   type XpmL0SelectStatusArray is array(natural range<>) of XpmL0SelectStatusType;
   constant XPM_L0_SELECT_STATUS_INIT_C : XpmL0SelectStatusType := (
      enabled   => (others => '0'),
      inhibited => (others => '0'),
      num       => (others => '0'),
      numInh    => (others => '0'),
      numAcc    => (others => '0'));

   type XpmL1SelectStatusType is record
      numAcc : slv(XPM_LCTR_DEPTH_C-1 downto 0);
   end record;
   constant XPM_L1_SELECT_STATUS_INIT_C : XpmL1SelectStatusType := (
      numAcc => (others => '0'));

   type XpmPartitionStatusType is record
      inhibit  : XpmInhibitStatusType;
      l0Select : XpmL0SelectStatusType;
      l1Select : XpmL1SelectStatusType;
      anaRd    : slv(XPM_NUM_TAG_BYTES_C-1 downto 0);
   end record;
   constant XPM_PARTITION_STATUS_INIT_C : XpmPartitionStatusType := (
      inhibit  => XPM_INHIBIT_STATUS_INIT_C,
      l0Select => XPM_L0_SELECT_STATUS_INIT_C,
      l1Select => XPM_L1_SELECT_STATUS_INIT_C,
      anaRd    => (others => '0'));
   type XpmPartitionStatusArray is array(natural range<>) of XpmPartitionStatusType;

   type XpmStatusType is record
      dsLink    : XpmLinkStatusArray (XPM_MAX_DS_LINKS_C-1 downto 0);
      bpLink    : XpmBpLinkStatusArray(XPM_MAX_BP_LINKS_C downto 0);
      partition : XpmPartitionStatusArray(XPM_PARTITIONS_C-1 downto 0);
      paddr     : slv(XPM_PARTITION_ADDR_LENGTH_C-1 downto 0);
   end record;

   constant XPM_STATUS_INIT_C : XpmStatusType := (
      dsLink    => (others => XPM_LINK_STATUS_INIT_C),
      bpLink    => (others => XPM_BP_LINK_STATUS_INIT_C),
      partition => (others => XPM_PARTITION_STATUS_INIT_C),
      paddr     => (others => '1'));

   type XpmPllConfigType is record
      bwSel  : slv(3 downto 0);
      frqTbl : slv(1 downto 0);
      frqSel : slv(7 downto 0);
      rate   : slv(3 downto 0);
      sfOut  : slv(3 downto 0);
      inc    : sl;
      dec    : sl;
      bypass : sl;
      rstn   : sl;
   end record;
   constant XPM_PLL_CONFIG_INIT_C : XpmPllConfigType := (
      bwSel  => "0111",
      frqTbl => "10",
      frqSel => "01101001",
      rate   => "1010",
      sfOut  => "0110",
      inc    => '0',
      dec    => '0',
      bypass => '0',
      rstn   => '1');
   type XpmPllConfigArray is array(natural range<>) of XpmPllConfigType;

   type XpmLinkConfigType is record
      enable     : sl;
      loopback   : sl;
      txReset    : sl;
      rxReset    : sl;
      txPllReset : sl;
      rxPllReset : sl;
      txDelayRst : sl;
      txDelay    : slv(8 downto 0);
      rxTimeOut  : slv(8 downto 0);
      groupMask  : slv(XPM_PARTITIONS_C-1 downto 0);
      trigsrc    : slv(3 downto 0);
   end record;
   type XpmLinkConfigArray is array (natural range<>) of XpmLinkConfigType;
   constant XPM_LINK_CONFIG_INIT_C : XpmLinkConfigType := (
      enable     => '0',
      loopback   => '0',
      txReset    => '0',
      rxReset    => '0',
      txPllReset => '0',
      rxPllReset => '0',
      txDelayRst => '0',
      txDelay    => (others => '0'),
      rxTimeOut  => toSlv(200, 9),
      groupMask  => (others => '0'),
      trigsrc    => (others => '0'));
   type XpmL0SelectConfigType is record
      reset   : sl;
      enabled : sl;
      -- EventSelection
      rateSel : slv(15 downto 0);
      -- Bits(15:14)=(fixed,AC,seq,Cu)
      -- fixed:  marker = 3:0
      -- AC   :  marker = 2:0;  TS = 8:3 (mask)
      -- seq  :  bit    = 4:0;  seq = 12:8
      -- cu   :  event  = 7:0
      destSel : slv(15 downto 0);
   -- 15:15 = DONT_CARE
   --  3:0  = Destination
      groups  : slv(XPM_PARTITIONS_C-1 downto 0);
   end record;
   constant XPM_L0_SELECT_CONFIG_INIT_C : XpmL0SelectConfigType := (
      reset   => '0',
      enabled => '0',
      rateSel => (others => '0'),
      destSel => x"8000",
      groups  => (others => '0'));

   type XpmL1SelectConfigType is record
      clear    : slv(XPM_NUM_L1_TRIGGERS_C-1 downto 0);
      enable   : slv(XPM_NUM_L1_TRIGGERS_C-1 downto 0);
      trigsrc  : slv(3 downto 0);
      trigword : slv(8 downto 0);
      trigwr   : slv(XPM_NUM_L1_TRIGGERS_C-1 downto 0);
   end record;
   constant XPM_L1_SELECT_CONFIG_INIT_C : XpmL1SelectConfigType := (
      clear    => (others => '0'),
      enable   => (others => '0'),
      trigsrc  => (others => '0'),
      trigword => (others => '0'),
      trigwr   => (others => '0'));

   type XpmL0TagConfigType is record
      enable : sl;
   end record;
   constant XPM_L0_TAG_CONFIG_INIT_C : XpmL0TagConfigType := (
      enable => '0');

   type XpmInhibitConfigType is record
      enable   : sl;
      interval : slv(11 downto 0);
      limit    : slv(3 downto 0);       -- max L0s within l0interval
   end record;
   constant XPM_INHIBIT_CONFIG_INIT_C : XpmInhibitConfigType := (
      enable   => '0',
      limit    => (others => '1'),
      interval => (others => '0'));
   type XpmInhibitConfigArray is array (natural range<>) of XpmInhibitConfigType;

   type XpmPartInhConfigType is record
      setup : XpmInhibitConfigArray(3 downto 0);
   end record;
   constant XPM_PART_INH_CONFIG_INIT_C : XpmPartInhConfigType := (
      setup => (others => XPM_INHIBIT_CONFIG_INIT_C));

   type XpmPartMsgConfigType is record
      insert : sl;
      header : slv(8 downto 0);
   end record;
   constant XPM_PART_MSG_CONFIG_INIT_C : XpmPartMsgConfigType := (
      insert => '0',
      header => (others => '0'));

   -- constants for header(8:7)
   constant XPM_PART_MSG_DEFAULT_C   : slv(1 downto 0) := "00";
   constant XPM_PART_MSG_DROP_FULL_C : slv(1 downto 0) := "01";
   constant XPM_PART_MSG_WAIT_FULL_C : slv(1 downto 0) := "11";
   constant XPM_PART_MSG_LOW_PRIO_C  : slv(1 downto 0) := "10";
   
   --  Clear event header -> event data match fifos
   constant MSG_CLEAR_FIFO  : slv(7 downto 0) := toSlv(0, 8);
   --  Communicate delay of pword
   constant MSG_DELAY_PWORD : slv(7 downto 0) := toSlv(1, 8);

   type XpmAnalysisConfigType is record
      rst  : slv(XPM_NUM_TAG_BYTES_C-1 downto 0);
      tag  : slv(8*XPM_NUM_TAG_BYTES_C-1 downto 0);
      push : slv(XPM_NUM_TAG_BYTES_C-1 downto 0);
   end record;
   constant XPM_ANALYSIS_CONFIG_INIT_C : XpmAnalysisConfigType := (
      rst  => (others => '0'),
      tag  => (others => '0'),
      push => (others => '0'));

   type XpmPipelineConfigType is record
      depth_clks : slv(15 downto 0);
      depth_fids : slv(7 downto 0);
   end record;
   constant XPM_PIPELINE_CONFIG_INIT_C : XpmPipelineConfigType := (
      depth_clks => toSlv(100*200, 16),
      depth_fids => toSlv(99, 8));

   type XpmBsaConfigType is record
      enabled     : sl;
      activeSetup : slv(6 downto 0);
      activeDelay : slv(19 downto 0);
      activeWidth : slv(19 downto 0);
   end record;
   constant XPM_BSA_CONFIG_INIT_C : XpmBsaConfigType := (
      enabled     => '0',
      activeSetup => (others => '0'),
      activeDelay => (others => '0'),
      activeWidth => (others => '0'));

   type XpmPartitionConfigType is record
      master   : sl;
      l0Select : XpmL0SelectConfigType;
      l1Select : XpmL1SelectConfigType;
      analysis : XpmAnalysisConfigType;
      l0Tag    : XpmL0TagConfigType;
      pipeline : XpmPipelineConfigType;
      inhibit  : XpmPartInhConfigType;
      message  : XpmPartMsgConfigType;
   end record;
   constant XPM_PARTITION_CONFIG_INIT_C : XpmPartitionConfigType := (
      master   => '0',
      l0Select => XPM_L0_SELECT_CONFIG_INIT_C,
      l1Select => XPM_L1_SELECT_CONFIG_INIT_C,
      analysis => XPM_ANALYSIS_CONFIG_INIT_C,
      l0Tag    => XPM_L0_TAG_CONFIG_INIT_C,
      pipeline => XPM_PIPELINE_CONFIG_INIT_C,
      inhibit  => XPM_PART_INH_CONFIG_INIT_C,
      message  => XPM_PART_MSG_CONFIG_INIT_C);
   type XpmPartitionConfigArray is array (natural range<>) of XpmPartitionConfigType;

   type XpmConfigType is record
      dsLink    : XpmLinkConfigArray(XPM_MAX_DS_LINKS_C-1 downto 0);
      bpLink    : XpmLinkConfigArray(XPM_MAX_BP_LINKS_C downto 0);
      pll       : XpmPllConfigArray(XPM_NUM_AMCS_C-1 downto 0);
      partition : XpmPartitionConfigArray(XPM_PARTITIONS_C-1 downto 0);
      paddr     : slv(XPM_PARTITION_ADDR_LENGTH_C-1 downto 0);
      tagstream : sl;
   end record;
   constant XPM_CONFIG_INIT_C : XpmConfigType := (
      dsLink    => (others => XPM_LINK_CONFIG_INIT_C),
      bpLink    => (others => XPM_LINK_CONFIG_INIT_C),
      pll       => (others => XPM_PLL_CONFIG_INIT_C),
      partition => (others => XPM_PARTITION_CONFIG_INIT_C),
      paddr     => (others => '0'),
      tagstream => '0');

   type XpmAcceptFrameType is record
      strobe : sl;
   end record;
   constant XPM_ACCEPT_FRAME_INIT_C : XpmAcceptFrameType := (
      strobe => '0');

   function toSlv(s             : XpmLinkStatusType) return slv;
   function toLinkStatus(vector : slv) return XpmLinkStatusType;

   -----------------------------------------------
   -- XPM L1 Feedbacks
   -----------------------------------------------
   type XpmL1FeedbackType is record
      valid     : sl;
      partition : slv(2 downto 0);
      trigsrc   : slv(3 downto 0);
      tag       : slv(4 downto 0);
      trigword  : slv(8 downto 0);
   end record;

   type XpmL1FeedbackArray is array (natural range <>) of XpmL1FeedbackType;

   constant XPM_L1_FEEDBACK_INIT_C : XpmL1FeedbackType := (
      valid     => '0',
      partition => (others => '0'),
      trigsrc   => (others => '0'),
      tag       => (others => '0'),
      trigword  => (others => '0'));

   function toSlv(s : XpmL1FeedbackType) return slv;
   function toL1Feedback(vector : slv) return XpmL1FeedbackType;


end package XpmPkg;

package body XpmPkg is

   function toSlv(s : XpmLinkStatusType) return slv is
      variable vector : slv(85 downto 0) := (others => '0');
      variable i      : integer          := 0;
   begin
      assignSlv(i, vector, s.txResetDone);
      assignSlv(i, vector, s.txReady);
      assignSlv(i, vector, s.rxResetDone);
      assignSlv(i, vector, s.rxReady);
      assignSlv(i, vector, s.rxErr);
      assignSlv(i, vector, s.rxErrCnts);
      assignSlv(i, vector, s.rxRcvCnts);
      assignSlv(i, vector, s.rxIsXpm);
      assignSlv(i, vector, s.rxId);
      return vector;
   end function;

   function toLinkStatus(vector : slv) return XpmLinkStatusType is
      variable v : XpmLinkStatusType := XPM_LINK_STATUS_INIT_C;
      variable i : integer           := 0;
   begin
      assignRecord(i, vector, v.txResetDone);
      assignRecord(i, vector, v.txReady);
      assignRecord(i, vector, v.rxResetDone);
      assignRecord(i, vector, v.rxReady);
      assignRecord(i, vector, v.rxErr);
      assignRecord(i, vector, v.rxErrCnts);
      assignRecord(i, vector, v.rxRcvCnts);
      assignRecord(i, vector, v.rxIsXpm);
      assignRecord(i, vector, v.rxId);
      return v;
   end function;

   function toSlv(s : XpmL1FeedbackType) return slv is
      variable vector : slv(21 downto 0) := (others=>'0');
      variable i      : integer := 0;
   begin
      assignSlv(i, vector, s.valid);
      assignSlv(i, vector, s.partition);
      assignSlv(i, vector, s.trigsrc);
      assignSlv(i, vector, s.tag);
      assignSlv(i, vector, s.trigword);
      return vector;
   end function;

   function toL1Feedback(vector : slv) return XpmL1FeedbackType is
      variable s : XpmL1FeedbackType := XPM_L1_FEEDBACK_INIT_C;
      variable i : integer := 0;
   begin
      assignRecord(i, vector, s.valid);
      assignRecord(i, vector, s.partition);
      assignRecord(i, vector, s.trigsrc);
      assignRecord(i, vector, s.tag);
      assignRecord(i, vector, s.trigword);
      return s;
   end function;

end package body XpmPkg;
