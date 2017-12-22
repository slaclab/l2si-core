##############################################################################
## This file is part of 'LCLS2 DAQ Software'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'LCLS2 DAQ Software', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
#######################
## Application Ports ##
#######################

# DS High Speed Ports

# AMC Bay 0
set_property PACKAGE_PIN AH1 [get_ports {amcRxN[0][0]}]
set_property PACKAGE_PIN AH2 [get_ports {amcRxP[0][0]}]
set_property PACKAGE_PIN AH5 [get_ports {amcTxN[0][0]}]
set_property PACKAGE_PIN AH6 [get_ports {amcTxP[0][0]}]
set_property PACKAGE_PIN AF1 [get_ports {amcRxN[0][1]}]
set_property PACKAGE_PIN AF2 [get_ports {amcRxP[0][1]}]
set_property PACKAGE_PIN AG3 [get_ports {amcTxN[0][1]}]
set_property PACKAGE_PIN AG4 [get_ports {amcTxP[0][1]}]
set_property PACKAGE_PIN AD1 [get_ports {amcRxN[0][2]}]
set_property PACKAGE_PIN AD2 [get_ports {amcRxP[0][2]}]
set_property PACKAGE_PIN AE3 [get_ports {amcTxN[0][2]}]
set_property PACKAGE_PIN AE4 [get_ports {amcTxP[0][2]}]
set_property PACKAGE_PIN AB1 [get_ports {amcRxN[0][3]}]
set_property PACKAGE_PIN AB2 [get_ports {amcRxP[0][3]}]
set_property PACKAGE_PIN AC3 [get_ports {amcTxN[0][3]}]
set_property PACKAGE_PIN AC4 [get_ports {amcTxP[0][3]}]
set_property PACKAGE_PIN AP1 [get_ports {amcRxN[0][4]}]
set_property PACKAGE_PIN AP2 [get_ports {amcRxP[0][4]}]
set_property PACKAGE_PIN AN3 [get_ports {amcTxN[0][4]}]
set_property PACKAGE_PIN AN4 [get_ports {amcTxP[0][4]}]
set_property PACKAGE_PIN AM1 [get_ports {amcRxN[0][5]}]
set_property PACKAGE_PIN AM2 [get_ports {amcRxP[0][5]}]
set_property PACKAGE_PIN AM5 [get_ports {amcTxN[0][5]}]
set_property PACKAGE_PIN AM6 [get_ports {amcTxP[0][5]}]
set_property PACKAGE_PIN AK1 [get_ports {amcRxN[0][6]}]
set_property PACKAGE_PIN AK2 [get_ports {amcRxP[0][6]}]
set_property PACKAGE_PIN AL3 [get_ports {amcTxN[0][6]}]
set_property PACKAGE_PIN AL4 [get_ports {amcTxP[0][6]}]
# MGTREFCLK1 Bank 224
#  DEVCLK2   (output of AMC PLL)
set_property PACKAGE_PIN AD5 [get_ports {amcClkN[0][0]}]
set_property PACKAGE_PIN AD6 [get_ports {amcClkP[0][0]}]
#  DEVCLK1   (oscillator on AMC)
#set_property PACKAGE_PIN AF5 [get_ports {amcClkN[0][0]}]
#set_property PACKAGE_PIN AF6 [get_ports {amcClkP[0][0]}]
#  DEVCLK0
#set_property PACKAGE_PIN AB6  [get_ports {amcClkP[0][0]}]
#set_property PACKAGE_PIN AB5  [get_ports {amcClkN[0][0]}]
# MGTREFCLK1 Bank 127
#set_property PACKAGE_PIN N29  [get_ports {amcClkP[0][1]}]
#set_property PACKAGE_PIN N30  [get_ports {amcClkN[0][1]}]


