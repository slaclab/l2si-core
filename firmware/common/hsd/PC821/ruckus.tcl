# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -dir "$::DIR_PATH/Fmc126/rtl/"
loadSource -dir "$::DIR_PATH/cid/rtl/"
loadSource -dir "$::DIR_PATH/host/flash_controller/"
