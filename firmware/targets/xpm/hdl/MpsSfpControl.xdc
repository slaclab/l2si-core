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
set_property -dict { PACKAGE_PIN AD16 IOSTANDARD DIFF_HSTL_I_18 } [get_ports {fpgaclk0_P}]
set_property -dict { PACKAGE_PIN AD15 IOSTANDARD DIFF_HSTL_I_18 } [get_ports {fpgaclk0_N}]
set_property -dict { PACKAGE_PIN AE16 IOSTANDARD DIFF_HSTL_I_18 } [get_ports {fpgaclk2_P}]
set_property -dict { PACKAGE_PIN AE15 IOSTANDARD DIFF_HSTL_I_18 } [get_ports {fpgaclk2_N}]

####################
## AMC Bay0 Ports ##
####################
set_property -dict { PACKAGE_PIN AK22 IOSTANDARD LVCMOS18 } [get_ports {pllRst[0]}]  
set_property -dict { PACKAGE_PIN AJ21 IOSTANDARD LVCMOS18 } [get_ports {inc[0]}]     
set_property -dict { PACKAGE_PIN AH22 IOSTANDARD LVCMOS18 } [get_ports {dec[0]}]     
set_property -dict { PACKAGE_PIN AJ23 IOSTANDARD LVCMOS18 } [get_ports {frqTbl[0]}]  
set_property -dict { PACKAGE_PIN V26  IOSTANDARD LVCMOS18 } [get_ports {bypass[0]}]  
set_property -dict { PACKAGE_PIN V29  IOSTANDARD LVCMOS18 } [get_ports {rate[0][0]}]    
set_property -dict { PACKAGE_PIN AH16 IOSTANDARD LVCMOS18 } [get_ports {rate[0][1]}]    
set_property -dict { PACKAGE_PIN AH18 IOSTANDARD LVCMOS18 } [get_ports {sfOut[0][0]}]   
set_property -dict { PACKAGE_PIN AK17 IOSTANDARD LVCMOS18 } [get_ports {sfOut[0][1]}]   
set_property -dict { PACKAGE_PIN AJ18 IOSTANDARD LVCMOS18 } [get_ports {bwSel[0][0]}]   
set_property -dict { PACKAGE_PIN U26  IOSTANDARD LVCMOS18 } [get_ports {bwSel[0][1]}]   
set_property -dict { PACKAGE_PIN W28  IOSTANDARD LVCMOS18 } [get_ports {frqSel[0][0]}]  
set_property -dict { PACKAGE_PIN U24  IOSTANDARD LVCMOS18 } [get_ports {frqSel[0][1]}]  
set_property -dict { PACKAGE_PIN V27  IOSTANDARD LVCMOS18 } [get_ports {frqSel[0][2]}]  
set_property -dict { PACKAGE_PIN V21  IOSTANDARD LVCMOS18 } [get_ports {frqSel[0][3]}]  
set_property -dict { PACKAGE_PIN AN23 IOSTANDARD LVCMOS18 } [get_ports {lol[0]}]     
set_property -dict { PACKAGE_PIN AP24 IOSTANDARD LVCMOS18 } [get_ports {los[0]}]     

set_property -dict { PACKAGE_PIN AN8  IOSTANDARD LVCMOS25 } [get_ports {hsrScl[0][0]}] 
set_property -dict { PACKAGE_PIN AK10 IOSTANDARD LVCMOS25 } [get_ports {hsrScl[0][1]}] 
set_property -dict { PACKAGE_PIN AN9  IOSTANDARD LVCMOS25 } [get_ports {hsrScl[0][2]}] 
set_property -dict { PACKAGE_PIN AP8  IOSTANDARD LVCMOS25 } [get_ports {hsrSda[0][0]}] 
set_property -dict { PACKAGE_PIN AL9  IOSTANDARD LVCMOS25 } [get_ports {hsrSda[0][1]}] 
set_property -dict { PACKAGE_PIN AJ8  IOSTANDARD LVCMOS25 } [get_ports {hsrSda[0][2]}] 

####################
## AMC Bay1 Ports ##
####################
set_property -dict { PACKAGE_PIN W25  IOSTANDARD LVCMOS18 } [get_ports {pllRst[1]}]
set_property -dict { PACKAGE_PIN W23  IOSTANDARD LVCMOS18 } [get_ports {inc[1]}]
set_property -dict { PACKAGE_PIN AA24 IOSTANDARD LVCMOS18 } [get_ports {dec[1]}]
set_property -dict { PACKAGE_PIN Y23  IOSTANDARD LVCMOS18 } [get_ports {frqTbl[1]}]
set_property -dict { PACKAGE_PIN AA20 IOSTANDARD LVCMOS18 } [get_ports {bypass[1]}]
set_property -dict { PACKAGE_PIN AC22 IOSTANDARD LVCMOS18 } [get_ports {rate[1][0]}]
set_property -dict { PACKAGE_PIN AB30 IOSTANDARD LVCMOS18 } [get_ports {rate[1][1]}]
set_property -dict { PACKAGE_PIN AA32 IOSTANDARD LVCMOS18 } [get_ports {sfOut[1][0]}]
set_property -dict { PACKAGE_PIN AC31 IOSTANDARD LVCMOS18 } [get_ports {sfOut[1][1]}]
set_property -dict { PACKAGE_PIN AD30 IOSTANDARD LVCMOS18 } [get_ports {bwSel[1][0]}]
set_property -dict { PACKAGE_PIN AB25 IOSTANDARD LVCMOS18 } [get_ports {bwSel[1][1]}]
set_property -dict { PACKAGE_PIN AA27 IOSTANDARD LVCMOS18 } [get_ports {frqSel[1][0]}]
set_property -dict { PACKAGE_PIN AC26 IOSTANDARD LVCMOS18 } [get_ports {frqSel[1][1]}]
set_property -dict { PACKAGE_PIN AB24 IOSTANDARD LVCMOS18 } [get_ports {frqSel[1][2]}]
set_property -dict { PACKAGE_PIN AD25 IOSTANDARD LVCMOS18 } [get_ports {frqSel[1][3]}]
set_property -dict { PACKAGE_PIN AM22 IOSTANDARD LVCMOS18 } [get_ports {lol[1]}]
set_property -dict { PACKAGE_PIN AM21 IOSTANDARD LVCMOS18 } [get_ports {los[1]}]

set_property -dict { PACKAGE_PIN AD9  IOSTANDARD LVCMOS25 } [get_ports {hsrScl[1][0]}] 
set_property -dict { PACKAGE_PIN AD10 IOSTANDARD LVCMOS25 } [get_ports {hsrScl[1][1]}] 
set_property -dict { PACKAGE_PIN AE8  IOSTANDARD LVCMOS25 } [get_ports {hsrScl[1][2]}] 
set_property -dict { PACKAGE_PIN AD8  IOSTANDARD LVCMOS25 } [get_ports {hsrSda[1][0]}] 
set_property -dict { PACKAGE_PIN AE10 IOSTANDARD LVCMOS25 } [get_ports {hsrSda[1][1]}] 
set_property -dict { PACKAGE_PIN AH8  IOSTANDARD LVCMOS25 } [get_ports {hsrSda[1][2]}] 


