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
set_property PACKAGE_PIN AH6 [get_ports {amcTxP[0][0]}]
set_property PACKAGE_PIN AH5 [get_ports {amcTxN[0][0]}]
set_property PACKAGE_PIN AH2 [get_ports {amcRxP[0][0]}]
set_property PACKAGE_PIN AH1 [get_ports {amcRxN[0][0]}]
set_property PACKAGE_PIN AG4 [get_ports {amcTxP[0][1]}]
set_property PACKAGE_PIN AG3 [get_ports {amcTxN[0][1]}]
set_property PACKAGE_PIN AF2 [get_ports {amcRxP[0][1]}]
set_property PACKAGE_PIN AF1 [get_ports {amcRxN[0][1]}]
set_property PACKAGE_PIN AE4 [get_ports {amcTxP[0][2]}]
set_property PACKAGE_PIN AE3 [get_ports {amcTxN[0][2]}]
set_property PACKAGE_PIN AD2 [get_ports {amcRxP[0][2]}]
set_property PACKAGE_PIN AD1 [get_ports {amcRxN[0][2]}]
set_property PACKAGE_PIN AC4 [get_ports {amcTxP[0][3]}]
set_property PACKAGE_PIN AC3 [get_ports {amcTxN[0][3]}]
set_property PACKAGE_PIN AB2 [get_ports {amcRxP[0][3]}]
set_property PACKAGE_PIN AB1 [get_ports {amcRxN[0][3]}]
set_property PACKAGE_PIN AN4 [get_ports {amcTxP[0][4]}]
set_property PACKAGE_PIN AN3 [get_ports {amcTxN[0][4]}]
set_property PACKAGE_PIN AP2 [get_ports {amcRxP[0][4]}]
set_property PACKAGE_PIN AP1 [get_ports {amcRxN[0][4]}]
set_property PACKAGE_PIN AM6 [get_ports {amcTxP[0][5]}]
set_property PACKAGE_PIN AM5 [get_ports {amcTxN[0][5]}]
set_property PACKAGE_PIN AM2 [get_ports {amcRxP[0][5]}]
set_property PACKAGE_PIN AM1 [get_ports {amcRxN[0][5]}]
set_property PACKAGE_PIN AL4 [get_ports {amcTxP[0][6]}]
set_property PACKAGE_PIN AL3 [get_ports {amcTxN[0][6]}]
set_property PACKAGE_PIN AK2 [get_ports {amcRxP[0][6]}]
set_property PACKAGE_PIN AK1 [get_ports {amcRxN[0][6]}]
# MGTREFCLK1 Bank 224
set_property PACKAGE_PIN AD6  [get_ports {amcClkP[0][0]}]
set_property PACKAGE_PIN AD5  [get_ports {amcClkN[0][0]}]
# MGTREFCLK1 Bank 127
#set_property PACKAGE_PIN N29  [get_ports {amcClkP[0][1]}]
#set_property PACKAGE_PIN N30  [get_ports {amcClkN[0][1]}]

set_property PACKAGE_PIN AK22  [get_ports {pllRst[0]}]  
set_property PACKAGE_PIN AJ21  [get_ports {inc[0]}]     
set_property PACKAGE_PIN AH22  [get_ports {dec[0]}]     
set_property PACKAGE_PIN AJ23  [get_ports {frqTbl[0]}]  
set_property PACKAGE_PIN V26   [get_ports {bypass[0]}]  
set_property PACKAGE_PIN V29   [get_ports {rate[0][0]}]    
set_property PACKAGE_PIN AH16  [get_ports {rate[0][1]}]    
set_property PACKAGE_PIN AH18  [get_ports {sfOut[0][0]}]   
set_property PACKAGE_PIN AK17  [get_ports {sfOut[0][1]}]   
set_property PACKAGE_PIN AJ18  [get_ports {bwSel[0][0]}]   
set_property PACKAGE_PIN U26   [get_ports {bwSel[0][1]}]   
set_property PACKAGE_PIN W28   [get_ports {frqSel[0][0]}]  
set_property PACKAGE_PIN U24   [get_ports {frqSel[0][1]}]  
set_property PACKAGE_PIN V27   [get_ports {frqSel[0][2]}]  
set_property PACKAGE_PIN V21   [get_ports {frqSel[0][3]}]  
set_property PACKAGE_PIN AN23  [get_ports {lol[0]}]     
set_property PACKAGE_PIN AP24  [get_ports {los[0]}]     


