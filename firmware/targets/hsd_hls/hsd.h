/*******************************************************************************

*******************************************************************************/
#ifndef _HSD_H_
#define _HSD_H_

#include "ap_fixed.h"

typedef ap_fixed<11,11> adcin_t;
typedef ap_fixed<16,16> adcout_t;
typedef ap_fixed<14,14> tout_t;

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
    PROC_ONE(8)                                \
    PROC_ONE(9)                                \
    PROC_ONE(10)                               \
    PROC_ONE(11)                               \
    PROC_ONE(12)                               \
    PROC_ONE(13)                               \
    PROC_ONE(14)                               \
    PROC_ONE(15)

#define XARG(v) adcin_t x##v,
#define YARG(v) adcout_t& y##v,
#define TARG(v) tout_t& t##v,

/*
void hsd_func(PROC_IN(XARG)  // input adc data
              PROC_OUT(YARG) // "y" outputs
              int config_a );
*/

#endif
