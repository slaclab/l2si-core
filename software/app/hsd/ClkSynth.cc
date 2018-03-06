#include "hsd/ClkSynth.hh"
#include "hsd/Globals.hh"

#include <time.h>
#include <unistd.h>

static double tdiff(const timespec& tvb, 
                    const timespec& tve)
{
  double diff = double(tve.tv_sec-tvb.tv_sec) + 
    1.e-9*(double(tve.tv_nsec)-double(tvb.tv_nsec));
  return diff;
}

static const uint8_t enable_mask[] = {
  0x00,0x00,0x00,0x00,0x00,0x00,0x1D,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x80,0xff,0xff,
  0xff,0xff,0xff,0xff,0xff,0xff,0x1f,0x1f,0x1f,0x1f,
  0xff,0x7f,0x3f,0x00,0x00,0xff,0xff,0xff,0xff,0xff,
  0xff,0xff,0x7f,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
  0xff,0xff,0x3f,0x7f,0xff,0xff,0xff,0xff,0xff,0xff,
  0xff,0xff,0xff,0x3f,0x7f,0xff,0xff,0xff,0xff,0xff,
  0xff,0xff,0xff,0xff,0x3f,0x7f,0xff,0xff,0xff,0xff,
  0xff,0xff,0xff,0xff,0xff,0x3f,0x00,0xff,0xff,0xff,
  0xff,0xff,0xff,0xff,0xff,0xff,0xbf,0xff,0x7f,0xff,
  0xff,0xff,0x7f,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x0f,
  0x0f,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
  0xff,0xff,0xff,0xff,0xff,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0xff,0xff,0xff,0xff,0xff,0xff,0x0f,0x0f,
  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
  0xff,0x0f,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
  0xff,0xff,0xff,0x0f,0xff,0xff,0xff,0xff,0xff,0xff,
  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x04,0x00,0x00,0x00,
  0xff,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x00,0xff,0x02,0x00,0x00,0x00,0xff,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0xff,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xff,0xff,0xff,
  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x0f,
  0x00,0x00,0x00,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
  0xff,0xff,0xff,0xff,0xff,0x0f,0x00,0x00,0x00,0xff,
  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
  0xff,0x0f,0x00,0x00,0x00,0xff,0xff,0xff,0xff,0xff,
  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x0f,0x00,0x00,
  0x00};

 //  4 x 125MHz
  /*
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0x70, 0x0F, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x70, 0x03, 0x42, 
0xB0, 0xC0, 0xC0, 0xC0, 0xC0, 0x00, 0x06, 0x06, 0x06, 0x06, 
0x63, 0x0C, 0x23, 0x00, 0x00, 0x00, 0x00, 0x14, 0x3A, 0x00, 
0xC4, 0x07, 0x10, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x01, 
0x00, 0x00, 0x00, 0x10, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 
0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x08, 0x00, 0x00, 0x00, 
0x00, 0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x08, 0x00, 0x00, 
0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x30, 0x00, 
0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 
0xC0, 0x00, 0x00, 0x00, 0xC0, 0x00, 0x80, 0x00, 0xC0, 0x00, 
0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x0D, 0x00, 0x00, 0xF4, 0xF0, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x14, 0x00,
0x00, 0x00, 0x00, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0xA8,
0x00, 0x84, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x90, 0x31, 0x00, 0x00, 
0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 
0x00, 0x00, 0x90, 0x31, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x90, 0x31, 
0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x01, 0x00, 0x00, 0x90, 0x31, 0x00, 0x00, 0x01, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x90, 0x31, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 
  */
/*
  // 4 x 186MHz
static const uint8_t write_values_186M[] = {
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0x70, 0x0F, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x70, 0x03, 0x42, 
0xB0, 0xC0, 0xC0, 0xC0, 0xC0, 0x00, 0x06, 0x06, 0x06, 0x06, 
0x63, 0x0C, 0x23, 0x00, 0x00, 0x00, 0x00, 0x14, 0x35, 0x00, 
0xC3, 0x07, 0x10, 0x00, 0x05, 0x00, 0x00, 0x00, 0x00, 0x01, 
0x00, 0x00, 0x00, 0x10, 0x00, 0x05, 0x00, 0x00, 0x00, 0x00, 
0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x05, 0x00, 0x00, 0x00, 
0x00, 0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x05, 0x00, 0x00, 
0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x32, 0x00, 
0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 
0xC0, 0x00, 0x00, 0x00, 0xC0, 0x00, 0x80, 0x00, 0xC0, 0x00, 
0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x0D, 0x00, 0x00, 0xF4, 0xF0, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x14, 0x00, 
0x00, 0x00, 0x00, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0xA8, 
0x00, 0x84, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x90, 0x31, 0x00, 0x00, 
0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 
0x00, 0x00, 0x90, 0x31, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x90, 0x31, 
0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x01, 0x00, 0x00, 0x90, 0x31, 0x00, 0x00, 0x01, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x90, 0x31, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 
};
*/
  // 4 x 186MHz
