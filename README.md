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

Full attribution and scope: [NOTICE](NOTICE). License: [LICENSE](LICENSE) (MIT,
the same terms as upstream).

---

## Status

Phase 1 — the vertical slice is in place: the upstream C++ game logic runs
unmodified, the idle screen renders, and CI produces an installable artifact.

**Working:** full game simulation (stat decay, evolution gating, egg rarity
rolls, streak/bond/medals, genes, offline progression), starter selection,
egg + hatching taps, idle scene (biome ground + real-time sky), need bars,
the four action buttons, feed menu, petting, sleep/wake, 6 UI languages, and
animated creature sprites on iOS once you [add them](#sprites).

**Not ported yet:** the sprite walk/gesture scheduler (the creature stands
centred instead of wandering), sprites on watchOS, the Pokédex gallery, stat
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

Two workflows. Which one you can use is decided entirely by what kind of Apple
account you have — CI can sign for a paid membership and cannot sign for a free
Apple ID, and there is no way around that.

| | [Build (unsigned)](.github/workflows/build.yml) | [Build (signed)](.github/workflows/build-signed.yml) |
|---|---|---|
| Apple account | free Apple ID | paid Developer Program ($99/yr) |
| Runs | every push + manually | manually only |
| Setup | none | 4 repository secrets |
| Output | `.ipa` you must re-sign yourself | `.ipa` that installs as-is |
| Expires | 7 days | 1 year |
| Apple Watch | usually dropped on install | correctly signed, no re-signing step to drop it |
| Needs a Mac | no | no |

### Build (unsigned) — free Apple ID

Push, and the run artifact `TamaPoke-unsigned-ipa` appears on the Actions tab.
Sign it on the way to the device (see [Installing](#installing)).

### Build (signed) — paid Developer Program

Add these under **Settings → Secrets and variables → Actions**:

| Secret | Where it comes from |
|---|---|
| `APPLE_TEAM_ID` | Developer portal → Membership, 10 characters |
| `ASC_KEY_ID` | App Store Connect → Users and Access → Integrations |
| `ASC_ISSUER_ID` | same page, a UUID |
| `ASC_PRIVATE_KEY` | the `AuthKey_*.p8` file's full contents, `BEGIN`/`END` lines included |

The API key needs the **App Manager** role — it creates App IDs and provisioning
profiles on demand. It does *not* register devices, so plug your iPhone and your
Apple Watch into Xcode once beforehand; a build signed for unregistered devices
installs on nothing.

Then **Actions → Build (signed) → Run workflow**. `debugging` is the default
export method; `release-testing` (formerly "ad-hoc") is there if you want a build
to hand to someone else on your team's device list.

The team ID is read from a secret rather than committed, so `project.yml` stays
clean in a public repo.

> This workflow deliberately does **not** upload to TestFlight. TestFlight means
> App Store Connect review, and this app cannot pass it — see [Legal](#legal).

### Locally on a Mac

```bash
brew install xcodegen && xcodegen generate && open TamaPoke.xcodeproj
```

The `.xcodeproj` is generated from `project.yml` and is never committed.

---

## Sprites

The app ships with **no creature art**, so out of the box it draws the firmware's
own "No sprites" notice where the creature goes. The art is Pokémon fan work
derived from [PMD SpriteCollab](https://github.com/PMDCollab/SpriteCollab)
(CC BY-NC): fine to build onto your own device, not fine to commit or
redistribute. `Resources/mons/` is gitignored for exactly that reason.

The upstream submodule already carries the packed sprites, so there is nothing to
download — just copy the species you want in:

```bash
Scripts/fetch_sprites.sh 7        # one species, by Pokédex number
Scripts/fetch_sprites.sh 1 4 7    # the three starters
Scripts/fetch_sprites.sh all      # all 151, about 20 MB
xcodegen generate                 # so Xcode picks them up
```

A species with no file falls back to the "No sprites" notice, so copying a subset
is a supported state — but the creature disappears again when it evolves into a
form you did not copy. `--shiny` adds the shiny variants (another 20 MB).

Sprites are read from the app bundle at `mons/p<dex>.bin` in upstream's TPK2
format, decoded by `Sources/Shared/TPSprite.swift`. Only the current species is
resident at a time.

> **CI builds never contain sprites** — the files are not in the repo, so an
> `.ipa` from either workflow shows the placeholder. Copy the sprites in and
> build from Xcode to see the creature.

The watchOS target does not bundle sprites yet; the watch app still shows the
placeholder.

---

## Installing

Before the first build, change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` from
`com.allenst486db.itamapoke` if you are not that account — provisioning refuses
identifiers already claimed by another developer.

> ⚠️ **Getting the app onto an Apple Watch is the hard part.** Sideloading tools
> handle embedded watch apps badly — AltStore does not install them at all, and
> Sideloadly commonly drops them. Both CI workflows **fail** if the watch app is
> missing from the bundle, so a green run means it shipped; whether the *install*
> keeps it is up to the tool. If you want the watch app, install from Xcode.

### From Xcode — works with any Apple ID, and the only reliable path to the watch

Needs a Mac. Free Apple IDs work here: the interactive sign-in that CI cannot do
is exactly what Xcode does for you.

1. **Enable Developer Mode on both devices** (iOS 16+ / watchOS 9+):
   Settings → Privacy & Security → Developer Mode → on, then restart. The watch
   has its own toggle — turning it on for the iPhone does not cover it.
2. Generate and open the project:
   ```bash
   brew install xcodegen && xcodegen generate && open TamaPoke.xcodeproj
   ```
3. Select the **TamaPoke** target → Signing & Capabilities → tick *Automatically
   manage signing* → pick your Team. Repeat for the **TamaPokeWatch** target.
   Both must be the same team.
   > The `.xcodeproj` is generated, so this is reset by every `xcodegen generate`.
   > Re-pick the team after regenerating, or pass `DEVELOPMENT_TEAM=YOURTEAMID`
   > to `xcodebuild` if you build from the command line.
4. Connect the iPhone over USB and tap **Trust** on the device.
5. Pick the **TamaPoke** scheme and your iPhone as the destination → `⌘R`.
6. First launch only: iPhone → Settings → General → VPN & Device Management →
   trust your developer certificate. The app will not open until you do.
7. For the watch: pick the **TamaPokeWatch** scheme and your Apple Watch as the
   destination → `⌘R`. Keep the watch unlocked and on its charger; the first
   install can take several minutes and often looks stalled before it lands.

To drop the cable, tick *Connect via network* in Window → Devices and Simulators.

With a free Apple ID the app stops launching after **7 days** — re-run `⌘R` to
renew it. A paid membership makes it a year.

### From a signed `.ipa` — paid Developer Program

Download the `TamaPoke-signed-ipa` artifact from a *Build (signed)* run. It is
already signed for your team's registered devices, so no re-signing tool is
involved: open Xcode → Window → **Devices and Simulators**, select your iPhone,
and drag the `.ipa` onto the *Installed Apps* list ([Apple Configurator](
https://apps.apple.com/app/apple-configurator/id1037126344) also works).

### From an unsigned `.ipa` — free Apple ID, no Mac

1. Download the `TamaPoke-unsigned-ipa` artifact from a *Build (unsigned)* run.
2. Install [AltStore](https://altstore.io) (AltServer runs on Windows) or
   [Sideloadly](https://sideloadly.io).
3. Sign it with your free Apple ID and install over USB or Wi-Fi.

Free-account limits: the app expires after **7 days** and must be re-signed
(AltServer refreshes it automatically while it is running), and a free Apple ID
allows 3 sideloaded apps at a time.

Expect the watch app not to survive this route — see the warning above. The
iPhone app is unaffected either way: the watch target is standalone
(`WKRunsIndependentlyOfCompanionApp`), so it can be installed on its own from
Xcode later without reinstalling the phone app.

---

## Upstream

Pinned at `37ba1c4` (v1.4). To pull in upstream fixes:

```bash
git submodule update --remote upstream
```

Then rebuild — the shims are the only coupling, so most upstream changes cost
nothing. If `pet.h` grows a new Arduino symbol, add it to `Sources/Core/Arduino.h`;
do not patch `upstream/`.
