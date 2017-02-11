#!/usr/bin/python
##############################################################################
## This file is part of 'LCLS2 AMC Carrier Firmware'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'LCLS2 AMC Carrier Firmware', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

import os
from subprocess import check_call

## Define the GIT submodule path and TAG-ing
tagConfig = [ ['/firmware/submodules/amc-carrier-core', 'v1.0.2'],
              ['/firmware/submodules/lcls-timing-core', 'v1.0.1'],
              ['/firmware/submodules/ruckus',           'v1.0.2'],
              ['/firmware/submodules/surf',             'v1.0.2'],
              ['/firmware/submodules/sysgen-dsp-lib',   'v1.0.0'] ]
         
## Loop through the submodules
for i in range(len(tagConfig)):
    # Generate a list of shell commands
    cmd  = 'cd ' + (os.getcwd() + tagConfig[i][0]) + '/; '
    cmd += 'pwd; '
    cmd += 'git fetch; '
    cmd += 'git checkout ' + tagConfig[i][1] + '; '
    cmd += 'cd ' + os.getcwd() + '; '
    cmd += 'git add ' + (os.getcwd() + tagConfig[i][0]) + '; '
    # Execut the list of commands
    check_call(cmd, shell=True)

# Commit the updated submodule tags
check_call('git ci -m "Updating submodules tags"', shell=True)
      
##################################################################################################
## Warning: This script does NOT push the commits to github.  You will need to do that manually
##################################################################################################
     
##################################################################################################
## NOTE: You MUST have your SSH keys configured on GITHUB for this script to work
##       https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/
##       https://help.github.com/articles/adding-a-new-ssh-key-to-your-github-account/
##################################################################################################


