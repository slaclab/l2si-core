-------------------------------------------------------------------------------
-- File       : MmcmPhaseLock.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-04
-- Last update: 2018-12-19
-------------------------------------------------------------------------------
-- Description: Application Core's Top Level
--
--
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 AMC Carrier Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 AMC Carrier Firmware', including this file, 
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

library unisim;
use unisim.vcomponents.all;

entity MmcmPhaseLock is
   generic ( CLKIN_PERIOD_G     : real;
             DIVCLK_DIVIDE_G    : integer := 1;
             CLKOUT_DIVIDE_F    : real;
             CLKFBOUT_MULT_F    : real;
             STEP_WIDTH_G       : integer := 9;
             PHASE_WIDTH_G      : integer := 17 );
   port (
      -- Clocks and resets
      clkIn            : in  sl;
      rstIn            : in  sl;
      syncIn           : in  sl;
      clkOut           : out sl;
      rstOut           : out sl;
      --
      axilClk          : in  sl;
      axilRst          : in  sl;
      axilReadMaster   : in  AxiLiteReadMasterType;
      axilReadSlave    : out AxiLiteReadSlaveType;
      axilWriteMaster  : in  AxiLiteWriteMasterType;
      axilWriteSlave   : out AxiLiteWriteSlaveType );
end MmcmPhaseLock;

architecture behavior of MmcmPhaseLock is

--  constant CNTWID   : integer := 13;
  constant CNTWID   : integer := 3;
  constant DLYWID   : integer := 11;
  constant DELAY_STEP : slv(DLYWID-1 downto 0) := toSlv(56, DLYWID);
  
  --  State of the MMCM phase shift control
  type PS_State is ( IDLE_S, ACTIVE_S, STALL_S );

  --  State of the phase measurement
  type Scan_State is ( RESET_S , SCAN_S, WAIT_S, DONE_S );

  type RegType is record
    delaySet       : slv(DLYWID-1 downto 0);
    delayValue     : slv(DLYWID-1 downto 0);
    ramwr          : sl;
    ramaddr        : slv(DLYWID-1 downto 0);
    pdState        : Scan_State;
    resetCount     : sl;
    rstOut         : sl;
    countHigh      : sl;
    psEn           : sl;
    psIncNdec      : sl;
    psState        : PS_State;
    axilReadSlave  : AxiLiteReadSlaveType;
    axilWriteSlave : AxiLiteWriteSlaveType;
  end record;

  constant REG_INIT_C : RegType := (
    delaySet       => (others=>'0'),
    delayValue     => (others=>'0'),
    ramwr          => '0',
    ramaddr        => (others=>'0'),
    pdState        => RESET_S,
    resetCount     => '1',
    rstOut         => '1',
    countHigh      => '0',
    psEn           => '0',
    psIncNdec      => '0',
    psState        => IDLE_S,
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C );

  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;

  signal count, ramdata, syncCount : slv(CNTWID-1 downto 0);
  signal isyncIn, syncOut : sl;
  signal clkHigh : sl;
  signal arstIn  : sl;
  
  signal ready : sl;

  signal clkFbIn, clkFbOut : sl;
  signal iiclkOut, iclkOut, locked : sl;

  signal psDone : sl;

