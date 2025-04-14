##############################################################################
## This file is part of 'L2SI-CORE'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'L2SI-CORE', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib l2si_core -dir "$::DIR_PATH/rtl/"
loadSource -lib l2si_core -dir "$::DIR_PATH/coregen/"
loadIpCore -path "$::DIR_PATH/coregen/ila_0.xci"
#loadSource -path "$::DIR_PATH/coregen/ila_0.dcp"
loadIpCore -path "$::DIR_PATH/coregen/debug_bridge_0.xci"
#loadIpCore -path "$::DIR_PATH/coregen/bd_54be_0_bsip_0.xci"
loadIpCore -path "$::DIR_PATH/coregen/jtag_bridge.xci"
#loadIpCore -path "$::DIR_PATH/coregen/bd_6f57_axi_jtag_0.xci"
#loadSource -lib l2si_core "$::DIR_PATH/coregen/MpsPgpGthCore_auto.dcp"
