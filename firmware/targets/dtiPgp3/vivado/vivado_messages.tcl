##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

########################################################
## Get variables and Custom Procedures
########################################################

source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

########################################################
## Message Suppression
########################################################

# Messages Suppression: INFO
# Messages Suppression: WARNING
set_msg_config -suppress -id {Synth 8-2519}; # SYNTH: partially associated formal cannot have actual OPEN
