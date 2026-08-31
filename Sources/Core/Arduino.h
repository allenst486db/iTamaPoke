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
#include <type_traits>

// Milliseconds since process start. Upstream uses this purely for animation
// timers and tick pacing, so a monotonic clock is the correct mapping.
unsigned long millis(void);

long random(long howbig);
long random(long howsmall, long howbig);
void randomSeed(unsigned long seed);

// Arduino exposes these as macros; templates keep them from leaking into the
// Objective-C++ translation units that also pull in Foundation.
//
// The return type is explicitly decayed to a plain value (std::decay, not a
// bare `decltype(a < b ? a : b)`) on purpose: when T and U are the same
// type, C++'s ternary operator on two lvalues of that type yields an
// *lvalue reference* to whichever one was picked -- so an undecayed
// decltype here deduces the return type as e.g. `uint8_t&`, and the
// function ends up returning a reference to its own by-value parameter,
// which is stack memory that's already gone by the time the caller reads
// it (clang warns about exactly this: "reference to stack memory
// associated with parameter... returned"). That dangling read doesn't
// reliably crash -- it silently returns whatever garbage now occupies that
// stack slot, which is what made Pet::lowestStat() (min(min(a,b),min(c,d)),
// all same-typed uint8_t) intermittently return values with no relation to
// fullness/joy/energy/hygiene at all, blocking evolution even with every
// stat well above the 40 threshold.
template <typename T, typename U>
inline typename std::decay<decltype(true ? T() : U())>::type min(T a, U b) {
  return a < b ? a : b;
}
template <typename T, typename U>
inline typename std::decay<decltype(true ? T() : U())>::type max(T a, U b) {
  return a > b ? a : b;
}

// pet.cpp logs offline catch-up through Serial.printf once.
struct TPSerialShim {
  void printf(const char *fmt, ...) __attribute__((format(printf, 2, 3)));
};
extern TPSerialShim Serial;
