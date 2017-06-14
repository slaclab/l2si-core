-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadAdcEventv2.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2017-04-06
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-- Independent channel setup.  Simplified to make reasonable interface
-- for feature extraction algorithms.
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
use work.ArbiterPkg.all;
use work.QuadAdcPkg.all;

entity QuadAdcEventv2 is
  generic (
    TPD_G             : time    := 1 ns;
    FIFO_ADDR_WIDTH_C : integer := 10;
    NFMC_G            : integer := 1;
    SYNC_BITS_G       : integer := 4 );
  port (
    eventClk   :  in sl;
    eventRst   :  in sl;
    configE    :  in QuadAdcConfigType;
    strobe     :  in sl;
    trigArm    :  in sl;
    eventId    :  in slv(95 downto 0);
    --
    adcClk     :  in sl;
    adcRst     :  in sl;
    configA    :  in QuadAdcConfigType;
    trigIn     :  in Slv8Array(SYNC_BITS_G-1 downto 0);
    adc        :  in AdcDataArray(4*NFMC_G-1 downto 0);
    --
    dmaClk     :  in sl;
    dmaRst     :  in sl;
    dmaFullThr :  in slv(FIFO_ADDR_WIDTH_C-1 downto 0);
    dmaFullS   : out sl;
    dmaFullQ   : out slv(FIFO_ADDR_WIDTH_C-1 downto 0);
    dmaMaster  : out AxiStreamMasterType;
    dmaSlave   : in  AxiStreamSlaveType );
end QuadAdcEventv2;

architecture mapping of QuadAdcEventv2 is

  constant NCHAN_C : integer := 4*NFMC_G;
  
  type EventStateType is (E_IDLE, E_SYNC);
  -- wait enough timingClks for adcSync to latch and settle
  constant T_SYNC : integer := 10;

  type EventRegType is record
    state    : EventStateType;
    delay    : slv( 25 downto 0);
    intv     : slv( 31 downto 0);
    hdrWr    : slv(  1 downto 0);
    hdrData  : slv(255 downto 0);
  end record;
  constant EVENT_REG_INIT_C : EventRegType := (
    state    => E_IDLE,
    delay    => (others=>'0'),
    intv     => (others=>'0'),
    hdrWr    => (others=>'0'),
    hdrData  => (others=>'0') );

  signal re    : EventRegType := EVENT_REG_INIT_C;
  signal re_in : EventRegType;

  type RdStateType is (S_IDLE, S_READHDR, S_WRITEHDR,
                       S_WAITCHAN, S_READCHAN, S_DUMP);
  type SyncStateType is (S_SHIFT_S, S_WAIT_S);

  constant TMO_VAL_C : integer := 4095;
  
  type RegType is record
    hdrRd    : sl;
    fmc      : integer range 0 to NFMC_G-1;
    channel  : integer range 0 to NCHAN_C-1;
    index    : integer range 0 to 23;
    enable   : slv(NCHAN_C-1 downto 0);
    rdFifo   : slv(NCHAN_C-1 downto 0);
    flast    : sl;
    chv      : slv(bitSize(NCHAN_C-1)-1 downto 0);
    selv     : sl;
    ack      : slv(NCHAN_C-1 downto 0);
    datacnt  : slv(FIFO_ADDR_WIDTH_C-1 downto 0);
    full     : sl;
    state    : RdStateType;
    master   : AxiStreamMasterType;
    start    : sl;
    syncState: SyncStateType;
    adcShift : slv(2 downto 0);
    trigd1   : slv(7 downto 0);
    trigd2   : slv(7 downto 0);
    trig     : Slv8Array(SYNC_BITS_G-1 downto 0);
    trigCnt  : slv(1 downto 0);
    trigArm  : sl;
    tmo      : integer range 0 to TMO_VAL_C;
  end record;

  constant REG_INIT_C : RegType := (
    hdrRd     => '0',
    fmc       => 0,
    channel   => NCHAN_C-1,
    index     => 0,
    enable    => (others=>'0'),
    rdFifo    => (others=>'0'),
    flast     => '0',
    chv       => (others=>'0'),
    selv      => '0',
    ack       => (others=>'0'),
    datacnt   => (others=>'0'),
    full      => '0',
    state     => S_IDLE,
    master    => AXI_STREAM_MASTER_INIT_C,
    start     => '0',
    syncState => S_SHIFT_S,
    adcShift  => (others=>'0'),
    trigd1    => (others=>'0'),
    trigd2    => (others=>'0'),
    trig      => (others=>(others=>'0')),
    trigCnt   => (others=>'0'),
    trigArm   => '0',
    tmo       => TMO_VAL_C );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  type DmaDataArray is array (natural range <>) of Slv11Array(7 downto 0);
  signal iadc        : DmaDataArray(NCHAN_C-1 downto 0);

  type AdcShiftArray is array (natural range<>) of Slv8Array(10 downto 0);
  signal  adcs : AdcShiftArray(NCHAN_C-1 downto 0);
  signal iadcs : AdcShiftArray(NCHAN_C-1 downto 0);
    
  type ChannelFifo is record
    data       : Slv11Array(15 downto 0);
    last       : sl;
    empty      : sl;
    data_count : slv(FIFO_ADDR_WIDTH_C-1 downto 0);
  end record;
  type ChannelFifoArray is array(natural range<>) of ChannelFifo;

  signal fifo  : ChannelFifoArray(NCHAN_C-1 downto 0);
  
  signal hdrDout  : slv(127 downto 0);
  signal hdrValid : sl;
  signal hdrEmpty : sl;

  signal fullE    : sl;

  signal pllSync   : slv(2 downto 0);
  signal trigArmS  : sl;
  
  constant XPMV7 : boolean := false;

  constant DEBUG_C : boolean := true;

  component ila_0
    port ( clk : in sl;
           probe0 : in slv(255 downto 0) );
  end component;

  signal r_state : slv(2 downto 0);
  signal r_syncstate : sl;
  signal r_intlv : sl;
  
