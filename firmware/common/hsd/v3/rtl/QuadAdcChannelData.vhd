-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadAdcChannelData.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2018-06-20
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-- Merges event header and channel data stream.
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
use work.SsiPkg.all;

entity QuadAdcChannelData is
  generic (
    TPD_G             : time    := 1 ns;
    FIFO_ADDR_WIDTH_C : integer := 10;
    SAXIS_CONFIG_G    : AxiStreamConfigType;
    MAXIS_CONFIG_G    : AxiStreamConfigType );
  port (
    dmaClk       :  in sl;
    dmaRst       :  in sl;
    --
    eventHdr     :  in slv(255 downto 0);
    eventHdrV    :  in sl;
    noPayload    :  in sl;
    eventHdrRd   : out sl;
    --
    chnMaster    :  in AxiStreamMasterType;
    chnSlave     : out AxiStreamSlaveType;
    dmaMaster    : out AxiStreamMasterType;
    dmaSlave     :  in AxiStreamSlaveType );
end QuadAdcChannelData;

architecture mapping of QuadAdcChannelData is

  type RdStateType is (S_WAIT, S_IDLE, S_READHDR, S_WAITHDR, S_WRITEHDR,
                       S_WAITCHAN, S_READCHAN, S_DUMP);

  constant TMO_VAL_C : integer := 4095;
  
  type RegType is record
    hdrRd    : sl;
    state    : RdStateType;
    master   : AxiStreamMasterType;
    slave    : AxiStreamSlaveType;
    tmo      : integer range 0 to TMO_VAL_C;
  end record;

  constant REG_INIT_C : RegType := (
    hdrRd     => '0',
    state     => S_IDLE,
    master    => AXI_STREAM_MASTER_INIT_C,
    slave     => AXI_STREAM_SLAVE_INIT_C,
    tmo       => TMO_VAL_C );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal tSlave : AxiStreamSlaveType;
  
begin  -- mapping

  assert (SAXIS_CONFIG_G.TDATA_BYTES_C = 16 or SAXIS_CONFIG_G.TDATA_BYTES_C = 32)
    report "EventHeader insertion requires TDATA_BYTES_C=16 or 32"
    severity error;
    
  U_FIFO : entity work.AxiStreamFifo
    generic map ( FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_C,
                  SLAVE_AXI_CONFIG_G  => SAXIS_CONFIG_G,
                  MASTER_AXI_CONFIG_G => MAXIS_CONFIG_G )
    port map ( sAxisClk    => dmaClk,
               sAxisRst    => dmaRst,
               sAxisMaster => r.master,
               sAxisSlave  => tSlave,
               mAxisClk    => dmaClk,
               mAxisRst    => dmaRst,
               mAxisMaster => dmaMaster,
               mAxisSlave  => dmaSlave );

  
  process (r, dmaRst, eventHdr, eventHdrV, noPayload,
           tSlave, chnMaster) is
    variable v   : RegType;
  begin  -- process
    v := r;
    v.hdrRd        := '0';
    v.slave.tReady := '0';

    if tSlave.tReady='1' then
      v.master.tValid := '0';
      ssiSetUserSof(SAXIS_CONFIG_G, v.master, '0');
    end if;

    if r.state = S_READCHAN and r.master.tValid='0' then
      v.tmo := r.tmo-1;
    else
      v.tmo := TMO_VAL_C;
    end if;
    
    case r.state is
      when S_WAIT =>
        v.state := S_IDLE;
      when S_IDLE =>
        if eventHdrV='1' then
          v.state := S_READHDR;
          v.tmo   := TMO_VAL_C;
        end if;
      when S_READHDR =>
        if v.master.tValid='0' then
          ssiSetUserSof(SAXIS_CONFIG_G, v.master, '1');
          v.master.tData(127 downto 0) := eventHdr(127 downto 0);
          v.master.tValid              := '1';
          v.master.tLast               := '0';
          if SAXIS_CONFIG_G.TDATA_BYTES_C = 16 then
            v.master.tKeep := genTKeep(16);
            v.state        := S_WRITEHDR;
          else
            v.master.tKeep := genTKeep(32);
            v.master.tData(255 downto 128) := eventHdr(255 downto 128);
            v.hdrRd := '1';
            if noPayload = '1' then
              v.master.tLast := '1';
              v.state := S_WAIT;
            else
              v.state := S_WAITCHAN;
            end if;
          end if;
        end if;
      when S_WRITEHDR =>
        if v.master.tValid='0' then
          v.master.tData(127 downto   0) := eventHdr(255 downto 128);
          v.master.tValid                := '1';
          v.hdrRd := '1';
          if noPayload = '1' then
            v.master.tLast := '1';
            v.state := S_WAIT;
          else
            v.state := S_WAITCHAN;
          end if;
        end if;
      when S_WAITCHAN =>
        if v.master.tValid='0' and chnMaster.tValid='1' then
          v.master       := chnMaster;
          v.slave.tReady := '1';
          v.state        := S_READCHAN;
        end if;
      when S_READCHAN =>
        if v.master.tValid='0' then
          v.master       := chnMaster;
          v.slave.tReady := chnMaster.tValid;
          if chnMaster.tLast='1' then
            ssiSetUserEofe(SAXIS_CONFIG_G,v.master,'0');
            v.state := S_IDLE;
          end if;
        end if;
      when S_DUMP =>
        v.slave.tReady := '1';
        if v.master.tLast='1' then
          v.state := S_IDLE;
        end if;
      when others => NULL;
    end case;

    if r.tmo = 0 then
      v.state := S_DUMP;
      ssiSetUserEofe(SAXIS_CONFIG_G,v.master,'1');
      v.master.tValid := '1';
      v.master.tLast  := '1';
    end if;
    
    chnSlave   <= v.slave;
    eventHdrRd <= r.hdrRd;

    if dmaRst='1' then
      v := REG_INIT_C;
    end if;

    rin <= v;

  end process;

  process (dmaClk)
  begin  -- process
    if rising_edge(dmaClk) then
      r <= rin;
    end if;
  end process;
  
end mapping;
