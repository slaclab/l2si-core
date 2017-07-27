
#include <sys/types.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stdio.h>
#include <termios.h>
#include <fcntl.h>
#include <sstream>
#include <iomanip>
#include <iostream>
#include <string.h>
#include <stdlib.h>
#include <signal.h>
#include <time.h>
#include <new>

#include "../../kernel/pgpcardG3/PgpCardMod.h"
#include "../../kernel/pgpcardG3/PgpCardReg.h"

#define PAGE_SIZE 4096

FILE*               writeFile           = 0;
bool                writing             = false;

void sigHandler( int signal ) {
  psignal( signal, "Signal received by pgpWidget");
  if (writing) fclose(writeFile);
  printf("Signal handler pulling the plug\n");
  ::exit(signal);
}


#include "../../kernel/pgpcardG3/PgpCardMod.h"

using namespace std;

void printUsage(char* name) {
  printf( "Usage: %s [-d <dev>]\n",name);
}

int main (int argc, char **argv) {

  const char*         dev = "/dev/pgpcardG3_0_0";
  ::signal( SIGINT, sigHandler );

  extern char*        optarg;
  int c;
  while( ( c = getopt( argc, argv, "hd:" ) ) != EOF ) {
    switch(c) {
      case 'd':
        dev = optarg;
        break;
      case 'h':
        printUsage(argv[0]);
        return 0;
        break;
      default:
        printf("Error: Option could not be parsed, or is not supported yet!\n");
        printUsage(argv[0]);
        return 0;
        break;
    }
  }

  int fd = open( dev,  O_RDWR );
  if (fd < 0) {
    perror("Opening pgp device");
    return 1;
  }
  void volatile *mapStart;

  // Map the PCIe device from Kernel to Userspace
  mapStart = (void volatile *)mmap(NULL, PAGE_SIZE, (PROT_READ|PROT_WRITE), (MAP_SHARED|MAP_LOCKED), fd, 0);   
  if(mapStart == MAP_FAILED){
    cout << "Error: mmap() = " << dec << mapStart << endl;
    close(fd);
    return(1);   
  }

  PgpReg* pgpReg = (PgpReg*)mapStart;

  //  First, clear the Tx FIFO of pending DMAs (triggered/looping)
  unsigned lane = strtoul(dev+strlen(dev)-1,NULL,0);
  if (lane==0 || lane > NUMBER_OF_LANES) {
    cout << "Error: failed to parse lane number from device " << dev << endl;
    close(fd);
    return 1;
  }
  lane--;
  unsigned txControl = pgpReg->txControl & ~(0x10001<<lane);
  pgpReg->txControl = txControl | (0x10000<<lane); // clear FIFO
  usleep(1);
  pgpReg->txControl = txControl;

  const unsigned maxAddr = 32;
  const unsigned maxSize = 1024;
  uint* data = new uint[maxSize];

  uint _reg[maxAddr];
  for(unsigned i=0; i<maxAddr; i++) 
    _reg[i] = 0x30201000 | (0x01010101*i);

  PgpCardTx           pgpCardTx;
  pgpCardTx.model   = sizeof(&pgpCardTx);
  pgpCardTx.cmd     = IOCTL_Normal_Write;
  pgpCardTx.pgpVc   = 1;  // TDEST=1
  //  pgpCardTx.pgpVc   = 0;
  pgpCardTx.pgpLane = 0;
  pgpCardTx.size    = 2;  // address, data word
  pgpCardTx.data    = data;

  PgpCardRx           pgpCardRx;
  pgpCardRx.maxSize = maxSize;
  pgpCardRx.data    = data;
  pgpCardRx.model   = sizeof(&pgpCardRx);

  // DMA Read
  int ret;
  do {
    ret = read(fd,&pgpCardRx,sizeof(PgpCardRx));

    if ( ret != 0 ) {
      if (1) {  // print
        cout << "Ret=" << dec << ret;
        cout << ", pgpLane=" << dec << pgpCardRx.pgpLane;
        cout << ", pgpVc=" << dec << pgpCardRx.pgpVc;
        cout << ", EOFE=" << dec << pgpCardRx.eofe;
        cout << ", FifoErr=" << dec << pgpCardRx.fifoErr;
        cout << ", LengthErr=" << dec << pgpCardRx.lengthErr;
        cout << endl << "   ";

        for (int x=0; x<ret; x++) {
          cout << " 0x" << setw(8) << setfill('0') << hex << data[x];
          if ( ((x+1)%10) == 0 ) cout << endl << "   ";
        }
        cout << endl;
      }

      // Respond
      //   Application-specific interpretation
      //   First word is address
      //   Second word is write value (if supplied)
      unsigned addr = data[0];
      if (ret==1) {
        if (addr<maxAddr) {
          data[1] = _reg[addr];
          ret = write(fd,&pgpCardTx,sizeof(PgpCardTx));
          printf("  Read address %u\n",addr);
          printf("  Wrote %d words [0x%08x]\n", ret, data[1]);
        }
        else
          printf("  Read address %08x out of range\n",addr);
      }
      else if (ret==2) {
        if (addr<maxAddr) {
          _reg[addr] = data[1];
          printf("  Wrote reg[%u] = 0x%08x\n", addr, data[1]);
        }
        else
          printf("  Write address %u out of range\n",addr);
      }
      else {
        printf("  Too many words [%u]\n", ret);
      }
    }
    else {
      printf("ret == 0\n");
    }
  } while ( ret > 0 );
  if (ret < 0) {
    perror("Reading pgp device");
    return 1;
  }

  close(fd);
  return 0;
}