begin  -- mapping

  GEN_DBUG : if DEBUG_C generate
    r_state <= "000" when r.state=S_IDLE else
               "001" when r.state=S_READHDR else
               "010" when r.state=S_WRITEHDR else
               "011" when r.state=S_WAITCHAN else
               "100" when r.state=S_READCHAN else
               "101" when r.state=S_DUMP else
               "111";
    r_syncstate <= '0' when r.syncState=S_SHIFT_S else
                   '1';
    r_intlv <= '1' when configA.intlv=Q_ABCD else
               '0';
    U_ILA : ila_0
      port map ( clk  => dmaClk,
                 probe0(0) => r.master.tValid,
                 probe0(1) => r.master.tLast,
                 probe0(65 downto 2) => r.master.tData(63 downto 0),
                 probe0(66) => dmaSlave.tReady,
                 probe0(67) => r.hdrRd,
                 probe0(75 downto 68) => r.enable,
                 probe0(83 downto 76) => r.rdFifo,
                 probe0(86 downto 84) => r_state,
                 probe0(87) => r.flast,
                 probe0(90 downto 88) => r.chv,
                 probe0(91) => r.selv,
                 probe0(99 downto 92) => r.ack,
                 probe0(113 downto 100) => r.datacnt,
                 probe0(114) => r.full,
                 probe0(115) => r.start,
                 probe0(116) => r_syncstate,
                 probe0(118 downto 117) => r.trigCnt,
                 probe0(119) => r.trigArm,
                 probe0(120) => r_intlv,
                 probe0(121) => dmaRst,
                 probe0(255 downto 122) => (others=>'0') );
  end generate;

  dmaMaster <= r.master;
  dmaFullS  <= r.full;
  dmaFullQ  <= r.datacnt;

  U_TRIGARM : entity work.SynchronizerOneShot
    port map ( clk     => dmaClk,
               dataIn  => trigArm,
               dataOut => trigArmS );
  
  GEN_CH : for i in 0 to NCHAN_C-1 generate
    GEN_BIT : for j in 0 to 10 generate
      U_Shift : entity work.AdcShift
        port map ( clk   => adcClk,
                   rst   => adcRst,
                   shift => r.adcShift,
                   din   =>  adcs(i)(j),
                   dout  => iadcs(i)(j) );
      GEN_IADC : for k in 0 to 7 generate
        adcs(i)(j)(k) <= adc(i).data(k)(j);
        iadc(i)(k)(j) <= iadcs(i)(j)(k);
      end generate GEN_IADC;
    end generate GEN_BIT;
  
    --  This is the large buffer.
    U_FIFO : entity work.QuadAdcChannelFifo
      generic map ( FIFO_ADDR_WIDTH_C => FIFO_ADDR_WIDTH_C )
      port map ( clk      => dmaClk,
                 rst      => dmaRst,
                 start    => r.start,
                 config   => configA,
                 din      => iadc(i),
                 rden     => rin.rdFifo(i),
                 rddata   => fifo(i).data,
                 rdlast   => fifo(i).last,
                 empty    => fifo(i).empty,
                 data_count => fifo(i).data_count );
  end generate;

  U_HDR : entity work.FifoAsync
    generic map ( DATA_WIDTH_G  => 128,
                  ADDR_WIDTH_G  =>   8 )
    port map ( rst      => dmaRst,
               wr_clk   => eventClk,
               wr_en    => re.hdrWr  (0),
               din      => re.hdrData(127 downto 0),
               rd_clk   => dmaClk,
               rd_en    => rin.hdrRd,
               dout     => hdrDout,
               valid    => hdrValid,
               empty    => hdrEmpty );

  U_PLL_SYNC : entity work.SynchronizerVector
    generic map ( WIDTH_G => pllSync'length )
    port map ( clk      => eventClk,
               rst      => eventRst,
               dataIn   => r.adcShift,
               dataOut  => pllSync );

  process (re, eventRst, eventId, strobe, fullE, configE, pllSync) is
    variable v  : EventRegType;
    variable sz : slv(31 downto 0);
  begin
    v := re;

    v.hdrWr   := '0' & re.hdrWr(1);
    v.intv    := re.intv+1;
    sz := toSlv(8+8*conv_integer(onesCount(configE.enable))*conv_integer(configE.samples(configE.samples'left downto 4)),32);

    case re.state is
      when E_IDLE =>
        if strobe='1' and fullE='0' then
          v.delay   := (others=>'0');
          v.hdrData(159 downto 0) := eventId &
                                     x"00" & configE.enable &
                                     "00" & configE.samples(17 downto 4) &
                                     sz;
          v.state   := E_SYNC;
        else
          v.hdrData := toSlv(0,128) & re.hdrData(re.hdrData'left downto 128);
        end if;
      when E_SYNC =>
        if re.delay=toSlv(T_SYNC,re.delay'length) then
          v.intv  := toSlv(1,re.intv'length);
          v.hdrData(255 downto 160) := toSlv(0,32) & -- space for trigIn
                                       re.intv &
                                       toSlv(0,29) & pllSync;
          v.delay := (others=>'0');
          v.hdrWr := (others=>'1');
          v.state := E_IDLE;
        else
          v.delay := re.delay+1;
        end if;
      when others => NULL;
    end case;
    
    if eventRst='1' then
      v := EVENT_REG_INIT_C;
    end if;

    re_in <= v;
  end process;

  process(eventClk) is
  begin
    if rising_edge(eventClk) then
      re <= re_in;
    end if;
  end process;
    
  process (r, dmaRst, configA, fifo, hdrValid, hdrEmpty, hdrDout, dmaSlave, dmaFullThr, trigArmS, trigIn)
    variable v   : RegType;
  begin  -- process
    v := r;

    v.hdrRd   := '0';
    v.rdFifo  := (others=>'0');
    v.trigd1  := trigIn(0);
    v.trigd2  := (r.trigd1 and configA.trigShift) or (trigIn(0) and not configA.trigShift);
    
    --v.datacnt := (others=>'0');
    --for i in 0 to NCHAN_C-1 loop
    --  if configA.enable(i)='1' then
    --    v.datacnt := fifo(i).data_count;
    --  end if;
    --end loop;
    v.datacnt := fifo(r.channel).data_count;
    
    if r.datacnt > dmaFullThr then
      v.full := '1';
    else
      v.full := '0';
    end if;

    --
    --  Pipeline the last sample check for Q_ABCD interleave mode
    --    (last is valid 3 clocks before sampling)
    --
    v.flast   := fifo(4*r.fmc).last;

    --
    --  Pipeline the arbitration decision for Q_NONE interleave mode
    --    (enable,channel is valid 1 clock before sampling)
    --
    arbitrate(r.enable, toSlv(r.channel,r.chv'length), v.chv, v.selv, v.ack);
    
    if dmaSlave.tReady='1' then
      v.master.tValid := '0';
    end if;

    if r.state = S_READCHAN and r.master.tValid='0' then
      v.tmo := r.tmo-1;
    else
      v.tmo := TMO_VAL_C;
    end if;
    
    case r.state is
      when S_IDLE =>
        v.index   := 0;
        v.enable  := configA.enable;
        v.channel := NCHAN_C-1;
        if hdrEmpty='0' then
          v.hdrRd := '1';
          v.state := S_READHDR;
          v.tmo   := TMO_VAL_C;
        end if;
      when S_READHDR =>
        if v.master.tValid='0' then
          v.master.tData(127 downto 0) := hdrDout;
          if hdrEmpty='0' then
            v.hdrRd := '1';
            v.state := S_WRITEHDR;
          end if;
        end if;
      when S_WRITEHDR =>
        if r.master.tValid='0' or dmaSlave.tReady='1' then
          v.master.tData(255 downto 224) := r.trig(3) & r.trig(2) & r.trig(1) & r.trig(0);
          v.master.tData(223 downto 128) := hdrDout(95 downto 0);
          v.master.tKeep                 := genTKeep(32);
          v.master.tValid                := '1';
          v.master.tLast                 := '0';
          v.state := S_WAITCHAN;
          v.channel  := conv_integer(r.chv);
          v.enable := r.enable and not r.ack;
          if r.selv='0' then
            v.master.tLast := '1';
            v.state        := S_IDLE;
          else
            v.state        := S_WAITCHAN;
          end if;
        end if;
      when S_WAITCHAN =>
        if fifo(r.channel).empty='0' then
          v.rdFifo(r.channel) := '1';
          v.state           := S_READCHAN;
        end if; -- config.intlv
      when S_READCHAN =>
        if v.master.tValid='0' then
          v.master.tKeep := genTKeep(32);
          v.master.tValid := '1';
          v.master.tLast  := '0';
          v.master.tData  := (others=>'0');
          for i in 0 to 15 loop
            v.master.tData(16*i+10 downto 16*i) := fifo(r.channel).data(i);
          end loop;
          if (fifo(r.channel).last='1') then
            v.channel  := conv_integer(r.chv);
            v.enable := r.enable and not r.ack;
            if r.selv='0' then
              v.master.tLast := '1';
              v.state        := S_IDLE;
            else
              v.state := S_WAITCHAN;
            end if;
          else
            if fifo(r.channel).empty='0' then
              v.rdFifo(r.channel) := '1';
            else
              v.state := S_WAITCHAN;
            end if; -- fifo(channel).empty
          end if;
        end if;
      when S_DUMP =>
        if v.master.tValid='0' then
          v.state := S_IDLE;
        end if;
      when others => NULL;
    end case;

    if r.tmo = 0 then
      v.state := S_DUMP;
      v.master.tValid := '1';
      v.master.tLast  := '1';
    end if;
    
    if r.trigCnt/="11" then
      v.trig    := r.trigd2 & r.trig(r.trig'left downto 1);
      v.trigCnt := r.trigCnt+1;
    end if;
    
   v.start := '0';
    case (r.syncState) is
      when S_SHIFT_S =>
        if trigArmS = '1' then
          v.trigArm := '1';
        end if;
        if r.trigd2/=toSlv(0,8) then
          v.start := configA.acqEnable;
          for i in 7 downto 0 loop
            if r.trigd2(i)='1' then
              v.adcShift := toSlv(i,3);
            end if;
          end loop;
          if r.trigArm='1' then
            v.trig      := r.trigd2 & r.trig(r.trig'left downto 1);
            v.trigArm   := '0';
            v.trigCnt   := (others=>'0');
          end if;
          v.syncState := S_WAIT_S;
        end if;
      when S_WAIT_S =>
        if r.trigd2=toSlv(0,8) then
          v.syncState := S_SHIFT_S;
        end if;
      when others => NULL;
    end case;

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

  U_Full : entity work.Synchronizer
    generic map ( TPD_G   => TPD_G )
    port map (    clk     => eventClk,
                  rst     => eventRst,
                  dataIn  => r.full,
                  dataOut => fullE );
  
  
end mapping;
