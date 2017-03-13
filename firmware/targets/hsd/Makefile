
# Define target output
target: prom

# Define Firmware Version Number
export PRJ_VERSION = 00000009

# Define target part
export PRJ_PART = XCKU085-FLVB1760-2-E

# Using a non-standard target directory structure, 
# which requires me to define the TOP_DIR path
export TOP_DIR = $(abspath $(PWD)/../..)

# Use top level makefile
include $(TOP_DIR)/submodules/ruckus/system_vivado.mk

#export MOD_TAG = head
#export AMC_TAG =$(MOD_TAG)
#export VIVADO_BUILD_DIR = $(abspath $(PWD)/../../modules/StdLib/$(MOD_TAG)/build)
#
## List of build core directories.
#export MODULE_DIRS = $(PROJ_DIR)/../../modules/StdLib/$(MOD_TAG) \
#                     $(PROJ_DIR)/../../modules/AxiMicronP30Core \
#                     $(PROJ_DIR)/../../modules/AxiPcieCore/AxiPcieQuadAdc \
#                     $(PROJ_DIR)/../../modules/TimingCore/$(MOD_TAG)/LCLS-II/core \
#                     $(PROJ_DIR)/../../modules/TimingCore/$(MOD_TAG)/LCLS-II/gthUltraScale \
#                     $(PROJ_DIR)
#
## Use top level makefile
#include ../../modules/StdLib/$(MOD_TAG)/build/system_vivado_v1.mk
