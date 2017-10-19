/*******************************************************************************

*******************************************************************************/
#ifndef _HSD_H_
#define _HSD_H_

#include "ap_fixed.h"

typedef ap_fixed<11,11> adcin_t;
typedef ap_fixed<16,16> adcout_t;
typedef ap_fixed<2,2>   trig_t;

#define NARG 8

//  A macro to execute 48 instances

#define PROC_IN(PROC_ONE)                      \
    PROC_ONE(0)                                \
    PROC_ONE(1)                                \
    PROC_ONE(2)                                \
    PROC_ONE(3)                                \
    PROC_ONE(4)                                \
    PROC_ONE(5)                                \
    PROC_ONE(6)                                \
    PROC_ONE(7)

#define PROC_OUT(PROC_ONE)                     \
    PROC_ONE(0)                                \
    PROC_ONE(1)                                \
    PROC_ONE(2)                                \
    PROC_ONE(3)                                \
    PROC_ONE(4)                                \
    PROC_ONE(5)                                \
    PROC_ONE(6)                                \
    PROC_ONE(7)                                \
    PROC_ONE(8)

#define PROC_SHIFT(PROC_ONE)                    \
  PROC_ONE(1,0)                                 \
  PROC_ONE(2,1)                                 \
  PROC_ONE(3,2)                                 \
  PROC_ONE(4,3)                                 \
  PROC_ONE(5,4)                                 \
  PROC_ONE(6,5)                                 \
  PROC_ONE(7,6)                                 \
  PROC_ONE(8,7)

#define XARG(v) adcin_t x##v,
#define YARG(v) adcout_t& y##v,
#define TIARG(v) trig_t& ti##v,
#define TOARG(v) trig_t& to##v,

#define DO_PRAGMA(x) _Pragma(#x)
#define TINTF(v) DO_PRAGMA(HLS INTERFACE ap_none port=to##v)
#define YINTF(v) DO_PRAGMA(HLS INTERFACE ap_none port=y##v)

static const int SKIP_THR = 0x0100;

#endif
