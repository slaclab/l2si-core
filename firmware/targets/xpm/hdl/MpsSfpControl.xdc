##############################################################################
## This file is part of 'LCLS2 DAQ Software'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'LCLS2 DAQ Software', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
###################
## Carrier Ports ##
###################
set_property PACKAGE_PIN AD15 [get_ports {fpgaclk_N[0]}]
set_property PACKAGE_PIN AD16 [get_ports {fpgaclk_P[0]}]
set_property PACKAGE_PIN AE17 [get_ports {fpgaclk_P[1]}]
set_property PACKAGE_PIN AF17 [get_ports {fpgaclk_N[1]}]
set_property PACKAGE_PIN AE15 [get_ports {fpgaclk_N[2]}]
set_property PACKAGE_PIN AE16 [get_ports {fpgaclk_P[2]}]
set_property PACKAGE_PIN AE18 [get_ports {fpgaclk_P[3]}]
set_property PACKAGE_PIN AF18 [get_ports {fpgaclk_N[3]}]

####################
## AMC Bay0 Ports ##
####################
set_property PACKAGE_PIN AK22 [get_ports {pllRst[0]}]
set_property PACKAGE_PIN AJ21 [get_ports {inc[0]}]
set_property PACKAGE_PIN AH22 [get_ports {dec[0]}]
set_property PACKAGE_PIN AJ23 [get_ports {frqTbl[0]}]
set_property PACKAGE_PIN V26 [get_ports {bypass[0]}]
set_property PACKAGE_PIN V29 [get_ports {rate[0][0]}]
set_property PACKAGE_PIN AH16 [get_ports {rate[0][1]}]
set_property PACKAGE_PIN AH18 [get_ports {sfOut[0][0]}]
set_property PACKAGE_PIN AK17 [get_ports {sfOut[0][1]}]
set_property PACKAGE_PIN AJ18 [get_ports {bwSel[0][0]}]
set_property PACKAGE_PIN U26 [get_ports {bwSel[0][1]}]
set_property PACKAGE_PIN W28 [get_ports {frqSel[0][0]}]
set_property PACKAGE_PIN U24 [get_ports {frqSel[0][1]}]
set_property PACKAGE_PIN V27 [get_ports {frqSel[0][2]}]
set_property PACKAGE_PIN V21 [get_ports {frqSel[0][3]}]
set_property PACKAGE_PIN AN23 [get_ports {lol[0]}]
set_property PACKAGE_PIN AP24 [get_ports {los[0]}]

set_property -dict {PACKAGE_PIN AN8 IOSTANDARD LVCMOS25} [get_ports {hsrScl[0][0]}]
set_property -dict {PACKAGE_PIN AK10 IOSTANDARD LVCMOS25} [get_ports {hsrScl[0][1]}]
set_property -dict {PACKAGE_PIN AN9 IOSTANDARD LVCMOS25} [get_ports {hsrScl[0][2]}]
set_property -dict {PACKAGE_PIN AP8 IOSTANDARD LVCMOS25} [get_ports {hsrSda[0][0]}]
set_property -dict {PACKAGE_PIN AL9 IOSTANDARD LVCMOS25} [get_ports {hsrSda[0][1]}]
set_property -dict {PACKAGE_PIN AJ8 IOSTANDARD LVCMOS25} [get_ports {hsrSda[0][2]}]

####################
## AMC Bay1 Ports ##
####################
set_property PACKAGE_PIN W25 [get_ports {pllRst[1]}]
set_property PACKAGE_PIN W23 [get_ports {inc[1]}]
set_property PACKAGE_PIN AA24 [get_ports {dec[1]}]
set_property PACKAGE_PIN Y23 [get_ports {frqTbl[1]}]
set_property PACKAGE_PIN AA20 [get_ports {bypass[1]}]
set_property PACKAGE_PIN AC22 [get_ports {rate[1][0]}]
set_property PACKAGE_PIN AB30 [get_ports {rate[1][1]}]
set_property PACKAGE_PIN AA32 [get_ports {sfOut[1][0]}]
set_property PACKAGE_PIN AC31 [get_ports {sfOut[1][1]}]
set_property PACKAGE_PIN AD30 [get_ports {bwSel[1][0]}]
set_property PACKAGE_PIN AB25 [get_ports {bwSel[1][1]}]
set_property PACKAGE_PIN AA27 [get_ports {frqSel[1][0]}]
set_property PACKAGE_PIN AC26 [get_ports {frqSel[1][1]}]
set_property PACKAGE_PIN AB24 [get_ports {frqSel[1][2]}]
set_property PACKAGE_PIN AD25 [get_ports {frqSel[1][3]}]
set_property PACKAGE_PIN AM22 [get_ports {lol[1]}]
set_property PACKAGE_PIN AM21 [get_ports {los[1]}]

set_property -dict {PACKAGE_PIN AD9 IOSTANDARD LVCMOS25} [get_ports {hsrScl[1][0]}]
set_property -dict {PACKAGE_PIN AD10 IOSTANDARD LVCMOS25} [get_ports {hsrScl[1][1]}]
set_property -dict {PACKAGE_PIN AE8 IOSTANDARD LVCMOS25} [get_ports {hsrScl[1][2]}]
set_property -dict {PACKAGE_PIN AD8 IOSTANDARD LVCMOS25} [get_ports {hsrSda[1][0]}]
set_property -dict {PACKAGE_PIN AE10 IOSTANDARD LVCMOS25} [get_ports {hsrSda[1][1]}]
set_property -dict {PACKAGE_PIN AH8 IOSTANDARD LVCMOS25} [get_ports {hsrSda[1][2]}]



