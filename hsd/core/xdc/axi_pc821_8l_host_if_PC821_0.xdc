##############################################################################
## This file is part of 'L2SI-CORE'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'L2SI-CORE', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################
###############################################################################
# PC821 lane 3..0 and local sys clock
###############################################################################

###############################################################################
# PCI reset
###############################################################################

#set_false_path -through [get_nets sys_reset_n]
#set_property PACKAGE_PIN AP28 [get_ports sys_reset_n]
#set_property IOSTANDARD LVCMOS18 [get_ports sys_reset_n]
#set_property PULLUP true [get_ports sys_reset_n]

###############################################################################
# PCI reference clock
###############################################################################

#LOCAL_REFCLK0
#set_property PACKAGE_PIN AR9  [get_ports sys_clk_n]
#set_property PACKAGE_PIN AR10 [get_ports sys_clk_p]


###############################################################################
# CPLD Signals
###############################################################################
set_property PACKAGE_PIN AT27 [get_ports {cpld_fpga_bus[0]}]
set_property PACKAGE_PIN AR28 [get_ports {cpld_fpga_bus[1]}]
set_property PACKAGE_PIN AT28 [get_ports {cpld_fpga_bus[2]}]
set_property PACKAGE_PIN BA27 [get_ports {cpld_fpga_bus[3]}]
set_property PACKAGE_PIN BB24 [get_ports {cpld_fpga_bus[4]}]
set_property PACKAGE_PIN AT24 [get_ports {cpld_fpga_bus[5]}]
set_property PACKAGE_PIN AT25 [get_ports {cpld_fpga_bus[6]}]
set_property PACKAGE_PIN AU21 [get_ports {cpld_fpga_bus[7]}]
set_property PACKAGE_PIN AU24 [get_ports {cpld_fpga_bus[8]}]


set_property IOSTANDARD LVCMOS18 [get_ports {cpld_fpga_bus[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {cpld_fpga_bus[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {cpld_fpga_bus[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {cpld_fpga_bus[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {cpld_fpga_bus[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {cpld_fpga_bus[5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {cpld_fpga_bus[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {cpld_fpga_bus[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {cpld_fpga_bus[8]}]

#Local EEPROM Write Protect Signal for Board Info EEPROM (CPLD feeds this directly to EEPROM)
set_property PACKAGE_PIN AV24 [get_ports cpld_eeprom_wp]
set_property IOSTANDARD LVCMOS18 [get_ports cpld_eeprom_wp]

###############################################################################
# Flash programming interface
# NOTE: the STARTUPE3 primitive is used to connect D0 to D3 and FLASH_nCE
# Flash data 11 downto 0 connects to physical pins 15 downto 4
###############################################################################

set_property PACKAGE_PIN AV21 [get_ports flash_noe]
set_property PACKAGE_PIN AV22 [get_ports flash_nwe]

set_property PACKAGE_PIN BA25 [get_ports {flash_address[0]}]
set_property PACKAGE_PIN BB25 [get_ports {flash_address[1]}]
set_property PACKAGE_PIN AY28 [get_ports {flash_address[2]}]
set_property PACKAGE_PIN BA28 [get_ports {flash_address[3]}]
set_property PACKAGE_PIN AY25 [get_ports {flash_address[4]}]
set_property PACKAGE_PIN AY26 [get_ports {flash_address[5]}]
set_property PACKAGE_PIN AW26 [get_ports {flash_address[6]}]
set_property PACKAGE_PIN AY27 [get_ports {flash_address[7]}]
set_property PACKAGE_PIN AW23 [get_ports {flash_address[8]}]
set_property PACKAGE_PIN AY23 [get_ports {flash_address[9]}]
set_property PACKAGE_PIN AW24 [get_ports {flash_address[10]}]
set_property PACKAGE_PIN AW25 [get_ports {flash_address[11]}]
set_property PACKAGE_PIN BB21 [get_ports {flash_address[12]}]
set_property PACKAGE_PIN BB22 [get_ports {flash_address[13]}]
set_property PACKAGE_PIN BA23 [get_ports {flash_address[14]}]
set_property PACKAGE_PIN BA24 [get_ports {flash_address[15]}]
set_property PACKAGE_PIN AW21 [get_ports {flash_address[16]}]
set_property PACKAGE_PIN AY21 [get_ports {flash_address[17]}]
set_property PACKAGE_PIN AY22 [get_ports {flash_address[18]}]
set_property PACKAGE_PIN BA22 [get_ports {flash_address[19]}]
set_property PACKAGE_PIN AT22 [get_ports {flash_address[20]}]
set_property PACKAGE_PIN AT23 [get_ports {flash_address[21]}]
set_property PACKAGE_PIN AR25 [get_ports {flash_address[22]}]
set_property PACKAGE_PIN AR26 [get_ports {flash_address[23]}]
set_property PACKAGE_PIN AU22 [get_ports {flash_address[24]}]
# Flash 25 goes through CPLD for factory save image loading
set_property PACKAGE_PIN AV23 [get_ports {flash_address[25]}]

set_property PACKAGE_PIN AV26 [get_ports {flash_data[4]}]
set_property PACKAGE_PIN AV27 [get_ports {flash_data[5]}]
set_property PACKAGE_PIN AU29 [get_ports {flash_data[6]}]
set_property PACKAGE_PIN AV29 [get_ports {flash_data[7]}]
set_property PACKAGE_PIN AU25 [get_ports {flash_data[8]}]
set_property PACKAGE_PIN AU26 [get_ports {flash_data[9]}]
set_property PACKAGE_PIN AU27 [get_ports {flash_data[10]}]
set_property PACKAGE_PIN AV28 [get_ports {flash_data[11]}]
set_property PACKAGE_PIN BB26 [get_ports {flash_data[12]}]
set_property PACKAGE_PIN BB27 [get_ports {flash_data[13]}]
set_property PACKAGE_PIN AW28 [get_ports {flash_data[14]}]
set_property PACKAGE_PIN AW29 [get_ports {flash_data[15]}]

set_property IOSTANDARD LVCMOS18 [get_ports flash_noe]
set_property IOSTANDARD LVCMOS18 [get_ports flash_nwe]

set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[8]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[9]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[10]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[11]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[12]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[13]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[14]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[15]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[16]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[17]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[18]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[19]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[20]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[21]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[22]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[23]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[24]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address[25]}]

set_property IOSTANDARD LVCMOS18 [get_ports {flash_data[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_data[5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_data[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_data[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_data[8]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_data[9]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_data[10]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_data[11]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_data[12]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_data[13]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_data[14]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_data[15]}]



###############################################################################
# Timing Constraints
###############################################################################
# Constrain Input System Clock.  MMCM outputs (CLK125,CLK250,USERCLK1,USERCLK2) are derived
create_clock -period 10.000 -name sys_clk_p [get_ports sys_clk_p]

###############################################################################
# Configuration settings
###############################################################################



