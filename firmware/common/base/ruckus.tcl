# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -dir "$::DIR_PATH/rtl/"
loadSource -dir "$::DIR_PATH/coregen/"
loadIpCore -path "$::DIR_PATH/coregen/ila_0.xci"
loadIpCore -path "$::DIR_PATH/coregen/debug_bridge_0.xci"
loadIpCore -path "$::DIR_PATH/coregen/bd_54be_0_bsip_0.xci"
loadIpCore -path "$::DIR_PATH/coregen/jtag_bridge.xci"
loadIpCore -path "$::DIR_PATH/coregen/bd_6f57_axi_jtag_0.xci"
#loadSource "$::DIR_PATH/coregen/MpsPgpGthCore_auto.dcp"
