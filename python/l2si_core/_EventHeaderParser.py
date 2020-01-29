

def getField(value, highBit, lowBit):
    mask = 2**(highBit-lowBit+1)-1
    return (value >> lowBit) & mask

def makeInt(ba):
    return int.from_bytes(ba, 'little', signed=False)

c_uint64 = ctypes.c_uint64
c_uint = ctypes.c_uint

class PackedStruct(ctypes.LittleEndianStructure):
    _pack_ = 1

    def __str__(self):
        l = []
        for f in self._fields_:
            if issubclass(f[1], _ctypes._SimpleCData):
                l.append(f'{f[0]} - {getattr(self, f[0]):x}')
            else:
                l.append(f'{f[0]} - {getattr(self, f[0])}')
        return '\n'.join(l)

    def __new__(self, ba):
        return self.from_buffer_copy(ba)

    def __init__(self, ba):
        pass

class TransitionInfo(PackedStruct):
    _fields_ = [
        ('dmy1', c_uint, 1),
        ('l0Tag', c_uint, 5),
        ('dmy2', c_uint, 2),
        ('header', c_uint, 7)]
        

class EventInfo(PackedStruct):
    _fields_ = [
        ('l0Accept', c_uint, 1),
        ('l0Tag', c_uint, 5),
        ('dmy1', c_uint, 1),
        ('l0Reject', c_uint, 1),
        ('l1Expect', c_uint, 1),
        ('l1Accept', c_uint, 1),
        ('l1Tag', c_uint, 5) ]


class TriggerInfo(ctypes.Union):
    _fields_ = [
        ('eventInfo', EventInfo),
        ('transitionInfo', TransitionInfo),
        ('asWord', ctypes.c_uint16)]

    def __init__(self, word):
        self.asWord = word

    def isEvent(self):
        return ((self.asWord & 0x8000) != 0)

class EventHeader(PackedStruct):
    _fields_ = [
        ('pulseId', ctypes.c_uint64, 56),
        ('dmy1', ctypes.c_uint8),
        ('timeStamp', ctypes.c_uint64),
        ('partitions', ctypes.c_uint8),
        ('dmy2', ctypes.c_uint8),
        ('triggerInfo', ctypes.c_uint16),
        ('count', ctypes.c_uint32, 24),
        ('version', ctypes.c_uint8, 8)]


def parseEventHeaderFrame(frame):
    """Given a rogue Frame representing an Event Header or Transition, parse into a dictionary of fields"""
    
    frameSize = frame.getPayload()
    ba = bytearray(frameSize)
    channel = frame.getChannel()
    frame.read(ba, 0)

    return parseBa2(ba)

def parseBa1(ba):
    eh = EventHeader(ba=ba)
    ti = TriggerInfo(eh.triggerInfo)


fmt = '<QQBxHLxxxxxxxx'
def parseBa2(ba):
    s = struct.unpack(fmt, ba) 
    d = {} 
    d['pulseId'] = (s[0] & 0x00FFFFFFFFFFFFFF) 
    d['timeStamp'] = s[1] 
    d['partitions'] = s[2] 
    d['triggerInfo'] = s[3] 
    d['count'] = s[4] & 0x00FFFFFF 
    d['version'] = s[4] >> 24

    return d 

