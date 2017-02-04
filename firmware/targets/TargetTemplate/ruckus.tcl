# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load submodules' code and constraints
loadRuckusTcl $::env(PROJ_DIR)/../../submodules

# Load commons' source code and constraints
loadRuckusTcl $::env(PROJ_DIR)/../../common/CommonTemplate/

# Load target's source code and constraints
loadSource      -path "$::DIR_PATH/Version.vhd"
loadSource      -dir  "$::DIR_PATH/hdl/"
loadConstraints -dir  "$::DIR_PATH/hdl/"
