-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DtiPkg.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-03-25
-- Last update: 2017-07-05
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Programmable configuration and status fields
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 Dti Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 Dti Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.TimingPkg.all;
use work.XpmPkg.all;
use work.AxiStreamPkg.all;

package DtiPkg is
  
   -- 
   constant AXI_CLK_FREQ_C   : real := 156.25E+6;                        -- In units of Hz
   constant TIMEOUT_C          : real     := 1.0E-3;  -- In units of seconds   
   constant WINDOW_ADDR_SIZE_C : positive := 3;
   constant MAX_CUM_ACK_CNT_C  : positive := WINDOW_ADDR_SIZE_C;
   constant MAX_RETRANS_CNT_C  : positive := ite((WINDOW_ADDR_SIZE_C > 1), WINDOW_ADDR_SIZE_C-1, 1);

   constant MaxUsLinks     : integer := 7;
--   constant MaxDsLinks     : integer := 13;
   constant MaxDsLinks     : integer := 7;

   constant US_IB_CONFIG_C : AxiStreamConfigType := (
     TSTRB_EN_C    => false,
     TDATA_BYTES_C => 8,                -- 10Gbps
     TDEST_BITS_C  => 1,                -- Event/Control
     TID_BITS_C    => 5,                -- L0Tag
     TKEEP_MODE_C  => TKEEP_COMP_C,
     TUSER_BITS_C  => 2,
     TUSER_MODE_C  => TUSER_FIRST_LAST_C );
   
   constant US_OB_CONFIG_C : AxiStreamConfigType := (
     TSTRB_EN_C    => false,
     TDATA_BYTES_C => 8,                -- 10Gbps
     TDEST_BITS_C  => 0,
     TID_BITS_C    => 5,                -- L0Tag
     TKEEP_MODE_C  => TKEEP_COMP_C,
     TUSER_BITS_C  => 2,
     TUSER_MODE_C  => TUSER_FIRST_LAST_C );

   constant CTLS_CONFIG_C : AxiStreamConfigType := (
     TSTRB_EN_C    => false,
     TDATA_BYTES_C => 8,                -- 10Gbps
     TDEST_BITS_C  => 1,
     TID_BITS_C    => 0,
     TKEEP_MODE_C  => TKEEP_COMP_C,
     TUSER_BITS_C  => 2,
     TUSER_MODE_C  => TUSER_FIRST_LAST_C );

   constant DTI_US_LINK_CONFIG_BITS_C : integer := MaxDsLinks+72;

   type QuadType is record
     amcClk           : sl;
     qplllock         : sl;
     qplloutclk       : sl;
     qplloutrefclk    : sl;
   end record;

   type QuadArray is array(natural range<>) of QuadType;
   type AmcQuadArray is array(natural range<>) of QuadArray(1 downto 0);
   
   type DtiUsLinkConfigType is record
     enable     : sl;
     partition  : slv(3 downto 0);
     trigDelay  : slv(7 downto 0);
     fwdMask    : slv(MaxDsLinks-1 downto 0);
     fwdMode    : sl;
     dataSrc    : slv(31 downto 0);
     dataType   : slv(31 downto 0);
     tagEnable  : sl;
     l1Enable   : sl;
   end record;

   constant DTI_US_LINK_CONFIG_INIT_C : DtiUsLinkConfigType := (
     enable     => '0',
     partition  => (others=>'0'),
     trigDelay  => (others=>'0'),
     fwdMask    => (others=>'0'),
     fwdMode    => '0',
     dataSrc    => (others=>'0'),
     dataType   => (others=>'0'),
     tagEnable  => '0',
     l1Enable   => '0');

   type DtiUsLinkConfigArray is array (natural range<>) of DtiUsLinkConfigType;

   
   type DtiUsLinkStatusType is record
     linkUp     : sl;
     rxErrs     : slv(31 downto 0);
     rxFull     : slv(31 downto 0);
     ibRecv     : slv(47 downto 0);
     ibEvt      : slv(31 downto 0);
     obL0       : slv(19 downto 0);
     obL1A      : slv(19 downto 0);
     obL1R      : slv(19 downto 0);
   end record;

   constant DTI_US_LINK_STATUS_INIT_C : DtiUsLinkStatusType := (
     linkUp     => '0',
     rxErrs     => (others=>'0'),
     rxFull     => (others=>'0'),
     ibRecv     => (others=>'0'),
     ibEvt      => (others=>'0'),
     obL0       => (others=>'0'),
     obL1A      => (others=>'0'),
     obL1R      => (others=>'0') );
   
   type DtiUsLinkStatusArray is array (natural range<>) of DtiUsLinkStatusType;

   type DtiUsAppStatusType is record
     obReceived : slv(31 downto 0);
     obSent     : slv(31 downto 0);
   end record;

   constant DTI_US_APP_STATUS_INIT_C : DtiUsAppStatusType := (
     obReceived => (others=>'0'),
     obSent     => (others=>'0') );
   
   type DtiUsAppStatusArray is array (natural range<>) of DtiUsAppStatusType;
   

   type DtiDsLinkStatusType is record
     linkUp     : sl;
     rxErrs     : slv(31 downto 0);
     rxFull     : slv(31 downto 0);
     obSent     : slv(47 downto 0);
   end record;

   constant DTI_DS_LINK_STATUS_INIT_C : DtiDsLinkStatusType := (
     linkUp     => '0',
     rxErrs     => (others=>'0'),
     rxFull     => (others=>'0'),
     obSent     => (others=>'0') );

   type DtiDsLinkStatusArray is array (natural range<>) of DtiDsLinkStatusType;

   
   type DtiConfigType is record
     usLink     : DtiUsLinkConfigArray   (MaxUsLinks-1 downto 0);
   end record;

   constant DTI_CONFIG_INIT_C : DtiConfigType := (
     usLink     => (others=>DTI_US_LINK_CONFIG_INIT_C) );

   type DtiStatusType is record
     usLink     : DtiUsLinkStatusArray   (MaxUsLinks-1 downto 0);
     dsLink     : DtiDsLinkStatusArray   (MaxDsLinks-1 downto 0);
     bpLinkUp   : sl;
     usApp      : DtiUsAppStatusArray    (MaxUsLinks-1 downto 0);
     qplllock   : slv(3 downto 0);
   end record;

   constant DTI_STATUS_INIT_C : DtiStatusType := (
     usLink     => (others=>DTI_US_LINK_STATUS_INIT_C),
     dsLink     => (others=>DTI_DS_LINK_STATUS_INIT_C),
     bpLinkUp   => '0',
     usApp      => (others=>DTI_US_APP_STATUS_INIT_C),
     qplllock   => "00" );

   type DtiEventHeaderType is record
     timeStamp  : slv(63 downto 0);
     pulseId    : slv(63 downto 0);
     evttag     : slv(31 downto 0);
   end record;

   constant DTI_EVENT_HEADER_INIT_C : DtiEventHeaderType := (
     timeStamp  => (others=>'0'),
     pulseId    => (others=>'0'),
     evttag     => (others=>'0') );

   function toSlv         (cfg : DtiUsLinkConfigType) return slv;
   function toUsLinkConfig(v : slv) return DtiUsLinkConfigType;