static const uint8_t write_values_186M[] = {
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0x70, 0x0F, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x70, 0x02, 0x42, 
0xB0, 0xC0, 0xC0, 0xC0, 0xC0, 0x00, 0x06, 0x06, 0x06, 0x06, 
0x63, 0x0C, 0x23, 0x00, 0x00, 0x00, 0x00, 0x14, 0x35, 0x00, 
0xC3, 0x07, 0x10, 0x00, 0x05, 0x00, 0x00, 0x00, 0x00, 0x01, 
0x00, 0x00, 0x00, 0x10, 0x00, 0x05, 0x00, 0x00, 0x00, 0x00, 
0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x05, 0x00, 0x00, 0x00, 
0x00, 0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x05, 0x00, 0x00, 
0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x32, 0x00, 
0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 
0x40, 0x00, 0x00, 0x00, 0x40, 0x00, 0x80, 0x00, 0x40, 0x00, 
0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x0D, 0x00, 0x00, 0xF4, 0xF0, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x14, 0x00, 
0x00, 0x00, 0x00, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0xA8, 
0x00, 0x84, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x90, 0x31, 0x00, 0x00, 
0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 
0x00, 0x00, 0x90, 0x31, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x90, 0x31, 
0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x01, 0x00, 0x00, 0x90, 0x31, 0x00, 0x00, 0x01, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x90, 0x31, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 
};

// 4 x 238MHz (works)
static const uint8_t write_values_238M[] = {
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0x70, 0x0F, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x70, 0x03, 0x42, 
0xB0, 0xC0, 0xC0, 0xC0, 0xC0, 0x00, 0x06, 0x06, 0x06, 0x06, 
0x63, 0x0C, 0x23, 0x00, 0x00, 0x00, 0x00, 0x14, 0x30, 0x10, 
0xC5, 0x07, 0x10, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x01, 
0x00, 0x00, 0x00, 0x10, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 
0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x03, 0x00, 0x00, 0x00, 
0x00, 0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x03, 0x00, 0x00, 
0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x10, 0x99, 0x2D, 0x0C, 
0x00, 0x00, 0x00, 0x05, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 
0xC0, 0x00, 0x00, 0x00, 0xC0, 0x00, 0x80, 0x00, 0xC0, 0x00, 
0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x0D, 0x00, 0x00, 0xF4, 0xF0, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x14, 0x00, 
0x00, 0x00, 0x00, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0xA8, 
0x00, 0x84, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x90, 0x31, 0x00, 0x00, 
0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 
0x00, 0x00, 0x90, 0x31, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x90, 0x31, 
0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x01, 0x00, 0x00, 0x90, 0x31, 0x00, 0x00, 0x01, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x90, 0x31, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 
};

