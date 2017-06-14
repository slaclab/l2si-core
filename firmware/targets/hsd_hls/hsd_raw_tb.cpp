#include "hsd_raw.h"

#include <fstream>
#include <iomanip>
#include <cstdlib>
using namespace std;

#define DIN(v) adcin_t((i+v)&0x3ff),
#define DOUT(v) dout[v],
#define TOUT(v) tout[v],

int main()
{
  ofstream result;
  adcout_t dout[8];
  tout_t   tout[8];
  ap_fixed<4,4> yv;

  // Open a file to save the results
  result.open("result_hsd_raw.dat");
  result << "Running" << endl;

  // Apply stimuli, call the top-level function and save the results
  int i=0;

  while(i < 10240) {
    //  Sample data
    hsd_raw((i%2696)==0,  // clks between beam pulses
            PROC_IN(DIN)
            PROC_IN(DOUT)
            PROC_IN(TOUT)
            yv,
            0);
    unsigned uyv = (unsigned(yv)&0xf);

    result << setw(5) << uyv << ":";
    for(unsigned j=0; j<uyv; j++)
      result << setw(8) << dout[j];
    result << ":" << setw(5) << tout[uyv-1] << endl;

    i += 8;
  }
  result.close();

  return 0;
}
