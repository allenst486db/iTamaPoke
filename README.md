# TamaPoke for iPhone / Apple Watch

A personal-build port of [socquique/TamaPoke](https://github.com/socquique/TamaPoke) —
a gen-1-Pokémon-inspired tamagotchi firmware for the Waveshare ESP32-S3 round
AMOLED board — to iOS and watchOS.

> **Personal use only. Not distributable, not for the App Store.**
> See [Legal](#legal) before doing anything with this.

---

## Legal

This repo contains **no Pokémon assets and no sprites**. It is source code only:

| Thing | Where it lives | License |
|---|---|---|
| Upstream firmware game logic (`pet.cpp`, `dex.h`, `i18n.cpp`) | `upstream/` submodule — a commit reference, no copied files | MIT © Quique Tortosa |
| Renderer, layout, UI palette, status strings — **translated** from upstream C++ | `Sources/Shared/`, `Sources/Core/TPPet.mm` | MIT © Quique Tortosa (derivative work) |
| Shims, ObjC bridge structure, CI — original to this port | `Sources/Core/`, `.github/` | MIT |
| Pokémon names, designs, species data | **not in this repo** | © Nintendo / Game Freak / The Pokémon Company |
| Sprites | **not in this repo**, fetched per-user (phase 2) | [PMD SpriteCollab](https://github.com/PMDCollab/SpriteCollab), CC BY-NC 4.0 |

**What you may do:** build this and install it on *your own* devices.

**What you may not do:** publish it to the App Store (Apple review guideline
5.2.1 requires proof of rights you cannot produce), distribute built binaries,
put it in an alternative marketplace, or monetise it in any form. Free
distribution is still distribution — "non-commercial" is not a legal defence
against the underlying copyright. Do not commit fetched sprites; `.gitignore`
already blocks `Resources/mons/`.

If you want something you *can* ship, replace the creature art, names, and dex
data with your own. The MIT-licensed engine underneath is yours to keep.

---

## Status

Phase 1 — the vertical slice is in place: the upstream C++ game logic runs
unmodified, the idle screen renders, and CI produces an installable artifact.

**Working:** full game simulation (stat decay, evolution gating, egg rarity
rolls, streak/bond/medals, genes, offline progression), starter selection,
egg + hatching taps, idle scene (biome ground + real-time sky), need bars,
the four action buttons, feed menu, petting, sleep/wake, 6 UI languages.

**Not ported yet (phase 2):** sprite rendering — the app currently shows the
firmware's own "no sprites loaded" placeholder — plus the Pokédex gallery, stat
card, ball minigame, training bag, bath scene, clock/settings screen, on-screen
keyboard, and the evolution / farewell decision dialogs. Sound is haptics only.

---

## How the port works

The firmware draws into a fixed **466×466** framebuffer. That coordinate space
is preserved verbatim in `Sources/Shared/TPGraphics.swift`, and the SwiftUI
`Canvas` applies a single scale transform. Two consequences:

- `drawScene`, `drawBars`, `drawButtons` and friends port **line-for-line** —
  every `CX - strlen(s) * 6` centring expression stays correct as written.
- iPhone and Apple Watch differ only by that scale factor. No separate layouts.

The C++ game logic is **not rewritten**. `upstream/pet.cpp` and
`upstream/i18n.cpp` compile as-is against two shim headers:

| Shim | Replaces | Backed by |
|---|---|---|
| `Sources/Core/Arduino.h` | `millis()`, `random()`, `min/max`, `Serial` | `mach_absolute_time`, `arc4random` |
| `Sources/Core/Preferences.h` | ESP32 NVS key/value store | `NSUserDefaults` |
| `Sources/Core/AudioStub.mm` | ES8311 codec + I2S tone synth | a callback into Swift (haptics) |

`Sources/Core/TPPet.mm` is a deliberately thin Objective-C++ facade over the C++
`Pet`. All string composition lives there rather than in Swift, because
`i18n.h`'s `StrId` enum is only visible on that side — mirroring the ids in
Swift would drift silently on a submodule bump.

**The firmware already keeps time across power-off via its RTC**, catching up to
two weeks of elapsed simulation on boot. That design maps exactly onto iOS
foregrounding, which is why this port needs no background execution at all.

---

## Building

You do **not** need a Mac. Push to GitHub and the
[build workflow](.github/workflows/build.yml) produces an unsigned `.ipa` as a
run artifact.

```bash
git add -A && git commit -m "TamaPoke iOS/watchOS port" && git push
```

Locally (macOS only):

```bash
brew install xcodegen && xcodegen generate && open TamaPoke.xcodeproj
```

The `.xcodeproj` is generated from `project.yml` and is never committed.

---

## Installing

**CI cannot sign the app for you.** Free personal provisioning requires an
interactive Apple ID sign-in and has no API-key equivalent, so the workflow
emits an *unsigned* `.ipa` that you sign yourself on the way to the device.

From Windows:

1. Download the `TamaPoke-unsigned-ipa` artifact from the workflow run.
2. Install [AltStore](https://altstore.io) (AltServer runs on Windows) or
   [Sideloadly](https://sideloadly.io).
3. Sign it with your **free** Apple ID and install over USB or Wi-Fi.

Free-account limits: the app expires after **7 days** and must be re-signed
(AltServer refreshes it automatically while it is running), and a free Apple ID
allows 3 sideloaded apps at a time. A paid Apple Developer account ($99/yr)
extends the certificate to 1 year.

Before the first build, change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` from
`com.allenst486db.itamapoke` if you are not that account — free provisioning refuses
identifiers already claimed by another developer.

> ⚠️ **The Apple Watch app is unverified.** It compiles and is embedded in the
> `.ipa`, but sideloading tools have a poor track record installing embedded
> watch apps under free provisioning. The CI summary reports whether the watch
> app made it into the bundle. If the install drops it, the iPhone app is
> unaffected — the watch target is standalone
> (`WKRunsIndependentlyOfCompanionApp`) and can be built and installed on its
> own from Xcode on a Mac.

---

## Upstream

Pinned at `37ba1c4` (v1.4). To pull in upstream fixes:

```bash
git submodule update --remote upstream
```

Then rebuild — the shims are the only coupling, so most upstream changes cost
nothing. If `pet.h` grows a new Arduino symbol, add it to `Sources/Core/Arduino.h`;
do not patch `upstream/`.
