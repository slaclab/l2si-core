#ifndef HSD_QABase_hh
#define HSD_QABase_hh

#include <stdint.h>

namespace Pds {
  namespace HSD {

    class QABase {
    public:
      void init();
      void setChannels(unsigned);
      enum Interleave { Q_NONE, Q_ABCD };
      void setMode    (Interleave);
      void setupDaq (unsigned partition);
      void setupLCLS(unsigned rate);
      void setupLCLSII(unsigned rate);
      void enableDmaTest(bool);
      void start();
      void stop ();
      void resetCounts();
      void resetClock (bool);
      void resetDma   ();
      bool clockLocked() const;
      void dump() const;
    public:
      uint32_t irqEnable;
      uint32_t irqStatus;
      uint32_t partitionAddr;
      uint32_t dmaFullThr;
      uint32_t csr; 
      //   CSR
      // [ 0:0]  count reset
      // [ 1:1]  dma size histogram enable
      // [ 2:2]  dma test pattern enable
      // [ 3:3]  adc sync reset
      // [ 4:4]  dma reset
      // [ 8:15] trigger bit mask shift
      // [31:31] acqEnable
      uint32_t acqSelect;
      //   AcqSelect
      // [12: 0]  rateSel  :   [7:0] eventCode
      // [31:13]  destSel
      uint32_t control;
      //   Control
      // [7:0] channel enable mask
      // [8:8] interleave
      // [19:16] partition
      uint32_t samples;       //  Must be a multiple of 16
      uint32_t prescale;
      //   Prescale
      //   Values are mapped as follows:
      //  Value    Rate Divisor    Nominal Rate
      //   [0..1]       1           1250 MHz
      //     2          2            625 MHz
      //   [3..5]       5            250 MHz
      //   [6..7]      10            125 MHz
      //   [8..15]     20             62.5 MHz
      //  [16..23]     30             41.7 MHz
      //  [24..31]     40             31.3 MHz
      //  [32..39]     50             25 MHz
      //  [40..47]     60             20.8 MHz
      //  [48..55]     70             17.9 MHz
      //  [56..63]     80             15.6 MHz
      //  Delay (bits 6:31) [units of TimingRef clk]
      uint32_t offset;        //  Not implemented
      uint32_t countAcquire;
      uint32_t countEnable;
      uint32_t countInhibit;
      uint32_t dmaFullQ;
      uint32_t adcSync;
      //
      uint32_t status;
      uint32_t statusCount[32];
    };
  };
};

#endif
