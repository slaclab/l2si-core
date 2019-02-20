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

# AMC Bay 1
set_property PACKAGE_PIN M2 [get_ports {dsRxP[1][0]}]
set_property PACKAGE_PIN M1 [get_ports {dsRxN[1][0]}]
set_property PACKAGE_PIN N4 [get_ports {dsTxP[1][0]}]
set_property PACKAGE_PIN N3 [get_ports {dsTxN[1][0]}]
set_property PACKAGE_PIN K2 [get_ports {dsRxP[1][1]}]
set_property PACKAGE_PIN K1 [get_ports {dsRxN[1][1]}]
set_property PACKAGE_PIN L4 [get_ports {dsTxP[1][1]}]
set_property PACKAGE_PIN L3 [get_ports {dsTxN[1][1]}]
set_property PACKAGE_PIN H2 [get_ports {dsRxP[1][2]}]
set_property PACKAGE_PIN H1 [get_ports {dsRxN[1][2]}]
set_property PACKAGE_PIN J4 [get_ports {dsTxP[1][2]}]
set_property PACKAGE_PIN J3 [get_ports {dsTxN[1][2]}]
set_property PACKAGE_PIN F2 [get_ports {dsRxP[1][3]}]
set_property PACKAGE_PIN F1 [get_ports {dsRxN[1][3]}]
set_property PACKAGE_PIN G4 [get_ports {dsTxP[1][3]}]
set_property PACKAGE_PIN G3 [get_ports {dsTxN[1][3]}]
set_property PACKAGE_PIN E4 [get_ports {dsRxP[1][4]}]
set_property PACKAGE_PIN E3 [get_ports {dsRxN[1][4]}]
set_property PACKAGE_PIN F6 [get_ports {dsTxP[1][4]}]
set_property PACKAGE_PIN F5 [get_ports {dsTxN[1][4]}]
set_property PACKAGE_PIN D2 [get_ports {dsRxP[1][5]}]
set_property PACKAGE_PIN D1 [get_ports {dsRxN[1][5]}]
set_property PACKAGE_PIN D6 [get_ports {dsTxP[1][5]}]
set_property PACKAGE_PIN D5 [get_ports {dsTxN[1][5]}]
set_property PACKAGE_PIN B2 [get_ports {dsRxP[1][6]}]
set_property PACKAGE_PIN B1 [get_ports {dsRxN[1][6]}]
set_property PACKAGE_PIN C4 [get_ports {dsTxP[1][6]}]
set_property PACKAGE_PIN C3 [get_ports {dsTxN[1][6]}]
# MGTREFCLK1 Bank 228
set_property PACKAGE_PIN H5 [get_ports {dsClkN[1][0]}]
set_property PACKAGE_PIN H6 [get_ports {dsClkP[1][0]}]
# MGTREFCLK1 Bank 128
#set_property PACKAGE_PIN J29  [get_ports {dsClkP[1][1]}]
#set_property PACKAGE_PIN J30  [get_ports {dsClkN[1][1]}]

