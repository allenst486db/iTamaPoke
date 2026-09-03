# iTamaPoke — browser port (work in progress)

A from-scratch browser build of the same game, meant to run wrapped in a
thin native WKWebView (iOS)/WebView (Android) shell you build and install on
your own device — not hosted anywhere public. See the root
[LICENSE](../LICENSE): personal use only, same as the iOS app.

**Status: feature-complete against `PetScreen.swift`'s render().** Egg
tap-to-hatch, live stat decay, the four action buttons, persistence
(IndexedDB), the real animated TPK2 sprite, the real chip-tune SFX, a
real settings screen, all five minigames, the Pokédex, the wild-battle
system, evolution/farewell/runaway, the rename keyboard, and all eight
stat card pages (including Daily goals/Box/Expedition and the training
sack) work against the real C++ game logic in an actual browser tab.
Native shells (WKWebView/WebView) exist too -- see `native/`. Dex grid
tiles now show the real sprite once you've picked it, the dex detail
screen has a real second page for user-supplied dex-entry text, and
evolution/farewell/runaway now draw the real halo/ray/spark/rain/heart
particle FX rather than a plain progress bar -- `PetScreen.swift`'s
render() is fully covered end to end, gameplay and presentation both.
Navigation is real swipe gestures now too (up/down/left for the stat
card/settings/dex, matching the iOS app), not the floating HTML buttons
earlier stages used as a placeholder -- see "known gaps" below for what's
still genuinely different from the iOS app rather than just a stand-in.

## What's here

