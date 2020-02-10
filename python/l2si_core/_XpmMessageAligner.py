import pyrogue as pr

import l2si_core

class XpmMessageAligner(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        for i in range(8):
            self.add(pr.RemoteVariable(
                name = f'PartitionDelay[{i}]',
                offset = i*4,
                bitSize = 7,
                mode = 'RO',
                disp = '{:d}'))

        self.add(pr.RemoteVariable(
            name = f'TxId',
            offset = 0x20,
            bitSize = 32,
            mode = 'RW'))

        self.add(pr.RemoteVariable(
            name = f'RxId',
            offset = 0x24,
            bitSize = 32,
            mode = 'RO'))
        