end package DtiPkg;

package body DtiPkg is

  function toSlv (cfg : DtiUsLinkConfigType) return slv
  is
    variable vector : slv(DTI_US_LINK_CONFIG_BITS_C-1 downto 0) := (others=>'0');
    variable i      : integer                                   := 0;
  begin
    assignSlv(i, vector, cfg.enable);
    assignSlv(i, vector, cfg.partition);
    assignSlv(i, vector, cfg.fwdMask);
    assignSlv(i, vector, cfg.fwdMode);
    assignSlv(i, vector, cfg.dataSrc);
    assignSlv(i, vector, cfg.dataType);
    assignSlv(i, vector, cfg.tagEnable);
    assignSlv(i, vector, cfg.l1Enable);
    return vector;
  end function;

  function toUsLinkConfig(v : slv) return DtiUsLinkConfigType
  is
    variable cfg : DtiUsLinkConfigType := DTI_US_LINK_CONFIG_INIT_C;
    variable i   : integer             := 0;
  begin
    assignRecord(i, v, cfg.enable);
    assignRecord(i, v, cfg.partition);
    assignRecord(i, v, cfg.fwdMask);
    assignRecord(i, v, cfg.fwdMode);
    assignRecord(i, v, cfg.dataSrc);
    assignRecord(i, v, cfg.dataType);
    assignRecord(i, v, cfg.tagEnable);
    assignRecord(i, v, cfg.l1Enable);
    return cfg;
  end function;
    
end package body DtiPkg;