# AMC Bay 0
set_property PACKAGE_PIN AH2 [get_ports {dsRxP[0][0]}]
set_property PACKAGE_PIN AH1 [get_ports {dsRxN[0][0]}]
set_property PACKAGE_PIN AH6 [get_ports {dsTxP[0][0]}]
set_property PACKAGE_PIN AH5 [get_ports {dsTxN[0][0]}]
set_property PACKAGE_PIN AF2 [get_ports {dsRxP[0][1]}]
set_property PACKAGE_PIN AF1 [get_ports {dsRxN[0][1]}]
set_property PACKAGE_PIN AG4 [get_ports {dsTxP[0][1]}]
set_property PACKAGE_PIN AG3 [get_ports {dsTxN[0][1]}]
set_property PACKAGE_PIN AD2 [get_ports {dsRxP[0][2]}]
set_property PACKAGE_PIN AD1 [get_ports {dsRxN[0][2]}]
set_property PACKAGE_PIN AE4 [get_ports {dsTxP[0][2]}]
set_property PACKAGE_PIN AE3 [get_ports {dsTxN[0][2]}]
set_property PACKAGE_PIN AB2 [get_ports {dsRxP[0][3]}]
set_property PACKAGE_PIN AB1 [get_ports {dsRxN[0][3]}]
set_property PACKAGE_PIN AC4 [get_ports {dsTxP[0][3]}]
set_property PACKAGE_PIN AC3 [get_ports {dsTxN[0][3]}]
set_property PACKAGE_PIN AP2 [get_ports {dsRxP[0][4]}]
set_property PACKAGE_PIN AP1 [get_ports {dsRxN[0][4]}]
set_property PACKAGE_PIN AN4 [get_ports {dsTxP[0][4]}]
set_property PACKAGE_PIN AN3 [get_ports {dsTxN[0][4]}]
set_property PACKAGE_PIN AM2 [get_ports {dsRxP[0][5]}]
set_property PACKAGE_PIN AM1 [get_ports {dsRxN[0][5]}]
set_property PACKAGE_PIN AM6 [get_ports {dsTxP[0][5]}]
set_property PACKAGE_PIN AM5 [get_ports {dsTxN[0][5]}]
set_property PACKAGE_PIN AK2 [get_ports {dsRxP[0][6]}]
set_property PACKAGE_PIN AK1 [get_ports {dsRxN[0][6]}]
set_property PACKAGE_PIN AL4 [get_ports {dsTxP[0][6]}]
set_property PACKAGE_PIN AL3 [get_ports {dsTxN[0][6]}]
# MGTREFCLK1 Bank 224
set_property PACKAGE_PIN AD5 [get_ports {dsClkN[0][0]}]
set_property PACKAGE_PIN AD6 [get_ports {dsClkP[0][0]}]
# MGTREFCLK1 Bank 127
#set_property PACKAGE_PIN N29  [get_ports {dsClkP[0][1]}]
#set_property PACKAGE_PIN N30  [get_ports {dsClkN[0][1]}]

# Backplane BP Ports
#  Change from TERM_NONE to TERM_100
set_property -dict {PACKAGE_PIN AD19 IOSTANDARD LVDS} [get_ports {bpBusRxP[1]}]
set_property -dict {PACKAGE_PIN AD18 IOSTANDARD LVDS} [get_ports {bpBusRxN[1]}]
set_property -dict {PACKAGE_PIN AG15 IOSTANDARD LVDS} [get_ports {bpBusRxP[2]}]
set_property -dict {PACKAGE_PIN AG14 IOSTANDARD LVDS} [get_ports {bpBusRxN[2]}]
set_property -dict {PACKAGE_PIN AG19 IOSTANDARD LVDS} [get_ports {bpBusRxP[3]}]
set_property -dict {PACKAGE_PIN AH19 IOSTANDARD LVDS} [get_ports {bpBusRxN[3]}]
set_property -dict {PACKAGE_PIN AJ15 IOSTANDARD LVDS} [get_ports {bpBusRxP[4]}]
set_property -dict {PACKAGE_PIN AJ14 IOSTANDARD LVDS} [get_ports {bpBusRxN[4]}]
set_property -dict {PACKAGE_PIN AG17 IOSTANDARD LVDS} [get_ports {bpBusRxP[5]}]
set_property -dict {PACKAGE_PIN AG16 IOSTANDARD LVDS} [get_ports {bpBusRxN[5]}]
set_property -dict {PACKAGE_PIN AL18 IOSTANDARD LVDS} [get_ports {bpBusRxP[6]}]
set_property -dict {PACKAGE_PIN AL17 IOSTANDARD LVDS} [get_ports {bpBusRxN[6]}]
set_property -dict {PACKAGE_PIN AK15 IOSTANDARD LVDS} [get_ports {bpBusRxP[7]}]
set_property -dict {PACKAGE_PIN AL15 IOSTANDARD LVDS} [get_ports {bpBusRxN[7]}]
set_property -dict {PACKAGE_PIN AL19 IOSTANDARD LVDS} [get_ports {bpBusRxP[8]}]
set_property -dict {PACKAGE_PIN AM19 IOSTANDARD LVDS} [get_ports {bpBusRxN[8]}]
set_property -dict {PACKAGE_PIN AL14 IOSTANDARD LVDS} [get_ports {bpBusRxP[9]}]
set_property -dict {PACKAGE_PIN AM14 IOSTANDARD LVDS} [get_ports {bpBusRxN[9]}]
set_property -dict {PACKAGE_PIN AP16 IOSTANDARD LVDS} [get_ports {bpBusRxP[10]}]
set_property -dict {PACKAGE_PIN AP15 IOSTANDARD LVDS} [get_ports {bpBusRxN[10]}]
set_property -dict {PACKAGE_PIN AM16 IOSTANDARD LVDS} [get_ports {bpBusRxP[11]}]
set_property -dict {PACKAGE_PIN AM15 IOSTANDARD LVDS} [get_ports {bpBusRxN[11]}]
set_property -dict {PACKAGE_PIN AN18 IOSTANDARD LVDS} [get_ports {bpBusRxP[12]}]
set_property -dict {PACKAGE_PIN AN17 IOSTANDARD LVDS} [get_ports {bpBusRxN[12]}]
set_property -dict {PACKAGE_PIN AM17 IOSTANDARD LVDS} [get_ports {bpBusRxP[13]}]
set_property -dict {PACKAGE_PIN AN16 IOSTANDARD LVDS} [get_ports {bpBusRxN[13]}]
set_property -dict {PACKAGE_PIN AN19 IOSTANDARD LVDS} [get_ports {bpBusRxP[14]}]
set_property -dict {PACKAGE_PIN AP18 IOSTANDARD LVDS} [get_ports {bpBusRxN[14]}]

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


