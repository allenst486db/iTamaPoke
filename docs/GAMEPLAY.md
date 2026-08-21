# How to play

This is the same game as [socquique/TamaPoke](https://github.com/socquique/TamaPoke)
— the C++ game logic is not reimplemented here, only rendered on a different
screen. Everything below is upstream's own design; this page just explains it
for the iPhone/Watch build.

[한국어](GAMEPLAY.ko.md)

---

## Getting a creature

The app starts with no creature: tap the screen and pick a starter, or if
you're mid-game already, hatch an egg. An egg's rarity (never its species) is
visible before it hatches — a rarer egg is worth waiting for if you want a
better starting roll on stats, but any egg eventually hatches into a normal
creature that grows the same way.

## The idle screen

The creature wanders your home screen on its own, following a day/night sky
that tracks the real time on your device. Nothing about it needs your
attention constantly — this is designed to be checked in on, not stared at.

- **Swipe up** — the four-page stat card (see below).
- **Swipe left** — the Pokédex: every species you've raised or seen, as a
  thumbnail grid.
- **Swipe down** — settings (language, sound).
- **Tap** the creature — a short reaction.
- **Hold** the creature for a few seconds — asks whether you want to let it
  go (see "Farewell" below). This is deliberately not a quick accident: you
  have to mean it.
- **Tap the feed icon** — opens the feed menu (berries and candy — see
  "Feeding").

## Feeding

Feeding is the main way you raise hunger and happiness. Two kinds of food:

- **Berries** — restore hunger. Different colours are cosmetic; all berries
  work the same way.
- **Candy** — a rarer treat that gives a bigger boost and nudges training
  stats, so it matters more as the creature gets stronger.

Overfeeding stops helping past a point and can make the creature sick, the
same way undereating does — the meter is a target range, not a "more is
always better" bar.

## Bath and cleaning

Neglect creates mess (shown as a poop icon near the creature); tap it to
clean up. The creature can also get dirty enough to need an actual bath —
opening that scene shows the same rising-bubble animation the original
hardware draws, not a generic wash effect.

## Training and play

Two activities raise different things:

- **Ball minigame** — catch/bounce timing game, raises happiness and bond.
- **Training sack** — a hit-the-target timing game, raises the battle stats
  used in the stat card's "battle" page.

Both are short, repeatable sessions rather than long minigames — meant to be
played in a spare minute, the same way you'd actually check on a real
tamagotchi.

## The stat card (4 pages)

Swipe up from idle, then swipe left/right between pages:

1. **Profile** — name, level, hunger/happiness/hygiene bars.
2. **Battle** — the gen-1-style stats (attack/defense/speed/etc.) built from
   genes rolled at hatching, training, and level.
3. **Medals** — badges earned for milestones (streaks, bond thresholds,
   training goals). A medal you just earned plays its own short celebration.
4. **Progress** — streak (consecutive days cared for), best streak, bond
   level, and total medals across every creature you've raised, not just
   this one.

Tap the creature's name on page 1 to open the rename keyboard. Tap anywhere
else, or swipe down past the last page, to close the card.

## Evolution

Once a creature meets its evolution conditions (level and, upstream's own
rules, other stat/bond thresholds), an evolve button appears on the stat
card. Evolving is always a choice — the game never forces it — and if you
decline, it asks again next time you level up rather than nagging
continuously. Evolving plays a flash/silhouette animation before the new
form settles in, and the creature keeps its name, bond, and stats across the
change.

## Farewell (letting a creature go)

Holding the creature (see "The idle screen") asks for confirmation, then
plays a short goodbye scene before returning you to starter/egg selection.
This is also how the game handles a creature that's been badly neglected for
long enough to run away on its own — same scene, same effect: a fresh start,
with your total medal count and best streak carried forward as your running
record.

## Time and offline progress

The original hardware keeps time through a real-time clock even while
powered off, and catches up on stat decay (up to a cap) the moment it powers
back on. This port relies on the same logic, driven by your device's own
clock instead of a hardware RTC — so leaving the app closed for a day and
reopening it works the same way leaving the original toy on a shelf does.

## Sound

Every effect (tap, eat, evolve, medal, deny, farewell, etc.) is the original
hardware's own square-wave tone, not a new sound — see the main
[README](../README.md#status) if you're curious how. A haptic plays alongside
sound, and either can be turned off from settings without turning off the
other.

---

## The actual numbers

Everything above in plain language; this is the same values straight from
the (unmodified) game code, for anyone who wants to know exactly what's
going on. Also in [the main README](../README.md#game-manual-the-actual-numbers).

**Leveling:** 1 real minute = 1 in-game minute. **+1 level per real hour** —
purely time-based, so good care doesn't speed it up, but neglect *delays*
evolution. Keeps aging while the app is closed, catching up to **2 weeks**
on reopen.

**Stats (0–100), start at 80/80/80/100, per minute while awake:**

| Stat | Drain/min | Extra drain |
|---|---|---|
| FOOD | −2 | |
| ENE (energy) | −1 | −1 more if overweight |
| HYG (hygiene) | −1 | −4 per visible mess |
| JOY (happiness) | −1 | −2 if FOOD < 30, −2 if HYG < 30 |

A stat hitting ≤10 is a **care slip-up**: delays evolution by 1 level, cools
the bond. About a 15%/minute chance of a mess appearing once FOOD > 40.

**Actions:** berry +25 FOOD (a species' hidden favorite flavor: +35 FOOD,
+10 JOY, and reveals itself); candy +10 FOOD/+12 JOY but +12 weight; ball
minigame trains SPEED and burns weight; training sack trains STRENGTH
(~4 hits per point, capped per session); bath clears mess and maxes HYG;
petting +5 JOY and bond; sleep cuts drains to roughly a quarter speed and
disables slip-ups/running away entirely.

**Eggs:** first creature is a starter you pick (Bulbasaur/Charmander/
Squirtle). Every egg after rolls a rarity tier — Common/Rare/Legendary
(Legendary only unlocks after 25+ registered species) — biased toward
evolution lines you haven't completed, and shiny odds run from a base
1-in-48 up to about 1-in-8 with strong streak and bond, doubling briefly
right after a farewell.

**Evolution:** level ≥ the species' threshold (16 for most base forms, ~30
for stone-style, ~40 for trade-style) *and* every stat ≥ 40 at that instant.
Never automatic — always a button you tap. Declining re-offers next level.

**Endings** (all lead to a new egg): **Farewell** — final form, 3 days old,
your choice, blesses the next egg. **Runaway** — all four stats at 0 for a
full hour, curses the next egg (forces Common). **Release** — long-press any
time, neutral.

**Streak/bond/medals:** streak is player-wide (survives across creatures) —
first care of each real day advances it, milestones at 3/7/30/100 days,
skipping a day breaks it. Bond is per-creature, resets on hatch. Both
improve egg rarity and shiny odds. 8 medals exist (level thresholds,
favorite berry found, 7-day streak, max bond, reaching final form, "fit" =
never overweight and no slip-ups) — tracked per-creature plus a running
total across every creature you've raised.