# AMC Bay 1
set_property PACKAGE_PIN M1 [get_ports {amcRxN[1][0]}]
set_property PACKAGE_PIN M2 [get_ports {amcRxP[1][0]}]
set_property PACKAGE_PIN N3 [get_ports {amcTxN[1][0]}]
set_property PACKAGE_PIN N4 [get_ports {amcTxP[1][0]}]
set_property PACKAGE_PIN K1 [get_ports {amcRxN[1][1]}]
set_property PACKAGE_PIN K2 [get_ports {amcRxP[1][1]}]
set_property PACKAGE_PIN L3 [get_ports {amcTxN[1][1]}]
set_property PACKAGE_PIN L4 [get_ports {amcTxP[1][1]}]
set_property PACKAGE_PIN H1 [get_ports {amcRxN[1][2]}]
set_property PACKAGE_PIN H2 [get_ports {amcRxP[1][2]}]
set_property PACKAGE_PIN J3 [get_ports {amcTxN[1][2]}]
set_property PACKAGE_PIN J4 [get_ports {amcTxP[1][2]}]
set_property PACKAGE_PIN F1 [get_ports {amcRxN[1][3]}]
set_property PACKAGE_PIN F2 [get_ports {amcRxP[1][3]}]
set_property PACKAGE_PIN G3 [get_ports {amcTxN[1][3]}]
set_property PACKAGE_PIN G4 [get_ports {amcTxP[1][3]}]
set_property PACKAGE_PIN E3 [get_ports {amcRxN[1][4]}]
set_property PACKAGE_PIN E4 [get_ports {amcRxP[1][4]}]
set_property PACKAGE_PIN F5 [get_ports {amcTxN[1][4]}]
set_property PACKAGE_PIN F6 [get_ports {amcTxP[1][4]}]
set_property PACKAGE_PIN D1 [get_ports {amcRxN[1][5]}]
set_property PACKAGE_PIN D2 [get_ports {amcRxP[1][5]}]
set_property PACKAGE_PIN D5 [get_ports {amcTxN[1][5]}]
set_property PACKAGE_PIN D6 [get_ports {amcTxP[1][5]}]
set_property PACKAGE_PIN B1 [get_ports {amcRxN[1][6]}]
set_property PACKAGE_PIN B2 [get_ports {amcRxP[1][6]}]
set_property PACKAGE_PIN C3 [get_ports {amcTxN[1][6]}]
set_property PACKAGE_PIN C4 [get_ports {amcTxP[1][6]}]
# MGTREFCLK1 Bank 228 (DEVCLK5)  (oscillator on AMC)
#set_property PACKAGE_PIN K6 [get_ports {amcClkP[1][0]}]
#set_property PACKAGE_PIN K5 [get_ports {amcClkN[1][0]}]
# MGTREFCLK1 Bank 228 (DEVCLK6)  (output of AMC PLL)
set_property PACKAGE_PIN H5 [get_ports {amcClkN[1][0]}]
set_property PACKAGE_PIN H6 [get_ports {amcClkP[1][0]}]
# MGTREFCLK1 Bank 128 (DEVCLK7)
#set_property PACKAGE_PIN J29  [get_ports {amcClkP[1][1]}]
#set_property PACKAGE_PIN J30  [get_ports {amcClkN[1][1]}]


set_property PACKAGE_PIN AD16 [get_ports fpgaclk_P]
set_property PACKAGE_PIN AD15 [get_ports fpgaclk_N]


# Backplane BP Ports
set_property -dict {PACKAGE_PIN AD19 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE} [get_ports bpRxP]
set_property -dict {PACKAGE_PIN AD18 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE} [get_ports bpRxN]

set_property -dict {PACKAGE_PIN AP11 IOSTANDARD LVDS_25} [get_ports bpTxP]
set_property -dict {PACKAGE_PIN AP10 IOSTANDARD LVDS_25} [get_ports bpTxN]

set_property -dict {PACKAGE_PIN AF10 IOSTANDARD LVCMOS25} [get_ports bpClkIn]
set_property -dict {PACKAGE_PIN AG10 IOSTANDARD LVCMOS25 SLEW FAST} [get_ports bpClkOut]

# LCLS Timing Ports
set_property -dict {PACKAGE_PIN AE11 IOSTANDARD LVCMOS25} [get_ports timingClkScl]
set_property -dict {PACKAGE_PIN AD11 IOSTANDARD LVCMOS25} [get_ports timingClkSda]

# Crossbar Ports
set_property -dict {PACKAGE_PIN AF13 IOSTANDARD LVCMOS25} [get_ports {xBarSin[0]}]
set_property -dict {PACKAGE_PIN AK13 IOSTANDARD LVCMOS25} [get_ports {xBarSin[1]}]
set_property -dict {PACKAGE_PIN AL13 IOSTANDARD LVCMOS25} [get_ports {xBarSout[0]}]
set_property -dict {PACKAGE_PIN AK12 IOSTANDARD LVCMOS25} [get_ports {xBarSout[1]}]
set_property -dict {PACKAGE_PIN AL12 IOSTANDARD LVCMOS25} [get_ports xBarConfig]
set_property -dict {PACKAGE_PIN AK11 IOSTANDARD LVCMOS25} [get_ports xBarLoad]
# IPMC Ports
set_property -dict {PACKAGE_PIN AE12 IOSTANDARD LVCMOS25} [get_ports ipmcScl]
set_property -dict {PACKAGE_PIN AF12 IOSTANDARD LVCMOS25} [get_ports ipmcSda]

