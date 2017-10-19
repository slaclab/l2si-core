#include "hsd_raw_v2.h"

#define PSHIFT(v) buffer[v]=x##v;
#define PWRITE(v) y##v=buffer[v];
#define PSET(v)  y##v=ap_fixed<16,16>(x##v) & 0x7ff;
#define TSET(v)  to##v=ti##v;
#define PSSH(u,v)  y##u=ap_fixed<16,16>(x##v) & 0x7ff;
#define TSSH(u,v)  to##u=ti##v;
#define OPENTEST(v) if (unsigned(ti##v)&1) lopening=true;
#define CLOSTEST(v) if (unsigned(ti##v)&2) lclosing=true;

// Top-level function with class instantiated
//
//   Pass individual arguments rather than an array to avoid memory access semantics
//
void hsd_raw(bool sync,
             PROC_IN(XARG)   // input adc data
             PROC_IN(TIARG)  // input trigger data
             PROC_OUT(YARG)  // "y" outputs (9 values)
             PROC_OUT(TOARG) // trigger outputs (9 values)
             ap_fixed<4,4>& yv,
             int config_a)
{
  //  Require full pipelining (new data every clock cycle)
#pragma HLS PIPELINE II=1
  //  Handle all configuration parameters with the one axilite bus
#pragma HLS INTERFACE s_axilite port=config_a bundle=BUS_A
  //  Remove all valid/handshake signals for y0..y7
  PROC_OUT(YINTF);
  //  Remove all valid/handshake signals for to0..to7
  PROC_OUT(TINTF);
  //  Remove all valid/handshake signals for yv
#pragma HLS INTERFACE ap_none port=yv
  //  Remove all function valid/handshake signals
#pragma HLS INTERFACE ap_ctrl_none port=return

  static int count=0;
  static int count_last=0;
  static int nopen=0;
  static bool lskipped=false;

  if (sync) {
    count=0;
    count_last=0;
    nopen=0;
    lskipped=false;
    y0 = y1 = y2 = y3 = y4 = y5 = y6 = y7 = y8 = 0;
    to0 = to1 = to2 = to3 = to4 = to5 = to6 = to7 = to8 = 0;
    yv = 0;
  }

  else {
    bool lopening=false;
    PROC_IN(OPENTEST);

    //  Insert a skip marker when
    //    we're opening the output or
    //    the output has been closed over limit
    //  
    if (lskipped) {
      // skip to the first position
      int dcount = count-count_last;
      y0  = 0x8000 | ((dcount-1)&0x7fff);
      to0 = 0;
      // insert data
      PROC_SHIFT(PSSH);
      PROC_SHIFT(TSSH);
      if (lopening) {
        yv = 9;
        count_last = count+7;
        lskipped = false;
      }
      else if (dcount >= SKIP_THR) { 
        yv  = 1;
        count_last = count;
      }
      else {
        yv = 0;
      }
    }
    else if (nopen) {
      PROC_IN(PSET);
      PROC_IN(TSET);
      y8 = ap_fixed<16,16>(x7) & 0x7ff;
      to8 = 0;
      yv = 8;
      count_last = count+7;
      lskipped = false;
    }
    else {
      PROC_IN(PSET);
      PROC_IN(TSET);
      y8 = ap_fixed<16,16>(x7) & 0x7ff;
      to8 = 0;
      yv = 0;
      lskipped = true;
    }

    bool lclosing=false;
    PROC_IN(CLOSTEST);
    if (lopening) nopen++;
    if (lclosing) nopen--;
    count += 8;
  }
}

