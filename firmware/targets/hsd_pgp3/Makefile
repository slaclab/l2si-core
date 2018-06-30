export GIT_BYPASS = 1
export REMOVE_UNUSED_CODE = 1

# Define target output
target: prom

# Define Firmware Version Number
#  00000000  Initial PGP3 + hsd/v2
#  00000001  hsd/v2 fixes from hsd/v3
#  00000002  pgp3 fixes from dtiPgp3
#  00000003  refclk to fmc = 929kHz * 4
export PRJ_VERSION = 00000003

# Define target part
export PRJ_PART = XCKU085-FLVB1760-2-E

# Using a non-standard target directory structure, 
# which requires me to define the TOP_DIR path
export TOP_DIR = $(abspath $(PWD)/../..)

# Use top level makefile
include $(TOP_DIR)/submodules/ruckus/system_vivado.mk