# AMC Bay 1
set_property PACKAGE_PIN N4  [get_ports {amcTxP[1][0]}]
set_property PACKAGE_PIN N3  [get_ports {amcTxN[1][0]}]
set_property PACKAGE_PIN M2  [get_ports {amcRxP[1][0]}]
set_property PACKAGE_PIN M1  [get_ports {amcRxN[1][0]}]
set_property PACKAGE_PIN L4  [get_ports {amcTxP[1][1]}]
set_property PACKAGE_PIN L3  [get_ports {amcTxN[1][1]}]
set_property PACKAGE_PIN K2  [get_ports {amcRxP[1][1]}]
set_property PACKAGE_PIN K1  [get_ports {amcRxN[1][1]}]
set_property PACKAGE_PIN J4  [get_ports {amcTxP[1][2]}]
set_property PACKAGE_PIN J3  [get_ports {amcTxN[1][2]}]
set_property PACKAGE_PIN H2  [get_ports {amcRxP[1][2]}]
set_property PACKAGE_PIN H1  [get_ports {amcRxN[1][2]}]
set_property PACKAGE_PIN G4  [get_ports {amcTxP[1][3]}]
set_property PACKAGE_PIN G3  [get_ports {amcTxN[1][3]}]
set_property PACKAGE_PIN F2  [get_ports {amcRxP[1][3]}]
set_property PACKAGE_PIN F1  [get_ports {amcRxN[1][3]}]
set_property PACKAGE_PIN F6  [get_ports {amcTxP[1][4]}]
set_property PACKAGE_PIN F5  [get_ports {amcTxN[1][4]}]
set_property PACKAGE_PIN E4  [get_ports {amcRxP[1][4]}]
set_property PACKAGE_PIN E3  [get_ports {amcRxN[1][4]}]
set_property PACKAGE_PIN D6  [get_ports {amcTxP[1][5]}]
set_property PACKAGE_PIN D5  [get_ports {amcTxN[1][5]}]
set_property PACKAGE_PIN D2  [get_ports {amcRxP[1][5]}]
set_property PACKAGE_PIN D1  [get_ports {amcRxN[1][5]}]
set_property PACKAGE_PIN C4  [get_ports {amcTxP[1][6]}]
set_property PACKAGE_PIN C3  [get_ports {amcTxN[1][6]}]
set_property PACKAGE_PIN B2  [get_ports {amcRxP[1][6]}]
set_property PACKAGE_PIN B1  [get_ports {amcRxN[1][6]}]
# MGTREFCLK1 Bank 228
set_property PACKAGE_PIN H6   [get_ports {amcClkP[1][0]}]
set_property PACKAGE_PIN H5   [get_ports {amcClkN[1][0]}]
# MGTREFCLK1 Bank 128
#set_property PACKAGE_PIN J29  [get_ports {amcClkP[1][1]}]
#set_property PACKAGE_PIN J30  [get_ports {amcClkN[1][1]}]

