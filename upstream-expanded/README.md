# upstream-expanded/

`upstream/` (the git submodule) is pinned to **socquique/TamaPoke**, the base
firmware this whole port is built from. This folder is a **plain vendored
copy** (not a submodule) of the game-logic files from a different, separate
fork:

**[ShadowEnemyx/TamaPoke](https://github.com/ShadowEnemyx/TamaPoke), branch
`tamapoke-expanded-update`, commit `6dc9db3` (2026-08-21).** MIT licensed —
see `LICENSE` in this folder. Credited in socquique's own README under
"Community forks" as **TamaPoke — Expanded**.

## Why a plain copy, not a submodule

The fork's `pet.cpp` defines the same `class Pet` as `upstream/pet.cpp` --
they're the same class lineage, one built on top of the other. A build can
only compile one definition, so `pet.h`/`pet.cpp` from `upstream/` and this
folder are **never both in `project.yml`'s `sources:` at once** -- whichever
one is listed there is the one the app actually runs on. Right now that's
this folder, because the features below only exist in the fork.

## Why only these eight files

The fork adds a lot -- a full type-matchup battle system (`battle.cpp`), an
expedition/exploration mode, IMU step-counting (`imu.cpp`), synthesized
per-species chirps (`species_chirp.cpp`). None of that is ported here. Only
what's needed for the features that *are* ported (Personality page, Daily
goals page, Box/collection page, and the Pokédex All/Raised/Caught filter)
was pulled in:

- `pet.h` / `pet.cpp` -- the extended `Pet` class. A strict superset of
  `upstream/pet.h`/`.cpp`: everything the base port's Objective-C++ bridge
  (`Sources/Core/TPPet.mm`) already calls still compiles unchanged against
  this version.
- `i18n.h` / `i18n.cpp` -- likewise a superset string table (includes
  strings for the battle/expedition features that aren't ported here; they
  just go unused).
- `dex.h` -- same 151-entry table, with `type1`/`type2` fields added (used
  by the Pokédex detail view and Box rows to print a creature's type).
- `dayphase.h` -- tiny, pure helper (`currentDayPhase()`'s dependency) for
  the Daily page's morning/day/evening/night label.
- `time_utils.h` -- tiny deadline-comparison helpers `pet.h` depends on.
- `audio.h` -- adds new `Sfx` enum entries (`pet.cpp` calls
  `sfxPlay(SFX_DAILY_GOAL)`); the original ten entries keep the same values,
  so `Sources/Shared/TPAudio.swift`'s effect table is unaffected. Only the
  header is vendored -- `Sources/Core/AudioStub.mm` (the no-hardware stub)
  already implements every function this header declares.

`battle.cpp`, `battle.h`, `imu.cpp`, `imu.h`, `species_chirp.cpp`,
`species_chirp.h` are **not** vendored -- nothing in these eight files
references them, so leaving them out doesn't break the build.
