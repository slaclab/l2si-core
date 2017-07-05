-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiStreamOrderedMux.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2017-06-19
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
--   Merge axi stream array in element order.
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
use ieee.NUMERIC_STD.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity AxiStreamOrderedMux is
  generic ( NUM_SLAVES_G : integer );
  port (
    clk             :  in sl;
    rst             :  in sl;
    enableValid     :  in sl;
    enableSel       :  in slv                 (NUM_SLAVES_G-1 downto 0);
    enableAck       : out sl;
    sAxisMasters    :  in AxiStreamMasterArray(NUM_SLAVES_G-1 downto 0);
    sAxisSlaves     : out AxiStreamSlaveArray (NUM_SLAVES_G-1 downto 0);
    mAxisMaster     : out AxiStreamMasterType;
    mAxisSlave      :  in AxiStreamSlaveType );
end AxiStreamOrderedMux;

architecture mapping of AxiStreamOrderedMux is

  type RegType is record
    enableAck  : sl;
    fexb       : slv(NUM_SLAVES_G-1 downto 0);
    fexn       : integer range 0 to NUM_SLAVES_G-1;
    axisMaster : AxiStreamMasterType;
    axisSlaves : AxiStreamSlaveArray(NUM_SLAVES_G-1 downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    enableAck  => '0',
    fexb       => (others=>'0'),
    fexn       => 0,
    axisMaster => AXI_STREAM_MASTER_INIT_C,
    axisSlaves => (others=>AXI_STREAM_SLAVE_INIT_C) );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

begin  -- mapping

  process (r, rst, sAxisMasters, mAxisSlave, enableValid, enableSel ) is
    variable v     : RegType;
    variable i     : integer;
  begin  -- process
    v := r;

    -- AxiStream interface
    if mAxisSlave.tReady='1' then
      v.axisMaster.tValid := '0';
    end if;

    for i in 0 to NUM_SLAVES_G-1 loop
      v.axisSlaves(i).tReady := '0';
    end loop;
    
    if r.fexb(r.fexn)='0' then
      if r.fexn=NUM_SLAVES_G-1 then
        if enableValid = '1' then
          v.enableAck := '1';
          v.fexb      := enableSel;
          v.fexn      := 0;
        end if;
      else
        v.fexn := r.fexn+1;
      end if;
    elsif v.axisMaster.tValid='0' then
      if sAxisMasters(r.fexn).tValid='1' then
        v.axisSlaves(r.fexn).tReady := '1';
        v.axisMaster.tValid := '1';
        v.axisMaster.tLast  := '0';
        v.axisMaster.tData  := sAxisMasters(r.fexn).tData;
        if sAxisMasters(r.fexn).tLast='1' then
          v.fexb(r.fexn) := '0';
          if v.fexb=0 then
            v.axisMaster.tLast := '1';
          end if;
        end if;
      end if;
    end if;

    if rst='1' then
      v := REG_INIT_C;
    end if;
    
    rin <= v;

    enableAck <= r.enableAck;
  end process;

  process (clk)
  begin  -- process
    if rising_edge(clk) then
      r <= rin;
    end if;
  end process;

end mapping;