set_property PACKAGE_PIN W25   [get_ports {pllRst[1]}]
set_property PACKAGE_PIN W23   [get_ports {inc[1]}]
set_property PACKAGE_PIN AA24  [get_ports {dec[1]}]
set_property PACKAGE_PIN Y23   [get_ports {frqTbl[1]}]
set_property PACKAGE_PIN AA20  [get_ports {bypass[1]}]
set_property PACKAGE_PIN AC22  [get_ports {rate[1][0]}]
set_property PACKAGE_PIN AB30  [get_ports {rate[1][1]}]
set_property PACKAGE_PIN AA32  [get_ports {sfOut[1][0]}]
set_property PACKAGE_PIN AC31  [get_ports {sfOut[1][1]}]
set_property PACKAGE_PIN AD30  [get_ports {bwSel[1][0]}]
set_property PACKAGE_PIN AB25  [get_ports {bwSel[1][1]}]
set_property PACKAGE_PIN AA27  [get_ports {frqSel[1][0]}]
set_property PACKAGE_PIN AC26  [get_ports {frqSel[1][1]}]
set_property PACKAGE_PIN AB24  [get_ports {frqSel[1][2]}]
set_property PACKAGE_PIN AD25  [get_ports {frqSel[1][3]}]
set_property PACKAGE_PIN AM22  [get_ports {lol[1]}]
set_property PACKAGE_PIN AM21  [get_ports {los[1]}]




set_property PACKAGE_PIN AD16 [get_ports {fpgaclk_P}]
set_property PACKAGE_PIN AD15 [get_ports {fpgaclk_N}]


# Backplane BP Ports
set_property -dict { PACKAGE_PIN AD19 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxP[1]}]
set_property -dict { PACKAGE_PIN AD18 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxN[1]}]
set_property -dict { PACKAGE_PIN AG15 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxP[2]}]
set_property -dict { PACKAGE_PIN AG14 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxN[2]}]
set_property -dict { PACKAGE_PIN AG19 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxP[3]}]
set_property -dict { PACKAGE_PIN AH19 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxN[3]}]
set_property -dict { PACKAGE_PIN AJ15 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxP[4]}]
set_property -dict { PACKAGE_PIN AJ14 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxN[4]}]
set_property -dict { PACKAGE_PIN AG17 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxP[5]}]
set_property -dict { PACKAGE_PIN AG16 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxN[5]}]
set_property -dict { PACKAGE_PIN AL18 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxP[6]}]
set_property -dict { PACKAGE_PIN AL17 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxN[6]}]
set_property -dict { PACKAGE_PIN AK15 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxP[7]}]
set_property -dict { PACKAGE_PIN AL15 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxN[7]}]
set_property -dict { PACKAGE_PIN AL19 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxP[8]}]
set_property -dict { PACKAGE_PIN AM19 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxN[8]}]
set_property -dict { PACKAGE_PIN AL14 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxP[9]}]
set_property -dict { PACKAGE_PIN AM14 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxN[9]}]
set_property -dict { PACKAGE_PIN AP16 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxP[10]}]
set_property -dict { PACKAGE_PIN AP15 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxN[10]}]
set_property -dict { PACKAGE_PIN AM16 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxP[11]}]
set_property -dict { PACKAGE_PIN AM15 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxN[11]}]
set_property -dict { PACKAGE_PIN AN18 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxP[12]}]
set_property -dict { PACKAGE_PIN AN17 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxN[12]}]
set_property -dict { PACKAGE_PIN AM17 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxP[13]}]
set_property -dict { PACKAGE_PIN AN16 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxN[13]}]
set_property -dict { PACKAGE_PIN AN19 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxP[14]}]
set_property -dict { PACKAGE_PIN AP18 IOSTANDARD LVDS DIFF_TERM_ADV TERM_NONE } [get_ports {bpRxN[14]}]

set_property -dict { PACKAGE_PIN AF10 IOSTANDARD LVCMOS25 }           [get_ports {bpClkIn}]
set_property -dict { PACKAGE_PIN AG10 IOSTANDARD LVCMOS25 SLEW FAST } [get_ports {bpClkOut}]

# LCLS Timing Ports
set_property -dict { PACKAGE_PIN AE11 IOSTANDARD LVCMOS25 } [get_ports {timingClkScl}]
set_property -dict { PACKAGE_PIN AD11 IOSTANDARD LVCMOS25 } [get_ports {timingClkSda}]

