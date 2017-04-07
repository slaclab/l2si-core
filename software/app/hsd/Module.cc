#include "hsd/Module.hh"

#include "hsd/AxiVersion.hh"
#include "hsd/TprCore.hh"
#include "hsd/RxDesc.hh"
#include "hsd/ClkSynth.hh"
#include "hsd/Mmcm.hh"
#include "hsd/DmaCore.hh"
#include "hsd/PhyCore.hh"
#include "hsd/RingBuffer.hh"
#include "hsd/I2cSwitch.hh"
#include "hsd/LocalCpld.hh"
#include "hsd/FmcSpi.hh"
#include "hsd/QABase.hh"
#include "hsd/Adt7411.hh"
#include "hsd/Tps2481.hh"
#include "hsd/AdcCore.hh"
#include "hsd/AdcSync.hh"
#include "hsd/FmcCore.hh"
#include "hsd/FlashController.hh"

#include <string>
#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <poll.h>

namespace Pds {
  namespace HSD {
    class Module::PrivateData {
    public:
      //  Initialize busses
      void init();

      //  Initialize clock tree and IO training
      void fmc_init();

      int  train_io(unsigned);

      void enable_test_pattern(TestPattern);
      void disable_test_pattern();
      void enable_cal ();
      void disable_cal();
      void setAdcMux(bool     interleave,
                     unsigned channels);

      void setRxAlignTarget(unsigned);
      void setRxResetLength(unsigned);
      void dumpRxAlign     () const;

      //
      //  Low level API
      //
    public:
      Pds::HSD::AxiVersion version;
      uint32_t rsvd_to_0x08000[(0x8000-sizeof(Pds::HSD::AxiVersion))/4];

      FlashController      flash;
      uint32_t rsvd_to_0x10000[(0x8000-sizeof(FlashController))/4];

      I2cSwitch i2c_sw_control;  // 0x10000
      ClkSynth  clksynth;        // 0x10400
      LocalCpld local_cpld;      // 0x10800
      Adt7411   vtmon1;          // 0x10C00
      Adt7411   vtmon2;          // 0x11000
      Adt7411   vtmon3;          // 0x11400
      Tps2481   imona;           // 0x11800
      Tps2481   imonb;           // 0x11C00
      Adt7411   vtmona;          // 0x12000
      FmcSpi    fmc_spi;         // 0x12400
      uint32_t rsvd_to_0x20000[(0x10000-12*0x400)/4];

      // DMA
      DmaCore           dma_core; // 0x20000
      uint32_t rsvd_to_0x30000[(0x10000-sizeof(DmaCore))/4];

      // PHY
      PhyCore           phy_core; // 0x30000
      uint32_t rsvd_to_0x40000[(0x10000-sizeof(PhyCore))/4];

      // Timing
      Pds::HSD::TprCore  tpr;     // 0x40000
      uint32_t rsvd_to_0x50000  [(0x10000-sizeof(Pds::HSD::TprCore))/4];

      RingBuffer         ring0;   // 0x50000
      uint32_t rsvd_to_0x60000  [(0x10000-sizeof(RingBuffer))/4];

      RingBuffer         ring1;   // 0x60000
      uint32_t rsvd_to_0x70000  [(0x10000-sizeof(RingBuffer))/4];
      uint32_t rsvd_to_0x80000  [0x10000/4];

      //  App registers
      QABase   base;             // 0x80000
      uint32_t rsvd_to_0x80800  [(0x800-sizeof(QABase))/4];

      Mmcm     mmcm;             // 0x80800
      FmcCore  fmca_core;        // 0x81000
      AdcCore  adca_core;        // 0x81400
      FmcCore  fmcb_core;        // 0x81800
      AdcCore  adcb_core;        // 0x81C00
      AdcSync  adc_sync;
      uint32_t rsvd_to_0x90000  [(0xE000-sizeof(AdcSync))/4];

      uint32_t gthAlign[10];     // 0x90000
      uint32_t rsvd_to_0x90100  [54];
      uint32_t gthAlignTarget;
      uint32_t gthAlignLast;
    };
  };
};

using namespace Pds::HSD;

