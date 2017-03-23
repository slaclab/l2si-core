#ifndef HSD_RingBuffer_hh
#define HSD_RingBuffer_hh

#include <stdint.h>

namespace Pds {
  namespace HSD {

    class RingBuffer {
    public:
      RingBuffer() {}
    public:
      void     enable (bool);
      void     clear  ();
      void     dump   ();
    private:
      uint32_t   _csr;
      uint32_t   _dump[0x1fff];
    };
  };
};

#endif
