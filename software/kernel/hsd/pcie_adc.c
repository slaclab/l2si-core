//---------------------------------------------------------------------------------
// Title         : Kernel Module For PCI-Express ADC Card
// Project       : PCI-Express ADC
//---------------------------------------------------------------------------------
// File          : pcie_adc.c
// Author        : Matt Weaver
// Created       : 09/24/2016
//---------------------------------------------------------------------------------
//
//---------------------------------------------------------------------------------
// Copyright (c) 2010 by SLAC National Accelerator Laboratory. All rights reserved.
//---------------------------------------------------------------------------------
// Modification history:
// 05/18/2010: created.
// 10/13/2015: Modified to support unlocked_ioctl if available
//             Added (irq_handler_t) cast in request_irq
//---------------------------------------------------------------------------------
#include <linux/init.h>
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/interrupt.h>
#include <linux/signal.h>
#include <linux/fs.h>
#include <linux/poll.h>
#include <linux/sched.h>
#include <linux/wait.h>
#include <asm/uaccess.h>
#include <asm/atomic.h>
#include <linux/cdev.h>
#include "pcie_adc.h"

MODULE_LICENSE("GPL");
MODULE_DEVICE_TABLE(pci, PcieAdc_Ids);
module_init(PcieAdc_Init);
module_exit(PcieAdc_Exit);

#ifndef SA_SHIRQ
/* No idea which version this changed in! */
#define SA_SHIRQ IRQF_SHARED
#endif

#define STRICT_ORDER

// Global Variable
struct AdcDevice gAdcDevices[MAX_PCI_DEVICES];

static int allocMinor(struct Minor* minor, int major, struct pci_dev* dev, int bar);

// Open Returns 0 on success, error code on failure
int PcieAdc_Open(struct inode *inode, struct file *filp) {
  struct AdcDevice * adcDevice;
  struct PcieAdcReg* adc;
  int                idx;

  // Extract structure for card
  adcDevice = container_of(inode->i_cdev, struct AdcDevice, cdev);
  filp->private_data = adcDevice;

  printk(KERN_WARNING"%s: Open: Maj %i\n",
	 MOD_NAME, adcDevice->major);

  if (adcDevice->minor.fp != 0) {
    printk(KERN_WARNING"%s: Open: module open failed.  Device already open. Maj=%i.\n",
           MOD_NAME, adcDevice->major);
    return (ERROR);
  }

  adcDevice->minor.fp    = filp;
  adcDevice->minor.inode = inode;

  adcDevice->minor.irqCount=0;
  adcDevice->minor.irqNoReq=0;
  adcDevice->minor.irqEnable=0;
  adcDevice->minor.irqDisable=0;
  adcDevice->minor.irqShared=0;
  adcDevice->minor.irqStatus=0;
  adcDevice->minor.irqFalse=0;
  adcDevice->minor.nClear=0;

  init_waitqueue_head(&adcDevice->inq);
  init_waitqueue_head(&adcDevice->outq);

  adc = (struct PcieAdcReg*)(adcDevice->minor.reg);

  adc->maxRxSize  = BUF_SIZE;
  adc->mode = 0x4;
  adc->fifoValid = 0;
  adc->fifoClear = 1;
  printk(KERN_WARNING"%s: Open: module fifo clear %x.\n", MOD_NAME, adc->fifoClear);
  adc->fifoClear = 0;
  printk(KERN_WARNING"%s: Open: module fifo clear %x.\n", MOD_NAME, adc->fifoClear);

  printk(KERN_WARNING"%s: Open: Setup QADC registers at %p\n",
         MOD_NAME, adc);


  for ( idx=0; idx < NUMBER_OF_RX_BUFFERS; idx++ ) {

    *(volatile unsigned long*)adcDevice->rxBuffer[idx]->buffer = 0;
    //    clear_bit(31,(volatile unsigned long*)adcDevice->rxBuffer[idx]->buffer);

    // Add to RX queue
    if (idx == 0) {
      adcDevice->rxFree = adcDevice->rxBuffer[idx];
      INIT_LIST_HEAD(&adcDevice->rxFree->lh);
    }
    else
      list_add_tail( &adcDevice->rxBuffer[idx]->lh, 
                     &adcDevice->rxFree->lh );
    adc->ibFifoPush[0] = adcDevice->rxBuffer[idx]->dma;
  }

  adcDevice->rxPend = adcDevice->rxFree;

  //  Set the threshold below which we will interrupt (nbuffers-1)
  adc->fifoValid = NUMBER_OF_RX_BUFFERS-1;

  adc->rxEnable = 1;

  return SUCCESS;
}


