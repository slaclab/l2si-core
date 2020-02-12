##############################################################################
## This file is part of 'L2SI Core'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'L2SI Core', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################
import pyrogue as pr

import l2si_core

class TriggerEventManager(pr.Device):
    def __init__(self, numDetectors=1, **kwargs):
        super().__init__(**kwargs)

        self.add(l2si_core.XpmMessageAligner(
            offset = 0x0000))

        for i in range(numDetectors):
            self.add(l2si_core.TriggerEventBuffer(
                name = f'TriggerEventBuffer[{i}]',
                offset = 0x100 + (i * 0x100)))
