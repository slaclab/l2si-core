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

class XpmMini(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name         = "AxilRdEn",
            offset       = 0x14,
            bitSize      = 1,
            bitOffset    = 31,
            base         = pr.Bool,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = "Link",
            offset       = 0x00,
            bitSize      = 4,
            bitOffset    = 0,
            disp         = '{:d}',
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = "TxPllRst",
            offset       = 0x04,
            bitSize      = 1,
            bitOffset    = 18,
            base         = pr.Bool,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = "RxPllRst",
            offset       = 0x04,
            bitSize      = 1,
            bitOffset    = 19,
            base         = pr.Bool,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = "Loopback",
            offset       = 0x04,
            bitSize      = 1,
            bitOffset    = 28,
            base         = pr.Bool,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = "TxRst",
            offset       = 0x04,
            bitSize      = 1,
            bitOffset    = 29,
            base         = pr.Bool,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = "RxRst",
            offset       = 0x04,
            bitSize      = 1,
            bitOffset    = 30,
            base         = pr.Bool,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = "HwEnable",
            offset       = 0x04,
            bitSize      = 1,
            bitOffset    = 31,
            base         = pr.Bool,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = "RxErrorCnts",
            offset       = 0x08,
            bitSize      = 16,
            bitOffset    = 0,
            disp         = '{:d}',
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = "TxResetDone",
            offset       = 0x08,
            bitSize      = 1,
            bitOffset    = 16,
            base         = pr.Bool,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = "TxReady",
            offset       = 0x08,
            bitSize      = 1,
            bitOffset    = 17,
            base         = pr.Bool,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = "RxResetDone",
            offset       = 0x08,
            bitSize      = 1,
            bitOffset    = 18,
            base         = pr.Bool,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = "RxReady",
            offset       = 0x08,
            bitSize      = 1,
            bitOffset    = 19,
            base         = pr.Bool,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = "RxIsXpm",
            offset       = 0x08,
            bitSize      = 1,
            bitOffset    = 20,
            base         = pr.Bool,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = "RxId",
            offset       = 0x0C,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = "RxRcvCnts",
            offset       = 0x10,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'RO',
        ))

        self.add(pr.RemoteCommand(
            name         = "Config_L0Select_Reset",
            offset       = 0x14,
            bitSize      = 1,
            bitOffset    = 0,
            function     = pr.RemoteCommand.toggle
        ))

        self.add(pr.RemoteVariable(
            name         = "Config_L0Select_Enabled",
            offset       = 0x14,
            bitSize      = 1,
            bitOffset    = 16,
            mode         = 'RW',
            base         = pr.Bool
        ))


        self.add(pr.RemoteVariable(
            name         = "Config_L0Select_RateSel",
            offset       = 0x18,
            bitSize      = 16,
            bitOffset    = 0,
            mode         = 'RW',
            enum = {
                0x0000: '929 kHz',
                0x0001: '71 kHz',
                0x0002: '10 kHz',
                0x0003: '1 kHz',
                0x0004: '100 Hz',
                0x0005: '10 Hz',
                0x0006: '1 Hz',
                0x8000: 'Undefined',
            }
        ))

        self.add(pr.RemoteVariable(
            name         = "Config_L0Select_DestSel",
            offset       = 0x18,
            bitSize      = 16,
            bitOffset    = 16,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = "Status_L0Select_Enabled",
            offset       = 0x20,
            bitSize      = 40,
            bitOffset    = 0,
            disp         = '{:d}',
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = "Status_L0Select_Inhibited",
            offset       = 0x28,
            bitSize      = 40,
            bitOffset    = 0,
            disp         = '{:d}',
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = "Status_L0Select_Num",
            offset       = 0x30,
            bitSize      = 40,
            bitOffset    = 0,
            disp         = '{:d}',
            mode         = 'RO',
        ))
        self.add(pr.RemoteVariable(
            name         = "Status_L0Select_NumInh",
            offset       = 0x38,
            bitSize      = 40,
            bitOffset    = 0,
            disp         = '{:d}',
            mode         = 'RO',
        ))
        self.add(pr.RemoteVariable(
            name         = "Status_L0Select_NumAcc",
            offset       = 0x40,
            bitSize      = 40,
            bitOffset    = 0,
            disp         = '{:d}',
            mode         = 'RO',
        ))
        self.add(pr.RemoteVariable(
            name         = "Pipeline_Depth_Clks",
            offset       = 0x48,
            bitSize      = 16,
            bitOffset    = 0,
            disp         = '{:d}',
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = "Pipeline_Depth_Fids",
            offset       = 0x48,
            bitSize      = 8,
            bitOffset    = 16,
            disp         = '{:d}',
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = "PartitionMessage_Hdr",
            offset       = 0x4C,
            bitSize      = 16,
            bitOffset    = 0,
            mode         = 'WO',
            hidden       = True,
        ))

        @self.command()
        def SendTransition(arg):
            self.PartitionMessage_Hdr.set(arg | (1<<15))

        @self.command()
        def TxPllReset():
            self.TxPllRst.set(0x1)
            self.Link.set(self.Link.get())
            self.TxPllRst.set(0x0)

        @self.command()
        def RxPllReset():
            self.RxPllRst.set(0x1)
            self.Link.set(self.Link.get())
            self.RxPllRst.set(0x0)

        @self.command()
        def TxReset():
            self.TxRst.set(0x1)
            self.Link.set(self.Link.get())
            self.TxRst.set(0x0)

        @self.command()
        def RxReset():
            self.RxRst.set(0x1)
            self.Link.set(self.Link.get())
            self.RxRst.set(0x0)
