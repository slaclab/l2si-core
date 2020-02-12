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

class TriggerEventBuffer(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name        = 'MasterEnable',
            description = 'Enables both the trigger and event processing in Firmware',
            offset      = 0x00,
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.Bool,
            mode        = 'RW',
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'EventBufferEnable',
            description = 'Enables the event buffer in firmware',
            offset      = 0x00,
            bitSize     = 1,
            bitOffset   = 1,
            base        = pr.Bool,
            mode        = 'RW',
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'Partition',
            description = 'Selected Partition to listen for events on',
            offset      = 0x04,
            bitSize     = 3,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'XpmOverflow',
            description = 'Overflow signal to XPM Feedback',
            offset      = 0x08,
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.Bool,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'XpmPause',
            description = 'Event Buffer Pause condition and signal to XPM Feedback',
            offset      = 0x08,
            bitSize     = 1,
            bitOffset   = 1,
            base        = pr.Bool,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'FifoOverflow',
            description = 'Event Buffer Overflow condition',
            offset      = 0x08,
            bitSize     = 1,
            bitOffset   = 2,
            base        = pr.Bool,
            mode        = 'RO',
        ))
        

        self.add(pr.RemoteVariable(
            name = 'FifoWrCnt',
            description = 'Number of Events in Event Buffer',
            offset = 0x08,
            bitSize = 5,
            bitOffset = 3,
            mode = 'RO'
        ))

        self.add(pr.RemoteVariable(
            name        = 'PauseThreshold',
            description = 'Buffer level at which Pause is asserted',
            offset      = 0x08,
            bitSize     = 5,
            bitOffset   = 16,
            base        = pr.UInt,
            mode        = 'RW',
            disp        = '{:d}'            
        ))
        
#         self.add(pr.RemoteVariable(
#             name        = 'MessageDelay',
#             description = 'Measure delay of each meassage',
#             offset      = 0x0C,
#             bitSize     = 8,
#             bitOffset   = 0,
#             base        = pr.UInt,
#             mode        = 'RO',
#             disp        = '{:d}'            
#         ))


        self.add(pr.RemoteVariable(
            name        = 'TransitionCount',
            description = '',
            offset      = 0x34,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
            disp        = '{:d}'
        ))


        self.add(pr.RemoteVariable(
            name        = 'XpmMessageCount',
            description = '',
            offset      = 0x38,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
            disp        = '{:d}'
        ))

        self.add(pr.RemoteVariable(
            name        = 'TriggerCount',
            offset      = 0x3C,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
            disp        = '{:d}'
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'L0Count',
            description = 'Number of L0 Triggers received',
            offset      = 0x10,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
            disp        = '{:d}'
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'L1AcceptCount',
            description = 'Number of L1 Triggers Accepted',
            offset      = 0x14,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
            disp        = '{:d}'            
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'L1RejectCount',
            description = 'Number of L1 Triggers Rejected',
            offset      = 0x1C,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
            disp        = '{:d}'            
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'TriggerDelay',
            description = 'Number of timingClk cycles to delay trigger output to application',
            offset      = 0x20,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
            disp        = '{:d}'            
        ))

        self.add(pr.RemoteVariable(
            name        = 'LastPartitionAddr',
            offset      = 0x40,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LastPartitionWord0',
            offset      = 0x44,
            bitSize     = 48,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
        ))

        self.add(pr.RemoteCommand(
            name = 'ResetCounters',
            offset = 0x4C,
            bitSize = 1,
            bitOffset = 0,
            function = pr.RemoteCommand.touchOne))
        
