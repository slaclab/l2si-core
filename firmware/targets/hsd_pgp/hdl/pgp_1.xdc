##############################
# StdLib: Custom Constraints #
##############################
#set_property ASYNC_REG TRUE [get_cells -hierarchical *crossDomainSyncReg_reg*]

set_property PACKAGE_PIN H8 [get_ports {pgpTxP[0]}]
set_property PACKAGE_PIN H7 [get_ports {pgpTxN[0]}]
set_property PACKAGE_PIN H4 [get_ports {pgpRxP[0]}]
set_property PACKAGE_PIN H3 [get_ports {pgpRxN[0]}]
set_property PACKAGE_PIN G6 [get_ports {pgpTxP[1]}]
set_property PACKAGE_PIN G5 [get_ports {pgpTxN[1]}]
set_property PACKAGE_PIN G2 [get_ports {pgpRxP[1]}]
set_property PACKAGE_PIN G1 [get_ports {pgpRxN[1]}]
set_property PACKAGE_PIN F8 [get_ports {pgpTxP[2]}]
set_property PACKAGE_PIN F7 [get_ports {pgpTxN[2]}]
set_property PACKAGE_PIN F4 [get_ports {pgpRxP[2]}]
set_property PACKAGE_PIN F3 [get_ports {pgpRxN[2]}]
set_property PACKAGE_PIN E6 [get_ports {pgpTxP[3]}]
set_property PACKAGE_PIN E5 [get_ports {pgpTxN[3]}]
set_property PACKAGE_PIN E2 [get_ports {pgpRxP[3]}]
set_property PACKAGE_PIN E1 [get_ports {pgpRxN[3]}]
set_property PACKAGE_PIN K8 [get_ports {pgpRefClkP}]
set_property PACKAGE_PIN K7 [get_ports {pgpRefClkN}]
set_property PACKAGE_PIN U36 [get_ports {pgpAltClkP}]
set_property PACKAGE_PIN U37 [get_ports {pgpAltClkN}]

set_property PACKAGE_PIN F14 [get_ports {usrClkSel}]
set_property PACKAGE_PIN F13 [get_ports {pgpClkEn}]
set_property PACKAGE_PIN E12 [get_ports {usrClkEn}]
set_property PACKAGE_PIN F12 [get_ports {qsfpRstN}]
set_property PACKAGE_PIN H4  [get_ports {pgpFabClkP}]
set_property PACKAGE_PIN H5  [get_ports {pgpFabClkN}]

######################
# Timing Constraints #
######################

create_clock -name pgpRefClk  -period  6.40 [get_ports pgpRefClkP]
create_clock -name pgpAltClk  -period  6.40 [get_ports pgpAltClkP]
create_clock -name pgpFabClk  -period  6.40 [get_ports pgpFabClkP]

##############################################
# Crossing Domain Clocks: Timing Constraints #
##############################################

create_generated_clock -name pgpClk0 [get_pins {GEN_PGP[0].U_Pgp/U_Pgp2b/U_BUFG/O}]
create_generated_clock -name pgpClk1 [get_pins {GEN_PGP[1].U_Pgp/U_Pgp2b/U_BUFG/O}]
create_generated_clock -name pgpClk2 [get_pins {GEN_PGP[2].U_Pgp/U_Pgp2b/U_BUFG/O}]
create_generated_clock -name pgpClk3 [get_pins {GEN_PGP[3].U_Pgp/U_Pgp2b/U_BUFG/O}]

set_clock_groups -asynchronous   -group [get_clocks {pgpClk*}] \
                                 -group [get_clocks {pciClk}] \

                                 
