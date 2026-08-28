// The only new C++ in this build: platform glue between JS and the
// untouched upstream-expanded/*.cpp game logic. Everything game-rule-shaped
// (feeding, evolution, battle math, minigame scoring, i18n strings) lives in
// upstream-expanded/ exactly as the iOS build uses it -- this file's whole
// job is standing in for what TPPet.mm does on iOS: own the one Pet
// instance, expose a flat C ABI Emscripten can bind, and shuttle time/save
// state across the JS boundary.
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <sstream>
#include <string>
#include <vector>

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

// --- Save persistence --------------------------------------------------
//
// Preferences (shim/Preferences.h) is only an in-memory map for the tick
// duration; these two calls are the round trip that lets web/main.js park
// it in IndexedDB across reloads. Custom length-prefixed binary rather than
// JSON: the store's Value variant already has a fixed small set of shapes
// (bool/int64/string/bytes), so a hand-parsed format avoids pulling in a
// JSON library for four cases.
//
// Layout: u32 entryCount, then per entry:
//   u8 keyLen, key bytes, u8 type (0 bool/1 int64/2 string/3 bytes),
//   u32 valueLen, value bytes (bool/int64 always 1/8 bytes; the length
//   prefix is still written for a uniform reader).
// All integers little-endian, matching wasm32's native layout, so a plain
// memcpy round-trips them.

namespace {
std::vector<uint8_t> gExportBuf;

void putU32(std::vector<uint8_t> &b, uint32_t v) {
  uint8_t tmp[4];
  std::memcpy(tmp, &v, 4);
  b.insert(b.end(), tmp, tmp + 4);
}
} // namespace

EMSCRIPTEN_KEEPALIVE
int tp_export_state() {
  gExportBuf.clear();
  auto &s = Preferences::store();
  putU32(gExportBuf, (uint32_t)s.size());
  for (auto &kv : s) {
    const std::string &key = kv.first;
    gExportBuf.push_back((uint8_t)key.size());
    gExportBuf.insert(gExportBuf.end(), key.begin(), key.end());

    uint8_t type;
    std::vector<uint8_t> val;
    if (std::holds_alternative<bool>(kv.second)) {
      type = 0;
      val.push_back(std::get<bool>(kv.second) ? 1 : 0);
    } else if (std::holds_alternative<int64_t>(kv.second)) {
      type = 1;
      int64_t v = std::get<int64_t>(kv.second);
      uint8_t tmp[8];
      std::memcpy(tmp, &v, 8);
      val.assign(tmp, tmp + 8);
    } else if (std::holds_alternative<std::string>(kv.second)) {
      type = 2;
      const std::string &v = std::get<std::string>(kv.second);
      val.assign(v.begin(), v.end());
    } else {
      type = 3;
      const auto &v = std::get<std::vector<uint8_t>>(kv.second);
      val = v;
    }
    gExportBuf.push_back(type);
    putU32(gExportBuf, (uint32_t)val.size());
    gExportBuf.insert(gExportBuf.end(), val.begin(), val.end());
  }
  return (int)gExportBuf.size();
}

// Valid only until the next tp_export_state() call -- web/main.js copies
// out of wasm memory (HEAPU8.slice) immediately after reading the length.
EMSCRIPTEN_KEEPALIVE
uint8_t *tp_export_ptr() { return gExportBuf.data(); }

// Replaces the whole store with what's in `data` -- must be called before
// the first tp_tick() (which calls gPet.begin() and reads the store), or
// not at all for a fresh save. Malformed/truncated input is ignored field
// by field rather than trusted, since it's round-tripped through browser
// storage a user could in principle edit.
EMSCRIPTEN_KEEPALIVE
void tp_import_state(const uint8_t *data, int len) {
  auto &s = Preferences::store();
  s.clear();
  size_t pos = 0;
  size_t n = len < 0 ? 0 : (size_t)len;
  auto need = [&](size_t k) { return pos + k <= n; };

  if (!need(4)) return;
  uint32_t count;
  std::memcpy(&count, data + pos, 4);
  pos += 4;

  for (uint32_t i = 0; i < count; i++) {
    if (!need(1)) return;
    uint8_t klen = data[pos];
    pos += 1;
    if (!need(klen)) return;
    std::string key(reinterpret_cast<const char *>(data + pos), klen);
    pos += klen;

    if (!need(1)) return;
    uint8_t type = data[pos];
    pos += 1;

    if (!need(4)) return;
    uint32_t vlen;
    std::memcpy(&vlen, data + pos, 4);
    pos += 4;
    if (!need(vlen)) return;
    const uint8_t *vptr = data + pos;
    pos += vlen;

    switch (type) {
      case 0:
        s[key] = (vlen >= 1 && vptr[0] != 0);
        break;
      case 1: {
        int64_t v = 0;
        if (vlen >= 8) std::memcpy(&v, vptr, 8);
        s[key] = v;
        break;
      }
      case 2:
        s[key] = std::string(reinterpret_cast<const char *>(vptr), vlen);
        break;
      case 3:
        s[key] = std::vector<uint8_t>(vptr, vptr + vlen);
        break;
      default:
        break;
    }
  }
}

} // extern "C"
