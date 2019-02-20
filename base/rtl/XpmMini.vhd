-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : XpmMini.vhd
-- Author     : Matt Weaver  <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-11-09
-- Last update: 2018-11-30
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
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.TPGPkg.all;
use work.StdRtlPkg.all;
use work.TimingPkg.all;
use work.TimingExtnPkg.all;
use work.XpmPkg.all;

entity XpmMini is
  generic (
    TPD_G : time := 1 ns );
  port (
    configI    : in  slv(19 downto 0);

    txClk      : in  sl;
    txRst      : in  sl;
    txRdy      : in  sl;
    txData     : out slv(15 downto 0);
    txDataK    : out slv(1 downto 0)
    );
end XpmMini;


-- Define architecture for top level module
architecture XpmMini of XpmMini is

  signal tpgConfig : TPGConfigType := TPG_CONFIG_INIT_C;
  signal streams   : TimingSerialArray(TIMING_EXTN_STREAMS_C downto 0);
  signal streamIds : Slv4Array        (TIMING_EXTN_STREAMS_C downto 0);
  signal advance   : slv              (TIMING_EXTN_STREAMS_C downto 0);
  signal fiducial  : sl;
  signal xpmVector : slv(16*TIMING_EXTN_WORDS_C(0)-1 downto 0);

  type RegType is record
    count  : slv(configI'range);
    bcount : integer;
    expt   : ExptMessageType;
  end record;
  constant REG_INIT_C : RegType := (
    count  => (others=>'0'),
    bcount => 0,
    expt   => EXPT_MESSAGE_INIT_C );

  signal r    : RegType := REG_INIT_C;
  signal rin  : RegType;
  
begin

  tpgConfig.pulseIdWrEn <= '0';
  
  U_TPG : entity work.TPGMini
    generic map ( STREAM_INTF => true )
    port map ( configI   => tpgConfig,
               txClk     => txClk,
               txRst     => txRst,
               txRdy     => txRdy,
               streams   => streams  (0 downto 0),
               streamIds => streamIds(0 downto 0),
               advance   => advance  (0 downto 0),
               fiducial  => fiducial );

   comb : process ( txRst, r, fiducial, configI ) is
     variable v : RegType;
     variable w : XpmPartitionDataType;
     variable pd : XpmBroadcastType := PDELAY;
     variable pdepth : slv(19 downto 0) := toSlv(1,20);
   begin
     v := r;

     w := toPartitionWord(r.expt.partitionWord(0));
     
     if fiducial = '1' then
       if r.count = configI then
         v.count  := (others=>'0');
         w.l0a    := '1';
         w.l0tag  := w.l0tag + 1;
         w.l1a    := w.l0a;
         w.l1tag  := w.l0tag;
         w.anatag := w.anatag+1;
       else
         v.count  := r.count + 1;
         w.l0a    := '0';
       end if;

       --  Add Partition Broadcasts
       if r.bcount = 8 then
         v.bcount := 0;
         v.expt.partitionAddr := (others=>'1');
       else
         v.bcount := r.bcount+1;
         v.expt.partitionAddr := toPaddr(pd,r.bcount,pdepth);
       end if;
     end if;

     v.expt.partitionWord(0) := toSlv(w);

     if txRst = '1' then
       v := REG_INIT_C;
     end if;
     
     rin <= v;
   end process comb;

   seq : process (txClk) is
   begin
     if rising_edge(txClk) then
       r <= rin;
     end if;
   end process seq;

   xpmVector <= toSlv(r.expt);

   U_XpmSerializer : entity work.WordSerializer
     generic map ( NWORDS_G => TIMING_EXTN_WORDS_C(0) )
     port map ( txClk     => txClk,
                txRst     => txRst,
                fiducial  => fiducial,
                words     => xpmVector,
                ready     => '1',
                advance   => advance(2),
                stream    => streams(2) );
   streamIds(2) <= toSlv(1,4);

   streams  (1) <= TIMING_SERIAL_INIT_C; -- No Cu Timing
   streamIds(1) <= toSlv(2,4);
  
   U_SimSerializer : entity work.TimingSerializer
    generic map ( STREAMS_C => TIMING_EXTN_STREAMS_C+1 )
    port map ( clk       => txClk,
               rst       => txRst,
               fiducial  => fiducial,
               streams   => streams,
               streamIds => streamIds,
               advance   => advance,
               data      => txData,
               dataK     => txDataK );

end XpmMini;
