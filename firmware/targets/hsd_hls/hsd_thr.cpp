#include "hsd_thr.h"

//  AMAX : cache depth of sample groups (8 ADC samples per group)
#define AMAX 16
#define PSHIFT(v) buffer[v]=x##v;
#define PWRITE(v) y##v=buffer[v];
#define PSET(v) y##v=ap_fixed<16,16>(xsave##v[raddr%AMAX]) & 0x7ff;
#define TSET(v) t##v=rcount*8+v;
#define PTEST(v) lkeep |= (x##v < xlo || x##v > xhi);
#define AINIT(v) static adcin_t xsave##v[AMAX];
#define ASAVE(v) xsave##v[waddr%AMAX] = x##v;
#define DO_PRAGMA(x) _Pragma(#x)
#define TINTF(v) DO_PRAGMA(HLS INTERFACE ap_none port=t##v)
#define YINTF(v) DO_PRAGMA(HLS INTERFACE ap_none port=y##v)
#define ARES(v)  DO_PRAGMA(HLS RESOURCE variable=xsave##v core=RAM_2P)
#define ADEP(v)  DO_PRAGMA(HLS DEPENDENCE variable=xsave##v inter WAR false)

// Top-level function with class instantiated
//
//   Pass individual arguments rather than an array to avoid memory access semantics
//
void hsd_thr(bool sync,
             PROC_IN(XARG)  // input adc data
             PROC_IN(YARG)  // "y" outputs (16 values)
             PROC_IN(TARG)  //
             ap_fixed<4,4>& yv,
             ap_fixed<3,3>& iy,
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
  PROC_IN(TINTF);
  //  Remove all valid/handshake signals for y0..y7
  PROC_IN(YINTF);
  //  Remove all valid/handshake signals for yv,iy
#pragma HLS INTERFACE ap_none port=yv
#pragma HLS INTERFACE ap_none port=iy
  //  Remove all function valid/handshake signals
#pragma HLS INTERFACE ap_ctrl_none port=return

  static int  waddr=0;
  static int  raddr=0;
  static int  count=0;
  static int  akeep=0;  // bit mask of sample groups to keep (1 bit = 8 ADC samples)
  //  Declare static arrays xsave0..xsave7
  PROC_IN(AINIT);

  //  Indicate dual port ram for xsave0..xsave7
  PROC_IN(ARES);
  //  Indicate reads and writes will never use same index/address
  PROC_IN(ADEP);

  unsigned xlo   = config_a;  // Low value of band to sparsify
  unsigned xhi   = config_b;  // High value of band to sparsify
  unsigned tpre  = config_c;  // Presamples (units of 8 ADC samples)
  unsigned tpost = config_d;  // Postsamples (units of 8 ADC samples)
  
  //  Reset indices
  count++;
  if (sync) {
    count = 0;
    waddr = tpre;
    raddr = 0;
  }

  //  Test if any of 8 input samples are out of the sparsification band
  bool lkeep=false;
  PROC_IN(PTEST);       // lkeep |= (x##v < a || x##v > b)
  if (lkeep)
    akeep |= (1<<(tpre+tpost+1))-1;  // keep tpre before, current, and tpost after

  // always keeping or discarding the whole group of 8 samples
  iy = 0;  
  if (akeep&1)
    yv = 8;
  else
    yv = 0;

  //  cache current ADC samples
  PROC_IN(ASAVE);       // xsave##v[waddr] = x##v
  akeep >>= 1;

  //  set output to cached samples from presample 
  int rcount = (count-tpre);
  PROC_IN(TSET);        // t##v = rcount*8+v
  PROC_IN(PSET);        // y##v = xsave##v[raddr]

  //  increment array indices
  raddr++;
  waddr++;
}
