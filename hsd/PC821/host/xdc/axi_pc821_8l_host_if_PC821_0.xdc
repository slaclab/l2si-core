###############################################################################
# PC821 lane 3..0 and local sys clock
###############################################################################

###############################################################################
# PCI reset
###############################################################################

set_false_path -through [get_nets sys_reset_n_0]
set_property PACKAGE_PIN AP28 [get_ports sys_reset_n_0]
set_property IOSTANDARD LVCMOS18 [get_ports sys_reset_n_0]
set_property PULLUP true [get_ports sys_reset_n_0]

###############################################################################
# PCI reference clock
###############################################################################

#LOCAL_REFCLK0
set_property PACKAGE_PIN AR9  [get_ports sys_clk_n_0]
set_property PACKAGE_PIN AR10 [get_ports sys_clk_p_0]


###############################################################################
# CPLD Signals
###############################################################################
set_property PACKAGE_PIN AT27 [get_ports {cpld_fpga_bus_0[0]}]
set_property PACKAGE_PIN AR28 [get_ports {cpld_fpga_bus_0[1]}]
set_property PACKAGE_PIN AT28 [get_ports {cpld_fpga_bus_0[2]}]
set_property PACKAGE_PIN BA27 [get_ports {cpld_fpga_bus_0[3]}]
set_property PACKAGE_PIN BB24 [get_ports {cpld_fpga_bus_0[4]}]
set_property PACKAGE_PIN AT24 [get_ports {cpld_fpga_bus_0[5]}]
set_property PACKAGE_PIN AT25 [get_ports {cpld_fpga_bus_0[6]}]
set_property PACKAGE_PIN AU21 [get_ports {cpld_fpga_bus_0[7]}]
set_property PACKAGE_PIN AU24 [get_ports {cpld_fpga_bus_0[8]}]


