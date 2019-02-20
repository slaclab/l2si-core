-------------------------------------------------------------------------------
-- Title      : TimingPkg
-------------------------------------------------------------------------------
-- File       : TimingExtnPkg.vhd
-- Author     : Matt Weaver  <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2018-07-20
-- Last update: 2018-12-02
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

use work.StdRtlPkg.all;

package TimingExtnPkg is

   constant EXPT_STREAM_ID    : slv(3 downto 0) := x"1";

   --
   --  Experiment timing information (appended by downstream masters)
   --
   constant PADDR_LEN : integer := 32;
   constant PWORD_LEN : integer := 48;
   constant EXPT_MESSAGE_BITS_C : integer := PADDR_LEN+8*PWORD_LEN;

   type ExptMessageType is record
     partitionAddr   : slv(31 downto 0);
     partitionWord   : Slv48Array(0 to 7);
   end record;
   constant EXPT_MESSAGE_INIT_C : ExptMessageType := (
     partitionAddr  => (others=>'1'),
     partitionWord  => (others=>x"800080008000") );
   type ExptMessageArray is array (integer range<>) of ExptMessageType;

   type ExptBusType is record
     message : ExptMessageType;
     valid   : sl;
   end record ExptBusType;
   constant EXPT_BUS_INIT_C : ExptBusType := (
     message => EXPT_MESSAGE_INIT_C,
     valid   => '0' );
   type ExptBusArray is array (integer range<>) of ExptBusType;

   function toSlv(message : ExptMessageType) return slv;
   function toExptMessageType (vector : slv) return ExptMessageType;

   --
   -- Cu Accelerator Timing System
   --
   type CuTimingType is record
     epicsTime  : slv( 63 downto 0);
     eventCodes : slv(255 downto 0);
   end record;
   constant CU_TIMING_INIT_C : CuTimingType := (
     epicsTime  => (others=>'0'),
     eventCodes => (others=>'0') );
   constant CU_TIMING_BITS_C : integer := 256+64;

   function toSlv(message : CuTimingType) return slv;
   function toCuTimingType (vector : slv) return CuTimingType;
   
   --
   -- The extended interface
   --

   constant TIMING_EXTN_STREAMS_C : integer := 2;
   constant TIMING_EXTN_WORDS_C : IntegerArray(1 downto 0) := (
     CU_TIMING_BITS_C   /16,
     EXPT_MESSAGE_BITS_C/16 );
   
   type TimingExtnType is record
     expt    : ExptMessageType;
     cuValid : sl;
     curx    : CuTimingType;
   end record;

   constant TIMING_EXTN_INIT_C : TimingExtnType := (
     expt    => EXPT_MESSAGE_INIT_C,
     cuValid => '0',
     curx    => CU_TIMING_INIT_C );

   constant TIMING_EXTN_BITS_C : integer := CU_TIMING_BITS_C + 1 + EXPT_MESSAGE_BITS_C;
   
   function toSlv(message : TimingExtnType) return slv;
   function toTimingExtnType(vector : in slv) return TimingExtnType;
   
   function toSlv(stream  : integer;
                  message : TimingExtnType) return slv;
   procedure toTimingExtnType(stream : in    integer;
                              vector : in    slv;
                              validi : in    sl;
                              extn   : inout TimingExtnType;
                              valido : inout sl );
end package TimingExtnPkg;

package body TimingExtnPkg is

   function toSlv(message : ExptMessageType) return slv
   is
      variable vector  : slv(EXPT_MESSAGE_BITS_C-1 downto 0) := (others=>'0');
      variable i       : integer := 0;
   begin
      assignSlv(i, vector, message.partitionAddr);
      for j in message.partitionWord'range loop
         assignSlv(i, vector, message.partitionWord(j));
      end loop;
      return vector;
   end function;
      
   function toExptMessageType (vector : slv) return ExptMessageType
   is
      variable message : ExptMessageType;
      variable i       : integer := 0;
   begin
      assignRecord(i, vector, message.partitionAddr);
      for j in message.partitionWord'range loop
         assignRecord(i, vector, message.partitionWord(j));
      end loop;
      return message;
   end function;
   
   function toSlv(message : CuTimingType) return slv
   is
      variable vector  : slv(CU_TIMING_BITS_C-1 downto 0) := (others=>'0');
      variable i       : integer := 0;
   begin
      assignSlv(i, vector, message.epicsTime);
      assignSlv(i, vector, message.eventCodes);
      return vector;
   end function;
      
   function toCuTimingType (vector : slv) return CuTimingType
   is
      variable message : CuTimingType;
      variable i       : integer := 0;
   begin
      assignRecord(i, vector, message.epicsTime);
      assignRecord(i, vector, message.eventCodes);
      return message;
   end function;
   
   function toSlv(message : TimingExtnType) return slv is
     variable vector : slv(TIMING_EXTN_BITS_C-1 downto 0);
   begin
     vector(EXPT_MESSAGE_BITS_C-1 downto 0)           := toSlv(message.expt);
     vector(EXPT_MESSAGE_BITS_C)                      := message.cuValid;
     vector(vector'left downto EXPT_MESSAGE_BITS_C+1) := toSlv(message.curx);
     return vector;
   end function;

   function toTimingExtnType(vector : slv) return TimingExtnType is
     variable message : TimingExtnType := TIMING_EXTN_INIT_C;
   begin
     message.expt := toExptMessageType(vector(EXPT_MESSAGE_BITS_C-1 downto 0));
     message.cuValid := vector(EXPT_MESSAGE_BITS_C);
     message.curx := toCuTimingType(vector(EXPT_MESSAGE_BITS_C+CU_TIMING_BITS_C downto EXPT_MESSAGE_BITS_C+1));
     return message;
   end function;
   
   function toSlv(stream  : integer;
                  message : TimingExtnType) return slv is
     variable vector : slv(16*TIMING_EXTN_WORDS_C(stream-1)-1 downto 0);
   begin
     case stream is
       when 1 => vector := toSlv(message.expt);
       when 2 => vector := toSlv(message.curx);
       when others => null;
     end case;
     return vector;
   end function;
   
   procedure toTimingExtnType(stream : in    integer;
                              vector : in    slv;
                              validi : in    sl;
                              extn   : inout TimingExtnType;
                              valido : inout sl ) is
   begin
     case stream is
       when 1 =>
         valido       := validi;
         extn.cuValid := '0';
         extn.expt    := toExptMessageType(vector);
       when 2 =>
         extn.cuValid := validi;
         extn.curx    := toCuTimingType(vector);
       when others => null;
     end case;
   end procedure;

end package body TimingExtnPkg;