# Crossbar Ports
set_property -dict { PACKAGE_PIN AF13 IOSTANDARD LVCMOS25 } [get_ports {xBarSin[0]}] 
set_property -dict { PACKAGE_PIN AK13 IOSTANDARD LVCMOS25 } [get_ports {xBarSin[1]}] 
set_property -dict { PACKAGE_PIN AL13 IOSTANDARD LVCMOS25 } [get_ports {xBarSout[0]}] 
set_property -dict { PACKAGE_PIN AK12 IOSTANDARD LVCMOS25 } [get_ports {xBarSout[1]}] 
set_property -dict { PACKAGE_PIN AL12 IOSTANDARD LVCMOS25 } [get_ports {xBarConfig}] 
set_property -dict { PACKAGE_PIN AK11 IOSTANDARD LVCMOS25 } [get_ports {xBarLoad}] 
# IPMC Ports
set_property -dict { PACKAGE_PIN AE12 IOSTANDARD LVCMOS25 } [get_ports {ipmcScl}]
set_property -dict { PACKAGE_PIN AF12 IOSTANDARD LVCMOS25 } [get_ports {ipmcSda}]

# Configuration PROM Ports
set_property -dict { PACKAGE_PIN N27 IOSTANDARD LVCMOS25 } [get_ports {calScl}]
set_property -dict { PACKAGE_PIN N23 IOSTANDARD LVCMOS25 } [get_ports {calSda}]

# DDR3L SO-DIMM Ports
set_property -dict { PACKAGE_PIN L19 IOSTANDARD LVCMOS15 } [get_ports {ddrScl}] 
set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS15 } [get_ports {ddrSda}] 


####################################
## Application Timing Constraints ##
####################################

#create_clock -name ddrClkIn   -period  5.000  [get_pins -hier -filter {NAME =~ *U_DdrMem/BUFG_Inst/O}]
create_clock -name fabClk     -period  6.400  [get_ports {fabClkP}]
create_clock -name ethRef     -period  6.400  [get_ports {ethClkP}]
#create_clock -name timingRef  -period  2.691  [get_ports {timingRefClkInP}]

