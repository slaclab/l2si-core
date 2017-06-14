##############################################################################
## This file is part of 'AxiPcieCore'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'AxiPcieCore', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
######################################
# BITSTREAM: .bit file Configuration #
######################################

set_property BITSTREAM.GENERAL.COMPRESS True [current_design]
set_property BITSTREAM.CONFIG.BPI_PAGE_SIZE 8 [current_design]
set_property BITSTREAM.CONFIG.BPI_1ST_READ_CYCLE 3 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 3 [current_design]
set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN DIV-2 [current_design]

set_property CFGBVS GND [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property CONFIG_MODE BPI16 [current_design]

##############################
# StdLib: Custom Constraints #
##############################

set_property ASYNC_REG true [get_cells -hierarchical *crossDomainSyncReg_reg*]

######################
# FLASH: Constraints #
######################

#set_property -dict { PACKAGE_PIN BA25 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[0] }]
#set_property -dict { PACKAGE_PIN BB25 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[1] }]
#set_property -dict { PACKAGE_PIN AY28 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[2] }]
#set_property -dict { PACKAGE_PIN BA28 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[3] }]
#set_property -dict { PACKAGE_PIN AY25 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[4] }]
#set_property -dict { PACKAGE_PIN AY26 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[5] }]
#set_property -dict { PACKAGE_PIN AW26 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[6] }]
#set_property -dict { PACKAGE_PIN AY27 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[7] }]
#set_property -dict { PACKAGE_PIN AW23 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[8] }]
#set_property -dict { PACKAGE_PIN AY23 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[9] }]
#set_property -dict { PACKAGE_PIN AW24 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[10] }]
#set_property -dict { PACKAGE_PIN AW25 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[11] }]
#set_property -dict { PACKAGE_PIN BB21 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[12] }]
#set_property -dict { PACKAGE_PIN BB22 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[13] }]
#set_property -dict { PACKAGE_PIN BA23 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[14] }]
#set_property -dict { PACKAGE_PIN BA24 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[15] }]
#set_property -dict { PACKAGE_PIN AW21 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[16] }]
#set_property -dict { PACKAGE_PIN AY21 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[17] }]
#set_property -dict { PACKAGE_PIN AY22 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[18] }]
#set_property -dict { PACKAGE_PIN BA22 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[19] }]
#set_property -dict { PACKAGE_PIN AT22 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[20] }]
#set_property -dict { PACKAGE_PIN AT23 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[21] }]
#set_property -dict { PACKAGE_PIN AR25 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[22] }]
#set_property -dict { PACKAGE_PIN AR26 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[23] }]
#set_property -dict { PACKAGE_PIN AU22 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[24] }]
#set_property -dict { PACKAGE_PIN AV23 IOSTANDARD LVCMOS18 } [get_ports { flashAddr[25] }]
#set_property -dict { PACKAGE_PIN N31  IOSTANDARD LVCMOS18 } [get_ports { flashAddr[26] }]
#set_property -dict { PACKAGE_PIN P31  IOSTANDARD LVCMOS18 } [get_ports { flashAddr[27] }]
#set_property -dict { PACKAGE_PIN R31  IOSTANDARD LVCMOS18 } [get_ports { flashAddr[28] }]

#set_property -dict { PACKAGE_PIN V28 IOSTANDARD LVCMOS18 PULLUP true} [get_ports { flashData[0] }]
#set_property -dict { PACKAGE_PIN V29 IOSTANDARD LVCMOS18 PULLUP true} [get_ports { flashData[1] }]
#set_property -dict { PACKAGE_PIN AE9 IOSTANDARD LVCMOS18 PULLUP true} [get_ports { flashData[2] }]
#set_property -dict { PACKAGE_PIN AF9 IOSTANDARD LVCMOS18 PULLUP true} [get_ports { flashData[3] }]
#set_property -dict { PACKAGE_PIN AV26 IOSTANDARD LVCMOS18 PULLUP true} [get_ports { flashData[4] }]
#set_property -dict { PACKAGE_PIN AV27 IOSTANDARD LVCMOS18 PULLUP true} [get_ports { flashData[5] }]
#set_property -dict { PACKAGE_PIN AU29 IOSTANDARD LVCMOS18 PULLUP true} [get_ports { flashData[6] }]
#set_property -dict { PACKAGE_PIN AV29 IOSTANDARD LVCMOS18 PULLUP true} [get_ports { flashData[7] }]
#set_property -dict { PACKAGE_PIN AU25 IOSTANDARD LVCMOS18 PULLUP true} [get_ports { flashData[8] }]
#set_property -dict { PACKAGE_PIN AU26 IOSTANDARD LVCMOS18 PULLUP true} [get_ports { flashData[9] }]
#set_property -dict { PACKAGE_PIN AU27 IOSTANDARD LVCMOS18 PULLUP true} [get_ports { flashData[10] }]
#set_property -dict { PACKAGE_PIN AV28 IOSTANDARD LVCMOS18 PULLUP true} [get_ports { flashData[11] }]
#set_property -dict { PACKAGE_PIN BB26 IOSTANDARD LVCMOS18 PULLUP true} [get_ports { flashData[12] }]
#set_property -dict { PACKAGE_PIN BB27 IOSTANDARD LVCMOS18 PULLUP true} [get_ports { flashData[13] }]
#set_property -dict { PACKAGE_PIN AW28 IOSTANDARD LVCMOS18 PULLUP true} [get_ports { flashData[14] }]
#set_property -dict { PACKAGE_PIN AW29 IOSTANDARD LVCMOS18 PULLUP true} [get_ports { flashData[15] }]

#set_property -dict { PACKAGE_PIN AD9  IOSTANDARD LVCMOS18 } [get_ports { flashCe }]
#set_property -dict { PACKAGE_PIN AV21 IOSTANDARD LVCMOS18 } [get_ports { flashOe }]
#set_property -dict { PACKAGE_PIN AV22 IOSTANDARD LVCMOS18 } [get_ports { flashWe }]

####################
# I2C Constraints #
####################

set_property PACKAGE_PIN AV18 [get_ports scl]
set_property PACKAGE_PIN AW18 [get_ports sda]
set_property IOSTANDARD LVCMOS33 [get_ports scl]
set_property IOSTANDARD LVCMOS33 [get_ports sda]

####################
# PCIe Constraints #
####################

set_property PACKAGE_PIN BB4 [get_ports {pciRxP[7]}]
set_property PACKAGE_PIN BB3 [get_ports {pciRxN[7]}]
set_property PACKAGE_PIN BB8 [get_ports {pciTxP[7]}]
set_property PACKAGE_PIN BB7 [get_ports {pciTxN[7]}]

set_property PACKAGE_PIN BA2 [get_ports {pciRxP[6]}]
set_property PACKAGE_PIN BA1 [get_ports {pciRxN[6]}]
set_property PACKAGE_PIN BA6 [get_ports {pciTxP[6]}]
set_property PACKAGE_PIN BA5 [get_ports {pciTxN[6]}]

set_property PACKAGE_PIN AY4 [get_ports {pciRxP[5]}]
set_property PACKAGE_PIN AY3 [get_ports {pciRxN[5]}]
set_property PACKAGE_PIN AY8 [get_ports {pciTxP[5]}]
set_property PACKAGE_PIN AY7 [get_ports {pciTxN[5]}]

set_property PACKAGE_PIN AW2 [get_ports {pciRxP[4]}]
set_property PACKAGE_PIN AW1 [get_ports {pciRxN[4]}]
set_property PACKAGE_PIN AW6 [get_ports {pciTxP[4]}]
set_property PACKAGE_PIN AW5 [get_ports {pciTxN[4]}]

set_property PACKAGE_PIN AV4 [get_ports {pciRxP[3]}]
set_property PACKAGE_PIN AV3 [get_ports {pciRxN[3]}]
set_property PACKAGE_PIN AV8 [get_ports {pciTxP[3]}]
set_property PACKAGE_PIN AV7 [get_ports {pciTxN[3]}]

set_property PACKAGE_PIN AU2 [get_ports {pciRxP[2]}]
set_property PACKAGE_PIN AU1 [get_ports {pciRxN[2]}]
set_property PACKAGE_PIN AU6 [get_ports {pciTxP[2]}]
set_property PACKAGE_PIN AU5 [get_ports {pciTxN[2]}]

set_property PACKAGE_PIN AT4 [get_ports {pciRxP[1]}]
set_property PACKAGE_PIN AT3 [get_ports {pciRxN[1]}]
set_property PACKAGE_PIN AT8 [get_ports {pciTxP[1]}]
set_property PACKAGE_PIN AT7 [get_ports {pciTxN[1]}]

set_property PACKAGE_PIN AR2 [get_ports {pciRxP[0]}]
set_property PACKAGE_PIN AR1 [get_ports {pciRxN[0]}]
set_property PACKAGE_PIN AR6 [get_ports {pciTxP[0]}]
set_property PACKAGE_PIN AR5 [get_ports {pciTxN[0]}]

set_property PACKAGE_PIN AR9 [get_ports pciRefClkN]
set_property PACKAGE_PIN AR10 [get_ports pciRefClkP]

####################
# Timing Constraints #
####################

set_property PACKAGE_PIN AA37 [get_ports timingRefClkN]
set_property PACKAGE_PIN AA36 [get_ports timingRefClkP]

set_property PACKAGE_PIN M39 [get_ports timingTxN]
set_property PACKAGE_PIN N41 [get_ports timingRxP]
set_property PACKAGE_PIN N42 [get_ports timingRxN]
set_property PACKAGE_PIN M38 [get_ports timingTxP]

create_clock -period 10.000 -name pciRefClkP [get_ports pciRefClkP]

#create_generated_clock -name serdesClk [get_pins {U_APP/U_FMC/ev10aq190_quad_phy_inst/serdes_mmcm_inst/clk_in1}]

create_generated_clock -name dnaClk [get_pins U_Core/U_REG/U_Version/GEN_DEVICE_DNA.DeviceDna_1/GEN_ULTRA_SCALE.DeviceDnaUltraScale_Inst/BUFGCE_DIV_Inst/O]
create_generated_clock -name pciClk [get_pins U_Core/U_AxiPciePhy/U_AxiPcie/inst/pcie3_ip_i/U0/gt_top_i/phy_clk_i/bufg_gt_userclk/O]
create_generated_clock -name flashClk [get_pins {U_Core/U_Clk/ClkOutGen[0].U_Bufg/O}]
#create_generated_clock -name rxUsrClk [get_pins {U_Core/U_TimingGth/GEN_EXTREF.TIMING_RECCLK_BUFG_GT/O}]

set_clock_groups -asynchronous -group [get_clocks dnaClk] -group [get_clocks pciClk]
set_clock_groups -asynchronous -group [get_clocks flashClk] -group [get_clocks pciClk]

set_property LOC PCIE_3_1_X0Y0 [get_cells U_Core/U_AxiPciePhy/U_AxiPcie/inst/pcie3_ip_i/U0/pcie3_uscale_top_inst/pcie3_uscale_wrapper_inst/PCIE_3_1_inst]
set_property PACKAGE_PIN AP28 [get_ports pciRstL]
set_property IOSTANDARD LVCMOS18 [get_ports pciRstL]
set_property PULLUP true [get_ports pciRstL]
set_false_path -from [get_ports pciRstL]

create_pblock PCIE_PHY_GRP
add_cells_to_pblock [get_pblocks PCIE_PHY_GRP] [get_cells -quiet [list U_Core/U_AxiPciePhy/U_AxiPcie]]
resize_pblock [get_pblocks PCIE_PHY_GRP] -add {CLOCKREGION_X3Y0:CLOCKREGION_X3Y1}

#  Dissolve the timing constraint between adr_p and the MMCM outputs
#    The MMCM clkout1 is creating an impossible constraint on the channel a pins IDELAY to ISERDES
#set_false_path -to [get_pins {U_APP/U_FMC/ev10aq190_quad_phy_inst/serdes_mmcm_inst/MMCME3_ADV/CLKIN1}]