set_property -dict {PACKAGE_PIN A4} [get_ports usRxP]
set_property -dict {PACKAGE_PIN A3} [get_ports usRxN]
set_property -dict {PACKAGE_PIN B6} [get_ports usTxP]
set_property -dict {PACKAGE_PIN B5} [get_ports usTxN]
set_property -dict {PACKAGE_PIN P6} [get_ports usClkP]
set_property -dict {PACKAGE_PIN P5} [get_ports usClkN]

set_property -dict {IOSTANDARD LVDS_25} [get_ports {rtmLsP[32]}]
set_property -dict {IOSTANDARD LVDS_25} [get_ports {rtmLsN[32]}]

set_property -dict {IOSTANDARD LVDS_25} [get_ports {rtmLsP[33]}]
set_property -dict {IOSTANDARD LVDS_25} [get_ports {rtmLsN[33]}]

set_property -dict {IOSTANDARD LVDS_25} [get_ports {rtmLsP[34]}]
set_property -dict {IOSTANDARD LVDS_25} [get_ports {rtmLsN[34]}]

set_property -dict {IOSTANDARD LVDS_25} [get_ports {rtmLsP[35]}]
set_property -dict {IOSTANDARD LVDS_25} [get_ports {rtmLsN[35]}]

####################################
## Application Timing Constraints ##
####################################

#create_clock -name ddrClkIn   -period  5.000  [get_pins -hier -filter {NAME =~ *U_DdrMem/BUFG_Inst/O}]
create_clock -period 6.400 -name fabClk [get_ports fabClkP]
create_clock -period 6.400 -name ethRef [get_ports ethClkP]
#create_clock -name timingRef  -period  2.691  [get_ports {timingRefClkInP}]

