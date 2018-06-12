# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/surf"
loadRuckusTcl "$::DIR_PATH/lcls-timing-core"
#loadRuckusTcl "$::DIR_PATH/amc-carrier-core"
loadRuckusTcl "$::DIR_PATH/../common/$::env(COMMON_FILE)"

#
#  Pick the pieces out of amc-carrier-core
#
loadSource -dir  "$::DIR_PATH/amc-carrier-core/AmcCarrierCore/core"
loadSource -dir  "$::DIR_PATH/amc-carrier-core/AmcCarrierCore/dcp/hdl"
loadSource -dir  "$::DIR_PATH/amc-carrier-core/AmcCarrierCore/ip"
# Keep a history of all the load paths
set ::DIR_LIST "$::DIR_LIST $::DIR_PATH/amc-carrier-core/AmcCarrierCore"
