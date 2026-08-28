# iTamaPoke — browser port (work in progress)

A from-scratch browser build of the same game, meant to run wrapped in a
thin native WKWebView (iOS)/WebView (Android) shell you build and install on
your own device — not hosted anywhere public. See the root
[LICENSE](../LICENSE): personal use only, same as the iOS app.

**Status: playable idle-screen MVP with persistence, real sprite art,
sound, and settings.** Egg tap-to-hatch, live stat decay, the four action
buttons (feed/play/light/clean), a save that survives a reload
(IndexedDB), the actual animated TPK2 sprite (picked locally, never
bundled), the real chip-tune SFX, and a real settings screen (sound mode,
one of the 7 real UI languages + the partial-Korean mode) all work against
the real game logic in an actual browser tab. No minigames, dex, or battle
yet -- see the roadmap below.

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
2. Canvas 2D renderer — idle screen (header, bars, poop, the four action
   buttons, egg tap-to-hatch, day/night/sleep palette) + settings screen
   ✅ done, `web/main.js`. All five minigames ✅ done too (`web/minigames.js`,
   a port of `MiniGames.swift`'s five game structs -- physics/timers/
   sequence state, tap hit-tests, scoring through the same
   `Pet::playResult`/`applyCatchResult`/`applyMemoResult`/`applyCleanResult`/
   `applyTypeResult` the iOS build calls, including the Type quiz's real
   `battleTypeEffectPct` distractor filter). Emoji glyphs (ball, food/berry
   icons, dirt bubbles) don't render in every environment -- a font-fallback
   gap, not a logic one; the underlying hit-tests were verified directly.
   The Pokédex grid + detail ✅ done too (`web/dex.js`, a Dex button next
   to Settings) -- real registered/caught state, filters, pagination, and
   type chips from `DEX_TBL`, minus the sprite-atlas thumbnails (`TPThumbs`)
   and the dex-entry text page (`TPDexEntryText`, which reads a
   user-supplied `mons/dex_entries_<lang>.txt`) -- tiles show the dex
   number instead of a thumbnail, and detail stops after the type/
   obtained-via page.
   The wild-battle system ✅ done too (`web/battle.js` +
   `core/browser_battle.cpp`, a plain-C++ port of `Sources/Core/TPBattle.mm`
   over the unmodified `battle.cpp` combat engine) -- wild-encounter prompt,
   attack/dodge/rest turns, HP bars, win/loss result with the real reward/
   catch-offer flow. Missing from *this* piece specifically: the wild
   species' own sprite in battle (falls back to a "?" unless it happens to
   already be the currently-loaded one) and the catch minigame integration
   isn't wired to the post-battle catch offer yet, just the plain
   probability roll.
   The stat card's profile page + rename keyboard ✅ done too
   (`web/card.js`, a Card button next to Dex) -- streak, bond bar, berry/
   age info, and a real rename round-tripping through `Pet::rename`. The
   card's other seven pages (personality, daily goals, box, battle record,
   medals, progress, expeditions) aren't ported.
   Still missing from `PetScreen.swift`'s full render(): evolution/
   farewell/runaway ceremonies (the game logic behind them -- evolving,
   the ending states -- already runs correctly server-side; only their
   animated screens aren't drawn), and the card's other seven pages.
3. ~~Web Audio synthesizer~~ ✅ done, `web/audio.js` — same 39-effect note
   table, four waveforms, LFSR noise, and anti-click envelope as
   `TPAudio.swift`, rendered into an `AudioBuffer` per effect and played
   through a plain `AudioContext` (no `AVAudioEngine` equivalent needed).
   Gated by the settings screen's sound pill (SILENT/VIBRATE/FULL, same
   3-level scheme as `GameModel.swift`, `web/audio.js`'s own dedicated
   `localStorage` key to avoid the raw-value collision bug just fixed on
   the iOS side) — starts SILENT, since browsers refuse audio before a
   user gesture; VIBRATE uses the Vibration API where the browser has one.
4. ~~TPK2 sprite parser in JS~~ ✅ done, `web/sprites.js` — ports
   `TPSprite.swift` (palette, actions, frame-walk, whole-pixel scale)
   exactly, verified against a real `p004.bin` rendering correctly on
   canvas. Only the idle pose animates so far; walk/eat/sleep/hurt/etc. are
   parsed but not yet drawn anywhere — that's step 2's remaining scope, not
   this one's.
5. ~~Asset loading~~ ✅ done, same file: a local multi-file picker
   (`accept=".bin" multiple`, not `webkitdirectory` — unreliable on iOS
   Safari) into IndexedDB, mirroring the iOS app's Documents/mons flow.
   Sprites are never bundled or fetched by this code — picked locally,
   stored locally, same as the iOS build's own rule (LICENSE/NOTICE).
6. ~~Save persistence via IndexedDB~~ ✅ done. `tp_export_state()`/
   `tp_import_state()` (browser_glue.cpp) round-trip `Preferences::store()`
   as a small binary blob; `web/main.js` writes it to IndexedDB every 15s
   and on tab hide/close, and loads it before the first tick. Language and
   sound mode persist too now (the language choice through the same store,
   since `tp_set_language()` calls the real `setLang()`/`setDexNamesKorean()`;
   sound mode through its own `localStorage` key in `web/audio.js`, not the
   WASM store, since it's a browser-side toggle with no iOS analogue in
   `Preferences`).
7. ~~Settings screen~~ ✅ done, part of step 2 above -- see there.
8. ~~Native shells~~ ✅ done, `native/` — a WKWebView `View` to drop into a
   new Xcode target and a minimal Android Studio project, both loading
   `web/` from local files (no server, no network permission). See
   `native/README.md` for the exact setup steps; the iOS half is a target
   you add by hand in Xcode rather than a second `.xcodeproj`, since
   hand-writing a correct `project.pbxproj` from scratch is far riskier
   than Xcode's own "New Target" wizard.
9. Install guide (+ HTML version) once there's something to install

## Why WASM instead of rewriting the game logic in JS

`upstream-expanded/` is the exact source the iOS app already ships, already
battle-tested there. Recompiling it instead of retranslating it means the
web build can't drift out of sync with iOS on game rules — a bug fixed once
in `pet.cpp` fixes both builds.
