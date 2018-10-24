------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Pgp3Interleave.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2018-04-26
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 DAQ Software'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 DAQ Software', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.Pgp3Pkg.all;
use work.SsiPkg.all;

entity Pgp3Interleave is
   generic ( LANES_G       : integer := 4;
             AXIS_CONFIG_G : AxiStreamConfigType );
   port ( axisClk         : in  sl;
          axisRst         : in  sl;
          sAxisMaster     : in  AxiStreamMasterType;
          sAxisSlave      : out AxiStreamSlaveType;
          mAxisMaster     : out AxiStreamMasterArray( LANES_G-1 downto 0 );
          mAxisSlave      : in  AxiStreamSlaveArray ( LANES_G-1 downto 0 ) );
end Pgp3Interleave;

architecture top_level_app of Pgp3Interleave is

  type RegType is record
    masters : AxiStreamMasterArray(LANES_G-1 downto 0);
    nready  : slv                 (LANES_G-1 downto 0);
    slave   : AxiStreamSlaveType;
  end record;

  constant REG_INIT_C : RegType := (
    masters => (others=>AXI_STREAM_MASTER_INIT_C),
    nready  => (others=>'0'),
    slave   => AXI_STREAM_SLAVE_INIT_C );
  
  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;
  
begin

  comb : process ( r, axisRst, sAxisMaster, mAxisSlave ) is
    variable v : RegType;
  begin
    v := r;

    v.slave.tReady := '0';

    if v.nready /= 0 then
      for i in 0 to LANES_G-1 loop
        if mAxisSlave(i).tReady = '1' then
          v.nready (i)        := '0';
          v.masters(i).tValid := '0';
        end if;
      end loop;
      if v.nready = 0 then
        v.slave.tReady := '1';
      end if;
    end if;
    
    if v.nready = 0 then
      if sAxisMaster.tValid = '1' then
        for i in 0 to LANE_G-1 loop
          v.nready(i)        := '1';
          v.master(i).tValid := '1';
          v.master(i).tLast  := sAxisMaster.tLast;
          -- set user bits
          axiStreamSetUserBit(PGP3_AXIS_CONFIG_C, v.master(i), SSI_SOF_C,
                              axiStreamGetUserBit(AXIS_CONFIG_G, sAxisMaster, SSI_SOF_C, 0), 0);
          -- distribute data
          for j in 0 to 7 loop
            m := 8*j;
            n := 8*LANES_G*j;
            v.master(i).tData(m+7 downto m) := sAxisMaster.tData(n+7 downto n);
          end loop;
        end loop;
      end if;
    end if;

    sAxisSlave  <= v.slave;
    mAxisMaster <= r.masters;
    
    if axisRst = '1' then
      v := REG_INIT_C;
    end if;

    rin <= v;
    
  end process comb;

  seq : process ( axisClk ) is
  begin
    if rising_edge(axisClk) then
      r <= rin;
    end if;
  end process seq;
  
end top_level_app;
