############################
# DO NOT EDIT THE CODE BELOW
############################

# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load submodules' code and constraints
loadRuckusTcl $::env(TOP_DIR)/submodules

# Load target's source code and constraints
loadSource      -path "$::DIR_PATH/Version.vhd"
loadSource      -dir  "$::DIR_PATH/hdl/"
loadConstraints -dir  "$::DIR_PATH/hdl/"
