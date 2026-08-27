# How to play

This is the same game as [socquique/TamaPoke](https://github.com/socquique/TamaPoke)
— the C++ game logic is not reimplemented here, only rendered on a different
screen. Everything below is upstream's own design; this page just explains it
for the iPhone/Watch build.

**Personality, Daily goals, Box, the Pokédex filter, the wild-battle system,
the Catch/Memo/Clean/Type minigames, and expeditions** come from a second
source, [ShadowEnemyx/TamaPoke](https://github.com/ShadowEnemyx/TamaPoke)
("TamaPoke — Expanded") — a separate community fork, not from socquique's own
repository. Sections below say so where it matters; see the main
[README](../README.md#status) for the attribution.

[한국어](GAMEPLAY.ko.md) · with screenshots: [Gameplay guide (HTML)](GAMEPLAY.html)

---

## Getting a creature

The app starts with no creature: tap the screen and pick a starter, or if
you're mid-game already, hatch an egg. The starters are each generation's
trio — Bulbasaur/Charmander/Squirtle, Chikorita/Cyndaquil/Totodile,
Treecko/Torchic/Mudkip — one trio per page, headed GEN 1/2/3. Swipe left or
right to change generation; the dots under the list show where you are. An egg's rarity (never its species) is
visible before it hatches — a rarer egg is worth waiting for if you want a
better starting roll on stats, but any egg eventually hatches into a normal
creature that grows the same way.

## The idle screen

The creature wanders your home screen on its own, following a day/night sky
that tracks the real time on your device. Nothing about it needs your
attention constantly — this is designed to be checked in on, not stared at.

- **Swipe up** — the eight-page stat card (see below).
- **Swipe left** — the Pokédex: every species you've raised or seen, as a
  thumbnail grid, filterable to All/Raised/Caught.
- **Swipe down** — settings (language, sound).
- **Tap** the creature — a short reaction.
- **Hold** the creature for a few seconds — asks whether you want to let it
  go (see "Farewell" below). This is deliberately not a quick accident: you
  have to mean it.
- **Tap the feed icon** — opens the feed menu (berries and candy — see
  "Feeding").
- **A chip near the top** appears once an expedition is running or has a
  reward waiting — tap it to jump straight to the Expedition page (see
  below).
- **A "wild battle?" prompt** occasionally appears on its own while the
  creature is awake and otherwise idle — fight or dismiss it (see "Battle").

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

The feed-row play icon opens a menu of five minigames — tap a tile to start:

- **Ball** — catch/bounce timing game, raises happiness and bond.
- **Catch** — tap a moving target before it (or your patience) runs out;
  missing counts against you the same as letting it expire. *Expanded fork.*
- **Memo** — a Simon-style pad sequence that grows one step every round you
  get right. *Expanded fork.*
- **Clean** — scrub dirt spots that keep popping up before three slip past.
  *Expanded fork.*
- **Type** — a quick type-effectiveness quiz: pick which of three types beats
  the one shown before the clock runs out. *Expanded fork.*

Separately, the **training sack** (reached from the stat card's Battle page,
not the play menu) is a hit-the-target timing game that raises the battle
stats used there and in wild battles.

All of these are short, repeatable sessions rather than long minigames —
meant to be played in a spare minute, the same way you'd actually check on a
real tamagotchi.

## Battle

*Ported from the Expanded fork.* While the creature is awake, idle, and not
mid-ceremony, a "wild battle?" prompt occasionally appears on its own — fight
it, or tap later to dismiss for now. You can also start one any time from the
stat card's Battle page (see below).

Each round you choose one action:

- **Attack** — opens a Quick/Heavy choice: quick attacks hit lighter but let
  you shrug off more of the enemy's next hit; heavy attacks hit harder but
  leave you more exposed.
- **Dodge** — a chance to avoid the enemy's attack entirely and land a
  counter-bonus on your next move.
- **Rest** — heals a chunk of your HP, guards against some damage that round,
  and can only be used twice per battle.

Type matchups (the same 18 types as the main series) swing damage up or down.
Win, and you're offered a chance to catch what you just beat — added to your
Box and Pokédex either way as "caught." Lose, and a badly-hurt wild creature
sometimes offers you a consolation catch chance instead. Wins, losses, and
your best win streak show on the Battle stat-card page.

## Expedition

*Ported from the Expanded fork.* Sends the creature off on a timed tour —
15, 30, or 60 minutes, each costing energy up front and paying out a bigger
chance of a good reward the longer it runs. A chip appears near the top of
the idle screen once a tour is running (tap it to jump to the page) and again
once it's back with a reward to claim.

Rewards are one of four items, held in a small inventory on the Expedition
page: a snack (restores food), a tonic (restores energy), a care kit (clears
a slip-up), or a train token (opens a stat-choice menu that boosts one battle
stat). Tap an item to use it; the inventory caps out, so it's worth spending
what you're holding before sending the creature out again.

## The stat card (8 pages)

Swipe up from idle, then swipe left/right between pages:

1. **Profile** — name, level, hunger/happiness/hygiene bars.
2. **Personality** *(Expanded fork)* — a trait (Balanced/Playful/Brave/
   Calm/Lazy) derived from how you've raised this creature, plus its age and
   a grid of every minigame's personal-best record.
3. **Daily goals** *(Expanded fork)* — three goals that reroll once a real
   day passes; clearing all three pays out a bonus.
4. **Box** *(Expanded fork)* — every wild creature you've caught in battle,
   sortable, each row showing its type.
5. **Battle** — the gen-1-style stats (attack/defense/speed/weight) built
   from genes rolled at hatching, training, and level, plus your battle
   win/loss record and buttons to start a wild battle or open the training
   sack.
6. **Medals** — badges earned for milestones (streaks, bond thresholds,
   training goals). A medal you just earned plays its own short celebration.
7. **Progress** — streak (consecutive days cared for), best streak, bond
   level, and total medals across every creature you've raised, not just
   this one.
8. **Expedition** *(Expanded fork)* — start a tour, claim a reward, and
   manage the item inventory described above.

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

Six gen-1 species evolve across generations: Golbat into Crobat and Chansey
into Blissey at level 25, and Onix into Steelix, Seadra into Kingdra, Scyther
into Scizor and Porygon into Porygon2 at level 40. Species whose only
evolution arrived in gen 4 or later (Magneton, Lickitung, Rhydon, Tangela,
Electabuzz, Magmar, and twelve gen 2-3 ones such as Togetic and Sneasel) are
final forms here, since this build's dex stops at 386.

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

Every effect (tap, eat, evolve, medal, deny, farewell, battle hits, minigame
feedback, and more) is a chip-tune synthesized the same way the original
hardware and the Expanded fork generate theirs, not a recording — see the
main [README](../README.md#status) if you're curious how. The settings
screen's sound pill cycles through four levels — **ALL** (everything),
**MID**, **LOW** (only the important events — records, evolution, farewell,
battle results), and **OFF** — rather than a plain on/off switch. A haptic
plays alongside whatever sound is enabled.

The dex detail screen's cry-preview button is the one exception — it plays an
actual audio file, not a synthesized effect, and follows the same sound
setting above (muted SFX mutes cries too). A species with no cry file
installed simply has no button. See [README "Cries"](../README.md#cries) for
how to install them.

## Dex entries and language

The dex detail view's second page shows that species' flavor text — like
cries, it isn't bundled and has to be fetched (see [README "Pokédex
entries"](../README.md#pokédex-entries)) — and it automatically picks the
file matching whatever UI language is active. The settings screen cycles
through 8 language slots: ES/EN/FR/DE/IT/PT plus two Korean modes, **KR**
(the whole UI) and **kr** (species names and the dex only, everything else
stays English). The starter-picker screen has its own language pill too, so
you can switch before your very first creature exists.

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

**Eggs:** first creature is a starter you pick — one of the nine, a
generation per page. Every egg after rolls a rarity tier — Common/Rare/Legendary
(Legendary only unlocks after 25+ registered species) — biased toward
evolution lines you haven't completed, and shiny odds run from a base
1-in-48 up to about 1-in-8 with strong streak and bond, doubling briefly
right after a farewell.

**Evolution:** level ≥ the species' threshold (16 for most base forms, ~30
for stone-style, ~40 for trade-style) *and* every stat ≥ 40 at that instant.
Never automatic — always a button you tap. Declining re-offers next level.
Cross-gen lines work: Golbat→Crobat, Chansey→Blissey (25), Onix→Steelix,
Seadra→Kingdra, Scyther→Scizor, Porygon→Porygon2 (40). Anything whose
evolution is gen 4+ is a final form here.

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
