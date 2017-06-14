-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadAdcChannelFifov2.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2017-06-12
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
--   Consider having two data formats: one for multi-channels over a certain
--   length and one for single channel any length or multi-channel under a
--   certain length.  The first would be interleaved allowing minimal buffering.
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
use work.TimingPkg.all;
use work.QuadAdcPkg.all;

entity QuadAdcChannelFifov2 is
  generic ( BASE_ADDR_C : slv(31 downto 0) := x"00000000" );
  port (
    clk             :  in sl;
    rst             :  in sl;
    start           :  in sl;
    din             :  in Slv11Array(7 downto 0);
    cfgen           : out slv       (3 downto 0);
    l1a             : out slv       (3 downto 0);
    l1v             : out slv       (3 downto 0);
    -- readout interface
    axisMaster      : out AxiStreamMasterType;
    axisSlave       :  in AxiStreamSlaveType;
    -- configuration interface
    axilClk         :  in sl;
    axilRst         :  in sl;
    axilReadMaster  :  in AxiLiteReadMasterType;
    axilReadSlave   : out AxiLiteReadSlaveType;
    axilWriteMaster :  in AxiLiteWriteMasterType;
    axilWriteSlave  : out AxiLiteWriteSlaveType );
end QuadAdcChannelFifov2;

architecture mapping of QuadAdcChannelFifov2 is

  constant NSTREAMS_C : integer := 3;
  
  type RegType is record
    fexb       : slv(NSTREAMS_C-1 downto 0);
    fexn       : integer range 0 to NSTREAMS_C-1;
    axisMaster : AxiStreamMasterType;
    axisSlaves : AxiStreamSlaveArray;
  end record;

  constant REG_INIT_C : RegType := (
    fexb       => (others=>'0'),
    fexn       => 0,
    axisMaster => AXI_STREAM_MASTER_INIT_C,
    axisSlaves => (others=>AXI_STREAM_SLAVE_INIT_C) );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal maxilReadMaster   : AxiLiteReadMasterType;
  signal maxilReadSlave    : AxiLiteReadSlaveType;
  signal maxilWriteMaster  : AxiLiteWriteMasterType;
  signal maxilWriteSlave   : AxiLiteWriteSlaveType;
  signal maxilReadMasters  : AxiLiteReadMasterArray (NSTREAMS_C-1 downto 0);
  signal maxilReadSlaves   : AxiLiteReadSlaveArray  (NSTREAMS_C-1 downto 0);
  signal maxilWriteMasters : AxiLiteWriteMasterArray(NSTREAMS_C-1 downto 0);
  signal maxilWriteSlaves  : AxiLiteWriteSlaveArray (NSTREAMS_C-1 downto 0);

  signal cfgenb : slv(3 downto 0);
  
  constant SAXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(32);
  constant MAXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(16);

  constant AXIL_XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NSTREAMS_C-1 downto 0) := (
    0 => (baseAddr => BASE_ADDR_C+x"00000000",
          addrBits => 8,
          connectivity => x"ffff"),
    1 => (baseAddr => BASE_ADDR_C+x"00000100",
          addrBits => 8,
          connectivity => x"ffff"),
    2 => (baseAddr => BASE_ADDR_C+x"00000200",
          addrBits => 8,
          connectivity => x"ffff") );

