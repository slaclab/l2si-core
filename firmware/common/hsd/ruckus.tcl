# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadRuckusTcl "$::DIR_PATH/axi"
loadRuckusTcl "$::DIR_PATH/i2c"
loadRuckusTcl "$::DIR_PATH/spi"
loadRuckusTcl "$::DIR_PATH/ssi"
loadRuckusTcl "$::DIR_PATH/AxiPcieQuadAdc"
loadRuckusTcl "$::DIR_PATH/PC821"
loadRuckusTcl "$::DIR_PATH/core"
loadRuckusTcl "$::DIR_PATH/fex"