// PcieAdc_Release
// Called when the device is closed
// Returns 0 on success, error code on failure
int PcieAdc_Release(struct inode *inode, struct file *filp) {
  struct AdcDevice *adcDevice = (struct AdcDevice *)filp->private_data;
  int idx;

 if (adcDevice->minor.fp == filp) {
    adcDevice->minor.irqDisable++;
    ((struct PcieAdcReg*)adcDevice->minor.reg)->irqEnable  = 0; 
    ((struct PcieAdcReg*)adcDevice->minor.reg)->rxEnable   = 0; 
    ((struct PcieAdcReg*)adcDevice->minor.reg)->txEnable   = 0; 
    init_waitqueue_head(&adcDevice->inq);
    init_waitqueue_head(&adcDevice->outq);
    adcDevice->minor.fp = 0;

    for ( idx=0; idx < NUMBER_OF_RX_BUFFERS; idx++ ) {
      const volatile unsigned* p = (volatile unsigned*)adcDevice->rxBuffer[idx]->buffer;
      if (adcDevice->rxPend == adcDevice->rxBuffer[idx])
        printk("%s: Release -- rxPend --\n",MOD_NAME);
      //      printk("%s: Release [%u]: %x:%x:%x\n",MOD_NAME,idx,p[0],p[3],p[4]);
    }
  }
  else {
    printk("%s: Release: module close failed. Device is not open. Maj=%i\n",MOD_NAME,adcDevice->major);
    return ERROR;
  }

 printk("%s: Release: irqEnable %u, irqDisable %u, irqCount %u, irqNoReq %u,  irqShared %u,  irqStatus %x,  irqFalse %x,  nClear %u\n",
        MOD_NAME,
        adcDevice->minor.irqEnable,
        adcDevice->minor.irqDisable,
        adcDevice->minor.irqCount,
        adcDevice->minor.irqNoReq,
        adcDevice->minor.irqShared,
        adcDevice->minor.irqStatus,
        adcDevice->minor.irqFalse,
        adcDevice->minor.nClear);

  return SUCCESS;
}


// PcieAdc_Write
// Called when the device is written to
// Returns write count on success. Error code on failure.
ssize_t PcieAdc_Write(struct file *filp, const char *buffer, size_t count, loff_t *f_pos) {
  return(0);
}


