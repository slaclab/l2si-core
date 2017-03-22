#ifndef HSD_Module_hh
#define HSD_Module_hh

#include <stdint.h>

namespace Pds {
  namespace HSD {
    class AxiVersion;
    class TprCore;

    class Module {
    public:
      //
      //  High level API
      //
      static Module* create(int fd);
      
      ~Module();

      //  Initialize busses
      void init();

      //  Initialize clock tree and IO training
      void fmc_init();

      int  train_io(unsigned);

      enum TestPattern { Ramp=0, Flash11=1, Flash12=3, Flash16=5, DMA=8 };
      void enable_test_pattern(TestPattern);
      void disable_test_pattern();
      void enable_cal ();
      void disable_cal();
      void setAdcMux(bool     interleave,
                     unsigned channels);

      void sample_init (unsigned length,
                        unsigned delay,
                        unsigned prescale);

      void trig_lcls  (unsigned eventcode);
      void trig_lclsii(unsigned fixedrate);
      void trig_daq   (unsigned partition);

      void start      ();
      void stop       ();

      const Pds::HSD::AxiVersion& version() const;
      const Pds::HSD::TprCore&    tpr    () const;

      void setRxAlignTarget(unsigned);
      void setRxResetLength(unsigned);
      void dumpRxAlign     () const;

      //  Zero copy read semantics
      //      ssize_t dequeue(void*&);
      //      void    enqueue(void*);
      //  Copy on read
      int read(uint32_t* data, unsigned data_size);

    private:
      Module() {}

      class PrivateData;
      PrivateData* p;

      int _fd;
    };
  };
};

#endif
