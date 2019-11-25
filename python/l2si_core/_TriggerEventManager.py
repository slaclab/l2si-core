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
