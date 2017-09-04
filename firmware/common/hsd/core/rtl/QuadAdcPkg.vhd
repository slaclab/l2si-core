-------------------------------------------------------------------------------
-- Title : top poject package
-- Poject : quad_demo
-------------------------------------------------------------------------------
-- File : quad_demo_top_pkg.vhd
-- Autho : FARCY G.
-- Compagny : e2v
-- Last update : 2009/04/06
-- Platefom :
-------------------------------------------------------------------------------
-- Desciption : define some signals type used in others files of the projectx 
-------------------------------------------------------------------------------
-- Revision :
-- Date         Vesion      Author         Description
-- 2009/04/06   1.0          FARCY G.       Ceated
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- libary description
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library work;
use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

package QuadAdcPkg is
  constant DMA_CHANNELS_C : natural := 5;  -- 4 ADC channels + 1 monitor channel
-------------------------------------------------------------------------------
--  Constants to configue in function of ADC witch is targeted
-------------------------------------------------------------------------------
  constant PATTERN_WIDTH          : natural := 11; --number of bits by channel 
  constant CHANNELS_C         : natural := 8;  -- number of channel FIXE DONT CHANGE
                                                   -- Wite in nb_channel register with SPI register to configure channel number 
  constant SERDES_FACTOR    : natural := 8;  --deserialization factor in SERDES

  type serdes_tap_value_type is array (CHANNELS_C-1 downto 0) of NaturalArray(PATTERN_WIDTH - 1 downto 0);
  constant SERDES_TAP_VALUE : serdes_tap_value_type := (others=>(others=>0));

  constant Q_NONE  : slv(1 downto 0) := "00";
  constant Q_ABCD  : slv(1 downto 0) := "01";
  constant Q_AC_BD : slv(1 downto 0) := "10";

  type AdcInput is record
    clkp  : sl;
    clkn  : sl;
    datap : slv(10 downto 0);
    datan : slv(10 downto 0);
  end record;

  type AdcInputArray is array (natural range <>) of AdcInput;

  type AdcData is record
    data : Slv11Array(7 downto 0);
  end record;
  constant ADC_DATA_INIT_C : AdcData := (
    data => (others=>(others=>'0')) );
  
  type AdcDataArray is array(natural range<>) of AdcData;

  type QuadAdcFex is ( F_SAMPLE, F_SUM );

  type QuadAdcStatusType is record
    status    : slv(31 downto 0);
    countH    : SlVectorArray(15 downto 0, 31 downto 0);
    countL    : SlVectorArray(15 downto 0, 31 downto 0);
  end record;
  
  constant QADC_CONFIG_TYPE_LEN_C : integer := CHANNELS_C+101;
  type QuadAdcConfigType is record
    enable    : slv(CHANNELS_C-1 downto 0);  -- channel mask
    partition : slv( 3 downto 0);  -- LCLS: not used
    intlv     : slv( 1 downto 0);
    samples   : slv(17 downto 0);
    prescale  : slv( 5 downto 0);
    offset    : slv(19 downto 0);
    acqEnable : sl;
    rateSel   : slv(12 downto 0);  -- LCLS: eventCode
    destSel   : slv(18 downto 0);  -- LCLS: not used
    inhibit   : sl;
    dmaTest   : sl;
    trigShift : slv( 7 downto 0);
  end record;
  constant QUAD_ADC_CONFIG_INIT_C : QuadAdcConfigType := (
    enable    => (others=>'0'),
    partition => (others=>'0'),
    intlv     => Q_NONE,
    samples   => toSlv(0,18),
    prescale  => toSlv(1,6),
    offset    => toSlv(0,20),
    acqEnable => '0',
    rateSel   => (others=>'0'),
    destSel   => (others=>'0'),
    inhibit   => '1',
    dmaTest   => '0',
    trigShift => (others=>'0') );

  constant QUAD_ADC_EVENT_TAG : slv(15 downto 0) := X"0000";
  constant QUAD_ADC_DIAG_TAG  : slv(15 downto 0) := X"0001";

  function toSlv       (config : QuadAdcConfigType) return slv;
  function toQadcConfig(vector : slv)               return QuadAdcConfigType;

end QuadAdcPkg;

package body QuadAdcPkg is

   function toSlv (config : QuadAdcConfigType) return slv
   is
      variable vector : slv(QADC_CONFIG_TYPE_LEN_C-1 downto 0) := (others => '0');
      variable i      : integer                               := 0;
   begin
      assignSlv(i, vector, config.enable);
      assignSlv(i, vector, config.partition);
      assignSlv(i, vector, config.intlv);
      assignSlv(i, vector, config.samples);
      assignSlv(i, vector, config.prescale);
      assignSlv(i, vector, config.offset);
      assignSlv(i, vector, config.acqEnable);
      assignSlv(i, vector, config.rateSel);
      assignSlv(i, vector, config.destSel);
      assignSlv(i, vector, config.inhibit);
      assignSlv(i, vector, config.dmaTest);
      assignSlv(i, vector, config.trigShift);
      return vector;
   end function;
   
   function toQadcConfig (vector : slv) return QuadAdcConfigType
   is
      variable config : QuadAdcConfigType;
      variable i       : integer := 0;
   begin
      assignRecord(i, vector, config.enable);
      assignRecord(i, vector, config.partition);
      assignRecord(i, vector, config.intlv);
      assignRecord(i, vector, config.samples);
      assignRecord(i, vector, config.prescale);
      assignRecord(i, vector, config.offset);
      assignRecord(i, vector, config.acqEnable);
      assignRecord(i, vector, config.rateSel);
      assignRecord(i, vector, config.destSel);
      assignRecord(i, vector, config.inhibit);
      assignRecord(i, vector, config.dmaTest);
      assignRecord(i, vector, config.trigShift);
      return config;
   end function;
   
end package body QuadAdcPkg;