// 4 x 119MHz (works)
static const uint8_t write_values_119M[] = {
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0x70, 0x0F, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x70, 0x03, 0x42, 
0xB0, 0xC4, 0xC4, 0xC4, 0xC4, 0x00, 0x06, 0x06, 0x06, 0x06, 
0x63, 0x0C, 0x23, 0x00, 0x00, 0x00, 0x00, 0x14, 0x30, 0x10, 
0xC5, 0x07, 0x10, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x01, 
0x00, 0x00, 0x00, 0x10, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 
0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x03, 0x00, 0x00, 0x00, 
0x00, 0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x03, 0x00, 0x00, 
0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x10, 0x99, 0x2D, 0x0C, 
0x00, 0x00, 0x00, 0x05, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 
0xC0, 0x00, 0x00, 0x00, 0xC0, 0x00, 0x80, 0x00, 0xC0, 0x00, 
0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x0D, 0x00, 0x00, 0xF4, 0xF0, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x14, 0x00, 
0x00, 0x00, 0x00, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0xA8, 
0x00, 0x84, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x90, 0x31, 0x00, 0x00, 
0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 
0x00, 0x00, 0x90, 0x31, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x90, 0x31, 
0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x01, 0x00, 0x00, 0x90, 0x31, 0x00, 0x00, 0x01, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x90, 0x31, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 
};

  /*
  // 4 x 100MHz (works)
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0x70, 0x0F, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x70, 0x03, 0x42, 
0xB0, 0xC0, 0xC0, 0xC0, 0xC0, 0x00, 0x06, 0x06, 0x06, 0x06, 
0x63, 0x0C, 0x23, 0x00, 0x00, 0x00, 0x00, 0x14, 0x35, 0x00, 
0xC3, 0x07, 0x10, 0x00, 0x0B, 0x00, 0x00, 0x00, 0x00, 0x01, 
0x00, 0x00, 0x00, 0x10, 0x00, 0x0B, 0x00, 0x00, 0x00, 0x00, 
0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x0B, 0x00, 0x00, 0x00, 
0x00, 0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x0B, 0x00, 0x00, 
0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x32, 0x00, 
0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 
0xC0, 0x00, 0x00, 0x00, 0xC0, 0x00, 0x80, 0x00, 0xC0, 0x00, 
0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x0D, 0x00, 0x00, 0xF4, 0xF0, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x14, 0x00, 
0x00, 0x00, 0x00, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0xA8, 
0x00, 0x84, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x90, 0x31, 0x00, 0x00, 
0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 
0x00, 0x00, 0x90, 0x31, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x90, 0x31, 
0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x01, 0x00, 0x00, 0x90, 0x31, 0x00, 0x00, 0x01, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x90, 0x31, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00,
  */
/*
  // 4 x 371MHz
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0x70, 0x0F, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x70, 0x03, 0x42, 
0xB0, 0xC0, 0xC0, 0xC0, 0xC0, 0x00, 0x06, 0x06, 0x06, 0x06, 
0x63, 0x0C, 0x23, 0x00, 0x00, 0x00, 0x00, 0x14, 0x37, 0x10, 
0xC6, 0xF7, 0x10, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x01, 
0x00, 0x00, 0x00, 0x10, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 
0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x01, 0x00, 0x00, 0x00, 
0x00, 0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x01, 0x00, 0x00, 
0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x10, 0x92, 0x2A, 0x08, 
0x00, 0x00, 0x00, 0x07, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 
0xC0, 0x00, 0x00, 0x00, 0xC0, 0x00, 0x80, 0x00, 0xC0, 0x00, 
0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x0D, 0x00, 0x00, 0xF4, 0xF0, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x14, 0x00, 
0x00, 0x00, 0x00, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0xA8, 
0x00, 0x84, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x90, 0x31, 0x00, 0x00, 
0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 
0x00, 0x00, 0x90, 0x31, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x90, 0x31, 
0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 0x01, 0x00, 0x00, 0x90, 0x31, 0x00, 0x00, 0x01, 0x00, 
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x90, 0x31, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 
0x00, 
*/
  /*
// 1 x 371MHz
  0x00,0x00,0x00,0x00,0x00,0x00,0x08,0x00,0x70,0x0F,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x70,0x03,0x42,
  //  0xB0,0xE3,0xC0,0xE3,0xE3,0x08,0x00,0x06,0x00,0x00,
  0xB0,0xE3,0xC0,0xE3,0xE3,0x00,0x00,0x06,0x00,0x00,
  //  0x83,0x0C,0x23,0x00,0x00,0x00,0x00,0x14,0x37,0x10,
  0x63,0x0C,0x23,0x00,0x00,0x00,0x00,0x14,0x37,0x10,
  0xC6,0x27,0x10,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x10,0x00,0x01,0x00,0x00,0x00,0x00,
  0x01,0x00,0x00,0x00,0x10,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x10,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x10,0x92,0x2A,0x08,
  0x00,0x00,0x00,0x07,0x00,0x00,0x80,0x00,0x00,0x00,
  //  0x40,0x00,0x00,0x00,0x40,0x00,0x80,0x00,0x40,0x00,
  0x40,0x00,0x00,0x00,0xc0,0x00,0x80,0x00,0x40,0x00,
  0x00,0x00,0x40,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0xFF,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x00,0x0D,0x00,0x00,0xF4,0xF0,0x00,0x00,0x00,0x00,
  0x0D,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x14,0x00,
  0x00,0xFF,0x00,0xF0,0x00,0x00,0xFF,0x00,0x00,0xA8,
  0x00,0x84,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x01,0x00,0x00,0x90,0x31,0x00,0x00,
  0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,
  0x00,0x00,0x90,0x31,0x00,0x00,0x01,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x01,0x00,0x00,0x90,0x31,
  0x00,0x00,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x00,0x01,0x00,0x00,0x90,0x31,0x00,0x00,0x01,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x90,0x31,0x00,0x00,0x01,0x00,0x00,0x00,0x00,0x00,
0x00,
  */

