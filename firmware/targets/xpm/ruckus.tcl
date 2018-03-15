############################
# DO NOT EDIT THE CODE BELOW
############################

# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load submodules' code and constraints
loadRuckusTcl $::env(TOP_DIR)/submodules
# Load development repos rather than submodules
##loadRuckusTcl /u1/weaver/amc-carrier-core
#loadSource      -dir  "/u1/weaver/amc-carrier-core/AmcCarrierCore/dcp/hdl/"
#loadSource      -dir  "/u1/weaver/amc-carrier-core/AmcCarrierCore/ip/"
#loadSource      -dir  "/u1/weaver/amc-carrier-core/AmcCarrierCore/core/"
#loadSource      -dir  "/u1/weaver/amc-carrier-core/AppMps/rtl/"

# Makefile export USE_XVC_DEBUG = 0 isn't working
loadSource -path "$::DIR_PATH/../../submodules/amc-carrier-core/AmcCarrierCore/debug/dcp/Stub/images/UdpDebugBridge.dcp"

#loadRuckusTcl $::env(TOP_DIR)/submodules/lcls-timing-core
#loadRuckusTcl $::env(TOP_DIR)/submodules/surf
#loadRuckusTcl /u1/weaver/lcls-timing-core
#loadRuckusTcl /u1/weaver/surf

loadRuckusTcl "$::DIR_PATH/../../common/base"
loadRuckusTcl "$::DIR_PATH/../../common/xpm"
loadRuckusTcl "$::DIR_PATH/../../common/gthUltraScale"

# Load target's source code and constraints
loadSource      -dir  "$::DIR_PATH/hdl/"
loadConstraints -dir  "$::DIR_PATH/hdl/"

#loadConstraints -path "/u1/weaver/amc-carrier-core/AmcCarrierCore/xdc/AmcCarrierCorePlacement.xdc"
#loadConstraints -path "/u1/weaver/amc-carrier-core/AmcCarrierCore/xdc/AmcCarrierCorePorts.xdc"
#loadConstraints -path "/u1/weaver/amc-carrier-core/AmcCarrierCore/xdc/AmcCarrierCoreZone2Eth.xdc"

