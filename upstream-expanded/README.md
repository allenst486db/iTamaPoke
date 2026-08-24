# upstream-expanded/

`upstream/` (the git submodule) is pinned to **socquique/TamaPoke**, the base
firmware this whole port is built from. This folder is a **plain vendored
copy** (not a submodule) of the game-logic files from a different, separate
fork:

**[ShadowEnemyx/TamaPoke](https://github.com/ShadowEnemyx/TamaPoke), branch
`tamapoke-expanded-update`, commit `6dc9db3` (2026-08-21).** MIT licensed —
see `LICENSE` in this folder. Credited in socquique's own README under
"Community forks" as **TamaPoke — Expanded**.

## Local modification: the dex runs to 386, not 151

These files are otherwise vendored verbatim, with one deliberate exception.
`dex.h` has been extended from the fork's 151 species to **386** (gen 1-3),
with the extra rows transcribed from a third fork,
[DylanPDao/TamaPoke](https://github.com/DylanPDao/TamaPoke) (`dex.h`, commit
`35cbad6`), which already carries a gen 1-3 table. That fork is MIT licensed
like the others.

Only the species list grew. Specifically:

- **Rows 1-151 are untouched** -- byte for byte the fork's own. DylanPDao's
  table differs from it on 19 gen-1 species (Pikachu/Clefairy/Jigglypuff
  become `R_EVO` because gen 2 gave them babies; Golbat, Onix, Chansey,
  Scyther, Seadra, Porygon and others gain cross-gen evolutions). None of
  that was taken: adopting it would change how gen-1 species hatch and
  evolve, which is a gameplay change, not a longer list.
- Rows 152-386 are converted into *this* table's column order and its
  narrower `DexEntry` (the fork has no special-attack/defence columns, and
  the battle engine here does not use them, so they are dropped).
- 12 of the new species evolve into gen 4 (Togetic to Togekiss, Sneasel to
  Weavile, and so on). Those targets do not exist at 386, so their
  `evolvesTo` is cleared -- they are final forms in this build rather than
  dangling pointers.
- Localized names for the new rows come from PokeAPI. The six language rows
  keep their gen-1 contents exactly as they were, including the hand-written
  fixes there (`NIDORAN F`, `FARFETCHD`, `MR. MIME`).

`evolvesTo` widened from `uint8_t` to `uint16_t` for numbers above 255, and
`pet.h`'s three dex bitmaps are now sized from `DEX_COUNT` rather than a
literal 19 bytes. An existing save keeps everything it had: the store copies
`min(stored, sizeof)` bytes, so a 19-byte bitmap loads into the front of the
wider one and the rest starts empty.

## Why a plain copy, not a submodule

The fork's `pet.cpp` defines the same `class Pet` as `upstream/pet.cpp` --
they're the same class lineage, one built on top of the other. A build can
only compile one definition, so `pet.h`/`pet.cpp` from `upstream/` and this
folder are **never both in `project.yml`'s `sources:` at once** -- whichever
one is listed there is the one the app actually runs on. Right now that's
this folder, because the features below only exist in the fork.

## Why only these ten files

The fork adds a lot -- IMU step-counting (`imu.cpp`), synthesized
per-species chirps (`species_chirp.cpp`). None of that is ported here. Only
what's needed for the features that *are* ported (Personality page, Daily
goals page, Box/collection page, the Pokédex All/Raised/Caught filter, the
wild-battle system, the catch minigame, and expeditions) was pulled in:

- `pet.h` / `pet.cpp` -- the extended `Pet` class. A strict superset of
  `upstream/pet.h`/`.cpp`: everything the base port's Objective-C++ bridge
  (`Sources/Core/TPPet.mm`) already calls still compiles unchanged against
  this version. Also where the expedition state and methods live --
  expeditions didn't need a file of their own.
- `battle.h` / `battle.cpp` -- the turn-based wild-battle engine (stats,
  type effectiveness, the attack/dodge/rest turn resolver). Self-contained;
  its only dependency is `dex.h`. Bridged from `Sources/Core/TPBattle.mm`,
  a separate facade from `TPPet.mm` that owns the live `BattleRuntime`.
- `i18n.h` / `i18n.cpp` -- likewise a superset string table (now including
  the battle/expedition strings this port actually uses).
- `dex.h` -- same 151-entry table, with `type1`/`type2` fields added (used
  by the Pokédex detail view, Box rows, and battle type-effectiveness to
  print/compute a creature's type).
- `dayphase.h` -- tiny, pure helper (`currentDayPhase()`'s dependency) for
  the Daily page's morning/day/evening/night label.
- `time_utils.h` -- tiny deadline-comparison helpers `pet.h` depends on.
- `audio.h` -- adds new `Sfx` enum entries (`pet.cpp`/`battle.cpp` call
  `sfxPlay(SFX_DAILY_GOAL)` etc.); the original ten entries keep the same
  values, so `Sources/Shared/TPAudio.swift`'s effect table is unaffected.
  Only the header is vendored -- `Sources/Core/AudioStub.mm` (the
  no-hardware stub) already implements every function this header declares.

`imu.cpp`, `imu.h`, `species_chirp.cpp`, `species_chirp.h` are **not**
vendored -- nothing in these ten files references them, so leaving them out
doesn't break the build.
