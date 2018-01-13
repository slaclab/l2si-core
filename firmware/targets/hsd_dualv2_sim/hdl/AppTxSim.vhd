----------------------------------------------------------------
-- File       : AppTxSim.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-10-26
-- Last update: 2018-01-10
-------------------------------------------------------------------------------
-- Description: Application File
-------------------------------------------------------------------------------
-- This file is part of 'axi-pcie-core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'axi-pcie-core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.AxiPciePkg.all;
use work.SsiPkg.all;

entity AppTxSim is
   generic (
      DMA_AXIS_CONFIG_C : AxiStreamConfigType );
   port (
      -- AXI-Lite Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      --
      clk             : in  sl;
      rst             : in  sl;
      saxisMasters    : in  AxiStreamMasterArray(7 downto 0);
      saxisSlaves     : out AxiStreamSlaveArray (7 downto 0);
      maxisMasters    : out AxiStreamMasterArray(7 downto 0);
      maxisSlaves     : in  AxiStreamSlaveArray (7 downto 0);
      rxOpCodeEn      : in  slv      (7 downto 0);
      rxOpCode        : in  Slv8Array(7 downto 0);
      txFull          : out slv      (7 downto 0)
      );
end AppTxSim;

architecture mapping of AppTxSim is

  signal rdReg : Slv32Array(0 downto 0);
  signal wrReg : Slv32Array(1 downto 0);
  
  signal txReqMax   : slv(3 downto 0);
  signal txReqDly   : slv(3 downto 0);
  signal txClear    : slv(7 downto 0);
  signal txEnable   : slv(7 downto 0);
  signal txFixed    : sl;
  signal txIntBase  : slv(3 downto 0);
  signal txIntExp   : slv(2 downto 0);
  signal txLength   : slv(18 downto 0);
  signal txOverflow : slv(31 downto 0);

  type StateType is (IDLE_S,
                     WAIT_S,
                     SEND_S);
  type StateArray is array(natural range<>) of StateType;
  
  type RegType is record
    state    : StateArray(7 downto 0);
    reqCnt   : Slv4Array (7 downto 0);
    reqTime  : Slv15Array(7 downto 0);
    length   : Slv19Array(7 downto 0);
    count    : Slv32Array(7 downto 0);
    tcount   : slv       (31 downto 0);
    sof      : slv       (7 downto 0);
    overflow : Slv4Array (7 downto 0);
    txMaster : AxiStreamMasterArray(7 downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    state       => (others=>IDLE_S),
    reqCnt      => (others=>(others=>'0')),
    reqTime     => (others=>(others=>'0')),
    length      => (others=>(others=>'0')),
    count       => (others=>(others=>'0')),
    tcount      => (others=>'0'),
    sof         => (others=>'0'),
    overflow    => (others=>(others=>'0')),
    txMaster    => (others=>AXI_STREAM_MASTER_INIT_C) );
  
  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  constant DEBUG_C : boolean := true;
  constant dp      : integer := 3;
  
  component ila_1
    port ( clk          : in  sl;
           trig_out     : out sl;
           trig_out_ack : in  sl;
           probe0       : in  slv(255 downto 0) );
  end component;

  signal trig_out  : sl;
  signal state_r   : slv(1 downto 0);

