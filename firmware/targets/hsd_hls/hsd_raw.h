/*******************************************************************************

*******************************************************************************/
#ifndef _HSD_RAW_H_
#define _HSD_RAW_H_

#include "hsd.h"

// # of valid outputs can be 0 when
//    (1) nothing needs to be recorded or
//    (2) more samples are needed to get a result
//
// a valid output must be given at least as often as every 1024 samples
//    a skip record can be issued
//
// output times are evaluated in # of samples since sync
//

void hsd_raw(bool sync,
             PROC_IN(XARG)  // "x" inputs  ( 8 11-bit values)
             PROC_IN(YARG)  // "y" outputs ( 8 16-bit values)
             PROC_IN(TARG)  // "y" output time ( 8 14-bit values)
             ap_fixed<4,4>& yv, // # of valid outputs
             int config_a);

#endif
