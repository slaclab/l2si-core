-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Package of constants and record definitions for the Timing Generator.
-------------------------------------------------------------------------------
-- This file is part of 'L2SI Core'. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'L2SI Core', including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use ieee.math_real.all;

library surf;
use surf.StdRtlPkg.all;

library lcls_timing_core;
use lcls_timing_core.TPGPkg.all;

package XpmSeqPkg is

   constant XPM_SEQ_DEPTH_C : integer := 1;

   type XpmSeqStatusType is record
      -- implemented resources
      nexptseq     : slv (7 downto 0);
      seqaddrlen   : slv (3 downto 0);
      --
      countRequest : Slv32Array(XPM_SEQ_DEPTH_C-1 downto 0);
      countInvalid : Slv32Array(XPM_SEQ_DEPTH_C-1 downto 0);
      countUpdate  : sl;                -- single sysclk pulse
      seqRdData    : Slv32Array(XPM_SEQ_DEPTH_C-1 downto 0);
      seqState     : SequencerStateArray(XPM_SEQ_DEPTH_C-1 downto 0);
   end record;

   constant XPM_SEQ_STATUS_INIT_C : XpmSeqStatusType := (
      nexptseq     => (others => '0'),
      seqaddrlen   => (others => '0'),
      countRequest => (others => (others => '0')),
      countInvalid => (others => (others => '0')),
      countUpdate  => '0',
      seqRdData    => (others => (others => '0')),
      seqState     => (others => SEQUENCER_STATE_INIT_C));

   constant XPM_SEQ_STATUS_BITS_C : integer := 13 + XPM_SEQ_DEPTH_C*(96+SEQCOUNTDEPTH+SEQADDRLEN);
   
   function toSlv(s : XpmSeqStatusType) return slv;
   function toXpmSeqStatusType (v : slv) return XpmSeqStatusType;
   
   type XpmSeqConfigType is record
      seqEnable     : slv(XPM_SEQ_DEPTH_C-1 downto 0);
      seqRestart    : slv(XPM_SEQ_DEPTH_C-1 downto 0);
      diagSeq       : slv(6 downto 0);
      seqAddr       : SeqAddrType;
      seqWrData     : slv(31 downto 0);
      seqWrEn       : slv(XPM_SEQ_DEPTH_C-1 downto 0);
      seqJumpConfig : TPGJumpConfigArray(XPM_SEQ_DEPTH_C-1 downto 0);
   end record;

   constant XPM_SEQ_CONFIG_INIT_C : XpmSeqConfigType := (
      seqEnable     => (others => '0'),
      seqRestart    => (others => '0'),
      diagSeq       => (others => '1'),
      seqAddr       => (others => '0'),
      seqWrData     => (others => '0'),
      seqWrEn       => (others => '0'),
      seqJumpConfig => (others => TPG_JUMPCONFIG_INIT_C)
      );

   constant XPM_SEQ_CONFIG_BITS_C : integer := 39 + SEQADDRLEN + XPM_SEQ_DEPTH_C*(3+24+(MPSCHAN+2)*SEQADDRLEN+MPSCHAN*4);

   function toSlv(c : XpmSeqConfigType) return slv;
   function toXpmSeqConfigType (v : slv) return XpmSeqConfigType;

   type XpmSeqConfigArray is array(natural range<>) of XpmSeqConfigType;

   type XpmSeqNotifyType is record
      valid : sl;
      addr  : SeqAddrType;
   end record;

   type XpmSeqNotifyArray is array(natural range<>) of XpmSeqNotifyType;

end XpmSeqPkg;

package body XpmSeqPkg is
  
   function toSlv(s : XpmSeqStatusType) return slv
   is
     variable vector : slv(XPM_SEQ_STATUS_BITS_C-1 downto 0) := (others => '0');
     variable i      : integer                               := 0;
   begin
      assignSlv(i, vector, s.nexpteq);
      assignSlv(i, vector, s.seqaddrlen);
      assignSlv(i, vector, s.countUpdate);
      for j in 0 to XPM_SEQ_DEPTH_C-1 loop
        assignSlv(i, vector, s.countRequest(j));
        assignSlv(i, vector, s.countInvalid(j));
        assignSlv(i, vector, s.seqRdData   (j));
        assignSlv(i, vector, s.seqState    (j));
      end loop;  -- j
      return vector;
   end function;
     
   function toXpmSeqStatusType (vector : slv) return XpmSeqStatusType
   is
     variable s : XpmSeqStatusType;
     variable i : integer := 0;
   begin
      assignRecord(i, vector, s.nexpteq);
      assignRecord(i, vector, s.seqaddrlen);
      assignRecord(i, vector, s.countUpdate);
      for j in 0 to XPM_SEQ_DEPTH_C-1 loop
        assignRecord(i, vector, s.countRequest(j));
        assignRecord(i, vector, s.countInvalid(j));
        assignRecord(i, vector, s.seqRdData   (j));
        assignRecord(i, vector, s.seqState    (j));
      end loop;  -- j
      return s;
   end function;

   function toSlv(s : XpmSeqConfigType) return slv
   is
     variable vector : slv(XPM_SEQ_CONFIG_BITS_C-1 downto 0) := (others => '0');
     variable i      : integer                               := 0;
   begin
      assignSlv(i, vector, s.seqEnable);
      assignSlv(i, vector, s.seqRestart);
      assignSlv(i, vector, s.diagSeq);
      assignSlv(i, vector, s.seqAddr);
      assignSlv(i, vector, s.seqWrData);
      assignSlv(i, vector, s.seqWrEn);
      for j in 0 to XPM_SEQ_DEPTH_C-1 loop
        assignSlv(i, vector, s.seqJumpConfig(j).syncSel);
        assignSlv(i, vector, s.seqJumpConfig(j).syncJump);
        assignSlv(i, vector, s.seqJumpConfig(j).syncClass);
        assignSlv(i, vector, s.seqJumpConfig(j).bcsJump);
        assignSlv(i, vector, s.seqJumpConfig(j).bcsClass);
        for k in 0 to MPSCHAN loop
          assignSlv(i, vector, s.seqJumpConfig(j).mpsJump (k));
          assignSlv(i, vector, s.seqJumpConfig(j).mpsClass(k));
        end loop;  -- k
      end loop;  -- j
      return vector;
   end function;
     
   function toXpmSeqConfigType (v : slv) return XpmSeqConfigType
   is
     variable s : XpmSeqConfigType;
     variable i : integer := 0;
   begin
      assignRecord(i, vector, s.seqEnable);
      assignRecord(i, vector, s.seqRestart);
      assignRecord(i, vector, s.diagSeq);
      assignRecord(i, vector, s.seqAddr);
      assignRecord(i, vector, s.seqWrData);
      assignRecord(i, vector, s.seqWrEn);
      for j in 0 to XPM_SEQ_DEPTH_C-1 loop
        assignRecord(i, vector, s.seqJumpConfig(j).syncSel);
        assignRecord(i, vector, s.seqJumpConfig(j).syncJump);
        assignRecord(i, vector, s.seqJumpConfig(j).syncClass);
        assignRecord(i, vector, s.seqJumpConfig(j).bcsJump);
        assignRecord(i, vector, s.seqJumpConfig(j).bcsClass);
        for k in 0 to MPSCHAN loop
          assignRecord(i, vector, s.seqJumpConfig(j).mpsJump (k));
          assignRecord(i, vector, s.seqJumpConfig(j).mpsClass(k));
        end loop;  -- k
      end loop;  -- j
      return s;
   end function;

end package body XpmSeqPkg;