// PcieAdc_Read
// Called when the device is read from
// Returns read count on success. Error code on failure.
ssize_t PcieAdc_Read(struct file *filp, char *buffer, size_t count, loff_t *f_pos) {

  int        ret, i;
  __u32      buf[count / sizeof(__u32)];
  AdcRxDesc* p64 = (AdcRxDesc *)buf;
  struct RxDesc*    desc;
  struct RxBuffer*  rxn;
  struct AdcDevice* adcDevice = (struct AdcDevice *)filp->private_data;
  __u32 __user * dp;
  __u32       maxSize;
  __u32       copyLength;

  if ( adcDevice->minor.fp != filp )
    return ERROR;

  if ( copy_from_user(buf, buffer, count) ) {
    printk(KERN_WARNING "%s: Read: failed to copy command structure from user(%p) space. Maj=%i\n",
           MOD_NAME,
           buffer,
           adcDevice->major);
    return ERROR;
  }

  if ( count != sizeof(AdcRxDesc) ) {
    printk(KERN_WARNING"%s: Read: passed size is not expected(%u) size(%u). Maj=%i\n",MOD_NAME, (unsigned)sizeof(AdcRxDesc), (unsigned)count, adcDevice->major);
    return(ERROR);
  } else {
    dp      = p64->data;
    maxSize = p64->maxSize;
  }

  while ( !get_rxpend(adcDevice,&rxn) ) {

    if ( filp->f_flags & O_NONBLOCK ) {
      return(-EAGAIN);
    }

    //  Enable interrupt before going to sleep
    adcDevice->minor.irqEnable++;

    ((struct PcieAdcReg*)adcDevice->minor.reg)->irqEnable = 1;
    if (((struct PcieAdcReg*)adcDevice->minor.reg)->irqStatus & 1) 
      adcDevice->minor.irqFalse++;

    if (wait_event_interruptible_timeout(adcDevice->inq,
                                         test_rxpend(adcDevice),
                                         HZ/1000)) {
      return (-EAGAIN);
    }
  }

  desc = (struct RxDesc*)rxn->buffer;

  // User buffer is short
  if ( maxSize < desc->length ) {
    printk(KERN_WARNING"%s: Read: user buffer is too small. Rx=%i, User=%i. Maj=%i\n",
           MOD_NAME, desc->length, maxSize, adcDevice->major);
    copyLength = maxSize;
    desc->lengthError |= 1;
  }
  else copyLength = desc->length+1;

  if ( (i=copy_to_user(dp, rxn->buffer, copyLength*sizeof(__u32))) ) {
    ret =  ERROR;
  }
  else {
    ret = copyLength;
  }

  ((struct PcieAdcReg*)adcDevice->minor.reg)->ibFifoPush[0] = rxn->dma;
  //  atomic_inc(&adcDevice->rdCount);

  return(ret);
}