```
browser_ver/
  core/
    browser_glue.cpp     # the only new C++: JS<->game-logic bridge
    shim/
      Arduino.h           # millis()/random()/Serial stand-ins
      Preferences.h        # in-memory NVS-shaped key/value store
  web/
    index.html, main.js   # the game: idle screen, input, screen routing
    icons.js, scene.js,   # TPIcon glyphs / SceneRenderer backdrop /
    behaviour.js          #   creature behaviour + bath (ports of the Swift)
    sprites.js, audio.js, minigames.js, dex.js, dexentry.js, cry.js,
    battle.js, card.js, expedition.js, ceremony.js
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
needs a real origin) and open `index.html`.

## Deploying (how players actually get it)

`web/` is a PWA: `manifest.webmanifest` + `sw.js` make it installable from
Safari/Chrome and fully offline after the first load, with the save and the
user-picked assets living in the phone's own storage. The **Build
(browser)** workflow (`.github/workflows/build-browser.yml`) compiles the
core on every push, stamps the service worker with the commit id (so
installed copies pick up the new version on their next launch), copies
`Resources/DefaultAppIcon.png` in as `icon.png`, refuses to publish if any
creature asset is found in the folder, builds the Android APK, and deploys
both to GitHub Pages. It runs in each player's own fork (one-time setup
there: **Settings → Pages → Source: GitHub Actions**, then run it once) --
this repository does not host a shared copy; see LICENSE §2/§3. The
install guide's Path D is "fork, run the workflow, open your link, Add to
Home Screen".

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
   The Pokédex grid + detail ✅ done too (`web/dex.js`, swipe left from idle,
   same as the iOS app) -- real registered/caught state, filters, pagination, and
   type chips from `DEX_TBL`. Grid tiles show the real TPK2 sprite once
   it's been picked locally (falls back to the dex number otherwise --
   `TPThumbs`' own packed sprite-atlas format isn't parsed, so this reuses
   whichever full sprite the user already loaded rather than a separate
   thumbnail asset). The dex-entry text page is done too (`web/dexentry.js`,
   a `Load dex text…` button next to the sprite one) -- ports
   `TPDexEntryText`'s `<dex>|<text>` file format and per-language lookup,
   picked locally and kept in this browser's own IndexedDB, same
   never-bundled rule as sprites; word-wrap is plain `measureText` rather
   than `TPDexEntryText.wrap`'s real per-language/character-mode wrapping,
   which is close enough for the Latin-script text these files hold.
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
   (`web/card.js`, swipe up from idle) -- streak, bond bar, berry/
   age info, and a real rename round-tripping through `Pet::rename`. The
   card's other seven pages (personality, daily goals, box, battle record,
   medals, progress, expeditions) aren't ported.
   Evolution/farewell/runaway ✅ done, including the particle FX
   (`web/ceremony.js`) -- the evolve/farewell/runaway call-to-action
   buttons, their confirm dialogs, and the ceremony/evolving screens all
   work against the real `Pet::evolve`/`startFarewell`/`startRunaway`.
   `drawEvolveFX`/`drawCeremony`'s halo rings, turning rays, sparks, rain,
   rising hearts and the white-out reveal are all ported (canvas
   `arc`/`fillRect` in place of `GraphicsContext`'s equivalents, and a
   `source-atop` composite for the flat-silhouette look). The one real
   simplification: evolving flickers the current sprite against itself
   rather than the old species against the new one, since this build
   doesn't keep a second sprite around for the pre-evolution form.
   Four more card pages ✅ done -- Personality, Battle (ATK/DEF/SPD/WGT
   bars, W/L record, a working wild-battle button), Medals, Progress
   (level bar, evolution status). Page-dot navigation added (tap left/
   right half of the dot row).
   The last three card pages ✅ done too (`web/expedition.js`) -- Daily
   goals (real progress/targets, `ensureDailyGoals`), Box (sortable,
   paginated, real type-coloured rows), and Expedition (start/claim,
   the 4-item inventory, the train-item stat-choice modal, all through
   the real `Pet::startExpedition`/`claimExpedition`/`useExpeditionItem`)
   -- plus the idle-screen expedition HUD chip. The training-sack
   minigame ✅ done too (`SackGame` in `web/minigames.js`, opened from the
   Battle page's "TRAIN STRENGTH" button) -- a 10s tap-fest scored
   through the real `Pet::trainStrength`.
   `PetScreen.swift`'s render() is now fully covered.
   The *input* model has since caught up to match too -- earlier stages got
   the content ported but not the gestures, so Settings/Dex/Card lived
   behind three floating HTML buttons bolted on top of the canvas, and
   there was no swipe at all. Those are gone now: `web/main.js` recognizes
   real swipes (a pointerdown/pointerup drag classified the same way
   `PetScreen.swift`'s `onGesture`/`onSwipe`/`onSwipeV` does -- distance and
   direction thresholds, same up/down/left/right mapping) so swipe up opens
   the stat card, down opens settings, left opens the dex, exactly like the
   iOS app -- no HTML chrome, no button that doesn't exist on a real device.
   The two file pickers (`Load sprites…`/`Load dex text…`) stay as actual
   buttons since they have no iOS equivalent to match in the first place.
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
   canvas. Every action the sheet carries is drawn now: `web/behaviour.js`
   ports `GameModel.swift`'s `advanceBehaviour`/`behNext` scheduler (look
   around / stroll / one-shot gesture, plus eat/sleep/hurt by mood), so the
   creature moves the same way it does on iOS.
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
9. ~~Install guide~~ ✅ done -- see `docs/INSTALL.md`/`.ko.md`'s "Path D".

## Known gaps from the iOS app

Everything above is ported faithfully; a few things genuinely aren't there
yet, rather than being a stand-in for something ported elsewhere:

Nothing outstanding: the entries this list used to carry are all resolved
below.

Fixed since this list was written:

- ~~**Presentation parity on the idle screen.**~~ The idle screen used to
  be a flat backdrop, emoji buttons and one looping sprite frame. It now
  matches `PetScreen.swift` piece for piece: `icons.js` carries the same
  TPIcon pixel glyphs (food/play/light/clean/berries/candy/poop/heart) with
  the same RGB565 palette; `scene.js` is a line-for-line port of
  `SceneRenderer.swift` (sky by hour, biome ground, night palette), used
  behind the idle screen, the minigames and the battle; `behaviour.js` is
  the creature's stroll/gesture scheduler and the CLEAN bath (suds, then
  the real `clean()` when they pop). Also ported: the egg with cracks,
  hint text and rarity label; the four-item FEED menu (berry/berry/candy);
  the streak badge; the level-up celebration; the header's status message;
  the long-press release dialog; the caress zone; the wild-battle "already
  caught" marker. The C++ side gained the matching presentation accessors
  in `browser_glue.cpp` (`tp_egg_*`, `tp_status_message`, `tp_show_heart`,
  `tp_release*`, medal/milestone banners …) mirroring `TPPet.mm`.

- ~~**Dex cry playback.**~~ Ported, in `cry.js`: a "Load cries…" picker
  (same local-file/IndexedDB pattern as sprites and dex text, never
  bundled or fetched), decoded through the AudioContext audio.js already
  stands up rather than a second audio graph, and the same capsule control
  PetScreen.swift draws -- play/pause icon, masthead-red gauge filling as
  the clip runs, hidden entirely for a species with no file installed, and
  muted unless the sound mode is full, matching TPCry.swift's own guard.

- ~~**Wild battle's opponent sprite** falls back to a "?" unless the wild
  species happens to already be the one you last loaded.~~ The opponent now
  loads its own sprite: `sprites.js`'s `spriteFor()` is a draw-loop-safe
  lookup (sync peek at what's parsed, lazy background load, in-flight guard)
  that the battle screen, the dex grid and the dex detail portrait all share.
  Still falls back to "?" for a species whose `.bin` hasn't been picked
  locally, same as everywhere else in this build.
- ~~**The dex detail portrait**~~ drew a 🐾 emoji for every known species,
  even though the grid tiles beside it were already showing real art. Now
  draws the species' own sprite through the same shared lookup.
- ~~**The post-battle catch offer** ... isn't wired to the catch minigame's
  own timing/skill mechanic yet, just a straight roll.~~ This was never a
  gap against iOS: `TPBattle.mm`'s `-tryCatch` is the same straight roll
  (`arc4random_uniform(100)` into `tryCatchWild`/`tryRespectCatchWild`), and
  `tp_battle_try_catch()` mirrors it call for call. Removed rather than
  fixed, since there was nothing to fix.

## Rebuild after pulling

`tp_core.js`/`tp_core.wasm` are gitignored build artifacts, so a `git pull`
updates the JS and the C++ *sources* but leaves your compiled core alone.
When a change adds or renames an export, JS pulled from git can end up
calling into a core built before it existed -- `cwrap` binds lazily, so it
fails at the call, not at load (that is what a stale core looks like: one
screen throwing rather than the page failing to start). Re-run
`browser_ver/build.sh` after pulling anything that touched
`upstream-expanded/` or `browser_ver/core/`.

## Why WASM instead of rewriting the game logic in JS

`upstream-expanded/` is the exact source the iOS app already ships, already
battle-tested there. Recompiling it instead of retranslating it means the
web build can't drift out of sync with iOS on game rules — a bug fixed once
in `pet.cpp` fixes both builds.
