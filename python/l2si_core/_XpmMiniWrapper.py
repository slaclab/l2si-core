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

import LclsTimingCore
import l2si_core

class XpmMiniWrapper(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(LclsTimingCore.TPGMiniCore(
            offset = 0x0000,
            NARRAYSBSA=1,
            expand=False))

        self.add(l2si_core.XpmMini(offset = 0x1000))
