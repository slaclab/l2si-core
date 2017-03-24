//---------------------------------------------------------------------------------
// Title         : Kernel Module For PCI-Express ADC Card
// Project       : PCI-Express ADC
//---------------------------------------------------------------------------------
// File          : pcie_adc.h
// Author        : Matt Weaver
// Created       : 09/24/2016
//---------------------------------------------------------------------------------
//
//---------------------------------------------------------------------------------
// Copyright (c) 2016 by SLAC National Accelerator Laboratory. All rights reserved.
//---------------------------------------------------------------------------------
// Modification history:
// 05/18/2010: created.
// 10/13/2015: Modified to support unlocked_ioctl if available
//---------------------------------------------------------------------------------
#include <linux/init.h>
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/interrupt.h>
#include <linux/fs.h>
#include <linux/poll.h>
#include <linux/cdev.h>
#include <asm/uaccess.h>

// Error codes
#define SUCCESS 0
#define ERROR   -1

// PCI IDs
#define PCI_VENDOR_ID_XILINX_PCIE 0x1A4A
#define PCI_DEVICE_ID_XILINX_PCIE 0x2100

// Max number of devices to support
#define MAX_PCI_DEVICES 8

// Module Name
#define MOD_NAME "pcie_adc"

// IoCtl Commands
#define EV_IOC_MAGIC 220
#define EV_IOCRESET  _IO(EV_IOC_MAGIC, 0)
#define EV_IOCIRQEN  _IO(EV_IOC_MAGIC, 1)
#define EV_IOCIRQDIS _IO(EV_IOC_MAGIC, 2)

// DMA Buffer Size, Bytes (could be as small as 512B)
//#define BUF_SIZE 65536
#define BUF_SIZE 1048576
#define BUFFER_FIFO_SIZE 16384
#define NUMBER_OF_RX_BUFFERS 255
//#define NUMBER_OF_RX_BUFFERS 4096
#define RX_BUFFERS_EMPTY_THR 2
#define MINIMUM_FIRMWARE_BUFFER_COUNT_THRESHOLD 32

// Address Map (partial), offset from base
struct PcieAdcReg {
  // AxiVersion
  __u32 reserved_axiv[0x20000/4];

  // AxiStreamDma
  __u32 rxEnable;
  __u32 txEnable;
  __u32 fifoClear;
  __u32 irqEnable;
  __u32 fifoValid; // W fifoThres, R b0 = inbound, b1=outbound
  __u32 maxRxSize; // inbound
  __u32 mode;      // b0 = online, b1=acknowledge
  __u32 irqStatus; // W b0=ack, R b0=ibPend, R b1=obPend

  __u32 reserved[248];

  __u32 ibFifoPop;
  __u32 obFifoPop;
  __u32 reserved_pop[62];

  __u32 loopFifoData; // RO
  __u32 reserved_loop[63];

  __u32 ibFifoPush[16];  // W data, R[0] status
  __u32 obFifoPush[16];  // R b0=full, R b1=almost full, R b2=prog full
  __u32 reserved_push[32];

  __u32 reserved_phy[16014];
  __u32 phyIrqStat;
  __u32 phyIrqMask;
  
};

// DMA descriptors
struct RxDesc {
  unsigned length      : 24;
  char     eofe        : 1;
  char     fifoError   : 1;
  char     lengthError : 1;
  char     rsvd        : 3;
  char     rxCmpl :  1;
  char     rdCmpl :  1;
};


// Structure for RX buffers
struct RxBuffer {
  struct list_head lh;
  dma_addr_t  dma;
  unchar*     buffer;
};

struct Minor {
  struct file*      fp;
  struct inode*     inode;
  ulong             baseHdwr;
  ulong             baseLen;
  void*             reg;
  uint              irqEnable;
  uint              irqDisable;
  uint              irqCount;
  uint              irqNoReq;
  uint              irqShared;
  uint              irqStatus;
  uint              irqFalse;
  uint              nClear;
};

// Device structure
struct AdcDevice {

   // Device structure
   int          major;
   struct Minor minor;
   struct cdev  cdev;

   // Queues
   wait_queue_head_t inq;
   wait_queue_head_t outq;

   // Async queue
   struct fasync_struct *async_queue;

   // Debug flag
   uint debug;

   // IRQ
   int irq;

   // One list, two pointers into the list
   // The list needs only to be singly-linked
   struct RxBuffer** rxBuffer;
   struct RxBuffer*  rxFree;
   struct RxBuffer*  rxPend;
};

// Function prototypes
int PcieAdc_Open(struct inode *inode, struct file *filp);
int PcieAdc_Release(struct inode *inode, struct file *filp);
ssize_t PcieAdc_Write(struct file *filp, const char *buf, size_t count, loff_t *f_pos);
ssize_t PcieAdc_Read(struct file *filp, char *buf, size_t count, loff_t *f_pos);
#ifdef HAVE_UNLOCKED_IOCTL
long  PcieAdc_Unlocked_Ioctl(struct file *filp, unsigned int cmd, unsigned long arg);
#else
int  PcieAdc_Ioctl(struct inode *inode, struct file *filp, unsigned int cmd, unsigned long arg);
#endif
static irqreturn_t PcieAdc_IRQHandler(int irq, void *dev_id, struct pt_regs *regs);
static int PcieAdc_Probe(struct pci_dev *pcidev, const struct pci_device_id *dev_id);
static void PcieAdc_Remove(struct pci_dev *pcidev);
static int PcieAdc_Init(void);
static void PcieAdc_Exit(void);
static uint PcieAdc_Poll(struct file *filp, poll_table *wait );
int PcieAdc_Mmap(struct file *filp, struct vm_area_struct *vma);
int PcieAdc_Fasync(int fd, struct file *filp, int mode);
void PcieAdc_VmOpen(struct vm_area_struct *vma);
void PcieAdc_VmClose(struct vm_area_struct *vma);
static int  test_rxpend(struct AdcDevice*);
static int  get_rxpend (struct AdcDevice*, struct RxBuffer**);

#ifdef CONFIG_COMPAT
long PcieAdc_Compat_Ioctl(struct file *file, unsigned int cmd, unsigned long arg);
#endif

// PCI device IDs
static struct pci_device_id PcieAdc_Ids[] = {
   { PCI_DEVICE(PCI_VENDOR_ID_XILINX_PCIE,PCI_DEVICE_ID_XILINX_PCIE) },
   { 0, }
};

// PCI driver structure
static struct pci_driver PcieAdcDriver = {
  .name     = MOD_NAME,
  .id_table = PcieAdc_Ids,
  .probe    = PcieAdc_Probe,
  .remove   = PcieAdc_Remove,
};

// Define interface routines
struct file_operations PcieAdc_Intf = {
   read:    PcieAdc_Read,
   write:   PcieAdc_Write,
#ifdef HAVE_UNLOCKED_IOCTL
   unlocked_ioctl: PcieAdc_Unlocked_Ioctl,
#else
   ioctl:   PcieAdc_Ioctl,
#endif
#ifdef CONFIG_COMPAT
  compat_ioctl: PcieAdc_Compat_Ioctl,
#endif

   open:    PcieAdc_Open,
   release: PcieAdc_Release,
   poll:    PcieAdc_Poll,
   fasync:  PcieAdc_Fasync,
   mmap:    PcieAdc_Mmap,
};

// Virtual memory operations
static struct vm_operations_struct PcieAdc_VmOps = {
  open:  PcieAdc_VmOpen,
  close: PcieAdc_VmClose,
};

// RX Structure
typedef struct {
    __u32   maxSize; // dwords
    __u32*  data;
} AdcRxDesc;

