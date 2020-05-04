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

class XpmMessageAligner(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        for i in range(8):
            self.add(pr.RemoteVariable(
                name = f'PartitionDelay[{i}]',
                offset = i*4,
                bitSize = 7,
                mode = 'RO',
                disp = '{:d}',
                pollInterval = 1,))

        self.add(pr.RemoteVariable(
            name = f'TxId',
            offset = 0x20,
            bitSize = 32,
            mode = 'RW',
            pollInterval = 1,))

        self.add(pr.RemoteVariable(
            name = f'RxId',
            offset = 0x24,
            bitSize = 32,
            mode = 'RO',
            pollInterval = 1,))