begin

  clkOut    <= iclkOut;
  clkFbIn   <= clkFbOut;

  U_SSyncIn : entity work.Synchronizer
    port map ( clk     => clkIn,
               dataIn  => syncIn,
               dataOut => isyncIn );

  clkHigh <= isyncIn and iclkOut;
  
  U_CountStrobe : entity work.SynchronizerOneShotCnt
    generic map ( CNT_WIDTH_G => CNTWID+1 )
    port map ( dataIn     => isyncIn,
               rollOverEn => '0',
               cntRst     => r.resetCount,
               dataOut    => open,
               cntOut(CNTWID-1 downto 0) => syncCount,
               cntOut(CNTWID) => ready,
               wrClk      => clkIn,
               rdClk      => axilClk );

  U_CountHigh : entity work.SynchronizerOneShotCnt
    generic map ( CNT_WIDTH_G => CNTWID )
    port map ( dataIn     => clkHigh,
               rollOverEn => '0',
               cntRst     => r.resetCount,
               dataOut    => open,
               cntOut     => count,
               wrClk      => clkIn,
               rdClk      => axilClk );

  U_RstSync : entity work.RstSync
    port map ( clk      => axilClk,
               asyncRst => rstIn,
               syncRst  => arstIn );
  
  U_MMCM : MMCME3_ADV
    generic map ( CLKFBOUT_MULT_F     => CLKFBOUT_MULT_F,
                  CLKOUT0_DIVIDE_F    => CLKOUT_DIVIDE_F,
                  DIVCLK_DIVIDE       => DIVCLK_DIVIDE_G,
                  CLKIN1_PERIOD       => CLKIN_PERIOD_G,
                  CLKOUT0_USE_FINE_PS => "TRUE" )
    port map ( DCLK     => axilClk,
               DADDR    => (others=>'0'),
               DI       => (others=>'0'),
               DWE      => '0',
               DEN      => '0',
               PSCLK    => axilClk,
               PSEN     => r.psEn,
               PSINCDEC => r.psIncNdec,
               PSDONE   => psDone,
               RST      => rstIn,
               CLKIN1   => clkIn,
               CLKIN2   => '0',
               CLKINSEL => '1',
               CLKFBOUT => clkFbOut,
               CLKFBIN  => clkFbIn,
               LOCKED   => locked,
               CLKOUT0  => iiclkOut,
               CDDCREQ  => '0',
               PWRDWN   => '0' );

  U_RstOut : entity work.RstSync
    generic map ( IN_POLARITY_G => '1' )
    port map ( clk      => iclkOut,
               asyncRst => r.rstOut,
               syncRst  => rstOut );
  
  U_RAM0 : entity work.SimpleDualPortRam
    generic map ( DATA_WIDTH_G => CNTWID,
                  ADDR_WIDTH_G => DLYWID )
    port map ( clka  => axilClk,
               wea   => r.ramwr,
               addra => r.delaySet,
               dina  => count,
               clkb  => axilClk,
               addrb => r.ramaddr,
               doutb => ramdata );

  U_BUFG : BUFG
    port map ( I => iiclkOut,
               O => iclkOut );

  comb : process ( r, axilRst, axilReadMaster, axilWriteMaster,
                   arstIn, psDone,
                   ready, count, locked, ramdata ) is
    variable v : RegType;
    variable ep : AxiLiteEndPointType;
  begin
    v := r;

    v.psEn       := '0';
    v.resetCount := '0';
    v.ramwr      := '0';
    
    axiSlaveWaitTxn(ep, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);
    ep.axiReadSlave.rdata := (others=>'0');

    axiSlaveRegister ( ep, toSlv( 0,12),  0, v.delaySet );
    axiSlaveRegisterR( ep, toSlv( 4,12),  0, r.delayValue );
    axiSlaveRegisterR( ep, toSlv( 4,12), 31, locked );
    axiSlaveRegister ( ep, toSlv( 8,12),  0, v.ramaddr );
    axiSlaveRegisterR( ep, toSlv(12,12),  0, ramdata );

    axiSlaveDefault( ep, v.axilWriteSlave, v.axilReadSlave );

    case (r.pdState) is
      when RESET_S =>
        v.rstOut     := '1';
        v.delaySet   := (others=>'0');
        v.delayValue := (others=>'0');
        v.countHigh  := '0';
        if arstIn = '0' then
          v.pdState := SCAN_S;
        end if;
      when SCAN_S =>
        v.resetCount := '1';
        if r.delayValue = r.delaySet then
          v.pdState    := WAIT_S;
        end if;
      when WAIT_S =>
        if ready = '1' then  -- new clock measurement ready
          v.ramwr    := '1';
          v.delaySet := r.delaySet + DELAY_STEP;
          v.pdState  := SCAN_S;
          if count(count'left) = '1' then
            v.countHigh := '1';
          elsif r.countHigh = '1' then
            v.delaySet  := r.delayValue;
            v.pdState   := DONE_S;
          end if;
        end if;
      when DONE_S =>
        v.rstOut := '0';
        if arstIn = '1' then
          v.pdState := RESET_S;
        end if;
    end case;
                           
    case (r.psState) is
      when IDLE_S =>
        v.psEn      := '1';
        v.psState   := ACTIVE_S;
        if r.delaySet > r.delayValue then
          v.psIncNdec := '1';
        elsif r.delaySet < r.delayValue then
          v.psIncNdec := '0';
        else
          v.psEn    := '0';
          v.psState := IDLE_S;
        end if;
      when ACTIVE_S =>
        if psDone = '1' then
          if r.psIncNdec = '1' then
            v.delayValue := r.delayValue+1;
          else
            v.delayValue := r.delayValue-1;
          end if;
          v.psState  := IDLE_S;
        end if;
      when others => NULL;
    end case;

    if axilRst = '1' then
      v := REG_INIT_C;
    end if;

    r_in <= v;

    axilReadSlave  <= r.axilReadSlave;
    axilWriteSlave <= r.axilWriteSlave;
  end process;

  seq: process(axilClk) is
  begin
    if rising_edge(axilClk) then
      r <= r_in;
    end if;
  end process;
      
end behavior;
