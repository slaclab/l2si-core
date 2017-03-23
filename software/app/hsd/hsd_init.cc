
#include <stdio.h>
#include <unistd.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <time.h>
#include <arpa/inet.h>
#include <poll.h>
#include <signal.h>
#include <new>

#include "hsd/Module.hh"
#include "hsd/Globals.hh"
#include "hsd/AxiVersion.hh"
#include "hsd/TprCore.hh"

#include <string>

extern int optind;

using namespace Pds::HSD;

void usage(const char* p) {
  printf("Usage: %s [options]\n",p);
  printf("Options: -d <dev id>\n");
  printf("\t-C <initialize clock synthesizer>\n");
  printf("\t-R <reset timing frame counters>\n");
  printf("\t-X <reset gtx timing receiver>\n");
  printf("\t-P <reverse gtx rx polarity>\n");
  printf("\t-A <dump gtx alignment>\n");
  printf("\t-0 <dump raw timing receive buffer>\n");
  printf("\t-1 <dump timing message buffer>\n");
  //  printf("Options: -a <IP addr (dotted notation)> : Use network <IP>\n");
}

static double lclsClock[] = { 125., 
                              624.75,624.75,624.75,624.75,
                              9.996,
                              312.375,
                              156.1875 };
                              
static double lclsiiClock[] = { 125., 
                                625.86,625.86,625.86,625.86,
                                14.875,
                                312.93,
                                156.46 };
                              
int main(int argc, char** argv) {

  extern char* optarg;
  char* endptr;

  char qadc='a';
  int c;
  bool lUsage = false;
  bool lSetupClkSynth = false;
  bool lReset = false;
  bool lResetRx = false;
  bool lPolarity = false;
  bool lRing0 = false;
  bool lRing1 = false;
  bool lDumpAlign = false;
  bool lTrain = false;
  bool lTrainNoReset = false;
  bool lTestSync = false;
  unsigned syncDelay[4] = {0,0,0,0};

  const char* fWrite=0;
#if 0
  bool lSetPhase = false;
  unsigned delay_int=0, delay_frac=0;
#endif
  unsigned trainRefDelay = 0;
  unsigned alignTarget = 16;
  int      alignRstLen = -1;
  const double*  clockRate = lclsClock;

  while ( (c=getopt( argc, argv, "CRS:XPA:01D:d:htT:W:")) != EOF ) {
    switch(c) {
    case 'A':
      lDumpAlign = true;
      alignTarget = strtoul(optarg,&endptr,0);
      if (endptr[0])
        alignRstLen = strtoul(endptr+1,NULL,0);
      break;
    case 'C':
      lSetupClkSynth = true;
      break;
    case 'P':
      lPolarity = true;
      break;
    case 'R':
      lReset = true;
      break;
    case 'S':
      lTestSync = true;
      syncDelay[0] = strtoul(optarg,&endptr,0);
      for(unsigned i=1; i<4; i++)
        syncDelay[i] = strtoul(endptr+1,&endptr,0);
      break;
    case 'X':
      lResetRx = true;
      break;
    case '0':
      lRing0 = true;
      break;
    case '1':
      lRing1 = true;
      break;
    case 'd':
      qadc = optarg[0];
      break;
    case 't':
      lTrainNoReset = true;
      break;
    case 'T':
      lTrain = true;
      trainRefDelay = strtoul(optarg,&endptr,0);
      break;
    case 'D':
#if 0      
      lSetPhase = true;
      delay_int  = strtoul(optarg,&endptr,0);
      if (endptr[0]) {
        delay_frac = strtoul(endptr+1,&endptr,0);
      }
#endif
      break;
    case 'W':
      fWrite = optarg;
      break;
    case '?':
    default:
      lUsage = true;
      break;
    }
  }

  if (lUsage) {
    usage(argv[0]);
    exit(1);
  }

  char devname[16];
  sprintf(devname,"/dev/qadc%c",qadc);
  int fd = open(devname, O_RDWR);
  if (fd<0) {
    perror("Open device failed");
    return -1;
  }

  Module* p = Module::create(fd);

  p->board_status();

  if (lTrain) {
    p->fmc_init();
    p->train_io(trainRefDelay);
  }

  if (lTrainNoReset) {
    p->train_io(trainRefDelay);
  }

  p->fmc_dump();

  if (lSetupClkSynth) {
    p->fmc_clksynth_setup();
  }

  if (lResetRx) {
#ifdef LCLSII
    p->tpr().setLCLSII();
#else
    p->tpr().setLCLS();
#endif
    p->tpr().resetRxPll();
    usleep(10000);
    p->tpr().resetRx();
  }

  printf("TPR [%p]\n", &(p->tpr()));
  p->tpr().dump();

  for(unsigned i=0; i<5; i++) {
    timespec tvb;
    clock_gettime(CLOCK_REALTIME,&tvb);
    unsigned vvb = p->tpr().TxRefClks;

    usleep(10000);

    timespec tve;
    clock_gettime(CLOCK_REALTIME,&tve);
    unsigned vve = p->tpr().TxRefClks;
    
    double dt = double(tve.tv_sec-tvb.tv_sec)+1.e-9*(double(tve.tv_nsec)-double(tvb.tv_nsec));
    printf("TxRefClk rate = %f MHz\n", 16.e-6*double(vve-vvb)/dt);
  }

  for(unsigned i=0; i<5; i++) {
    timespec tvb;
    clock_gettime(CLOCK_REALTIME,&tvb);
    unsigned vvb = p->tpr().RxRecClks;

    usleep(10000);

    timespec tve;
    clock_gettime(CLOCK_REALTIME,&tve);
    unsigned vve = p->tpr().RxRecClks;
    
    double dt = double(tve.tv_sec-tvb.tv_sec)+1.e-9*(double(tve.tv_nsec)-double(tvb.tv_nsec));
    printf("RxRecClk rate = %f MHz\n", 16.e-6*double(vve-vvb)/dt);
  }

  if (fWrite) {
    FILE* f = fopen(fWrite,"r");
    if (f)
      p->flash_write(f);
    else 
      perror("Failed opening prom file\n");
  }

  return 0;
}
