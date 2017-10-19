############################
# DO NOT EDIT THE CODE BELOW
############################

# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load submodules' code and constraints
set SURF_DIR /u1/weaver/surf
#loadRuckusTcl /u1/weaver/surf
#loadRuckusTcl "$::SURF_DIR/axi"        "quiet"
loadRuckusTcl "${SURF_DIR}/base"       "quiet"
#loadRuckusTcl "${SURF_DIR}/devices"    "quiet"
#loadRuckusTcl "${SURF_DIR}/ethernet"   "quiet"
#loadRuckusTcl "${SURF_DIR}/protocols/ssi"  "quiet"
loadRuckusTcl "${SURF_DIR}/xilinx"     "quiet"

loadRuckusTcl "$::DIR_PATH/../../submodules/lcls-timing-core"
loadRuckusTcl "$::DIR_PATH/../../common/base"
loadRuckusTcl "$::DIR_PATH/../../common/hsd"
loadRuckusTcl "$::DIR_PATH/../../common/hsd/v2"
loadRuckusTcl "$::DIR_PATH/../../common/xpm"

# Load target's source code and constraints
loadSource      -dir  "$::DIR_PATH/hdl/"