Module* Module::create(int fd)
{
  void* ptr = mmap(0, sizeof(Pds::HSD::Module::PrivateData), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
  if (ptr == MAP_FAILED) {
    perror("Failed to map");
    return 0;
  }

  Pds::HSD::Module* m = new Pds::HSD::Module;
  m->p = reinterpret_cast<Pds::HSD::Module::PrivateData*>(ptr);
  m->_fd = fd;

  return m;
}

Module::~Module()
{
}

int Module::read(uint32_t* data, unsigned data_size)
{
  RxDesc* desc = new RxDesc(data,data_size);
  int nw = ::read(_fd, desc, sizeof(*desc));
  delete desc;

  nw *= sizeof(uint32_t);
  if (nw>=32)
    data[7] = nw - 8*sizeof(uint32_t);

  return nw;
}

enum 
{
        FMC12X_INTERNAL_CLK = 0,                                                /*!< FMC12x_init() configure the FMC12x for internal clock operations */
        FMC12X_EXTERNAL_CLK = 1,                                                /*!< FMC12x_init() configure the FMC12x for external clock operations */
        FMC12X_EXTERNAL_REF = 2,                                                /*!< FMC12x_init() configure the FMC12x for external reference operations */

        FMC12X_VCXO_TYPE_2500MHZ = 0,                                   /*!< FMC12x_init() Vco on the card is 2.5GHz */
        FMC12X_VCXO_TYPE_2200MHZ = 1,                                   /*!< FMC12x_init() Vco on the card is 2.2GHz */
        FMC12X_VCXO_TYPE_2000MHZ = 2,                                   /*!< FMC12x_init() Vco on the card is 2.0GHz */
};

enum 
{
        CLOCKTREE_CLKSRC_EXTERNAL = 0,                                                  /*!< FMC12x_clocktree_init() configure the clock tree for external clock operations */
        CLOCKTREE_CLKSRC_INTERNAL = 1,                                                  /*!< FMC12x_clocktree_init() configure the clock tree for internal clock operations */
        CLOCKTREE_CLKSRC_EXTREF   = 2,                                                  /*!< FMC12x_clocktree_init() configure the clock tree for external reference operations */

        CLOCKTREE_VCXO_TYPE_2500MHZ = 0,                                                /*!< FMC12x_clocktree_init() Vco on the card is 2.5GHz */
        CLOCKTREE_VCXO_TYPE_2200MHZ = 1,                                                /*!< FMC12x_clocktree_init() Vco on the card is 2.2GHz */
        CLOCKTREE_VCXO_TYPE_2000MHZ = 2,                                                /*!< FMC12x_clocktree_init() Vco on the card is 2.0GHz */
        CLOCKTREE_VCXO_TYPE_1600MHZ = 3,                                                /*!< FMC12x_clocktree_init() Vco on the card is 1.6 GHZ */
        CLOCKTREE_VCXO_TYPE_BUILDIN = 4,                                                /*!< FMC12x_clocktree_init() Vco on the card is the AD9517 build in VCO */
        CLOCKTREE_VCXO_TYPE_2400MHZ = 5                                                 /*!< FMC12x_clocktree_init() Vco on the card is 2.4GHz */
};

enum 
{       // clock sources
        CLKSRC_EXTERNAL_CLK = 0,                                                /*!< FMC12x_cpld_init() external clock. */
        CLKSRC_INTERNAL_CLK_EXTERNAL_REF = 3,                   /*!< FMC12x_cpld_init() internal clock / external reference. */
        CLKSRC_INTERNAL_CLK_INTERNAL_REF = 6,                   /*!< FMC12x_cpld_init() internal clock / internal reference. */

        // sync sources
        SYNCSRC_EXTERNAL_TRIGGER = 0,                                   /*!< FMC12x_cpld_init() external trigger. */
        SYNCSRC_HOST = 1,                                                               /*!< FMC12x_cpld_init() software trigger. */
        SYNCSRC_CLOCK_TREE = 2,                                                 /*!< FMC12x_cpld_init() signal from the clock tree. */
        SYNCSRC_NO_SYNC = 3,                                                    /*!< FMC12x_cpld_init() no synchronization. */

        // FAN enable bits
        FAN0_ENABLED = (0<<4),                                                  /*!< FMC12x_cpld_init() FAN 0 is enabled */
        FAN1_ENABLED = (0<<5),                                                  /*!< FMC12x_cpld_init() FAN 1 is enabled */
        FAN2_ENABLED = (0<<6),                                                  /*!< FMC12x_cpld_init() FAN 2 is enabled */
        FAN3_ENABLED = (0<<7),                                                  /*!< FMC12x_cpld_init() FAN 3 is enabled */
        FAN0_DISABLED = (1<<4),                                                 /*!< FMC12x_cpld_init() FAN 0 is disabled */
        FAN1_DISABLED = (1<<5),                                                 /*!< FMC12x_cpld_init() FAN 1 is disabled */
        FAN2_DISABLED = (1<<6),                                                 /*!< FMC12x_cpld_init() FAN 2 is disabled */
        FAN3_DISABLED = (1<<7),                                                 /*!< FMC12x_cpld_init() FAN 3 is disabled */

        // LVTTL bus direction (HDMI connector)
        DIR0_INPUT      = (0<<0),                                                       /*!< FMC12x_cpld_init() DIR 0 is input */
        DIR1_INPUT      = (0<<1),                                                       /*!< FMC12x_cpld_init() DIR 1 is input */
        DIR2_INPUT      = (0<<2),                                                       /*!< FMC12x_cpld_init() DIR 2 is input */
        DIR3_INPUT      = (0<<3),                                                       /*!< FMC12x_cpld_init() DIR 3 is input */
        DIR0_OUTPUT     = (1<<0),                                                       /*!< FMC12x_cpld_init() DIR 0 is output */
        DIR1_OUTPUT     = (1<<1),                                                       /*!< FMC12x_cpld_init() DIR 1 is output */
        DIR2_OUTPUT     = (1<<2),                                                       /*!< FMC12x_cpld_init() DIR 2 is output */
        DIR3_OUTPUT     = (1<<3),                                                       /*!< FMC12x_cpld_init() DIR 3 is output */
};

void Module::PrivateData::init()
{
  i2c_sw_control.select(I2cSwitch::PrimaryFmc); 
  fmc_spi.initSPI();
  i2c_sw_control.select(I2cSwitch::SecondaryFmc); 
  fmc_spi.initSPI();
}

void Module::PrivateData::fmc_init()
{
// if(FMC12x_init(AddrSipFMC12xBridge, AddrSipFMC12xClkSpi, AddrSipFMC12xAdcSpi, AddrSipFMC12xCpldSpi, AddrSipFMC12xAdcPhy, 
//                modeClock, cardType, GA, typeVco, carrierKC705)!=FMC12X_ERR_OK) {

#ifdef TIMINGREF
  const uint32_t clockmode = FMC12X_EXTERNAL_REF;
#else
  const uint32_t clockmode = FMC12X_INTERNAL_CLK;
#endif

  //  uint32_t clksrc_cpld;
  uint32_t clksrc_clktree;
  uint32_t vcotype = 0; // default 2500 MHz

  if(clockmode==FMC12X_INTERNAL_CLK) {
    //    clksrc_cpld    = CLKSRC_INTERNAL_CLK_INTERNAL_REF;
    clksrc_clktree = CLOCKTREE_CLKSRC_INTERNAL;
  }
  else if(clockmode==FMC12X_EXTERNAL_REF) {
    //    clksrc_cpld    = CLKSRC_INTERNAL_CLK_EXTERNAL_REF;
    clksrc_clktree = CLOCKTREE_CLKSRC_EXTREF;
  }
  else {
    //    clksrc_cpld    = CLKSRC_EXTERNAL_CLK;
    clksrc_clktree = CLOCKTREE_CLKSRC_EXTERNAL;
  }

  if (!fmca_core.present()) {
    printf("FMC card A not present\n");
    printf("FMC init failed!\n");
    return;
  }

  {
    printf("FMC card A initializing\n");
    i2c_sw_control.select(I2cSwitch::PrimaryFmc); 
    if (fmc_spi.cpld_init())
      printf("cpld_init failed!\n");
    if (fmc_spi.clocktree_init(clksrc_clktree, vcotype))
      printf("clocktree_init failed!\n");
  }

  if (fmcb_core.present()) {
    printf("FMC card B initializing\n");
    i2c_sw_control.select(I2cSwitch::SecondaryFmc); 
    if (fmc_spi.cpld_init())
      printf("cpld_init failed!\n");
    if (fmc_spi.clocktree_init(clksrc_clktree, vcotype))
      printf("clocktree_init failed!\n");
  }
}

int Module::PrivateData::train_io(unsigned ref_delay)
{
  //
  //  IO Training
  //
  if (!fmca_core.present()) {
    printf("FMC card A not present\n");
    printf("IO training failed!\n");
    return -1;
  }

  bool fmcb_present = fmcb_core.present();

  i2c_sw_control.select(I2cSwitch::PrimaryFmc); 
  if (fmc_spi.adc_enable_test(Flash11)) 
    return -1;

  if (fmcb_present) {
    i2c_sw_control.select(I2cSwitch::SecondaryFmc); 
    if (fmc_spi.adc_enable_test(Flash11))
      return -1;
  }

  //  adcb_core training is driven by adca_core
  adca_core.init_training(0x08);
  if (fmcb_present)
    adcb_core.init_training(ref_delay);

  adca_core.start_training();

  adca_core.dump_training();
  
  if (fmcb_present)
    adcb_core.dump_training();

  i2c_sw_control.select(I2cSwitch::PrimaryFmc); 
  if (fmc_spi.adc_disable_test())
    return -1;
  if (fmc_spi.adc_enable_test(Flash11))
    return -1;

  if (fmcb_present) {
    i2c_sw_control.select(I2cSwitch::SecondaryFmc); 
    if (fmc_spi.adc_disable_test())
      return -1;
    if (fmc_spi.adc_enable_test(Flash11))
      return -1;
  }

  adca_core.loop_checking();
  if (fmcb_present)
    adcb_core.loop_checking();

  i2c_sw_control.select(I2cSwitch::PrimaryFmc); 
  if (fmc_spi.adc_disable_test())
    return -1;

  if (fmcb_present) {
    i2c_sw_control.select(I2cSwitch::SecondaryFmc); 
    if (fmc_spi.adc_disable_test())
      return -1;
  }

  return 0;
}

void Module::PrivateData::enable_test_pattern(TestPattern p)
{
  if (p < 8) {
    i2c_sw_control.select(I2cSwitch::PrimaryFmc); 
    fmc_spi.adc_enable_test(p);
    if (fmcb_core.present()) {
      i2c_sw_control.select(I2cSwitch::SecondaryFmc); 
      fmc_spi.adc_enable_test(p);
    }
  }
  else
    base.enableDmaTest(true);
}

void Module::PrivateData::disable_test_pattern()
{
  i2c_sw_control.select(I2cSwitch::PrimaryFmc); 
  fmc_spi.adc_disable_test();
  if (fmcb_core.present()) {
    i2c_sw_control.select(I2cSwitch::SecondaryFmc); 
    fmc_spi.adc_disable_test();
  }
  base.enableDmaTest(false);
}

void Module::PrivateData::enable_cal()
{
  i2c_sw_control.select(I2cSwitch::PrimaryFmc); 
  fmc_spi.adc_enable_cal();
  fmca_core.cal_enable();
  if (fmcb_core.present()) {
    i2c_sw_control.select(I2cSwitch::SecondaryFmc); 
    fmc_spi.adc_enable_cal();
    fmca_core.cal_enable();
  }
}

void Module::PrivateData::disable_cal()
{
  i2c_sw_control.select(I2cSwitch::PrimaryFmc); 
  fmca_core.cal_disable();
  fmc_spi.adc_disable_cal();
  if (fmcb_core.present()) {
    i2c_sw_control.select(I2cSwitch::SecondaryFmc); 
    fmcb_core.cal_disable();
    fmc_spi.adc_disable_cal();
  }
}

void Module::PrivateData::setRxAlignTarget(unsigned t)
{
  unsigned v = gthAlignTarget;
  v &= ~0x3f;
  v |= (t&0x3f);
  gthAlignTarget = v;
}

void Module::PrivateData::setRxResetLength(unsigned len)
{
  unsigned v = gthAlignTarget;
  v &= ~0xf0000;
  v |= (len&0xf)<<16;
  gthAlignTarget = v;
}
 
void Module::PrivateData::dumpRxAlign     () const
{
  printf("\nTarget: %u\tRstLen: %u\tLast: %u\n",
         gthAlignTarget&0x7f,
         (gthAlignTarget>>16)&0xf, 
         gthAlignLast&0x7f);
  for(unsigned i=0; i<128; i++) {
    printf(" %04x",(gthAlign[i/2] >> (16*(i&1)))&0xffff);
    if ((i%10)==9) printf("\n");
  }
  printf("\n");
}

void Module::PrivateData::setAdcMux(bool     interleave,
                                    unsigned channels)
{
  if (interleave) {
    base.setChannels(channels);
    base.setMode( QABase::Q_ABCD );
    i2c_sw_control.select(I2cSwitch::PrimaryFmc); 
    fmc_spi.setAdcMux(interleave, channels&0x0f);
    if (fmcb_core.present())
      i2c_sw_control.select(I2cSwitch::SecondaryFmc); 
      fmc_spi.setAdcMux(interleave, (channels>>4)&0x0f);
  }
  else {
    if (fmcb_core.present()) {
      base.setChannels(0xff);
      base.setMode( QABase::Q_NONE );
      i2c_sw_control.select(I2cSwitch::PrimaryFmc); 
      fmc_spi.setAdcMux(interleave, (channels>>0)&0xf);
      i2c_sw_control.select(I2cSwitch::SecondaryFmc); 
      fmc_spi.setAdcMux(interleave, (channels>>4)&0xf);
    }
    else {
      base.setChannels(0xff);
      base.setMode( QABase::Q_NONE );
      i2c_sw_control.select(I2cSwitch::PrimaryFmc); 
      fmc_spi.setAdcMux(interleave, channels&0xf);
    }
  }
}

void Module::init() { p->init(); }

void Module::fmc_init() { p->fmc_init(); }

void Module::fmc_dump() {
  if (p->fmca_core.present())
    for(unsigned i=0; i<8; i++) {
      p->fmca_core.selectClock(i);
      usleep(100000);
      printf("Clock [%i]: rate %f MHz\n", i, p->fmca_core.clockRate()*1.e-6);
    }
  
  if (p->fmcb_core.present())
    for(unsigned i=0; i<8; i++) {
      p->fmcb_core.selectClock(i);
      usleep(100000);
      printf("Clock [%i]: rate %f MHz\n", i, p->fmcb_core.clockRate()*1.e-6);
    }
}

void Module::fmc_clksynth_setup()
{
  p->i2c_sw_control.select(I2cSwitch::LocalBus);  // ClkSynth is on local bus
  p->clksynth.setup();
  p->clksynth.dump ();
}

void Module::board_status()
{
  printf("Axi Version [%p]: BuildStamp[%p]: %s\n", 
         &(p->version), &(p->version.BuildStamp[0]), p->version.buildStamp().c_str());

  p->i2c_sw_control.select(I2cSwitch::LocalBus);
  p->i2c_sw_control.dump();
  
  printf("Local CPLD revision: 0x%x\n", p->local_cpld.revision());
  printf("Local CPLD GAaddr  : 0x%x\n", p->local_cpld.GAaddr  ());
  p->local_cpld.GAaddr(0);

  printf("vtmon1 mfg:dev %x:%x\n", p->vtmon1.manufacturerId(), p->vtmon1.deviceId());
  printf("vtmon2 mfg:dev %x:%x\n", p->vtmon2.manufacturerId(), p->vtmon2.deviceId());
  printf("vtmon3 mfg:dev %x:%x\n", p->vtmon3.manufacturerId(), p->vtmon3.deviceId());

  p->vtmon1.dump();
  p->vtmon2.dump();
  p->vtmon3.dump();

  p->imona.dump();
  p->imonb.dump();

  printf("FMC A [%p]: %s present power %s\n",
         &p->fmca_core,
         p->fmca_core.present() ? "":"not",
         p->fmca_core.powerGood() ? "up":"down");

  printf("FMC B [%p]: %s present power %s\n",
         &p->fmcb_core,
         p->fmcb_core.present() ? "":"not",
         p->fmcb_core.powerGood() ? "up":"down");

  p->i2c_sw_control.select(I2cSwitch::PrimaryFmc); 
  p->i2c_sw_control.dump();

  printf("vtmona mfg:dev %x:%x\n", p->vtmona.manufacturerId(), p->vtmona.deviceId());


  p->i2c_sw_control.select(I2cSwitch::SecondaryFmc); 
  p->i2c_sw_control.dump();

  printf("vtmonb mfg:dev %x:%x\n", p->vtmona.manufacturerId(), p->vtmona.deviceId());
}

void Module::flash_write(FILE* f)
{
  p->flash.write(f);
}

int  Module::train_io(unsigned v) { return p->train_io(v); }

void Module::enable_test_pattern(TestPattern t) { p->enable_test_pattern(t); }

void Module::disable_test_pattern() { p->disable_test_pattern(); }

void Module::enable_cal () { p->enable_cal(); }

void Module::disable_cal() { p->disable_cal(); }

void Module::setAdcMux(unsigned channels)
{
  if (p->fmcb_core.present()) {
    p->base.setChannels(0xff);
    p->base.setMode( QABase::Q_NONE );
    p->i2c_sw_control.select(I2cSwitch::PrimaryFmc); 
    p->fmc_spi.setAdcMux((channels>>0)&0xf);
    p->i2c_sw_control.select(I2cSwitch::SecondaryFmc); 
    p->fmc_spi.setAdcMux((channels>>4)&0xf);
  }
  else {
    p->base.setChannels(0xf);
    p->base.setMode( QABase::Q_NONE );
    p->i2c_sw_control.select(I2cSwitch::PrimaryFmc); 
    p->fmc_spi.setAdcMux(channels&0xf);
  }
}

void Module::setAdcMux(bool     interleave,
                       unsigned channels) 
{ p->setAdcMux(interleave, channels); }

const Pds::HSD::AxiVersion& Module::version() const { return p->version; }
Pds::HSD::TprCore&    Module::tpr    () { return p->tpr; }

void Module::setRxAlignTarget(unsigned v) { p->setRxAlignTarget(v); }
void Module::setRxResetLength(unsigned v) { p->setRxResetLength(v); }
void Module::dumpRxAlign     () const { p->dumpRxAlign(); }

void Module::sample_init(unsigned length, 
                         unsigned delay,
                         unsigned prescale)
{
  p->base.init();
  p->base.samples  = length;
  p->base.prescale = (delay<<6) | (prescale&0x3f);

  p->dma_core.init(32+48*length);

  p->dma_core.dump();

  //  p->dma.setEmptyThr(emptyThr);
  //  p->base.dmaFullThr=fullThr;

  p->base.dump();
  //  p->dma.dump();
  p->tpr.dump();

  //  flush out all the old
  { printf("flushing\n");
    unsigned nflush=0;
    uint32_t* data = new uint32_t[1<<20];
    RxDesc* desc = new RxDesc(data,1<<20);
    pollfd pfd;
    pfd.fd = _fd;
    pfd.events = POLLIN;
    while(poll(&pfd,1,0)>0) { 
      ::read(_fd, desc, sizeof(*desc));
      nflush++;
    }
    delete[] data;
    delete desc;
    printf("done flushing [%u]\n",nflush);
  }
    
  p->base.resetCounts();
}

void Module::trig_lcls  (unsigned eventcode)
{
  p->base.setupLCLS(eventcode);
}

void Module::trig_lclsii(unsigned fixedrate)
{
  p->base.setupLCLSII(fixedrate);
}

void Module::trig_daq   (unsigned partition)
{
  p->base.setupDaq(partition);
}

void Module::start()
{
  p->base.start();
}

void Module::stop()
{
  p->base.stop();
  p->dma_core.dump();
}

unsigned Module::get_offset(unsigned channel)
{
  p->i2c_sw_control.select((channel&0x4)==0 ? 
                           I2cSwitch::PrimaryFmc :
                           I2cSwitch::SecondaryFmc); 
  return p->fmc_spi.get_offset(channel&0x3);
}

unsigned Module::get_gain(unsigned channel)
{
  p->i2c_sw_control.select((channel&0x4)==0 ? 
                           I2cSwitch::PrimaryFmc :
                           I2cSwitch::SecondaryFmc); 
  return p->fmc_spi.get_gain(channel&0x3);
}

void Module::set_offset(unsigned channel, unsigned value)
{
  p->i2c_sw_control.select((channel&0x4)==0 ? 
                           I2cSwitch::PrimaryFmc :
                           I2cSwitch::SecondaryFmc); 
  p->fmc_spi.set_offset(channel&0x3,value);
}

void Module::set_gain(unsigned channel, unsigned value)
{
  p->i2c_sw_control.select((channel&0x4)==0 ? 
                           I2cSwitch::PrimaryFmc :
                           I2cSwitch::SecondaryFmc); 
  p->fmc_spi.set_gain(channel&0x3,value);
}