# Configuration PROM Ports
set_property -dict {PACKAGE_PIN N27 IOSTANDARD LVCMOS25} [get_ports calScl]
set_property -dict {PACKAGE_PIN N23 IOSTANDARD LVCMOS25} [get_ports calSda]

# DDR3L SO-DIMM Ports
set_property -dict {PACKAGE_PIN L19 IOSTANDARD LVCMOS15} [get_ports ddrScl]
set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVCMOS15} [get_ports ddrSda]

set_property -dict {PACKAGE_PIN V12} [get_ports vPIn]
set_property -dict {PACKAGE_PIN W11} [get_ports vNIn]


####################################
## Application Timing Constraints ##
####################################

create_clock -period 5.000 -name ddrClkIn [get_pins -hier -filter {NAME =~ *U_DdrMem/BUFG_Inst/O}]
create_clock -period 6.400 -name fabClk [get_ports fabClkP]
create_clock -period 6.400 -name ethRef [get_ports ethClkP]
create_clock -period 2.691 -name timingRef [get_ports timingRefClkInP]

create_generated_clock -name axilClk [get_pins U_Core/U_ClkAndRst/U_ClkManagerMps/MmcmGen.U_Mmcm/CLKOUT2]
create_generated_clock -name ddrIntClk0 [get_pins -hier -filter {NAME =~ *U_DdrMem/MigCore_Inst/inst/u_ddr3_infrastructure/gen_mmcme3.u_mmcme_adv_inst/CLKOUT0}]
create_generated_clock -name ddrIntClk1 [get_pins -hier -filter {NAME =~ *U_DdrMem/MigCore_Inst/inst/u_ddr3_infrastructure/gen_mmcme3.u_mmcme_adv_inst/CLKOUT6}]

create_clock -period 6.400 -name amcClk0 [get_ports {amcClkP[0][0]}]
create_clock -period 6.400 -name amcClk1 [get_ports {amcClkP[1][0]}]
create_clock -period 6.400 -name fabClk [get_ports fabClkP]
create_clock -period 5.000 -name ddrClkIn [get_ports ddrClkP]
create_clock -period 10.000 -name bpClk [get_ports bpClkIn]

