
#include <sys/types.h>
#include <sys/mman.h>

#include <linux/types.h>
#include <unistd.h>
#include <stdio.h>
#include <termios.h>
#include <fcntl.h>
#include <sstream>
#include <string>
#include <iomanip>
#include <iostream>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>

#include "../../kernel/pgpcardG3/PgpCardMod.h"
#include "../../kernel/pgpcardG3/PgpCardReg.h"

#define PAGE_SIZE 4096

using namespace std;

void showUsage(const char* p) {
  printf("Usage: %p [options]\n", p);
  printf("Options:\n"
         "\t-d <dev>   Use pgpcard <dev>\n"
         "\t-T <code>  Trigger on code/rate\n"
         "\t-e <lanes> Enable transmission on lanes\n"
         "\t-s <words> Tx size in 32b words\n"
         "\t-n <count> Number of transmissions in ring\n");
}

int main (int argc, char **argv) {
  int           fd;
  int           ret;
  unsigned      lane=0;
  unsigned      opCode=0;
  unsigned      size  =512;
  unsigned      ntx   =1;
  const char*   dev   =0;

  int c;

  while((c=getopt(argc,argv,"d:T:e:n:s:")) != EOF) {
    switch(c) {
    case 'd': dev    = optarg; break;
    case 'T': opCode = strtoul(optarg,NULL,0); break;
    case 'e': lane   = strtoul(optarg,NULL,0); break;
    case 'n': ntx    = strtoul(optarg,NULL,0); break;
    case 's': size   = strtoul(optarg,NULL,0); break;
    default:
      showUsage(argv[0]); return 0;
    }
  }

  if (!dev) {
    showUsage(argv[0]);
    return 0;
  }

  if ( (fd = open(dev, O_RDWR)) <= 0 ) {
    cout << "Error opening " << dev << endl;
    perror(dev);
    return(1);
  }

  void volatile *mapStart;
  PgpReg* pgpReg;

  // Map the PCIe device from Kernel to Userspace
  mapStart = (void volatile *)mmap(NULL, PAGE_SIZE, (PROT_READ|PROT_WRITE), (MAP_SHARED|MAP_LOCKED), fd, 0);   
  if(mapStart == MAP_FAILED){
    cout << "Error: mmap() = " << dec << mapStart << endl;
    close(fd);
    return(1);   
  }

  pgpReg = (PgpReg*)mapStart;

  //  First, clear the FIFO of pending Tx DMAs
  unsigned txControl = pgpReg->txControl & ~(0x10001<<lane);
  pgpReg->txControl = txControl | (0x10000<<lane);

  //  Second, load the FIFO with the new Tx data
  if (opCode) {
    PgpCardTx     pgpCardTx;
    time_t        t;
    unsigned      count=0;
    unsigned      vc=0;
    unsigned*     data;
    unsigned      x;

    time(&t);
    srandom(t);

    data = (uint *)malloc(sizeof(uint)*size);

    { 
      unsigned debug = 0;
      pgpCardTx.cmd = IOCTL_Set_Debug;
      pgpCardTx.model = sizeof(&pgpCardTx);
      pgpCardTx.size = sizeof(PgpCardTx);
      pgpCardTx.data = reinterpret_cast<__u32*>(debug);

      printf("Setting debug\n");
      write(fd,&pgpCardTx,sizeof(PgpCardTx));
    }

    { 
      pgpCardTx.cmd = IOCTL_Tx_Loop_Clear;
      pgpCardTx.model = sizeof(&pgpCardTx);
      pgpCardTx.size = sizeof(PgpCardTx);
      pgpCardTx.data = (__u32*)(1UL<<lane);

      printf("Clearing Tx for lane %x\n",lane);
      write(fd,&pgpCardTx,sizeof(PgpCardTx));
    }

    pgpCardTx.model   = (sizeof(data));
    pgpCardTx.cmd     = IOCTL_Looped_Write;
    pgpCardTx.pgpVc   = vc;
    pgpCardTx.pgpLane = lane;
    pgpCardTx.size    = size;
    pgpCardTx.data    = (__u32*)data;
    cout << endl;
    while (count++ < ntx) {
      // DMA Write
      cout << "Sending:";
      cout << " Lane=" << dec << lane;
      cout << ", Vc=" << dec << vc << endl;
      for (x=0; x<size; x++) {
        data[x] = random();
        if (x<40) {
          cout << " 0x" << setw(8) << setfill('0') << hex << data[x];
          if ( ((x+1)%10) == 0 ) cout << endl << "   ";
        }
      }
      cout << endl;
      ret = write(fd,&pgpCardTx,sizeof(PgpCardTx));
      cout << "Returned " << dec << ret << endl;
    }
    free(data);
  }

  //  Finally, enable the FIFO
  if (opCode) 
    pgpReg->txControl = txControl | (1<<lane);
  else
    pgpReg->txControl = txControl;

  printf("TxControl: %08x\n", pgpReg->txControl);

  pgpReg->txOpCode = opCode;
  printf("TxOpCode: %08x\n", pgpReg->txOpCode);

  close(fd);
  return 0;
}
