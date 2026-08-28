# iTamaPoke

![Platform](https://img.shields.io/badge/platform-iPhone%20%2B%20Apple%20Watch-black?logo=apple&logoColor=white)
![Code](https://img.shields.io/badge/code-custom%20license-blue)
![Status](https://img.shields.io/badge/status-personal%20project%2C%20bugs%20possible-yellow)

**[한국어 README](README.ko.md)**

A personal-build port of [socquique/TamaPoke](https://github.com/socquique/TamaPoke) —
a gen-1-Pokémon-inspired tamagotchi firmware for a round AMOLED board — to
iPhone and Apple Watch. The game itself is unchanged: the same C++ that runs
on the original hardware runs here too, just drawn on a different screen.

> **Personal use only. Do not publish or hand out builds — including
> reskinned versions (different creatures, same engine).**
> See [License](#license) before doing anything with this.

New here? Start with one of these:

| | |
|---|---|
| 🎮 [How to play](docs/GAMEPLAY.md) | What the game actually does, page by page |
| 🖼️ [How to play — screenshots](https://htmlpreview.github.io/?https://github.com/allenst486db/iTamaPoke/blob/main/docs/GAMEPLAY.html) | Same guide, illustrated with real screenshots (captured in English mode) |
| 📲 [Install guide](docs/INSTALL.md) | Step-by-step, no coding knowledge assumed — **works on both Mac and Windows now** |
| 🖼️ [Install guide — screenshots](https://htmlpreview.github.io/?https://github.com/allenst486db/iTamaPoke/blob/main/docs/INSTALL.html) | Same guide, illustrated with real screenshots |
| 🛠️ [Xcode build guide](https://htmlpreview.github.io/?https://github.com/allenst486db/iTamaPoke/blob/main/docs/xcode_build_guide.html) | Building and installing straight from Xcode, illustrated (Korean only) |
| 🍎 [Free vs. paid Apple account](docs/DEV_ACCOUNT.md) | Which install path is right for you |

> ⚠️ **This is a solo hobby port, not a finished product.** Some bugs are
> likely, especially on the Apple Watch side and the free-account install
> path (still being verified). If something looks wrong, that's expected at
> this stage — not something you broke.

---

## Status

Feature-complete against upstream: every screen and animation in the
firmware is ported and running the same underlying game logic.

**Screens:** idle scene with a real-time day/night sky, starter selection,
egg and hatching, feed menu, bath, the Pokédex gallery (with an
All/Raised/Caught filter), the eight-page stat card (profile / personality /
daily goals / box / battle / medals / progress / expedition), a wild-battle
screen (attack / dodge / rest, with a catch offer on a win), a five-tile play
menu (Ball, Catch, Memo, Clean, Type), the training sack, the rename
keyboard, settings, and the evolution / farewell / runaway decisions with
their animations.

**Personality, Daily goals, Box, the Pokédex filter, the battle system, the
Catch/Memo/Clean/Type minigames, expeditions, and the sound-effect
synthesizer (chip-tune waveforms, four-level sound mode)** are ported from
[ShadowEnemyx/TamaPoke](https://github.com/ShadowEnemyx/TamaPoke) ("TamaPoke
— Expanded"), a separate community fork — not from the `upstream/` submodule,
which pins socquique/TamaPoke and doesn't have these. See
[`upstream-expanded/README.md`](upstream-expanded/README.md) for exactly
which files that is and why. The Box page fills in as you win wild battles
and catch what you beat.

**The dex holds 386 species (gen 1-3), not 151.** Only the list grew: the
gen-1 rows are byte-for-byte the ones this port already shipped, and no
rarity, evolution, stat or battle rule changed with them. The extra rows are
transcribed from a third fork,
[DylanPDao/TamaPoke](https://github.com/DylanPDao/TamaPoke) —
see [`upstream-expanded/README.md`](upstream-expanded/README.md) for exactly
what was and wasn't taken. An existing save keeps every species it had.

**Sound** is re-synthesised in software rather than re-recorded, the same
chip-tune waveforms (square/triangle/soft/noise, with slides and per-effect
volume) the fork's own audio.cpp generates — see [How the port
works](#how-the-port-works).

**Korean is a seventh language**, alongside the fork's existing ES/EN/FR/DE/IT/PT
— cycle to it from Settings. Unlike those six, Korean has no glyphs in the
system's monospaced font and falls back to a proportional one, so every
centring/alignment call in the UI now measures real glyph width instead of
assuming a fixed `size*6`px/character (see
[`kor_patch/FEASIBILITY.ko.md`](kor_patch/FEASIBILITY.ko.md) for why, and
[`kor_patch/`](kor_patch) generally for the localization notes). Species
names and UI strings are translated and built in; Pokédex entry text follows
the existing per-user fetch (`Scripts/fetch_dex_entries.sh --lang ko`), same
copyright handling as the sprites. **Not yet verified on a real phone or
watch** — only structural checks (string-table sizes, printf format-specifier
safety, compiler syntax checks) — so treat it as freshly landed until someone
actually plays through it in Korean.

**One deliberate difference:** the settings screen has no manual clock. The
original hardware sets its own clock by hand because it has no other way to
know the time; the phone already knows, so this port just uses that instead.

---

## Game manual (the actual numbers)

Same engine as upstream, so the same numbers — this is the same table from
[upstream's README](https://github.com/socquique/TamaPoke#game-manual-the-actual-numbers),
kept here for reference. For the plain-language version, see [How to
play](docs/GAMEPLAY.md).

**Leveling:** 1 real minute = 1 in-game minute. **+1 level every hour** of
real time — leveling itself doesn't speed up from good care, but neglect
*delays evolution*. Time keeps passing while the app is closed (like the
original hardware's RTC), catching up to **2 weeks** on reopen.

**The four stats (0–100):** FOOD, JOY, ENE (energy), HYG (hygiene). Start at
80/80/80/100, and while awake, per minute: FOOD −2, ENE −1 (extra −1 if
overweight), HYG −1 (extra −4 per visible mess), JOY −1 (extra −2 if FOOD or
HYG < 30). A stat hitting ≤10 is a **care slip-up** — it delays evolution by
one level and cools the bond.

**Actions:** Berries +25 FOOD (a species' hidden favorite flavor gives more,
plus bond); Candy +10 FOOD/+12 JOY but adds weight; the ball minigame trains
SPEED; the training sack trains STRENGTH; bath clears mess; petting is a
small JOY/bond bump; sleep slows every drain roughly 4× and disables
slip-ups and running away.

**Eggs:** your very first creature is a starter you pick from nine — each
generation's trio, one generation per swipeable page. Every egg after
that rolls a rarity (Common/Rare/Legendary — Legendary only unlocks after
you've registered 25+ species), biased toward evolution lines you haven't
finished, improved by streak/bond, and shiny odds run from a base **1-in-48**
up to **1-in-8** with a strong streak and bond.

**Evolution:** needs level ≥ the species' threshold *and* every stat ≥ 40 at
that moment. Never automatic — you tap a button to trigger it. Six gen-1
species evolve across generations (Golbat, Onix, Chansey, Seadra, Scyther,
Porygon); anything whose evolution only exists in gen 4+ is a final form
here.

**Endings:** Farewell (final form, 3 days old, your choice — blesses the
next egg), Runaway (all four stats at 0 for a full hour — curses the next
egg), Release (long-press any time). All three lead to a new egg.

---

## How the port works

The firmware draws into a fixed **466×466** framebuffer. That exact
coordinate space is preserved in this port, with a single scale transform
applied for the iPhone/Watch screen sizes — so `drawScene`, `drawBars`, and
every other draw call port **line-for-line** from the original C++.

The game logic itself is **not rewritten**. The original `pet.cpp` and
`i18n.cpp` compile as-is, against small shim headers that stand in for
Arduino/ESP32-specific pieces (timers, random, key/value storage). A thin
bridge layer exposes that C++ object to the Swift UI — nothing about the
simulation, stat decay, evolution rules, or egg odds is reimplemented.

Sound is the same story: the firmware generates chip-tune waveforms (square,
triangle, a softer wave, and noise, with slides and per-effect volume — the
Expanded fork's own audio.cpp) on its own audio chip. There's no such chip
here, so the same waveforms (same note tables, same sample rate, same
envelope) are synthesised in software instead of using a new sound.

---

## Installing

Full step-by-step walkthrough (screenshots-level detail, assumes no coding
background): **[docs/INSTALL.md](docs/INSTALL.md)**.

The short version — three ways to get this running, easiest first:

| | Needs | Works on | Apple Watch | Notes |
|---|---|---|---|---|
| **Unsigned `.ipa` (no-watch) + Sideloadly/AltStore** | free Apple ID, no Mac | Mac or **Windows** | not included in this build — see note below | Easiest path; iPhone only; re-sign every 7 days |
| **Signed `.ipa` from GitHub Actions** | paid Apple Developer account ($99/yr) | Mac or Windows | installs correctly | No sideloading tool needed at all |
| **Build with Xcode yourself** | a Mac | Mac only | most reliable path | For anyone comfortable with Xcode already |

**A free Apple ID cannot sideload the watch app, full stop** — a free
provisioning profile can't cover a second, embedded watchOS app. The
"Build (unsigned)" CI job produces two `.ipa` files for exactly this reason:
`TamaPoke-unsigned-nowatch.ipa` (iPhone only — download this one) and
`TamaPoke-unsigned-withwatch.ipa` (kept for reference; AltStore refuses to
install it and Sideloadly drops the watch app while installing the phone app,
so don't sideload it). If you want the game on your watch without a paid
account, use Path C (build with Xcode, connected directly to your paired
watch) instead of sideloading.

Whichever path you take, the app installs with **no creature art built in**
— see [Sprites](#sprites) for how that gets added, which now works the same
way regardless of which install path you used.

---

## Sprites

The app never ships with Pokémon art baked in — that's fan art with its own
license (see [License](#license)), so it's added after installing, not
included in any build.

**The simple way — works after any install method:** open the **Files**
app → **On My iPhone → iTamaPoke** → make a folder named `mons` → copy in
`.bin` sprite files (get them from
[upstream's repo](https://github.com/socquique/TamaPoke), `tools/sdcard/mons/`
— see [Install guide](docs/INSTALL.md) for exactly where to click). Restart
the app afterward. Add `thumbs.bin` too, or the Pokédex screen shows nothing
at all. If you also have an Apple Watch paired, opening the phone app briefly
tries to relay whatever you added over to the watch automatically — opening
the watch app afterward tends to make that happen immediately.

**The Xcode way — for a build you make yourself:** `Scripts/fetch_sprites.sh`
copies sprites from the `upstream/` submodule straight into the build, so
they're baked into the app the moment you build. See
[docs/INSTALL.md](docs/INSTALL.md) ("Path C") for the exact commands.

`upstream/` carries the gen-1 151 only. Gen 2-3 sprites, and the shiny
variants of everything, are built from PMD SpriteCollab with
`Scripts/pack_shiny_sprites.py` (shiny) into the same folder. Shiny is a rare
recolour a creature can hatch with — a species without a shiny file simply
hatches looking normal, still marked with a `*`.

A species with no sprite file just shows a placeholder instead of a broken
screen, so partial sets are fine.

---

## Pokédex entries

Tapping a species in the Pokédex opens a two-page detail view — the portrait
with its type chips on the first page, its dex entry on the second. That entry
text is Nintendo / Game Freak's writing, so, exactly like the sprites above,
**none of it is committed here**. The page reads `mons/dex_entries_<lang>.txt`
— one file per language, matching whichever the UI is currently set to —
resolved the same way sprites are: `Documents/mons/` first (Files → On My
iPhone → iTamaPoke), then the app bundle.

`Scripts/fetch_dex_entries.sh` builds one of those files from
[PokéAPI](https://pokeapi.co) — the same source upstream already uses for the
battle stats in `dex.h`. Run it once per language you want available; each
run only touches that language's own file:

```bash
Scripts/fetch_dex_entries.sh              # every species, in English
Scripts/fetch_dex_entries.sh --lang es    # in Spanish
Scripts/fetch_dex_entries.sh 1 4 7        # just these three
```

The format is one entry per line, `<dex number>|<text>`; blank lines and `#`
comments are ignored, so you can also write it by hand:

```
122|It uses its hands to create invisible walls.
```

With no file installed for the active language, the page just says
`NO DEX ENTRY`; nothing else about the screen changes.

---

## Cries

The same detail view's first page can also play a short cry, in a capsule
button between the portrait and the page dots — hidden entirely for a species
with no cry file installed. Like the sprites and dex entries, cries are
Nintendo / Game Freak's audio, **not committed here**, read from
`mons/psnd<dex number>.m4a` the same way (`Documents/mons/` first, then the
bundle). Playback follows the app's own sound setting — muted SFX means muted
cries too.

`Scripts/fetch_cries.sh` builds those files from
[PokéAPI's cries repo](https://github.com/PokeAPI/cries), converting each
clip from `.ogg` to `.m4a` with `ffmpeg` on the way in, since AVFoundation
cannot decode Ogg Vorbis on iOS/watchOS. Install `ffmpeg` first
(`brew install ffmpeg`), then:

```bash
Scripts/fetch_cries.sh              # every species
Scripts/fetch_cries.sh 1 4 7        # just these three
```

`Scripts/fetch_assets.sh` is a thin wrapper that fetches sprites, shiny
sprites, and cries together — everything `Resources/mons/` can hold, in one
call:

```bash
Scripts/fetch_assets.sh                    # every asset, every species
Scripts/fetch_assets.sh 1 4 7              # every asset, just these three
Scripts/fetch_assets.sh --only sound       # cries only
Scripts/fetch_assets.sh --only sprites,shiny 25 25   # Pikachu's two sprites
```

---

## Saves and the Files app

The iPhone app keeps its save in **Files → On My iPhone → iTamaPoke** as
`iTamaPoke-save.json`, rewritten automatically whenever the game saves. Copy
it out as a backup, or onto another device.

To restore one, drop it back in renamed to `iTamaPoke-import.json` and open
the app — it loads once, then renames itself so a restart can't silently
re-import it again. **This replaces the creature currently on that device.**

The Apple Watch app keeps a fully separate save and has no Files folder of
its own.

---

## App icon

Ships with a small generic mascot icon by default (no Pokémon art, drawn
for this project). Want your own? `Scripts/fetch_app_icon.sh path/to/icon.png`
replaces it — see [docs/INSTALL.md](docs/INSTALL.md) ("App icon") for details.

---

## License

- **This port's own code** (the Swift/watchOS layer, scripts, docs):
  **[LICENSE](LICENSE)** — a short custom license, not a standard
  open-source one. Personal use and modification are free; publishing or
  handing out any build (including a reskinned one) needs the copyright
  holder's permission first. Read it — it's a few screens, not forty.
- **Portions translated line-for-line from upstream's C++** (the renderer,
  layout, and similar): remain © Quique Tortosa, MIT — the exact MIT notice
  travels with this repo in [NOTICE](NOTICE) so it's included regardless of
  how you obtained this repo, per MIT's own terms.
- **The `upstream/` submodule itself**: not ours to relicense — get it
  directly from [its own repository](https://github.com/socquique/TamaPoke)
  under its own MIT terms.
- **Pokémon names, designs, dex text, and cries**: © Nintendo / Game Freak /
  The Pokémon Company. **Not distributed anywhere in this repository or its
  builds** — see [Sprites](#sprites), [Pokédex entries](#pokédex-entries),
  and [Cries](#cries) for how you fetch your own copy after installing.
- **Sprite art**: [PMD SpriteCollab](https://github.com/PMDCollab/SpriteCollab)
  (CC BY-NC 4.0 — https://creativecommons.org/licenses/by-nc/4.0/), a
  fan-drawn, non-commercial project distinct from Nintendo's own art. Also
  not distributed here — see [NOTICE](NOTICE) for why this repo treats it
  under the same "fetch per device" rule as the Nintendo-owned assets above,
  even though CC BY-NC alone would permit more.

This is an unofficial fan project, not affiliated with or endorsed by
Nintendo. Full accounting of what is and isn't covered: [NOTICE](NOTICE).

---

## Credits

Game design, engine, and original hardware: **Quique Tortosa**
([socquique/TamaPoke](https://github.com/socquique/TamaPoke)). Sprites:
[PMD SpriteCollab](https://github.com/PMDCollab/SpriteCollab). Battle stats:
[PokéAPI](https://pokeapi.co). Pokémon is a trademark of Nintendo / Game
Freak / The Pokémon Company.

---

## Upstream

Pinned at `37ba1c4`. To pull in upstream fixes:

```bash
git submodule update --remote upstream
```

Then rebuild — the shim layer is the only coupling, so most upstream changes
cost nothing on this side.
