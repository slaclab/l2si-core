############################
# DO NOT EDIT THE CODE BELOW
############################

# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load submodules' code and constraints
#   Need surf without:
#      axi package (need wider AxiStream for PCIe GEN3 DMA)
#      ssi package (initialize wider tData)
set SURF_DIR $::DIR_PATH/../../submodules/surf
loadRuckusTcl "${SURF_DIR}/base"       "quiet"
loadRuckusTcl "${SURF_DIR}/protocols/pgp/pgp3/core"  "quiet"
loadSource -dir "${SURF_DIR}/protocols/pgp/pgp3/gthUs/rtl/"  "quiet"
loadRuckusTcl "${SURF_DIR}/xilinx"     "quiet"

loadRuckusTcl "$::DIR_PATH/../../submodules/lcls-timing-core"
loadRuckusTcl "$::DIR_PATH/../../common/base"
loadRuckusTcl "$::DIR_PATH/../../common/hsd"
loadRuckusTcl "$::DIR_PATH/../../common/hsd/v3"
loadRuckusTcl "$::DIR_PATH/../../common/hsd/pgp"

# Load target's source code and constraints
loadSource      -dir  "$::DIR_PATH/hdl/"
loadIpCore      -path "$::DIR_PATH/hdl/Pgp3GthUsIp.xci"
loadConstraints -dir  "$::DIR_PATH/hdl/"
loadConstraints -dir  "$::DIR_PATH/../../common/hsd/core/xdc/"
loadConstraints -dir  "$::DIR_PATH/../../common/hsd/AxiPcieQuadAdc/xdc/"