set_property IOSTANDARD LVCMOS18 [get_ports {cpld_fpga_bus_0[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {cpld_fpga_bus_0[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {cpld_fpga_bus_0[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {cpld_fpga_bus_0[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {cpld_fpga_bus_0[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {cpld_fpga_bus_0[5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {cpld_fpga_bus_0[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {cpld_fpga_bus_0[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {cpld_fpga_bus_0[8]}]

#Local EEPROM Write Protect Signal for Board Info EEPROM (CPLD feeds this directly to EEPROM)
set_property PACKAGE_PIN AV24 [get_ports cpld_eeprom_wp_0]
set_property IOSTANDARD LVCMOS18 [get_ports cpld_eeprom_wp_0]

###############################################################################
# Flash programming interface
# NOTE: the STARTUPE3 primitive is used to connect D0 to D3 and FLASH_nCE
# Flash data 11 downto 0 connects to physical pins 15 downto 4
###############################################################################

set_property PACKAGE_PIN AV21 [get_ports flash_noe_0]
set_property PACKAGE_PIN AV22 [get_ports flash_nwe_0]

set_property PACKAGE_PIN BA25 [get_ports {flash_address_0[0]}]
set_property PACKAGE_PIN BB25 [get_ports {flash_address_0[1]}]
set_property PACKAGE_PIN AY28 [get_ports {flash_address_0[2]}]
set_property PACKAGE_PIN BA28 [get_ports {flash_address_0[3]}]
set_property PACKAGE_PIN AY25 [get_ports {flash_address_0[4]}]
set_property PACKAGE_PIN AY26 [get_ports {flash_address_0[5]}]
set_property PACKAGE_PIN AW26 [get_ports {flash_address_0[6]}]
set_property PACKAGE_PIN AY27 [get_ports {flash_address_0[7]}]
set_property PACKAGE_PIN AW23 [get_ports {flash_address_0[8]}]
set_property PACKAGE_PIN AY23 [get_ports {flash_address_0[9]}]
set_property PACKAGE_PIN AW24 [get_ports {flash_address_0[10]}]
set_property PACKAGE_PIN AW25 [get_ports {flash_address_0[11]}]
set_property PACKAGE_PIN BB21 [get_ports {flash_address_0[12]}]
set_property PACKAGE_PIN BB22 [get_ports {flash_address_0[13]}]
set_property PACKAGE_PIN BA23 [get_ports {flash_address_0[14]}]
set_property PACKAGE_PIN BA24 [get_ports {flash_address_0[15]}]
set_property PACKAGE_PIN AW21 [get_ports {flash_address_0[16]}]
set_property PACKAGE_PIN AY21 [get_ports {flash_address_0[17]}]
set_property PACKAGE_PIN AY22 [get_ports {flash_address_0[18]}]
set_property PACKAGE_PIN BA22 [get_ports {flash_address_0[19]}]
set_property PACKAGE_PIN AT22 [get_ports {flash_address_0[20]}]
set_property PACKAGE_PIN AT23 [get_ports {flash_address_0[21]}]
set_property PACKAGE_PIN AR25 [get_ports {flash_address_0[22]}]
set_property PACKAGE_PIN AR26 [get_ports {flash_address_0[23]}]
set_property PACKAGE_PIN AU22 [get_ports {flash_address_0[24]}]
# Flash 25 goes through CPLD for factory save image loading
set_property PACKAGE_PIN AV23 [get_ports {flash_address_0[25]}]

set_property PACKAGE_PIN AV26 [get_ports {flash_data_0[0]}]
set_property PACKAGE_PIN AV27 [get_ports {flash_data_0[1]}]
set_property PACKAGE_PIN AU29 [get_ports {flash_data_0[2]}]
set_property PACKAGE_PIN AV29 [get_ports {flash_data_0[3]}]
set_property PACKAGE_PIN AU25 [get_ports {flash_data_0[4]}]
set_property PACKAGE_PIN AU26 [get_ports {flash_data_0[5]}]
set_property PACKAGE_PIN AU27 [get_ports {flash_data_0[6]}]
set_property PACKAGE_PIN AV28 [get_ports {flash_data_0[7]}]
set_property PACKAGE_PIN BB26 [get_ports {flash_data_0[8]}]
set_property PACKAGE_PIN BB27 [get_ports {flash_data_0[9]}]
set_property PACKAGE_PIN AW28 [get_ports {flash_data_0[10]}]
set_property PACKAGE_PIN AW29 [get_ports {flash_data_0[11]}]

set_property IOSTANDARD LVCMOS18 [get_ports flash_noe_0]
set_property IOSTANDARD LVCMOS18 [get_ports flash_nwe_0]

set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[8]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[9]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[10]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[11]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[12]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[13]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[14]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[15]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[16]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[17]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[18]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[19]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[20]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[21]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[22]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[23]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[24]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_address_0[25]}]

set_property IOSTANDARD LVCMOS18 [get_ports {flash_data_0[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_data_0[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_data_0[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_data_0[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_data_0[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_data_0[5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_data_0[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_data_0[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_data_0[8]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_data_0[9]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_data_0[10]}]
set_property IOSTANDARD LVCMOS18 [get_ports {flash_data_0[11]}]



###############################################################################
# Timing Constraints
###############################################################################
# Constrain Input System Clock.  MMCM outputs (CLK125,CLK250,USERCLK1,USERCLK2) are derived
create_clock -period 10.000 -name sys_clk_p [get_ports sys_clk_p_0]

###############################################################################
# Configuration settings
###############################################################################

set_property BITSTREAM.GENERAL.COMPRESS True [current_design]
set_property BITSTREAM.CONFIG.BPI_PAGE_SIZE 8 [current_design]
set_property BITSTREAM.CONFIG.BPI_1ST_READ_CYCLE 3 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 3 [current_design]
set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN DIV-2 [current_design]

set_property CFGBVS GND [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property config_mode B_SCAN [current_design]
set_property config_mode BPI16 [current_design]
