------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DtiUsSimApp.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2017-04-12
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: DtiApp's Top Level
-- 
-- Note: Common-to-DtiApp interface defined here (see URL below)
--       https://confluence.slac.stanford.edu/x/rLyMCw
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
use work.XpmPkg.all;
use work.DtiPkg.all;
use work.DtiSimPkg.all;

entity DtiUsSimApp is
   generic (
      TPD_G               : time                := 1 ns;
      SERIAL_ID_G         : slv(31 downto 0)    := (others=>'0');
      ENABLE_TAG_G        : boolean             := false );
   port (
     amcClk          : in  sl;
     amcRst          : in  sl;
     --amcRxP          : in  sl;
     --amcRxN          : in  sl;
     --amcTxP          : out sl;
     --amcTxN          : out sl;
     fifoRst         : in  sl;
     --
     ibClk           : in  sl;
     ibRst           : in  sl;
     ibMaster        : out AxiStreamMasterType;
     ibSlave         : in  AxiStreamSlaveType;
     linkUp          : out sl;
     rxErr           : out sl;
     --
     obClk           : in  sl;
     obRst           : in  sl;
     obTrig          : in  XpmPartitionDataType;
     obMaster        : in  AxiStreamMasterType;
     obSlave         : out AxiStreamSlaveType );
end DtiUsSimApp;

architecture top_level_app of DtiUsSimApp is

  type StateType is (S_IDLE, S_READTAG, S_READOUT, S_PAYLOAD);
  
  type RegType is record
    state    : StateType;
    payload  : slv(31 downto 0);
    scratch  : slv(31 downto 0);
    localts  : slv(63 downto 0);
    wordcnt  : slv(31 downto 0);
    tagRd    : sl;
    l1a      : sl;
    master   : AxiStreamMasterType;
    slave    : AxiStreamSlaveType;
  end record;
  
  constant REG_INIT_C : RegType := (
    state    => S_IDLE,
    payload  => toSlv(32,32),
    scratch  => x"DEADBEEF",
    localts  => (others=>'0'),
    wordcnt  => (others=>'0'),
    tagRd    => '0',
    l1a      => '0',
    master   => AXI_STREAM_MASTER_INIT_C,
    slave    => AXI_STREAM_SLAVE_INIT_C );
  
  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  constant AXIS_CONFIG_C : AxiStreamConfigType := (
    TSTRB_EN_C    => false,
    TDATA_BYTES_C => 8,
    TDEST_BITS_C  => 0,
    TID_BITS_C    => 5,
    TKEEP_MODE_C  => TKEEP_NORMAL_C,
    TUSER_BITS_C  => 0,
    TUSER_MODE_C  => TUSER_NORMAL_C );
  
  signal amcIbMaster, amcObMaster : AxiStreamMasterType;
  signal amcIbSlave , amcObSlave  : AxiStreamSlaveType;

  signal l0S, l1S, l1aS : sl;

  signal tagdout : slv(4 downto 0);
  signal tsdout  : slv(63 downto 0);
  signal tagValid : sl;
  
