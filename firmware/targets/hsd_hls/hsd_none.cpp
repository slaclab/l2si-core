#include "hsd_none.h"

#define PSET(v) y##v=x##v;
#define TSET(v) t##v=v;

// Top-level function with class instantiated
//
//   Pass individual arguments rather than an array to avoid memory access semantics
//
void hsd_none(bool sync,
              PROC_IN(XARG)  // input adc data
              PROC_IN(YARG)  // "y" outputs (16 values)
              PROC_IN(TARG)  //
              ap_fixed<4,4>& yv,
              int config_a)
{
#pragma HLS PIPELINE II=1
#pragma HLS INTERFACE s_axilite port=config_a bundle=BUS_A
#pragma HLS INTERFACE ap_none port=y0
#pragma HLS INTERFACE ap_none port=y1
#pragma HLS INTERFACE ap_none port=y2
#pragma HLS INTERFACE ap_none port=y3
#pragma HLS INTERFACE ap_none port=y4
#pragma HLS INTERFACE ap_none port=y5
#pragma HLS INTERFACE ap_none port=y6
#pragma HLS INTERFACE ap_none port=y7
#pragma HLS INTERFACE ap_none port=yv

  PROC_IN(PSET);
  PROC_IN(TSET);
  yv = 0;
}
