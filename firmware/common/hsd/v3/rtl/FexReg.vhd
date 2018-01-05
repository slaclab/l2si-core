-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : FexReg.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2018-01-01
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
use ieee.NUMERIC_STD.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.QuadAdcPkg.all;

entity FexReg is
  port (
    -- AXI-Lite and IRQ Interface
    axilClk             : in  sl;
    axilRst             : in  sl;
    axilWriteMaster     : in  AxiLiteWriteMasterType;
    axilWriteSlave      : out AxiLiteWriteSlaveType;
    axilReadMaster      : in  AxiLiteReadMasterType;
    axilReadSlave       : out AxiLiteReadSlaveType;
    -- Configuration
    config              : out FexConfigType;
    status              : in  FexStatusType );
end FexReg;

architecture mapping of FexReg is

  type RegType is record
    axilReadSlave  : AxiLiteReadSlaveType;
    axilWriteSlave : AxiLiteWriteSlaveType;
    config         : FexConfigType;
  end record;
  constant REG_INIT_C : RegType := (
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
    config         => FEX_CONFIG_INIT_C );
  
  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

begin  -- mapping

  process (axilClk)
  begin  -- process
    if rising_edge(axilClk) then
      r <= rin;
    end if;
  end process;

  process (r,axilReadMaster,axilWriteMaster,axilRst,status) is
    variable v : RegType;
    variable ep : AxiLiteEndPointType;
  begin  -- process
    v  := r;
    
    axiSlaveWaitTxn(ep, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

    v.axilReadSlave.rdata := (others=>'0');
    
    axilSlaveRegister(ep, x"00", 0, v.config.fexEnable);

    for i in 0 to MAX_STREAMS_C-1 loop
      axiSlaveRegister ( ep, toSlv(16*i+16,8), 0, v.config.fexPrescale(i) );
      axiSlaveRegister ( ep, toSlv(16*i+20,8), 0, v.config.fexBegin (i) );
      axiSlaveRegister ( ep, toSlv(16*i+20,8),16, v.config.fexLength(i) );
      axiSlaveRegister ( ep, toSlv(16*i+24,8), 0, v.config.aFull    (i) );
      axiSlaveRegister ( ep, toSlv(16*i+24,8),16, v.config.aFullN   (i) );
      axiSlaveRegisterR( ep, toSlv(16*i+28,8), 0, status.free       (i) );
      axiSlaveRegisterR( ep, toSlv(16*i+28,8),16, status.nfree      (i) );
    end loop;

    axilSlaveDefault(ep, v.axilWriteSlave, v.axilReadSlave );

    if axilRst = '1' then
      v := REG_INIT_C;
    end if;
    
    rin <= v;
  end process;
end mapping;