create_generated_clock -name axilClk      [get_pins {U_Core/U_ClkAndRst/U_ClkManagerMps/MmcmGen.U_Mmcm/CLKOUT2}] 
create_generated_clock -name ddrIntClk0   [get_pins -hier -filter {NAME =~ *U_DdrMem/MigCore_Inst/inst/u_ddr3_infrastructure/gen_mmcme3.u_mmcme_adv_inst/CLKOUT0}]
create_generated_clock -name ddrIntClk1   [get_pins -hier -filter {NAME =~ *U_DdrMem/MigCore_Inst/inst/u_ddr3_infrastructure/gen_mmcme3.u_mmcme_adv_inst/CLKOUT6}]
create_generated_clock -name recTimingClk [get_pins -hier -filter {NAME =~ *U_Timing/TimingGthCoreWrapper_1/LOCREF_G.U_TimingGthCore/*/RXOUTCLK}]   

create_clock -period 5.382 -name amcClk0  [get_ports amcClkP[0]]
create_clock -period 5.382 -name amcClk1  [get_ports amcClkP[1]]
create_clock -period 6.400 -name fabClk   [get_ports fabClkP]
create_clock -period 5.000 -name ddrClkIn [get_ports ddrClkP]
create_clock -period 8.000 -name bpClk    [get_ports bpClkIn]

create_generated_clock -name bpClk625MHz  [get_pins {U_Backplane/U_Clk/U_ClkManagerMps/MmcmGen.U_Mmcm/CLKOUT0}] 
create_generated_clock -name bpClk312MHz  [get_pins {U_Backplane/U_Clk/U_ClkManagerMps/MmcmGen.U_Mmcm/CLKOUT1}] 
create_generated_clock -name bpClk125MHz  [get_pins {U_Backplane/U_Clk/U_ClkManagerMps/MmcmGen.U_Mmcm/CLKOUT2}] 

#  USE_SLOWCLK_G = true (axilClk)
#create_generated_clock -name iprogClk [get_pins {U_Core/U_SysReg/U_Iprog/GEN_ULTRA_SCALE.IprogUltraScale_Inst/BUFGCE_DIV_Inst/O}]]
#create_generated_clock -name dnaClk [get_pins {U_Core/U_SysReg/U_Version/GEN_DEVICE_DNA.DeviceDna_1/GEN_ULTRA_SCALE.DeviceDnaUltraScale_Inst/BUFGCE_DIV_Inst/O}]]
#set_clock_groups -asynchronous -group [get_clocks {axilClk}] -group [get_clocks {iprogClk}]
#set_clock_groups -asynchronous -group [get_clocks {axilClk}] -group [get_clocks {dnaClk}]

set_clock_groups -asynchronous \
                 -group [get_clocks -include_generated_clocks timingRef] \
                 -group [get_clocks -include_generated_clocks ddrClkIn] \
                 -group [get_clocks -include_generated_clocks fabClk] \
                 -group [get_clocks -include_generated_clocks ethRef] \
                 -group [get_clocks -include_generated_clocks bpClk] \
                 -group [get_clocks -include_generated_clocks amcClk0] \
                 -group [get_clocks -include_generated_clocks amcClk1]

#set_clock_groups -asynchronous \
#                 -group [get_clocks fabClk] \
#                 -group [get_clocks bpClk125MHz]

set_false_path -to [get_cells -hierarchical -filter {NAME =~ *GEN_ULTRA_SCALE.IprogUltraScale_Inst/RstSync_Inst/syncRst_reg}]
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *GEN_ULTRA_SCALE.IprogUltraScale_Inst/RstSync_Inst/Synchronizer_1/GEN.ASYNC_RST.crossDomainSyncReg_reg[0]}]
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *GEN_ULTRA_SCALE.IprogUltraScale_Inst/RstSync_Inst/Synchronizer_1/GEN.ASYNC_RST.crossDomainSyncReg_reg[1]}]

set_false_path -to [get_cells -hierarchical -filter {NAME =~ *RX_ENABLE.SaltRx_Inst/FIFO_TX/U_Fifo/U_Fifo/ONE_STAGE.Fifo_1xStage/NON_BUILT_IN_GEN.FIFO_ASYNC_Gen.FifoAsync_Inst/READ_RstSync/syncRst_reg}]
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *RX_ENABLE.SaltRx_Inst/FIFO_TX/U_Fifo/U_Fifo/ONE_STAGE.Fifo_1xStage/NON_BUILT_IN_GEN.FIFO_ASYNC_Gen.FifoAsync_Inst/READ_RstSync/Synchronizer_1/GEN.ASYNC_RST.crossDomainSyncReg_reg[0]}]
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *RX_ENABLE.SaltRx_Inst/FIFO_TX/U_Fifo/U_Fifo/ONE_STAGE.Fifo_1xStage/NON_BUILT_IN_GEN.FIFO_ASYNC_Gen.FifoAsync_Inst/READ_RstSync/Synchronizer_1/GEN.ASYNC_RST.crossDomainSyncReg_reg[1]}]

#set_property CLOCK_DEDICATED_ROUTE FALSE    [get_nets -hier -filter {NAME =~ *U_DdrMem/refClock}]
set_property CLOCK_DEDICATED_ROUTE FALSE    [get_nets U_Core/U_DdrMem/IBUFDS_Inst/O]
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets -hier -filter {NAME =~ *U_DdrMem/refClkBufg}]

##########################
## Misc. Configurations ##
##########################


set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design] 
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR Yes [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 1 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE No [current_design]

set_property CFGBVS         {VCCO} [current_design]
set_property CONFIG_VOLTAGE {3.3} [current_design]

set_property SEVERITY {Warning} [get_drc_checks {NSTD-1}]
set_property SEVERITY {Warning} [get_drc_checks {UCIO-1}]

set_property UNAVAILABLE_DURING_CALIBRATION TRUE [get_ports {ddrPg}]
