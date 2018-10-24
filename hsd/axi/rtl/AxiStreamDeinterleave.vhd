------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiStreamDeinterleave.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2018-04-27
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
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity AxiStreamDeinterleave is
   generic ( LANES_G        : integer := 4;
             SAXIS_CONFIG_G : AxiStreamConfigType;
             MAXIS_CONFIG_G : AxiStreamConfigType );
   port ( axisClk         : in  sl;
          axisRst         : in  sl;
          sAxisMaster     : in  AxiStreamMasterArray( LANES_G-1 downto 0 );
          sAxisSlave      : out AxiStreamSlaveArray ( LANES_G-1 downto 0 );
          mAxisMaster     : out AxiStreamMasterType;
          mAxisSlave      : in  AxiStreamSlaveType );
end AxiStreamDeinterleave;

architecture top_level_app of AxiStreamDeinterleave is

  type RegType is record
    master  : AxiStreamMasterType;
    eofe    : slv                (LANES_G-1 downto 0);
    slaves  : AxiStreamSlaveArray(LANES_G-1 downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    master  => axiStreamMasterInit(MAXIS_CONFIG_G),
    eofe    => (others=>'0'),
    slaves  => (others=>AXI_STREAM_SLAVE_INIT_C) );
  
  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;
  
begin

  comb : process ( r, axisRst, sAxisMaster, mAxisSlave ) is
    variable v : RegType;
    variable ready : sl;
    variable m,n : integer;
  begin
    v := r;

    -- clear strobe signals
    for i in 0 to LANES_G-1 loop
      v.slaves(i).tReady := '0';
    end loop;

    -- process acknowledge
    if mAxisSlave.tReady = '1' then
      v.master.tValid := '0';
    end if;

    --  sink any streams that have excess data
    if r.eofe /= 0 then
      for i in 0 to LANES_G-1 loop
        if sAxisMaster(i).tValid = '1' and r.eofe(i)='1' then
          v.slaves(i).tReady := '1';
          if sAxisMaster(i).tLast = '1' then
            v.eofe(i) := '0';
          end if;
        end if;
      end loop;
    --  handle aligned streams
    else
      -- wait for all streams to contribute
      ready := '1';
      for i in 0 to LANES_G-1 loop
        if sAxisMaster(i).tValid='0' then
          ready := '0';
        end if;
      end loop;

      if ready = '1' and v.master.tValid = '0' then
        v.master.tValid := '1';
        -- Verify all streams are closing or not
        v.master.tLast := sAxisMaster(0).tLast;
        for i in 0 to LANES_G-1 loop
          v.eofe(i) := not sAxisMaster(i).tLast;
        end loop;

        axiStreamSetUserBit(MAXIS_CONFIG_G, v.master, SSI_EOFE_C, '0');
        if allBits(v.eofe,'0') then
          v.master.tLast := '1';
        elsif allBits(v.eofe,'1') then
          v.master.tLast := '0';
          v.eofe         := (others=>'0');
        else
          v.master.tLast := '1';
          axiStreamSetUserBit(MAXIS_CONFIG_G, v.master, SSI_EOFE_C, '1');
        end if;

        -- set SOF (assume for all lanes)
        axiStreamSetUserBit(MAXIS_CONFIG_G, v.master, SSI_SOF_C,
                            axiStreamGetUserBit(SAXIS_CONFIG_G, sAxisMaster(0), SSI_SOF_C, 0), 0);   

        -- gather data
        for i in 0 to LANES_G-1 loop
          for j in 0 to SAXIS_CONFIG_G.TDATA_BYTES_C-1 loop
            m := 8*j;
            n := 8*(LANES_G*j+i);
            v.master.tData(n+7 downto n) := sAxisMaster(i).tData(m+7 downto m);
            v.master.tKeep(LANES_G*j+i)  := sAxisMaster(i).tKeep(j);
          end loop;
          v.slaves(i).tReady := '1';
        end loop;
      end if;
    end if;

    sAxisSlave  <= v.slaves;
    mAxisMaster <= r.master;
    
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
