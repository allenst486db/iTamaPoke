// The only new C++ in this build: platform glue between JS and the
// untouched upstream-expanded/*.cpp game logic. Everything game-rule-shaped
// (feeding, evolution, battle math, minigame scoring, i18n strings) lives in
// upstream-expanded/ exactly as the iOS build uses it -- this file's whole
// job is standing in for what TPPet.mm does on iOS: own the one Pet
// instance, expose a flat C ABI Emscripten can bind, and shuttle time/save
// state across the JS boundary.
#include <cstdint>
#include <cstdlib>
#include <ctime>
#include <sstream>
#include <string>

#include <emscripten.h>

#include "pet.h"
#include "i18n.h"
#include "audio.h"
#include "shim/Preferences.h"

// Defined here, read by shim/Arduino.h's millis(). JS drives this once per
// frame via tp_tick() below -- there is no free-running hardware clock to
// read on the web, only whatever time the page's own loop hands in.
uint32_t g_millis = 0;
TPSerialShim Serial;

namespace {
Pet gPet;
bool gStarted = false;
}

// pet.cpp/battle.cpp raise effects by calling this directly (audio.h's own
// declaration, same call sites the ESP32 firmware and the iOS port's
// TPSetSfxHook trampoline both use) -- here it just forwards the id to a JS
// function, same shape as TPPet.mm's Objective-C block trampoline. web/'s
// audio module (not yet written) supplies `Module.onSfx`.
EM_JS(void, tp_js_on_sfx, (int id), {
  if (Module.onSfx) Module.onSfx(id);
});

void sfxPlay(uint8_t id) { tp_js_on_sfx((int)id); }

extern "C" {

// Called once at startup, before anything else touches gPet: seeds the
// std::rand() shim/Arduino.h's random() draws from (egg rarity, shiny rolls,
// starter tables) with real entropy from the browser rather than libc's
// fixed default seed, which would otherwise make every fresh save roll
// identically.
EMSCRIPTEN_KEEPALIVE
void tp_seed_random(uint32_t seed) { std::srand(seed); }

// One call per rendered frame (or per fixed-step tick, TBD once the render
// loop lands): advances the shim clock and steps the Pet the same way
// TPPet.mm's tick() does on iOS.
EMSCRIPTEN_KEEPALIVE
void tp_tick(uint32_t nowMs) {
  g_millis = nowMs;
  if (!gStarted) {
    gStarted = true;
    gPet.begin();
    gPet.syncClock((uint32_t)std::time(nullptr));
  }
  gPet.update(g_millis);
}

// A minimal end-to-end smoke test for the very first WASM build: proves
// pet.cpp/i18n.cpp/battle.cpp/dex.h link and run inside the module, without
// yet wiring a real render loop or save round trip. Returns the active
// species' English name once a starter/egg exists, "EGG" before that.
EMSCRIPTEN_KEEPALIVE
const char *tp_debug_status() {
  static std::string out;
  out = gPet.isEgg() ? "EGG" : dexName(gPet.speciesId);
  return out.c_str();
}

// --- Idle-screen MVP surface -----------------------------------------
//
// Minimal getters/actions to drive the browser idle screen (web/main.js):
// no sprites, minigames, battle, dex, or settings yet -- see
// browser_ver/README.md's roadmap. Mirrors the handful of Pet fields/calls
// PetScreen.swift's idle branch and its four action buttons touch.

EMSCRIPTEN_KEEPALIVE int tp_is_egg() { return gPet.isEgg() ? 1 : 0; }
EMSCRIPTEN_KEEPALIVE int tp_species_id() { return gPet.speciesId; }
EMSCRIPTEN_KEEPALIVE int tp_fullness() { return gPet.fullness; }
EMSCRIPTEN_KEEPALIVE int tp_joy() { return gPet.joy; }
EMSCRIPTEN_KEEPALIVE int tp_energy() { return gPet.energy; }
EMSCRIPTEN_KEEPALIVE int tp_hygiene() { return gPet.hygiene; }
EMSCRIPTEN_KEEPALIVE int tp_poops() { return gPet.poops; }
EMSCRIPTEN_KEEPALIVE int tp_sleeping() { return gPet.sleeping ? 1 : 0; }
EMSCRIPTEN_KEEPALIVE int tp_level() { return gPet.level(); }

EMSCRIPTEN_KEEPALIVE
const char *tp_name() {
  static std::string out;
  if (gPet.isEgg()) { out = "EGG"; return out.c_str(); }
  out = gPet.nick[0] ? gPet.nick : dexName(gPet.speciesId);
  return out.c_str();
}

// Actions -- each just forwards to the same Pet methods the buttons in
// TamaPoke.ino / TPPet.mm already call; see pet.h for what each one does
// to the stats above.
EMSCRIPTEN_KEEPALIVE void tp_feed_berry(int color) { gPet.feedBerry((uint8_t)color); }
EMSCRIPTEN_KEEPALIVE void tp_feed_candy() { gPet.feedCandy(); }
EMSCRIPTEN_KEEPALIVE void tp_play() { gPet.play(); }
EMSCRIPTEN_KEEPALIVE void tp_toggle_light() { gPet.toggleLight(); }
EMSCRIPTEN_KEEPALIVE void tp_clean() { gPet.clean(); }
EMSCRIPTEN_KEEPALIVE void tp_caress() { gPet.caress(); }
EMSCRIPTEN_KEEPALIVE void tp_egg_tap() { gPet.eggTap(); }

} // extern "C"