begin  -- mapping

  cfgen     <= cfgenb;
  
  GEN_AXIL_ASYNC : entity work.AxiLiteAsync
    generic map ( NUM_ADDR_BITS_G => 10 )
    port map ( sAxiClk         => axilClk,
               sAxiClkRst      => axilRst,
               sAxiReadMaster  => axilReadMaster,
               sAxiReadSlave   => axilReadSlave,
               sAxiWriteMaster => axilWriteMaster,
               sAxiWriteSlave  => axilWriteSlave,
               mAxiClk         => clk,
               mAxiClkRst      => rst,
               mAxiReadMaster  => maxilReadMaster,
               mAxiReadSlave   => maxilReadSlave,
               mAxiWriteMaster => maxilWriteMaster,
               mAxiWriteSlave  => maxilWriteSlave );

  GEN_AXIL_XBAR : entity work.AxiLiteCrossbar
    generic map ( NUM_MASTERS_SLOTS_G => AXIL_XBAR_CONFIG_C'length,
                  MASTERS_CONFIG_G    => AXIL_XBAR_CONFIG_C )
    port map ( axiClk           => clk,
               axiClkRst        => rst,
               sAxiReadMasters (0) => maxilReadMaster,
               sAxiReadSlaves  (0) => maxilReadSlave,
               sAxiWriteMasters(0) => maxilWriteMaster,
               sAxiWriteSlaves (0) => maxilWriteSlave,
               mAxiReadMasters     => maxilReadMasters,
               mAxiReadSlaves      => maxilReadSlaves,
               mAxiWriteMasters    => maxilWriteMasters,
               mAxiWriteSlaves     => maxilWriteSlaves );
               
  GEN_FIFO : entity work.AxiStreamFifoV2
    generic map ( FIFO_ADDR_WIDTH_G   => 14,
                  SLAVE_AXI_CONFIG_G  => SAXIS_CONFIG_C,
                  MASTER_AXI_CONFIG_G => MAXIS_CONFIG_C )
    port map ( -- Slave Port
               sAxisClk    => clk,
               sAxisRst    => rst,
               sAxisMaster => axisMaster,
               sAxisSlave  => axisSlave,
               -- Master Port
               mAxisClk    => clk,
               mAxisRst    => rst,
               mAxisMaster => r.axisMaster,
               mAxisSlave  => maxisSlave );

  GEN_FEX : for i in 0 to NSTREAMS_C-1 generate
    U_FEX : entity work.hsd_fex_wrapper
      generic map ( AXIS_CONFIG_G => MAXIS_CONFIG_C )
      port map ( clk               => clk,
                 rst               => rst,
                 start             => start,
                 din               => din,
                 axisMaster        => axisMasters     (i),
                 axisSlave         => r.axisSlaves    (i),
                 l1v               => l1v             (i),
                 l1a               => l1a             (i),
                 cfgen             => cfgenb          (i),
                 axilReadMaster    => axilReadMasters (i),
                 axilReadSlave     => axilReadSlaves  (i),
                 axilWriteMaster   => axilWriteMasters(i),
                 axilWriteSlave    => axilWriteSlaves (i) );
  end generate;
  
  GEN_REM : for i in NSTREAMS_C to 3 generate
    cfgenb(i) <= '0';
    l1v   (i) <= start;
    l1a   (i) <= '0';
  end generate;
  
  process (r, rst, axisMasters, maxisSlave, cfgenb) is
    variable v     : RegType;
  begin  -- process
    v := r;

    if maxisSlave.tReady='1' then
      v.axisMaster.tValid := '0';
    end if;

    for i in cfgenb'right downto cfgenb'left loop
      v.axisSlaves(i).tReady := '0';
    end loop;
    
    if r.fexb(r.fexn)='0' then
      if r.fexn=cfgenb'left then
        v.fexb := cfgenb;
        v.fexn := 0;
      else
        v.fexn := r.fexn+1;
      end if;
    elsif v.axisMaster.tValid='0' then
      if axisMasters(r.fexn).tValid='1' then
        v.axisSlaves(r.fexn).tReady := '1';
        v.axisMaster.tValid := '1';
        v.axisMaster.tLast  := '0';
        v.axisMaster.tData  := axisMaster(r.fexn).tData;
        if axisMasters(r.fexn).tLast='1' then
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
  end process;

  process (clk)
  begin  -- process
    if rising_edge(clk) then
      r <= rin;
    end if;
  end process;

end mapping;