create_generated_clock -name axilClk [get_pins U_Base/U_Core/U_ClkAndRst/U_ClkManagerMps/MmcmGen.U_Mmcm/CLKOUT2]
create_generated_clock -name ddrIntClk0   [get_pins -hier -filter {NAME =~ *U_DdrMem/MigCore_Inst/inst/u_ddr3_infrastructure/gen_mmcme3.u_mmcme_adv_inst/CLKOUT0}]
create_generated_clock -name ddrIntClk1   [get_pins -hier -filter {NAME =~ *U_DdrMem/MigCore_Inst/inst/u_ddr3_infrastructure/gen_mmcme3.u_mmcme_adv_inst/CLKOUT6}]
create_generated_clock -name recTimingClk [get_pins -hier -filter {NAME =~ *U_Core/TimingGtCoreWrapper_1/LOCREF_G.U_TimingGthCore/*/RXOUTCLK}]

create_clock -period 2.691 -name timingRef [get_ports usClkP]
create_clock -period 5.382 -name dsClk0 [get_ports {dsClkP[0]}]
create_clock -period 5.382 -name dsClk1 [get_ports {dsClkP[1]}]
create_clock -period 6.400 -name fabClk [get_ports fabClkP]
create_clock -period 5.000 -name ddrClkIn [get_ports ddrClkP]

create_generated_clock -name bpClk625MHz [get_pins U_Base/U_Backplane/U_Clk/U_ClkManagerMps/MmcmGen.U_Mmcm/CLKOUT0]
create_generated_clock -name bpClk312MHz [get_pins U_Base/U_Backplane/U_Clk/U_ClkManagerMps/MmcmGen.U_Mmcm/CLKOUT1]
create_generated_clock -name bpClk125MHz [get_pins U_Base/U_Backplane/U_Clk/U_ClkManagerMps/MmcmGen.U_Mmcm/CLKOUT2]

set_clock_groups -asynchronous \
                 -group [get_clocks -include_generated_clocks timingRef] \
                 -group [get_clocks -include_generated_clocks ddrClkIn] \
                 -group [get_clocks -include_generated_clocks fabClk] \
                 -group [get_clocks -include_generated_clocks axilClk] \
                 -group [get_clocks -include_generated_clocks ethRef] \
                 -group [get_clocks -include_generated_clocks dsClk0] \
                 -group [get_clocks -include_generated_clocks dsClk1]

set_clock_groups -asynchronous -group [get_clocks fabClk] -group [get_clocks bpClk125MHz]
set_clock_groups -asynchronous -group [get_clocks fabClk] -group [get_clocks bpClk312MHz]
set_clock_groups -asynchronous -group [get_clocks fabClk] -group [get_clocks bpClk625MHz]

create_generated_clock -name timingPhyClk [get_pins U_Base/U_Core/TimingGtCoreWrapper_1/LOCREF_G.TIMING_TXCLK_BUFG_GT/O]
create_generated_clock -name iusRefClk [get_pins U_Base/U_Core/TIMING_REFCLK_IBUFDS_GTE3/ODIV2]

set_clock_groups -asynchronous \
                 -group [get_clocks timingPhyClk] \
                 -group [get_clocks recTimingClk]

set_clock_groups -asynchronous \
                 -group [get_clocks [get_clocks -of_objects [get_pins {U_Base/U_Core/TimingGtCoreWrapper_1/LOCREF_G.U_TimingGthCore/inst/gen_gtwizard_gthe3_top.TimingGth_fixedlat_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[0].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST/RXOUTCLK}]]] \
                 -group [get_clocks timingPhyClk]

set_false_path -to [get_cells -hierarchical -filter {NAME =~ *GEN_ULTRA_SCALE.IprogUltraScale_Inst/RstSync_Inst/syncRst_reg}]
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *GEN_ULTRA_SCALE.IprogUltraScale_Inst/RstSync_Inst/Synchronizer_1/GEN.ASYNC_RST.crossDomainSyncReg_reg[0]}]
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *GEN_ULTRA_SCALE.IprogUltraScale_Inst/RstSync_Inst/Synchronizer_1/GEN.ASYNC_RST.crossDomainSyncReg_reg[1]}]

set_false_path -to [get_cells -hierarchical -filter {NAME =~ *RX_ENABLE.SaltRx_Inst/FIFO_TX/U_Fifo/U_Fifo/ONE_STAGE.Fifo_1xStage/NON_BUILT_IN_GEN.FIFO_ASYNC_Gen.FifoAsync_Inst/READ_RstSync/syncRst_reg}]
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *RX_ENABLE.SaltRx_Inst/FIFO_TX/U_Fifo/U_Fifo/ONE_STAGE.Fifo_1xStage/NON_BUILT_IN_GEN.FIFO_ASYNC_Gen.FifoAsync_Inst/READ_RstSync/Synchronizer_1/GEN.ASYNC_RST.crossDomainSyncReg_reg[0]}]
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *RX_ENABLE.SaltRx_Inst/FIFO_TX/U_Fifo/U_Fifo/ONE_STAGE.Fifo_1xStage/NON_BUILT_IN_GEN.FIFO_ASYNC_Gen.FifoAsync_Inst/READ_RstSync/Synchronizer_1/GEN.ASYNC_RST.crossDomainSyncReg_reg[1]}]

#set_property CLOCK_DEDICATED_ROUTE FALSE    [get_nets -hier -filter {NAME =~ *U_DdrMem/refClock}]
set_property CLOCK_DEDICATED_ROUTE FALSE    [get_nets U_Base/U_Core/U_DdrMem/IBUFDS_Inst/O]
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


set_property UNAVAILABLE_DURING_CALIBRATION TRUE [get_ports {ddrPg}]


