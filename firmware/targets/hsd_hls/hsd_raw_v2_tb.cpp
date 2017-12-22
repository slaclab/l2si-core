#include "hsd_raw_v2.h"

#include <fstream>
#include <iomanip>
#include <cstdlib>
using namespace std;

#define DIN(v) adcin_t((i+v)&0x7ff),
#define TIN(v) tin[v],
#define DOUT(v) dout[v],
#define TOUT(v) tout[v],

int main()
{
  ofstream result;
  adcout_t dout[9];
  trig_t   tin [8];
  trig_t   tout[9];
  ap_fixed<4,4> yv;
  ap_fixed<3,3> iy;

  // Open a file to save the results
  result .open("result_hsd_raw.dat");

  // Apply stimuli, call the top-level function and save the results
  int i=0;

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
      hsd_raw(false,
              PROC_IN(DIN)
              PROC_IN(TIN)
              PROC_OUT(DOUT)
              PROC_OUT(TOUT)
              yv,
              0);
      unsigned uyv = (unsigned(yv)&0xf);

      result << setw(5) << dec << uyv << ":";
      unsigned utout=0;
      for(unsigned j=0; j<uyv; j++) {
        result << setw(8) << hex << (unsigned(dout[j])&0xffff);
        utout |= (unsigned(tout[j])&3)<<(2*j);
      }
      result << ":" << hex << utout
             << "(" << hex << utin << ")" << endl;
    }

    i += 8;
  }
  result.close();

  return 0;
}