void Pds::HSD::ClkSynth::dump() const
{
  volatile uint32_t* r255 = const_cast<Pds::HSD::ClkSynth*>(this)->_reg+255;
  *r255 = 0;
  for(unsigned i=0; i<351; i++) {
    if (i==255)
      *r255 = 1;
    printf("%02x%c",_reg[i&0xff],(i%10)==9?'\n':' ');
  }
  printf("\n");
  *r255 = 0;
}

#define SET_REG(i,q) {                                          \
    timespec tvb,tve;                                           \
    clock_gettime(CLOCK_REALTIME, &tvb);                        \
    unsigned t = _reg[i&0xff];                                  \
    if (t!=q) {                                                    \
      _reg[i&0xff] = q;                                         \
      unsigned u = _reg[i&0xff];                                \
      clock_gettime(CLOCK_REALTIME, &tve);                              \
      printf("RMW[%03u] %02x -> %02x [%02x] (%02x): %f sec  %c\n",      \
             i, t, q, u, _reg[2], tdiff(tvb,tve), (u==q)?'X':' ');      \
    }                                                                   \
  }


static void _setup(volatile uint32_t* _reg,
                   const uint8_t*     write_values);
    
void Pds::HSD::ClkSynth::setup(TimingType timing)
{
  switch(timing) {
  case LCLS:
    _setup(_reg, write_values_119M);
    break;
  case LCLSII:
    _setup(_reg, write_values_186M);
    break;
  default:
    break;
  }
}

void _setup(volatile uint32_t* _reg,
            const uint8_t*     write_values)
{
  static const unsigned LOS_MASK  = 0x04;
  static const unsigned LOCK_MASK = 0x15;

  SET_REG(255,0);
  SET_REG(230,0x10);
  SET_REG(241,0xe5);

  for(unsigned i=0; i<sizeof(write_values_238M); i++) {
    if (i==230 || i==241 || i==246 || (enable_mask[i]==0))
      continue;
    if (i==255) {
      SET_REG(i,1);
    }
    else {
      unsigned r = i&0xff;
      unsigned v = _reg[r];
      unsigned q = v & ~enable_mask[i];
      q |= write_values[i]&enable_mask[i];
      SET_REG(i,q);
    }
  }

  SET_REG(255,0);

  timespec tvb, tve;
  clock_gettime(CLOCK_REALTIME, &tvb);
  while( (_reg[218]&LOS_MASK) )
    ;
  clock_gettime(CLOCK_REALTIME, &tve);
  printf("Time1 : %f sec\n", tdiff(tve,tvb));

  { unsigned q = _reg[49]&0x7f;
    SET_REG(49,q); }
  printf("SET_REG 49 done\n");

  SET_REG(246,2);
  printf("SET_REG 246 done\n");

  usleep(50000);

  SET_REG(241,0x65);
  printf("SET_REG 241 done\n");

  clock_gettime(CLOCK_REALTIME, &tvb);
  do {
    printf("wait for LOCK [%x]\n", _reg[218]);
    usleep(100000);
  } while( (_reg[218]&LOCK_MASK) );

  clock_gettime(CLOCK_REALTIME, &tve);
  printf("Time2 : %f sec\n", tdiff(tve,tvb));

  SET_REG(45,_reg[235]);
  SET_REG(46,_reg[236]);

  { unsigned q = (_reg[47]&0xFC) | (_reg[237]&3);
    //  { unsigned q = 0x14 | (_reg[237]&3);
    SET_REG(47,q); }
  { unsigned q = _reg[49] | 0x80;
    SET_REG(49,q); }
  SET_REG(230,0);
}


