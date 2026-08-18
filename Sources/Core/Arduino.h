#pragma once
//
// Minimal Arduino compatibility shim.
//
// Lets the upstream firmware's game logic (upstream/pet.cpp, upstream/i18n.cpp)
// compile unmodified on Apple platforms, so bumping the submodule stays free.
// Only the surface those files actually touch is here -- do not grow this
// speculatively; add a symbol when a build actually asks for it.
//
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdio.h>

// Milliseconds since process start. Upstream uses this purely for animation
// timers and tick pacing, so a monotonic clock is the correct mapping.
unsigned long millis(void);

long random(long howbig);
long random(long howsmall, long howbig);
void randomSeed(unsigned long seed);

// Arduino exposes these as macros; templates keep them from leaking into the
// Objective-C++ translation units that also pull in Foundation.
template <typename T, typename U>
inline auto min(T a, U b) -> decltype(a < b ? a : b) { return a < b ? a : b; }
template <typename T, typename U>
inline auto max(T a, U b) -> decltype(a > b ? a : b) { return a > b ? a : b; }

// pet.cpp logs offline catch-up through Serial.printf once.
struct TPSerialShim {
  void printf(const char *fmt, ...) __attribute__((format(printf, 2, 3)));
};
extern TPSerialShim Serial;
