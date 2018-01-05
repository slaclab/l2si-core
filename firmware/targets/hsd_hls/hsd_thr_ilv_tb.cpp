#include "hsd_thr_ilv.h"

#include <fstream>
#include <iomanip>
#include <cstdlib>
using namespace std;

#define DIN(v) adci_t( (uint64_t((4*(i+v)+0)&0x7ff) <<  0) | \
                       (uint64_t((4*(i+v)+1)&0x7ff) << 11) | \
                       (uint64_t((4*(i+v)+2)&0x7ff) << 22) | \
                       (uint64_t((4*(i+v)+3)&0x7ff) << 33) ),
#define TIN(v) tin[v],
#define DOUT(v) dout[v],
#define TOUT(v) tout[v],

int main()
{
  ofstream input;
  ofstream result;
  adco_t   dout[9];
  trig_t   tin [8];
  trig_t   tout[9];
  ap_fixed<4,4> yv;
  ap_fixed<3,3> iy;

  // Open a file to save the results
  input  .open("input_hsd_thr_ilv.dat");
  result .open("result_hsd_thr_ilv.dat");

  // Apply stimuli, call the top-level function and save the results
  uint64_t i=0;

  while(i < 10240) {
    for(unsigned j=0; j<8; j++)
      tin[j] = 0;

    if ((i&0x3ff)==0x100)
      tin[0] = 1;
    else if ((i&0x3ff)==0x200)
      tin[0] = 2;
    else
      tin[0] = 0;

    unsigned utin=0;
    for(unsigned j=0; j<8; j++) {
      utin |= (unsigned(tin[j])&3)<<(2*j);
    }

    { //  Sample data
      hsd_thr_ilv(i==0,
                  PROC_IN(DIN)
                  PROC_IN(TIN)
                  PROC_OUT(DOUT)
                  PROC_OUT(TOUT)
                  yv,
                  0x120,
                  0x5C0,
                  3,
                  4);
      unsigned uyv = (unsigned(yv)&0xf);

      for(unsigned j=0; j<8; j++) {
        input << setw(5) << hex << ((4*(i+j)+0)&0x7ff);
        input << setw(5) << hex << ((4*(i+j)+1)&0x7ff);
        input << setw(5) << hex << ((4*(i+j)+2)&0x7ff);
        input << setw(5) << hex << ((4*(i+j)+3)&0x7ff);
      }
      input << ":" << hex << utin << endl;

      result << setw(5) << dec << uyv << ":";
      unsigned utout=0;
      for(unsigned j=0; j<uyv; j++) {
        result << setw(5) << hex << ((uint64_t(dout[j])>> 0)&0xffff);
        result << setw(5) << hex << ((uint64_t(dout[j])>>16)&0xffff);
        result << setw(5) << hex << ((uint64_t(dout[j])>>32)&0xffff);
        result << setw(5) << hex << ((uint64_t(dout[j])>>48)&0xffff);
        utout |= (unsigned(tout[j])&3)<<(2*j);
      }
      result << ":" << hex << utout
             << "(" << hex << utin << ")" << endl;
    }

    i += 8;
  }
  input .close();
  result.close();

  return 0;
}
