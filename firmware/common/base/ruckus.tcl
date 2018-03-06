# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -dir "$::DIR_PATH/rtl/"
loadSource -dir "$::DIR_PATH/coregen/"
loadIpCore -path "$::DIR_PATH/coregen/ila_0.xci"
#loadSource "$::DIR_PATH/coregen/MpsPgpGthCore_auto.dcp"