// PcieAdc_Ioctl
// Called when ioctl is called on the device
// Returns success. Error code on failure.
#ifdef HAVE_UNLOCKED_IOCTL
long PcieAdc_Unlocked_Ioctl(struct file *filp, unsigned int cmd, unsigned long arg) {
#else
  int PcieAdc_Ioctl(struct inode *inode, struct file *filp, unsigned int cmd, unsigned long arg) {
#endif
    //  struct AdcDevice *adcDevice = (struct AdcDevice *)filp->private_data;

  return(ERROR);
}

#ifdef CONFIG_COMPAT
long PcieAdc_Compat_Ioctl(struct file *file, unsigned int cmd, unsigned long arg) {
#ifdef HAVE_UNLOCKED_IOCTL
  return PcieAdc_Unlocked_Ioctl(file, cmd, arg);
#else
  return PcieAdc_Ioctl(NULL, file, cmd, arg);
#endif   
}
#endif

// IRQ Handler
static irqreturn_t PcieAdc_IRQHandler(int irq, void *dev_id, struct pt_regs *regs) {
  unsigned int stat;
  unsigned int handled=0;

  struct AdcDevice *adcDevice = (struct AdcDevice *)dev_id;

  // Read IRQ Status
  // Is this the source

  stat = ((struct PcieAdcReg*)adcDevice->minor.reg)->irqStatus;
  if ( (stat & 1) != 0 ) { // ADC
    // Disable interrupts
    adcDevice->minor.irqCount++;
    adcDevice->minor.irqDisable++;
    //  Remove this test
    if (((struct PcieAdcReg*)adcDevice->minor.reg)->irqEnable==0)
      adcDevice->minor.irqNoReq++;
    ((struct PcieAdcReg*)adcDevice->minor.reg)->irqEnable = 0;
    // Queue interrupt
    wake_up_interruptible(&(adcDevice->inq));
    handled=1;
  }
  else
    adcDevice->minor.irqShared++;

  if (handled==0) return(IRQ_NONE);

  return(IRQ_HANDLED);
}

static uint PcieAdc_Poll(struct file *filp, poll_table *wait ) {
  struct AdcDevice *adcDevice = (struct AdcDevice *)filp->private_data;

  if (adcDevice->minor.fp==filp) {
    poll_wait(filp, &(adcDevice->inq), wait);
    poll_wait(filp, &(adcDevice->outq), wait);

    if ( test_rxpend(adcDevice) ) {
      return(POLLIN | POLLRDNORM); // Readable
    }
  }
  return(0);
}

// Probe device
static int PcieAdc_Probe(struct pci_dev *pcidev, const struct pci_device_id *dev_id) {
   int i, idx, res;
   dev_t chrdev = 0;
   struct AdcDevice *adcDevice;
   struct pci_device_id *id = (struct pci_device_id *) dev_id;

   // We keep device instance number in id->driver_data
   id->driver_data = -1;

   // Find empty structure
   for (i = 0; i < MAX_PCI_DEVICES; i++) {
     if (gAdcDevices[i].minor.baseHdwr == 0) {
       id->driver_data = i;
       break;
     }
   }

   // Overflow
   if (id->driver_data < 0) {
     printk(KERN_WARNING "%s: Probe: Too Many Devices.\n", MOD_NAME);
     return -EMFILE;
   }
   adcDevice = &gAdcDevices[id->driver_data];

   // Allocate device numbers for character device.
   res = alloc_chrdev_region(&chrdev, 0, 2, MOD_NAME);
   if (res < 0) {
     printk(KERN_WARNING "%s: Probe: Cannot register char device\n", MOD_NAME);
     return res;
   }

   // Init device
   cdev_init(&adcDevice->cdev, &PcieAdc_Intf);

   // Initialize device structure
   adcDevice->major         = MAJOR(chrdev);
   adcDevice->cdev.owner    = THIS_MODULE;
   adcDevice->cdev.ops      = &PcieAdc_Intf;
   adcDevice->debug         = 0;

   // Add device
   if ( cdev_add(&adcDevice->cdev, chrdev, 2) ) 
     printk(KERN_WARNING "%s: Probe: Error adding device Maj=%i\n", MOD_NAME,adcDevice->major);

   // Enable devices
   if (pci_enable_device(pcidev)) {
     printk(KERN_WARNING "%s: Could not enable device \n", MOD_NAME);
     return (ERROR);
   } 
   
   if (allocMinor(&adcDevice->minor, adcDevice->major, pcidev, 0) == ERROR)
     return (ERROR);

   // Get IRQ from pci_dev structure. 
   adcDevice->irq = pcidev->irq;
   printk(KERN_WARNING "%s: Init: IRQ %d Maj=%i\n", MOD_NAME, adcDevice->irq,adcDevice->major);

   //
   //  This is the FIFO threshold for generating an interrupt
   //
   // FIFO size for detecting DMA complete
   //   ((struct PcieAdcReg*)adcDevice->minor.reg)->rxFifoSize = NUMBER_OF_RX_BUFFERS-1;

   // Init RX Buffers
   adcDevice->rxBuffer   = (struct RxBuffer **) vmalloc(NUMBER_OF_RX_BUFFERS * sizeof(struct RxBuffer *));

   for ( idx=0; idx < NUMBER_OF_RX_BUFFERS; idx++ ) {
     adcDevice->rxBuffer[idx] = (struct RxBuffer *) vmalloc(sizeof(struct RxBuffer ));
     if ((adcDevice->rxBuffer[idx]->buffer = pci_alloc_consistent(pcidev, BUF_SIZE, &(adcDevice->rxBuffer[idx]->dma))) == NULL ) {
       printk(KERN_WARNING"%s: Init: unable to allocate rx buffer [%d/%d]. Maj=%i\n",
              MOD_NAME,idx,NUMBER_OF_RX_BUFFERS,adcDevice->major);
       break;
     }
     /*
     printk(KERN_WARNING "%s: Probe: Alloc buffer[%i] %p/%x\n", MOD_NAME, 
	    idx,
	    adcDevice->rxBuffer[idx]->buffer, 
	    (unsigned)adcDevice->rxBuffer[idx]->dma);
     */
   }

   // Request IRQ from OS.
   if (request_irq(adcDevice->irq, (irq_handler_t) PcieAdc_IRQHandler, SA_SHIRQ, MOD_NAME, adcDevice) < 0 ) {
     printk(KERN_WARNING"%s: Open: Unable to allocate IRQ. Maj=%i",MOD_NAME,adcDevice->major);
     return (ERROR);
   }

   printk("%s: Init: Driver is loaded. Maj=%i\n", MOD_NAME,adcDevice->major);
   return SUCCESS;
}


// Remove
static void PcieAdc_Remove(struct pci_dev *pcidev) {
   int  i, idx;
   struct AdcDevice *adcDevice = NULL;

   // Look for matching device
   for (i = 0; i < MAX_PCI_DEVICES; i++) {
     if ( gAdcDevices[i].minor.baseHdwr == pci_resource_start(pcidev, 0)) {
       adcDevice = &gAdcDevices[i];
       break;
     }
   }

   // Device not found
   if (adcDevice == NULL) {
     printk(KERN_WARNING "%s: Remove: Device Not Found.\n", MOD_NAME);
   }
   else {
     //  Free all rx buffers awaiting read (TBD)
     for ( idx=0; idx < NUMBER_OF_RX_BUFFERS; idx++ ) {
       /*
       printk(KERN_WARNING "%s: Remove: Free buffer[%i] %p/%x\n", MOD_NAME, 
	      idx,
	      adcDevice->rxBuffer[idx]->buffer, 
	      (unsigned)adcDevice->rxBuffer[idx]->dma);
       */
       if (adcDevice->rxBuffer[idx]->dma != 0) {
         pci_free_consistent( pcidev, BUF_SIZE, adcDevice->rxBuffer[idx]->buffer, adcDevice->rxBuffer[idx]->dma);
         if (adcDevice->rxBuffer[idx]) {
           vfree(adcDevice->rxBuffer[idx]);
         }
       }
     }

     // Unmap
     iounmap(adcDevice->minor.reg);

     release_mem_region(adcDevice->minor.baseHdwr, adcDevice->minor.baseLen);

     // Release IRQ
     free_irq(adcDevice->irq, adcDevice);

     // Unregister Device Driver
     cdev_del(&adcDevice->cdev);
     unregister_chrdev_region(MKDEV(adcDevice->major,0), 2);

     // Disable device
     pci_disable_device(pcidev);
     adcDevice->minor.baseHdwr = 0;
     printk(KERN_ALERT"%s: Remove: Driver is unloaded. Maj=%i\n", MOD_NAME,adcDevice->major);
   }
 }


 // Init Kernel Module
static int PcieAdc_Init(void) {

   /* Allocate and clear memory for all devices. */
   memset(gAdcDevices, 0, sizeof(struct AdcDevice)*MAX_PCI_DEVICES);

   printk(KERN_WARNING"%s: Init: PcieAdc Init.\n", MOD_NAME);

   // Register driver
   return(pci_register_driver(&PcieAdcDriver));
}


 // Exit Kernel Module
static void PcieAdc_Exit(void) {
   printk(KERN_WARNING"%s: Exit: PcieAdc Exit.\n", MOD_NAME);
   pci_unregister_driver(&PcieAdcDriver);
}


 // Memory map
int PcieAdc_Mmap(struct file *filp, struct vm_area_struct *vma) {

   struct AdcDevice *adcDevice = (struct AdcDevice *)filp->private_data;

   unsigned long offset = vma->vm_pgoff << PAGE_SHIFT;
   unsigned long vsize  = vma->vm_end - vma->vm_start;
   unsigned long physical;
   int result;

   if ( adcDevice->minor.fp == filp ) {

       // Check bounds of memory map
       if (vsize > adcDevice->minor.baseLen) {
	 printk(KERN_WARNING"%s: Mmap: mmap vsize %08x, baseLen %08x. Maj=%i\n", MOD_NAME,
		(unsigned int) vsize, (unsigned int) adcDevice->minor.baseLen, adcDevice->major);
	 return -EINVAL;
       }
       physical = ((unsigned long) adcDevice->minor.baseHdwr) + offset;
       result = io_remap_pfn_range(vma, vma->vm_start, physical >> PAGE_SHIFT,
				   vsize, vma->vm_page_prot);
       if (result) return -EAGAIN;

       vma->vm_ops = &PcieAdc_VmOps;
       PcieAdc_VmOpen(vma);
       return 0;  
     }

   printk(KERN_WARNING"%s: Mmap device does not map. Maj=%i\n", MOD_NAME, adcDevice->major);
   return -EINVAL;
}


void PcieAdc_VmOpen(struct vm_area_struct *vma) { }


void PcieAdc_VmClose(struct vm_area_struct *vma) { }


 // Flush queue
int PcieAdc_Fasync(int fd, struct file *filp, int mode) {
   struct AdcDevice *adcDevice = (struct AdcDevice *)filp->private_data;
   return fasync_helper(fd, filp, mode, &(adcDevice->async_queue));
}

int allocMinor(struct Minor* minor, int major, struct pci_dev* pcidev, int bar)
{
   // Get Base Address of registers from pci structure.
   minor->fp = 0;
   minor->inode = 0;
   minor->baseHdwr = pci_resource_start (pcidev, bar);
   minor->baseLen  = pci_resource_len   (pcidev, bar);
   printk(KERN_WARNING"%s: Init: Alloc bar %i [%lu/%lu].\n", MOD_NAME, bar,
	  minor->baseHdwr, minor->baseLen);

#if 0
   // Try to gain exclusive control of memory
   if (check_mem_region(minor->baseHdwr, minor->baseLen) < 0 ) {
     printk(KERN_WARNING"%s: Init: Memory in use Maj=%i.\n", MOD_NAME,major);
     return (ERROR);
   }
#endif

   request_mem_region(minor->baseHdwr, minor->baseLen, MOD_NAME);
   printk(KERN_WARNING "%s: Probe: Found card. Bar%d. Maj=%i\n", 
	  MOD_NAME, bar, major);

   // Remap the I/O register block so that it can be safely accessed.
   minor->reg = ioremap_nocache(minor->baseHdwr, minor->baseLen);
   if (! minor->reg ) {
     printk(KERN_WARNING"%s: Init: Could not remap memory Maj=%i.\n", MOD_NAME,major);
     return (ERROR);
   }

   return SUCCESS;
}

int test_rxpend(struct AdcDevice* adcDevice) {
  struct RxBuffer*  empty;
  struct RxBuffer*  next;
  struct RxDesc*    desc;
#ifdef STRICT_ORDER
  __u32             count = 0;
#endif
  empty = next = adcDevice->rxPend;
  do {
    desc = (struct RxDesc*)next->buffer;
    if (test_bit(31,(volatile unsigned long*)desc)) {
      return 1;
    }
#ifdef STRICT_ORDER
    next = (struct RxBuffer*)next->lh.next;
  } while (count--);
#else
    next = (struct RxBuffer*)next->lh.next;
  } while (next != empty);
#endif

  return 0;
}

int get_rxpend(struct AdcDevice* adcDevice, 
	       struct RxBuffer** rxn) {
  struct RxBuffer*  empty;
  struct RxBuffer*  next;
  struct RxBuffer*  first;
  struct RxDesc*    desc;
#ifdef STRICT_ORDER
  __u32             count=0;
#endif
  empty = next = adcDevice->rxPend;
  first = 0;

  do {
    desc = (struct RxDesc*)next->buffer;
    if (test_and_clear_bit(31, (volatile unsigned long*)desc)) {
      *rxn = next;
      adcDevice->rxPend = first ? first : (struct RxBuffer*)next->lh.next;
      adcDevice->minor.nClear++;
      return 1;
    }
    else if (!first)
      first = next;
    next = (struct RxBuffer*)next->lh.next;
#ifdef STRICT_ORDER
  } while (count--);
#else
  } while (next != empty);
#endif
  return 0;
}

