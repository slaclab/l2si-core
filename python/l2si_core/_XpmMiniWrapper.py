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
            
