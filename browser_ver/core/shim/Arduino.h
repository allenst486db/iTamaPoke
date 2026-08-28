// Browser/WASM stand-in for the ESP32 Arduino core, covering only the
// symbols upstream-expanded/*.cpp actually calls (see the grep audit this
// was built from -- millis(), random(), min()). Mirrors the same idea as
// Sources/Core/TPPet.mm's Objective-C++ shim for the iOS build: the C++
// game logic in upstream-expanded/ is untouched, only the platform glue
// changes per target.
#pragma once

#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <algorithm>

// millis() is normally the hardware's free-running tick counter. On the web
// build, browser_glue.cpp's JS-facing tp_tick(uint32_t nowMs) passes in
// performance.now() (or the save file's resumed elapsed time) each frame,
// and this just echoes it back -- see browser_glue.cpp for where it's set.
extern uint32_t g_millis;
inline uint32_t millis() { return g_millis; }

// Arduino's random(): random(max) -> [0, max), random(min, max) -> [min, max).
// Seeded once from JS (crypto.getRandomValues) at startup -- see
// browser_glue.cpp's tp_seed_random().
inline long random(long max) {
  if (max <= 0) return 0;
  return std::rand() % max;
}
inline long random(long min, long max) {
  if (max <= min) return min;
  return min + (std::rand() % (max - min));
}

// Arduino defines min/max as macros; upstream-expanded's callers use them
// like ordinary two-argument functions on integer types, which std::min/max
// already cover -- no macro needed here, and a macro would break any call
// site that happens to use std::min/std::max itself.
using std::max;
using std::min;

// Arduino's Serial.printf(...) is upstream's one debug-log call (offline
// catch-up minutes). Emscripten's own libc printf already lands in the
// browser devtools console via stdout, so this just forwards to it --
// no real serial port to open on the web.
struct TPSerialShim {
  void printf(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vprintf(fmt, args);
    va_end(args);
  }
};
extern TPSerialShim Serial;
