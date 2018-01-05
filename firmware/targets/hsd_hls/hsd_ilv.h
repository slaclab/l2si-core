/*******************************************************************************

*******************************************************************************/
#ifndef _HSD_ILV_H_
#define _HSD_ILV_H_

#include "hsd_v2.h"

typedef ap_fixed<44,44> adci_t;
typedef ap_fixed<64,64> adco_t;

#undef XARG
#undef YARG
#define XARG(v) adci_t x##v,
#define YARG(v) adco_t& y##v,

#endif
