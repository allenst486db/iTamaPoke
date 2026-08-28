# iTamaPoke — browser port (work in progress)

A from-scratch browser build of the same game, meant to run wrapped in a
thin native WKWebView (iOS)/WebView (Android) shell you build and install on
your own device — not hosted anywhere public. See the root
[LICENSE](../LICENSE): personal use only, same as the iOS app.

**Status: playable idle-screen MVP with persistence.** Egg tap-to-hatch,
live stat decay, the four action buttons (feed/play/light/clean), and a
save that survives a reload (IndexedDB) all work against the real game
logic in an actual browser tab. No sprite art, minigames, dex, battle,
settings, or sound yet -- see the roadmap below.

## What's here

```
browser_ver/
  core/
    browser_glue.cpp     # the only new C++: JS<->game-logic bridge
    shim/
      Arduino.h           # millis()/random()/Serial stand-ins
      Preferences.h        # in-memory NVS-shaped key/value store
  web/
    index.html, main.js   # WASM smoke test (NOT the game UI)
    tp_core.js/.wasm       # build.sh's output, gitignored
  build.sh                # builds core/ + upstream-expanded/*.cpp -> web/tp_core.*
```

`upstream-expanded/pet.cpp`, `battle.cpp`, `i18n.cpp`, and `dex.h` are used
**completely unmodified** — the same files the iOS build compiles, here
compiled to WebAssembly instead of linked into the Swift app. `core/`'s job
is standing in for what `Sources/Core/TPPet.mm` does on iOS: own the one
`Pet` instance and expose a small C ABI. Everything platform-specific it
needed (`Preferences`, `millis()`, `random()`, `Serial.printf`) got a shim in
`core/shim/`, found by actually trying to compile the real files and fixing
whatever the linker complained about — see the shim files' own comments for
exactly what each one stands in for and why.

## Building

```bash
git clone --depth 1 https://github.com/emscripten-core/emsdk.git
cd emsdk && ./emsdk install latest && ./emsdk activate latest
source ./emsdk_env.sh
cd /path/to/iTamaPoke
browser_ver/build.sh              # writes browser_ver/web/tp_core.{js,wasm}
```

Then serve `browser_ver/web/` over HTTP (not `file://` — the WASM fetch
needs a real origin) and open `index.html`. It doesn't play the game yet;
it ticks a fresh egg forward once a frame and prints the core's status, to
prove the link between the browser and the untouched C++ logic actually
works before anything else gets built on top of it.

emsdk requires Python 3.10+; if your system Python is older, a portable
build from [astral-sh/python-build-standalone](https://github.com/astral-sh/python-build-standalone)
works fine just to run `emsdk.py` — Emscripten will use its own bundled
Python for everything after that.

## Roadmap

1. ~~Verify the C++ core actually compiles and runs as WASM~~ ✅ done
2. ~~Canvas 2D renderer — idle screen only (header, bars, poop, the four
   action buttons, egg tap-to-hatch, day/night/sleep palette)~~ ✅ done,
   `web/main.js`. Still missing from `PetScreen.swift`'s full render(): the
   real sprite art (placeholder "?" for now, see step 4), minigames, the
   Pokédex, battle, evolution/farewell/runaway ceremonies, the stat card,
   settings screen, and the rename keyboard.
3. Web Audio synthesizer — port `TPAudio.swift`'s oscillator/noise tables
4. TPK2 sprite parser in JS (same format `TPSprite.swift` reads)
5. Asset loading: local file picker (multi-select, not `webkitdirectory` —
   unreliable on iOS Safari) -> IndexedDB, mirroring the iOS app's
   Documents/mons flow
6. ~~Save persistence via IndexedDB~~ ✅ done. `tp_export_state()`/
   `tp_import_state()` (browser_glue.cpp) round-trip `Preferences::store()`
   as a small binary blob; `web/main.js` writes it to IndexedDB every 15s
   and on tab hide/close, and loads it before the first tick. Settings
   (sound mode, language) aren't wired into the UI yet, so there's nothing
   settings-shaped to persist beyond what the store already carries.
7. Native shells: a minimal WKWebView Xcode project and a minimal
   Android `WebView` project, each loading `web/` as local bundled assets
   (no server at runtime) and installed only on your own device
8. Install guide (+ HTML version) once there's something to install

## Why WASM instead of rewriting the game logic in JS

`upstream-expanded/` is the exact source the iOS app already ships, already
battle-tested there. Recompiling it instead of retranslating it means the
web build can't drift out of sync with iOS on game rules — a bug fixed once
in `pet.cpp` fixes both builds.
