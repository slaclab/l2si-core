/*******************************************************************************

*******************************************************************************/
#ifndef _HSD_THR_H_
#define _HSD_THR_H_

#include "hsd_ilv.h"

// # of valid outputs can be 0 when
//    (1) nothing needs to be recorded or
//    (2) more samples are needed to get a result
//
// a valid output must be given at least as often as every 1024 samples
//    a skip record can be issued
//
// output times are evaluated in # of samples since sync
//

void hsd_thr_ilv(bool sync,
                 PROC_IN(XARG)   // "x" inputs  ( 8 11-bit values)
                 PROC_IN(TIARG)  // "trig" inputs ( 8 2-bit values)
                 PROC_OUT(YARG)  // "y" outputs ( 9 16-bit values)
                 PROC_OUT(TOARG) // "trig" outputs ( 8 2-bit values)
                 ap_fixed<4,4>& yv, // # of valid outputs
                 int config_a,
                 int config_b,
                 int config_c,
                 int config_d);

#endif