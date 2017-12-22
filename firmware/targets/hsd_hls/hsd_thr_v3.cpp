#include "hsd_thr_v2.h"

//  AMAX : cache depth of sample groups (8 ADC samples per group)
#define AMAX 16
#define PSHIFT(v) buffer[v]=x##v;
#define PWRITE(v) y##v=buffer[v];
#define PSET(v) y##v=ap_fixed<16,16>(xsave##v[raddr%AMAX]) & 0x7ff;
#define TSET(v) to##v=tsave##v[raddr%AMAX];
#define PSSH(u,v) y##u=ap_fixed<16,16>(xsave##v[raddr%AMAX]) & 0x7ff;
#define TSSH(u,v) to##u=tsave##v[raddr%AMAX];

#define PTEST(v) lkeep |= (x##v < xlo || x##v > xhi);

#define AINIT(v) static adcin_t xsave##v[AMAX];
#define ASAVE(v) xsave##v[waddr%AMAX] = x##v;
#define ARES(v)  DO_PRAGMA(HLS RESOURCE variable=xsave##v core=RAM_2P)
#define ADEP(v)  DO_PRAGMA(HLS DEPENDENCE variable=xsave##v inter WAR false)

#define TINIT(v) static trig_t tsave##v[AMAX];
#define TSAVE(v) tsave##v[waddr%AMAX] = ti##v;
#define TRES(v)  DO_PRAGMA(HLS RESOURCE variable=tsave##v core=RAM_2P)
//#define TDEP(v)  DO_PRAGMA(HLS DEPENDENCE variable=tsave##v inter WAR false)
#define TDEP(v)  DO_PRAGMA(HLS DEPENDENCE variable=tsave##v inter distance=0 false)
#define TPTN(v)  DO_PRAGMA(HLS array_partition variable=tsave##v complete)

#define OPENTEST(v) if (unsigned(tsave##v[raddr%AMAX])&1) { lopening=true; iopen=v; }
#define CLOSTEST(v) if (unsigned(tsave##v[raddr%AMAX])&2) lclosing=true;

class SkipChar {
public:
  SkipChar() { reset(); }
public:
  void reset() {
    _count      = 0;
    _count_last = 0;
    _lskipped   = false;
  }
  void insert(adcout_t& y, trig_t& to, int position, bool lopening=false, bool lclosing=false) {
    y = 0x8000 | ((_count-_count_last+position-1)&0x7fff);
    to = (lopening ? 1:0) | (lclosing ? 2:0);
  }
  void fill(int n) {
    _count_last = _count+n-1;
    _lskipped   = (n < 8);
  }
  void incr(int n) { _count+=n; }
private:
  int  _count;
  int  _count_last;
  bool _lskipped;
};

static SkipChar skip;

// Top-level function with class instantiated
//
//   Pass individual arguments rather than an array to avoid memory access semantics
//
void hsd_thr(bool sync,
             PROC_IN(XARG)  // input adc data
             PROC_IN(TIARG)  // input trigger data
             PROC_OUT(YARG)  // "y" outputs (16 values)
             PROC_OUT(TOARG) // trigger outputs (9 values)
             ap_fixed<4,4>& yv,
             int config_a,  // low band
             int config_b,  // high band
             int config_c,  // early margin / presamples
             int config_d)  // late margin / postsamples
{
  //  Require full pipelining (new data every clock cycle)
#pragma HLS PIPELINE II=1
  //  Handle all configuration parameters with the one axilite bus
#pragma HLS INTERFACE s_axilite port=config_a bundle=BUS_A
#pragma HLS INTERFACE s_axilite port=config_b bundle=BUS_A
#pragma HLS INTERFACE s_axilite port=config_c bundle=BUS_A
#pragma HLS INTERFACE s_axilite port=config_d bundle=BUS_A

  //  Remove all valid/handshake signals for t0..t7
  PROC_OUT(TINTF);
  //  Remove all valid/handshake signals for y0..y7
  PROC_OUT(YINTF);
  //  Remove all valid/handshake signals for yv
#pragma HLS INTERFACE ap_none port=yv
  //  Remove all function valid/handshake signals
#pragma HLS INTERFACE ap_ctrl_none port=return

  static int  waddr=0;
  static int  raddr=0;
  static int  akeep=0;  // bit mask of sample groups to keep (1 bit = 8 ADC samples)
  //  Declare static arrays xsave0..xsave7
  PROC_IN(AINIT);
  PROC_IN(TINIT);

  //  Indicate dual port ram for xsave0..xsave7
  PROC_IN(ARES);
  PROC_IN(TRES);
  //  Indicate reads and writes will never use same index/address
  PROC_IN(ADEP);
  PROC_IN(TDEP);
  //  PROC_IN(TPTN);

  static unsigned nopen = 0;

  unsigned xlo   = config_a;  // Low value of band to sparsify
  unsigned xhi   = config_b;  // High value of band to sparsify
  unsigned tpre  = config_c;  // Presamples (units of 8 ADC samples)
  unsigned tpost = config_d;  // Postsamples (units of 8 ADC samples)
  
  //  Reset indices
  if (sync) {
    skip.reset();
    nopen = 0;
    waddr = tpre;
    raddr = 0;
  }
  else {

    //  Test if any of 8 input samples are out of the sparsification band
    bool lkeep=false;
    PROC_IN(PTEST);       // lkeep |= (x##v < a || x##v > b)
    if (lkeep)
      akeep |= (1<<(tpre+tpost+1))-1;  // keep tpre before, current, and tpost after

    bool lout = akeep&1;

    //  cache current ADC samples
    PROC_IN(ASAVE);       // xsave##v[waddr] = x##v
    PROC_IN(TSAVE);       // tsave##v[waddr] = t##v
    akeep >>= 1;

    bool lopening=false;
    int  iopen=0;
    PROC_IN(OPENTEST);
    bool lclosing=false;
    PROC_IN(CLOSTEST);

    int dcount = count-count_last;

    if ((nopen || lopening) && lout) {
      if (lskipped) {
        // skip to the first position
        skip.insert(y0,to0,0);
        PROC_SHIFT(PSSH);
        PROC_SHIFT(TSSH);
        yv = 9;
      }
      else {
        PROC_IN(PSET);
        PROC_IN(TSET);
        y8  = ap_fixed<16,16>(xsave7[raddr%AMAX])&0x7ff;
        to8 = tsave7[raddr%AMAX];
        yv = 8;
      }
      skip.fill(8);
    }
    else if (lopening) {
      // skip to the opening position
      skip.insert(y0,to0,iopen,lopening,lclosing);
      PROC_SHIFT(PSSH);
      PROC_SHIFT(TSSH);
      yv = 1;
      skip.fill(iopen+1);
    }
    else if (lclosing || dcount >= SKIP_THR) {
      // skip to the first position
      skip.insert(y0,to0,0);
      PROC_SHIFT(PSSH);
      PROC_SHIFT(TSSH);
      yv = 1;
      skip.fill(1);
    }
    else {
      skip.insert(y0,to0,0);
      PROC_SHIFT(PSSH);
      PROC_SHIFT(TSSH);
      yv = 0;
      skip.fill(1);
    }

    //  increment array indices
    raddr++;
    waddr++;

    if (lopening) nopen++;
    if (lclosing) nopen--;

    skip.incr(8);
  }
}