begin
  
  GEN_DEBUG : if DEBUG_C generate
    state_r <= "00" when (r.state(dp) = IDLE_S) else
               "01" when (r.state(dp) = WAIT_S) else
               "10";
    U_ILA : ila_1
      port map ( clk          => clk,
                 trig_out     => trig_out,
                 trig_out_ack => trig_out,
                 probe0( 1 downto  0) => state_r,
                 probe0( 5 downto  2) => r.reqCnt(dp),
                 probe0(20 downto  6) => r.reqTime(dp),
                 probe0(39 downto 21) => r.length(dp),
                 probe0(71 downto 40) => r.count(dp),
                 probe0(72) => r.sof(dp),
                 probe0(76 downto 73) => r.overflow(dp),
                 probe0(77) => rxOpCodeEn(dp),
                 probe0(78) => r.txMaster(dp).tValid,
                 probe0(79) => r.txMaster(dp).tLast,
                 probe0(80) => txEnable(dp),
                 probe0(255 downto 81) => (others=>'0') );
  end generate;

  U_Axil : entity work.AxiLiteEmpty
    generic map ( NUM_WRITE_REG_G => 2 )
    port map (
      axiClk         => axilClk,
      axiClkRst      => axilRst,
      axiReadMaster  => axilReadMaster,
      axiReadSlave   => axilReadSlave,
      axiWriteMaster => axilWriteMaster,
      axiWriteSlave  => axilWriteSlave,
      writeRegister  => wrReg,
      readRegister   => rdReg );

  U_SyncWr : entity work.SynchronizerVector
    generic map ( WIDTH_G => 32 )
    port map ( clk    => clk,
               dataIn => wrReg(0),
               dataOut( 7 downto  0) => txEnable,
               dataOut( 8 )          => txFixed,
               dataOut(12 downto  9) => txIntBase,
               dataOut(15 downto 13) => txIntExp,
               dataOut(23 downto 16) => txClear,
               dataOut(27 downto 24) => txReqDly,
               dataOut(31 downto 28) => txReqMax );

  U_SyncWr1 : entity work.SynchronizerVector
    generic map ( WIDTH_G => txLength'length )
    port map ( clk     => clk,
               dataIn  => wrReg(1)(txLength'range),
               dataOut => txLength );

  GEN_RDREG : for i in 0 to 7 generate
    U_SyncRd : entity work.SynchronizerVector
      generic map ( WIDTH_G => 4 )
      port map ( clk     => clk,
                 dataIn  => r.overflow(i),
                 dataOut => rdReg(0)(4*i+3 downto 4*i) );
  end generate;
  
  maxisMasters <= r.txMaster;
  
  comb : process ( r, rst, txEnable, rxOpCodeEn, saxisMasters,
                   txFixed, txIntBase, txIntExp,
                   maxisSlaves, txReqMax, txReqDly, txLength ) is
    variable v : RegType;
    variable exp  : integer;
    variable trig : sl;
    variable j    : integer;
  begin
    v := r;

    --  Fixed period triggering
    trig     := '0';
    exp      := 2*conv_integer(txIntExp);
    v.tcount := r.tcount + 1;
    if txFixed = '1' then
      if r.tcount(exp+3 downto exp) = txIntBase then
        v.tcount := (others=>'0');
        trig := '1';
      end if;
    else
      v.tcount := (others=>'0');
    end if;
   
    for i in 0 to 7 loop

      if maxisSlaves(i).tReady = '1' then
        v.txMaster(i).tValid := '0';
      end if;

      saxisSlaves(i).tReady <= '0';

      if r.reqCnt(i) < txReqMax then
        txFull(i) <= '0';
      else
        txFull(i) <= '1';
      end if;

      if txEnable(i) = '1' then
        if ((txFixed = '0' and rxOpCodeEn(i) = '1') or
            (txFixed = '1' and trig = '1')) then
          if r.reqCnt(i) /= toSlv(15,4) then
            v.reqCnt(i) := r.reqCnt(i) + 1;
          else
            v.overflow(i) := r.overflow(i) + 1;
          end if;
        end if;
      end if;
      
      case r.state(i) is
        when IDLE_S =>
          if txEnable(i) = '0' then
            if v.txMaster(i).tValid = '0' then
              v.txMaster(i) := saxisMasters(i);
              saxisSlaves  (i).tReady <= '1';
            end if;
            v.reqCnt (i) := (others=>'0');
            v.reqTime(i) := (others=>'0');
          elsif r.reqCnt(i) /= 0 then
            v.reqCnt (i) := r.reqCnt(i) - 1;
            v.reqTime(i) := (others=>'0');
            v.state  (i) := WAIT_S;
          end if;
        when WAIT_S =>
          if r.reqTime(i)(conv_integer(txReqDly)) = '1' then
            v.sof   (i) := '1';
            v.state (i) := SEND_S;
            v.length(i) := txLength;
          end if;
          v.reqTime(i) := r.reqTime(i) + 1;
        when SEND_S =>
          if v.txMaster(i).tValid = '0' then
            saxisSlaves(i).tReady <= '1';
            ssiSetUserSof(DMA_AXIS_CONFIG_C, v.txMaster(i), r.sof(i));
            v.sof     (i)        := '0';
            v.txMaster(i).tValid := '1';
            for j in 0 to DMA_AXIS_CONFIG_C.TDATA_BYTES_C/4-1 loop
              v.txMaster(i).tData(32*j+31 downto 32*j)  :=  resize(r.length(i) - j, 32);
            end loop;
            v.txMaster(i).tLast  := '1';
            v.length  (i)        := toSlv(0,txLength'length);
            v.state   (i)        := IDLE_S;
            j := conv_integer(r.length(i));
            if j <= DMA_AXIS_CONFIG_C.TDATA_BYTES_C/4 then
              v.txMaster(i).tKeep := (others=>'0');
              v.txMaster(i).tKeep(4*j-1 downto 0) := (others=>'1');
            else
              v.txMaster(i).tKeep := (others=>'0');
              v.txMaster(i).tKeep(DMA_AXIS_CONFIG_C.TDATA_BYTES_C-1 downto 0) := (others=>'1');
              v.txMaster(i).tLast := '0';
              v.length  (i)       := r.length(i) - DMA_AXIS_CONFIG_C.TDATA_BYTES_C/4;
              v.state   (i)       := SEND_S;
            end if;
            if r.sof(i) = '1' then
              v.count   (i) := r.count(i) + 1;
              v.txMaster(i).tData(31 downto 0) := resize(r.count(i),32);
            end if;
          end if;
        when others => null;
      end case;
    end loop;
    
    if rst = '1' then
      v := REG_INIT_C;
    end if;

    rin <= v;
  end process;

  process (clk) is
  begin
    if rising_edge(clk) then
      r <= rin;
    end if;
  end process;
  
end mapping;