create_generate_clock -name usClk0 [get_pins {GEN_US_PGP[0].U_App/U_Pgp3/U_Pgp3GthUsIpWrapper_1/U_Pgp3GthUsIp_1//O}]
create_generate_clock -name usClk1 [get_pins {GEN_US_PGP[1].U_App/U_Pgp2b/U_BUFG/O}]
create_generate_clock -name usClk2 [get_pins {GEN_US_PGP[2].U_App/U_Pgp2b/U_BUFG/O}]
create_generate_clock -name usClk3 [get_pins {GEN_US_PGP[3].U_App/U_Pgp2b/U_BUFG/O}]
create_generate_clock -name usClk4 [get_pins {GEN_US_PGP[4].U_App/U_Pgp2b/U_BUFG/O}]
create_generate_clock -name usClk5 [get_pins {GEN_US_PGP[5].U_App/U_Pgp2b/U_BUFG/O}]
create_generate_clock -name usClk6 [get_pins {GEN_US_PGP[6].U_App/U_Pgp2b/U_BUFG/O}]

create_generate_clock -name dsClk0 [get_pins {GEN_DS_PGP[0].U_App/U_Pgp2b/U_BUFG/O}]
create_generate_clock -name dsClk1 [get_pins {GEN_DS_PGP[1].U_App/U_Pgp2b/U_BUFG/O}]
create_generate_clock -name dsClk2 [get_pins {GEN_DS_PGP[2].U_App/U_Pgp2b/U_BUFG/O}]
create_generate_clock -name dsClk3 [get_pins {GEN_DS_PGP[3].U_App/U_Pgp2b/U_BUFG/O}]
create_generate_clock -name dsClk4 [get_pins {GEN_DS_PGP[4].U_App/U_Pgp2b/U_BUFG/O}]
create_generate_clock -name dsClk5 [get_pins {GEN_DS_PGP[5].U_App/U_Pgp2b/U_BUFG/O}]
create_generate_clock -name dsClk6 [get_pins {GEN_DS_PGP[6].U_App/U_Pgp2b/U_BUFG/O}]

#set_clock_groups -asynchronous -group [get_clocks usClk0] -group [get_clocks usClk1] -group [get_clocks usClk2] -group [get_clocks usClk3] -group [get_clocks usClk4] -group [get_clocks usClk5] -group [get_clocks usClk6] -group [get_clocks -include_generated_clocks amcClk0]


#set_clock_groups -asynchronous -group [get_clocks dsClk0] -group [get_clocks dsClk1] -group [get_clocks dsClk2] -group [get_clocks dsClk3] -group [get_clocks dsClk4] -group [get_clocks dsClk5] -group [get_clocks dsClk6] -group [get_clocks -include_generated_clocks amcClk1]

create_generated_clock -name bpClk625MHz [get_pins U_Backplane/U_Clk/U_ClkManagerMps/MmcmGen.U_Mmcm/CLKOUT0]
create_generated_clock -name bpClk312MHz [get_pins U_Backplane/U_Clk/U_ClkManagerMps/MmcmGen.U_Mmcm/CLKOUT1]
create_generated_clock -name bpClk125MHz [get_pins U_Backplane/U_Clk/U_ClkManagerMps/MmcmGen.U_Mmcm/CLKOUT2]

#  USE_SLOWCLK_G = true (axilClk)
#create_generated_clock -name iprogClk [get_pins {U_Core/U_SysReg/U_Iprog/GEN_ULTRA_SCALE.IprogUltraScale_Inst/BUFGCE_DIV_Inst/O}]]
#create_generated_clock -name dnaClk [get_pins {U_Core/U_SysReg/U_Version/GEN_DEVICE_DNA.DeviceDna_1/GEN_ULTRA_SCALE.DeviceDnaUltraScale_Inst/BUFGCE_DIV_Inst/O}]]
#set_clock_groups -asynchronous -group [get_clocks {axilClk}] -group [get_clocks {iprogClk}]
#set_clock_groups -asynchronous -group [get_clocks {axilClk}] -group [get_clocks {dnaClk}]

set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks timingRef] -group [get_clocks -include_generated_clocks ddrClkIn] -group [get_clocks -include_generated_clocks axilClk] -group [get_clocks -include_generated_clocks fabClk] -group [get_clocks -include_generated_clocks ethRef] -group [get_clocks -include_generated_clocks bpClk] -group [get_clocks -include_generated_clocks amcClk0] -group [get_clocks -include_generated_clocks amcClk1]


set_false_path -to [get_cells -hierarchical -filter {NAME =~ *GEN_ULTRA_SCALE.IprogUltraScale_Inst/RstSync_Inst/syncRst_reg}]
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *GEN_ULTRA_SCALE.IprogUltraScale_Inst/RstSync_Inst/Synchronizer_1/GEN.ASYNC_RST.crossDomainSyncReg_reg[0]}]

####################################################################################
# Constraints from file : 'SaltUltraScaleTxOnly.xdc'
####################################################################################


####################################################################################
# Constraints from file : 'SaltUltraScaleTxOnly.xdc'
####################################################################################


####################################################################################
# Constraints from file : 'SaltUltraScaleTxOnly.xdc'
####################################################################################


####################################################################################
# Constraints from file : 'SaltUltraScaleTxOnly.xdc'
####################################################################################


####################################################################################
# Constraints from file : 'SaltUltraScaleTxOnly.xdc'
####################################################################################


####################################################################################
# Constraints from file : 'SaltUltraScaleTxOnly.xdc'
####################################################################################


####################################################################################
# Constraints from file : 'SaltUltraScaleTxOnly.xdc'
####################################################################################

set_false_path -to [get_cells -hierarchical -filter {NAME =~ *GEN_ULTRA_SCALE.IprogUltraScale_Inst/RstSync_Inst/Synchronizer_1/GEN.ASYNC_RST.crossDomainSyncReg_reg[1]}]

#####
#  Asynchronous reset? (no parallel inputs)
#####
set_false_path -through [get_cells {U_Core/U_ClkAndRst/rstDly_reg[2]}]

#set_property CLOCK_DEDICATED_ROUTE FALSE    [get_nets -hier -filter {NAME =~ *U_DdrMem/refClock}]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets U_Core/U_DdrMem/IBUFDS_Inst/O]
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets -hier -filter {NAME =~ *U_DdrMem/refClkBufg}]

##########################
## Misc. Configurations ##
##########################


set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR Yes [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 1 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE No [current_design]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]


set_property UNAVAILABLE_DURING_CALIBRATION true [get_ports ddrPg]


set_property CLKOUT0_PHASE 0 [get_cells U_Backplane/U_Clk/U_ClkManagerMps/MmcmGen.U_Mmcm]

