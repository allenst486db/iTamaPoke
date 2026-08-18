#import <Foundation/Foundation.h>
#include <mach/mach_time.h>
#include <stdarg.h>
#include <stdlib.h>
#include "Arduino.h"

TPSerialShim Serial;

void TPSerialShim::printf(const char *fmt, ...) {
#if DEBUG
  va_list ap;
  va_start(ap, fmt);
  vfprintf(stderr, fmt, ap);
  va_end(ap);
#else
  (void)fmt;
#endif
}

unsigned long millis(void) {
  static mach_timebase_info_data_t tb;
  static uint64_t origin;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    mach_timebase_info(&tb);
    origin = mach_absolute_time();
  });
  uint64_t ns = (mach_absolute_time() - origin) * tb.numer / tb.denom;
  return (unsigned long)(ns / 1000000ull);
}

// Upstream seeds nothing and relies on Arduino's PRNG. arc4random_uniform is a
// strictly better source and matches the [0, howbig) contract.
long random(long howbig) {
  if (howbig <= 0) return 0;
  return (long)arc4random_uniform((uint32_t)howbig);
}

long random(long howsmall, long howbig) {
  if (howbig <= howsmall) return howsmall;
  return howsmall + random(howbig - howsmall);
}

void randomSeed(unsigned long) { /* arc4random needs no seeding */ }
