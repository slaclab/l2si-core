#include "hsd_raw.h"

#define PSHIFT(v) buffer[v]=x##v;
#define PWRITE(v) y##v=buffer[v];
#define PSET(v) y##v=ap_fixed<16,16>(x##v) & 0x7ff;
#define TSET(v) t##v=count+v;

// Top-level function with class instantiated
//
//   Pass individual arguments rather than an array to avoid memory access semantics
//
void hsd_raw(bool sync,
             PROC_IN(XARG)  // input adc data
             PROC_IN(YARG)  // "y" outputs (16 values)
             PROC_IN(TARG)  //
             ap_fixed<4,4>& yv,
             ap_fixed<3,3>& iy,
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
#pragma HLS INTERFACE ap_ctrl_none port=return
  static int count=0;

  if (sync)
    count = 0;

  PROC_IN(PSET);
  PROC_IN(TSET);
  yv = 8;
  iy = 0;

  count += 8;
}