begin

  U_IbFifo : entity work.AxiStreamFifo
    generic map ( SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_C,
                  MASTER_AXI_CONFIG_G => US_IB_CONFIG_C )
    port map ( sAxisClk    => amcClk,
               sAxisRst    => amcRst,
               sAxisMaster => amcIbMaster,
               sAxisSlave  => amcIbSlave,
               mAxisClk    => ibClk,
               mAxisRst    => ibRst,
               mAxisMaster => ibMaster,
               mAxisSlave  => ibSlave );

  U_ObFifo : entity work.AxiStreamFifo
    generic map ( SLAVE_AXI_CONFIG_G  => US_OB_CONFIG_C,
                  MASTER_AXI_CONFIG_G => AXIS_CONFIG_C )
    port map ( sAxisClk    => obClk,
               sAxisRst    => obRst,
               sAxisMaster => obMaster,
               sAxisSlave  => obSlave,
               mAxisClk    => amcClk,
               mAxisRst    => amcRst,
               mAxisMaster => amcObMaster,
               mAxisSlave  => amcObSlave );

  U_TagFifo : entity work.FifoAsync
    generic map ( FWFT_EN_G    => true,
                  DATA_WIDTH_G => 5,
                  ADDR_WIDTH_G => 5 )
    port map ( rst     => fifoRst,
               wr_clk  => obClk,
               wr_en   => obTrig.l0a,
               din     => obTrig.l0tag,
               rd_clk  => amcClk,
               rd_en   => r.tagRd,
               dout    => tagdout,
               valid   => tagValid );

  U_TsFifo : entity work.FifoSync
    generic map ( FWFT_EN_G    => true,
                  DATA_WIDTH_G => 64,
                  ADDR_WIDTH_G => 5 )
    port map ( rst    => fifoRst,
               clk    => amcClk,
               wr_en  => l0S,
               rd_en  => r.tagRd,
               din    => r.localts,
               dout   => tsdout );

  U_SyncL0 : entity work.SynchronizerOneShot
    port map ( clk     => amcClk,
               rst     => fifoRst,
               dataIn  => obTrig.l0a,
               dataOut => l0S );
  
  U_SyncL1 : entity work.SynchronizerOneShot
    port map ( clk     => amcClk,
               rst     => fifoRst,
               dataIn  => obTrig.l1e,
               dataOut => l1S );
  
  U_SyncL1A : entity work.Synchronizer
    port map ( clk     => amcClk,
               rst     => fifoRst,
               dataIn  => obTrig.l1a,
               dataOut => l1aS );
  
  --
  --  Parse amcOb stream for register transactions or obTrig
  --
  comb : process ( fifoRst, r, amcObMaster, amcIbSlave, l1S, l1aS, tagValid, tagdout, tsdout ) is
    variable v   : RegType;
    variable reg : RegTransactionType;
  begin
    v := r;

    v.tagRd   := '0';
    v.localts := r.localts+1;
    v.slave.tReady := '0';
    
    if amcIbSlave.tReady='1' then
      v.master.tValid := '0';
    end if;
    
    reg := toRegTransType(amcObMaster.tData(63 downto 0));
    
    case r.state is
      when S_IDLE =>
        if v.master.tValid='0' and amcObMaster.tValid='1' then -- register transaction
          v.slave .tReady := '1';
          v.master.tValid := '1';
          v.master.tLast  := '1';
          v.master.tData  := amcObMaster.tData;
          if reg.rnw='1' then
            case conv_integer(reg.address) is
              when      0 => v.master.tData(63 downto 32) := SERIAL_ID_G;
              when      4 => v.master.tData(63 downto 32) := r.payload;
              when      8 => v.master.tData(63 downto 32) := r.scratch;
              when others => v.master.tData(63 downto 32) := x"DEADBEEF";
            end case;
          else
            case conv_integer(reg.address) is
              when      4 => v.payload := amcObMaster.tData(63 downto 32);
              when      8 => v.scratch := amcObMaster.tData(63 downto 32);
              when others => null;
            end case;
          end if;
        end if;

        if l1S='1' then  -- readout
          if l1aS='0' then
            v.tagRd := '1';
          else
            v.wordcnt := (others=>'0');
            v.state := S_READOUT;
          end if;
        end if;

      when S_READOUT =>
        if v.master.tValid='0' and tagValid='1' then
          v.tagRd := '1';
          v.master.tId(4 downto 0) := tagdout;
          v.master.tValid := '1';
          v.master.tLast  := '0';
          v.master.tData(63 downto 0) := tsdout;
          v.wordcnt       := r.wordcnt+1;
          v.state         := S_PAYLOAD;
        end if;

      when S_PAYLOAD =>
        if v.master.tValid='0' then
          v.master.tValid := '1';
          v.master.tLast  := '0';
          v.master.tData(63 downto 0) := r.localts(31 downto 0) & r.wordcnt;
          v.wordcnt       := r.wordcnt+1;
          v.state         := S_PAYLOAD;
          if r.wordcnt = r.payload then
            v.master.tLast := '1';
            v.state        := S_IDLE;
          end if;
        end if;
        
      when others =>
        null;
    end case;

    rin <= v;

    amcIbMaster <= r.master;
    amcObSlave  <= v.slave;
    
  end process;
            
  seq : process (amcClk) is
  begin
    if rising_edge(amcClk) then
      r <= rin;
    end if;
  end process;
  
end top_level_app;
