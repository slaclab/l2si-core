export GIT_BYPASS = 1

export REMOVE_UNUSED_CODE = 1

# Define target output
target: prom

# Define Firmware Version Number
# PRJ_VERSION = 0000000  First synthesized, PcieGen2 x8
# PRJ_VERSION = 0000001  PcieGen3 x4
# PRJ_VERSION = 0000002  Add debug bridge (XVC)
# PRJ_VERSION = 0000003  Add debug bridge on JTAG (XVC)
# PRJ_VERSION = 0000004  Add timing feedback link ID
export PRJ_VERSION = 00000004

# Define target part
export PRJ_PART = XCKU085-FLVB1760-2-E

# Using a non-standard target directory structure, 
# which requires me to define the TOP_DIR path
export TOP_DIR = $(abspath $(PWD)/../..)

# Use top level makefile
include $(TOP_DIR)/submodules/ruckus/system_vivado.mk
