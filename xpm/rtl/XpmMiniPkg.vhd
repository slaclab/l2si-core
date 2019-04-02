-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : XpmMiniPkg.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-03-25
-- Last update: 2019-03-29
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Programmable configuration and status fields
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 XPM Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 XPM Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.TimingPkg.all;
use work.XpmPkg.all;

package XpmMiniPkg is

   -----------------------------------------------------------
   -- Application: Configurations, Constants and Records Types
   -----------------------------------------------------------

   constant NSTREAMS_C : integer := 3;
  
   type XpmStreamType is record
     fiducial : sl;
     streams  : TimingSerialArray(NSTREAMS_C-1 downto 0);
     advance  : slv              (NSTREAMS_C-1 downto 0);
   end record;

   constant XPM_STREAM_INIT_C : XpmStreamType := (
     fiducial => '0',
     streams  => (others=>TIMING_SERIAL_INIT_C),
     advance  => (others=>'0') );
   
   type XpmMiniPartitionStatusType is record
     l0Select   : XpmL0SelectStatusType;
   end record;
   constant XPM_MINI_PARTITION_STATUS_INIT_C : XpmMiniPartitionStatusType := (
     l0Select   => XPM_L0_SELECT_STATUS_INIT_C );

   type XpmMiniStatusType is record
     dsLink     : XpmLinkStatusArray(NDSLinks-1 downto 0);
     partition  : XpmMiniPartitionStatusType;
   end record;

   constant XPM_MINI_STATUS_INIT_C : XpmMiniStatusType := (
     dsLink     => (others=>XPM_LINK_STATUS_INIT_C),
     partition  => XPM_MINI_PARTITION_STATUS_INIT_C );


   type XpmMiniLinkConfigType is record
     enable     : sl;
     loopback   : sl;
     txReset    : sl;
     rxReset    : sl;
     txPllReset : sl;
     rxPllReset : sl;
   end record;

   constant XPM_MINI_LINK_CONFIG_INIT_C : XpmMiniLinkConfigType := (
     enable     => '0',
     loopback   => '0',
     txReset    => '0',
     rxReset    => '0',
     txPllReset => '0',
     rxPllReset => '0' );

   type XpmMiniLinkConfigArray is array (natural range<>) of XpmMiniLinkConfigType;

   type XpmMiniPartitionConfigType is record
     l0Select   : XpmL0SelectConfigType;
     pipeline   : XpmPipelineConfigType;
     message    : XpmPartMsgConfigType;
   end record;

   constant XPM_MINI_PARTITION_CONFIG_INIT_C : XpmMiniPartitionConfigType := (
     l0Select   => XPM_L0_SELECT_CONFIG_INIT_C,
     pipeline   => XPM_PIPELINE_CONFIG_INIT_C,
     message    => XPM_PART_MSG_CONFIG_INIT_C );

   type XpmMiniConfigType is record
     dsLink     : XpmMiniLinkConfigArray(NDSLinks-1 downto 0);
     partition  : XpmMiniPartitionConfigType;
   end record;

   constant XPM_MINI_CONFIG_INIT_C : XpmMiniConfigType := (
     dsLink     => (others=>XPM_MINI_LINK_CONFIG_INIT_C),
     partition  => XPM_MINI_PARTITION_CONFIG_INIT_C );

end package XpmMiniPkg;

package body XpmMiniPkg is
end package body XpmMiniPkg;
