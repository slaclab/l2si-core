############################
# DO NOT EDIT THE CODE BELOW
############################

# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load submodules' code and constraints
loadRuckusTcl $::env(TOP_DIR)/submodules
# Load development repos rather than submodules
#loadRuckusTcl /u1/weaver/amc-carrier-core
#loadRuckusTcl /u1/weaver/lcls-timing-core
#loadRuckusTcl /u1/weaver/surf

loadSource -dir "$::DIR_PATH/../../common/base/rtl/"
loadSource -dir "$::DIR_PATH/../../common/xpm/rtl/"
loadSource -dir "$::DIR_PATH/../../common/dti/rtl/"

# Load target's source code and constraints
loadSource      -dir  "$::DIR_PATH/hdl/"
#loadConstraints -dir  "$::DIR_PATH/hdl/"
