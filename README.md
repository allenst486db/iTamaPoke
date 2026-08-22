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
| 📲 [Install guide](docs/INSTALL.md) | Step-by-step, no coding knowledge assumed — **works on both Mac and Windows now** |
| 🖼️ [Install guide — screenshots](https://htmlpreview.github.io/?https://github.com/allenst486db/iTamaPoke/blob/main/docs/install_guide.html) | Same guide, illustrated with real screenshots — EN/한국어 and light/dark toggle |
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
egg and hatching, feed menu, bath, the Pokédex gallery, the four-page stat
card (profile / battle / medals / progress), the ball minigame, the training
sack, the rename keyboard, settings, and the evolution / farewell / runaway
decisions with their animations.

**Sound** is the original hardware's own square-wave tones, re-synthesised
in software rather than re-recorded — see [How the port
works](#how-the-port-works).

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

**Eggs:** your very first creature is a starter you pick. Every egg after
that rolls a rarity (Common/Rare/Legendary — Legendary only unlocks after
you've registered 25+ species), biased toward evolution lines you haven't
finished, improved by streak/bond, and shiny odds run from a base **1-in-48**
up to **1-in-8** with a strong streak and bond.

**Evolution:** needs level ≥ the species' threshold *and* every stat ≥ 40 at
that moment. Never automatic — you tap a button to trigger it.

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

Sound is the same story: the firmware generates Game Boy–style square waves
on its own audio chip. There's no such chip here, so the same waveform
(same note tables, same sample rate, same envelope) is synthesised in
software instead of using a new sound.

---

## Installing

Full step-by-step walkthrough (screenshots-level detail, assumes no coding
background): **[docs/INSTALL.md](docs/INSTALL.md)**.

The short version — three ways to get this running, easiest first:

| | Needs | Works on | Apple Watch | Notes |
|---|---|---|---|---|
| **Unsigned `.ipa` + Sideloadly/AltStore** | free Apple ID, no Mac | Mac or **Windows** | often not carried over — see note below | Easiest path; re-sign every 7 days. **Still being verified — see the warning above.** |
| **Signed `.ipa` from GitHub Actions** | paid Apple Developer account ($99/yr) | Mac or Windows | installs correctly | No sideloading tool needed at all |
| **Build with Xcode yourself** | a Mac | Mac only | most reliable path | For anyone comfortable with Xcode already |

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

A species with no sprite file just shows a placeholder instead of a broken
screen, so partial sets are fine.

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
- **Pokémon names, designs, and sprites**: © Nintendo / Game Freak / The
  Pokémon Company; sprite art from
  [PMD SpriteCollab](https://github.com/PMDCollab/SpriteCollab) (CC BY-NC
  4.0). **Not distributed anywhere in this repository or its builds** — see
  [Sprites](#sprites) for how you add your own copy after installing.

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
