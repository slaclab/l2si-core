# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Check for Vivado version 2016.4 (or later)
if { [VersionCheck 2016.4 ] < 0 } {
   exit -1
}

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/base"  "quiet"
loadRuckusTcl "$::DIR_PATH/xpm" "quiet"
loadRuckusTcl "$::DIR_PATH/gthUltraScale" "quiet"

