# Install guide (no coding knowledge needed)

[한국어](INSTALL.ko.md)

This assumes nothing except that you can download a file and follow steps.
If a term isn't explained inline, it's explained the first time it comes up.

> ⚠️ **Before you start:** this is a one-person hobby port, not a finished
> commercial app. The free-account install path below is still being
> verified across different devices, and bugs are possible anywhere in the
> app — especially around the Apple Watch. If something doesn't work, please
> don't assume it's something you did wrong.

## Which path should I take?

```
Do you have a paid Apple Developer account ($99/year)?
│
├─ No (most people) ─┬─ Don't want to re-sign every 7 days,
│                    │  or just want the easiest route ───► Path D: Browser build
│                    │                                       (any computer, ~10 min,
│                    │                                       never expires, no coding)
│                    │
│                    └─ Want it as a real iOS app ─────────► Path A: Free install
│                                                            (Mac or Windows, ~15 min,
│                                                            renew every 7 days)
│
└─ Yes ────────────────────────────────────────────────────► Path B: Signed install
                                                             (~10 min, no re-signing ever)
```

There's also **Path C**, building it yourself with Xcode — only relevant if
you already have a Mac with Xcode and want to bake sprites directly into the
app instead of adding them afterward. **Path D** is a separate browser
build (`browser_ver/`) that runs the same game logic, with the same
screens, in a web page. It needs no Mac, no developer account and no
sideloading tool, so **if this is your first time, start with Path D.**

---

## Path A — Free install (Sideloadly or AltStore)

Works on **both Mac and Windows**. You'll need: your iPhone, its USB cable
(for the first step), and a free Apple ID (the same kind you already use for
the App Store — no paid account needed).

### 1. Download the app file

1. Open this repository's page in a browser and click the **Actions** tab
   near the top.
2. Click **Build (unsigned)** in the left sidebar.
3. Click the most recent run at the top of the list — it should have a green
   checkmark ✅ next to it.
4. Scroll down to **Artifacts** — there are two files. Download
   **`TamaPoke-unsigned-nowatch-ipa`** (iPhone only). It downloads as a
   `.zip` — unzip it, and you'll have a file called
   `TamaPoke-unsigned-nowatch.ipa`. That's the app, just not yet signed for
   your phone (see below for what that means).

   > Ignore `TamaPoke-unsigned-withwatch-ipa`. It's the same app with the
   > Apple Watch companion app built in, kept around for reference — but a
   > free Apple ID can't provision a second, embedded watch app, so AltStore
   > refuses to install that file at all, and Sideloadly installs the phone
   > app but silently drops the watch half. If you want this on your watch
   > without a paid developer account, use **Path C** below (Xcode, connected
   > directly to your paired watch) instead of sideloading.

### 2. Install a sideloading tool

An `.ipa` you download from the internet isn't signed for your specific
Apple account yet, so iOS won't install it directly. A **sideloading tool**
signs it with your own free Apple ID first. Pick one:

- **[AltStore](https://altstore.io)** — recommended if you want the app to
  keep renewing itself automatically (see step 5). Works on Windows and Mac.
- **[Sideloadly](https://sideloadly.io)** — simpler one-time install, but you
  repeat the renewal step by hand every 7 days. Also works on Windows and
  Mac.

Both are free, official-looking third-party tools widely used for exactly
this purpose — install whichever from its own website.

### 3. Sign and install

**With Sideloadly:**
1. Connect your iPhone to your computer with a USB cable, and open
   Sideloadly.
2. Drag `TamaPoke-unsigned-nowatch.ipa` into the Sideloadly window.
3. Enter your Apple ID email in the box provided.
4. Click **Start**. It'll ask for your Apple ID password at some point —
   this goes directly to Apple to sign the app, not to us or anyone else.
5. Wait for it to finish. The app appears on your phone's home screen.

**With AltStore:**
1. Install **AltServer** on your computer (from altstore.io) and follow its
   setup — it walks you through installing AltStore on your iPhone the
   first time, which needs the phone connected once.
2. Make sure your phone and computer are on the **same Wi-Fi network**.
3. On your iPhone, open the **AltStore** app → **My Apps** → tap the **+**
   button → choose `TamaPoke-unsigned-nowatch.ipa`.
4. Enter your Apple ID if asked. Wait for the install.

### 4. Trust the app on your iPhone

The first time you try to open it, iOS will refuse and tell you the
developer isn't trusted. Fix this once:

**Settings → General → VPN & Device Management** → tap the entry under
"Developer App" (it'll have your Apple ID's name on it) → **Trust**.

Now the app opens normally.

### 5. Add the creature art

The app installs with no Pokémon sprites in it — see [why in the main
README](../README.md#sprites). Add them like this:

1. On your computer, go to
   [github.com/socquique/TamaPoke](https://github.com/socquique/TamaPoke) →
   green **Code** button → **Download ZIP**.
2. Unzip it, and find the folder `tools/sdcard/mons` inside — that's a
   folder full of `.bin` files, one per creature, plus one called
   `thumbs.bin`.
3. Get that `mons` folder onto your iPhone — AirDrop (Mac), emailing it to
   yourself, or a cloud drive app all work. The point is just getting the
   files somewhere the **Files** app on your iPhone can reach.
4. On your iPhone, open the **Files** app → **On My iPhone** → **iTamaPoke**.
5. Inside that folder, create a new folder named exactly `mons` (if the
   files you transferred already came as a `mons` folder, you can just move
   that whole folder in instead of creating an empty one).
6. Copy the `.bin` files in — all of them for every creature, or just a few
   if you want to keep it small. **Make sure `thumbs.bin` is included too**
   — without it, the Pokédex screen shows nothing.
7. Fully close the iTamaPoke app (swipe it away in the app switcher) and
   reopen it. The creature should now appear instead of a placeholder.

<img src="img/dex-detail.png" alt="Pokedex detail confirming art, dex entry and cry are installed" width="220">

*What it looks like once sprites (and optionally dex text/cries, next)
are correctly installed — portrait, type chips, and the cry-playback button
all present on the dex detail screen.*

Want dex entries and cries too? Both are optional and go in the same `mons`
folder — see [README "Pokédex entries"](../README.md#pokédex-entries) and
[README "Cries"](../README.md#cries). Cries need `ffmpeg` on the computer
you fetch them with (`brew install ffmpeg`), not on the iPhone.

This `.ipa` doesn't include the Apple Watch app — see the note in step 1. If
you want the game on a paired Apple Watch without a paid developer account,
use Path C below (build with Xcode, connected directly to your watch)
instead; there's no sideloading route to it on a free account.

### 6. Keep it working (every 7 days)

Apps signed with a free Apple ID stop opening after **7 days** — this is an
Apple restriction on free accounts, not a bug.

- **AltStore users:** leave AltServer running on your computer and keep your
  phone on the same Wi-Fi occasionally — it renews on its own.
- **Sideloadly users:** repeat step 3 by hand once a week. Your save data is
  untouched by this.

A free Apple ID can also only have **3 sideloaded apps** installed at once,
counting anything else you've sideloaded the same way.

---

## Path B — Signed install (paid Apple Developer account)

If you already pay $99/year for an Apple Developer account, this path skips
sideloading tools entirely and doesn't need re-signing for a year.

> If this isn't your own fork of the repository, first change
> `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` away from
> `com.allenst486db.itamapoke` to something unique to you — Apple's servers
> refuse to sign an identifier that's already registered to someone else's
> account.

1. In this repository, go to **Settings → Secrets and variables → Actions**
   and add four secrets — see the comments at the top of
   [`.github/workflows/build-signed.yml`](../.github/workflows/build-signed.yml)
   for exactly where each value comes from in your Apple Developer account.
2. Go to the **Actions** tab → **Build (signed)** → **Run workflow**.
3. Once it finishes (green checkmark), download the `TamaPoke-signed-ipa`
   artifact the same way as Path A step 1.
4. Install it with Apple Configurator or Xcode's Devices window — it's
   already signed for your registered devices, so no sideloading tool is
   involved.
5. Add sprites the same way as Path A step 5.

This path installs the Apple Watch app correctly and doesn't expire for a
year.

---

## Path C — Build with Xcode (Mac only)

For anyone who already has a Mac with Xcode and is comfortable typing a few
commands into Terminal. This is the most reliable path for the Apple Watch
specifically, and lets you bake sprites directly into the build instead of
adding them afterward.

If this isn't your own fork, change `PRODUCT_BUNDLE_IDENTIFIER` in
`project.yml` away from `com.allenst486db.itamapoke` first (same reason as
Path B above).

```bash
git clone --recurse-submodules https://github.com/allenst486db/iTamaPoke
cd iTamaPoke
brew install xcodegen
Scripts/fetch_sprites.sh all      # or a few dex numbers instead of "all"
xcodegen generate
open TamaPoke.xcodeproj
```

Building with none of that run at all works too — the app just starts with no
sprites, dex entries, or cries until you add them (see [README
"Sprites"](../README.md#sprites), ["Pokédex
entries"](../README.md#pokédex-entries), and ["Cries"](../README.md#cries)).
`Scripts/fetch_assets.sh` fetches sprites, shiny sprites, and cries together
in one call instead of running each script by hand; cries need `ffmpeg`
(`brew install ffmpeg`) first.

In Xcode: select the **TamaPoke** target → *Signing & Capabilities* → turn on
*Automatically manage signing* → pick your Apple ID as the team. Do the same
for **TamaPokeWatch**. Then plug in your iPhone, pick it as the run
destination, and press ⌘R. Repeat with the **TamaPokeWatch** scheme and your
Apple Watch as the destination.

Both iOS 16+ and watchOS 9+ need **Developer Mode** turned on once: Settings
→ Privacy & Security → Developer Mode → on, then restart. The watch has its
own separate toggle.

A free Apple ID still expires after 7 days here too — just press ⌘R again to
renew.

### App icon

Ships with a small default mascot icon (see the main README). To use your
own image instead:

```bash
Scripts/fetch_app_icon.sh path/to/your/icon.png   # square, ideally 1024x1024
xcodegen generate
```

---

## Path D — Browser build (no Mac, no developer account, no coding)

`browser_ver/` is the same game — same C++ logic, same screens, same
sprites, same sounds — compiled to run inside a web browser instead of as
an iOS app. That means: **no App Store, no sideloading tool, no 7-day
expiry, and no Xcode.** Any computer works (Windows, Mac, Linux), and your
phone plays it over your home Wi-Fi. It keeps its own save data; it does
not share a save with the iOS app.

What you need: a computer, a phone or tablet on the same Wi-Fi, a free
GitHub account, and about ten minutes. Nothing gets typed except one short
command, and that one is copy-paste.

### D1. Download the built game (2 minutes)

The game has to be "built" once, and GitHub does that for you on its own
computers, so you don't install anything for this step.

1. Sign in to GitHub (a free account is enough — the download button only
   appears when you're signed in).
2. Open this repository's page and click the **Actions** tab at the top.
3. In the left column click **Build (browser)**.
4. Click the topmost run in the list. It should have a green check ✅.
   (If there is no run yet, click **Run workflow** → **Run workflow** on the
   right, wait about two minutes, then refresh the page.)
5. Scroll down to **Artifacts** and click **`iTamaPoke-browser`**. A file
   called `iTamaPoke-browser.zip` downloads.
6. Unzip it. You get a folder with `index.html`, `main.js`,
   `tp_core.wasm` and about a dozen other files. Rename that folder to
   something easy to find, e.g. **`itamapoke`** on your Desktop.

That folder *is* the game. There is nothing else to install for the game
itself.

### D2. Start it on your computer (3 minutes)

Browsers refuse to run this kind of app straight from a double-clicked
file (the `.wasm` part needs to be *served*, not opened), so the folder
has to be served by a tiny local web server. Python has one built in.

**Install Python (once).**

- **Windows**: go to [python.org/downloads](https://www.python.org/downloads/),
  click the big yellow **Download Python 3.x** button, run the installer,
  and on the first screen **tick "Add python.exe to PATH"** before clicking
  **Install Now**. That checkbox is the only thing people miss.
- **Mac**: open the **Terminal** app (⌘-space, type `Terminal`) and paste:
  ```bash
  xcode-select --install
  ```
  Click **Install** in the dialog that appears. That gives you `python3`.
  (Or install from python.org exactly as on Windows.)
- **Linux**: it's already there.

**Open a terminal *in the game folder*.**

- **Windows**: open the `itamapoke` folder in Explorer, click in the empty
  white part of the address bar, type `cmd` and press Enter. A black window
  opens, already inside that folder.
- **Mac**: open Finder, right-click the `itamapoke` folder → **Services →
  New Terminal at Folder**. (If that entry is missing: open Terminal, type
  `cd ` with a space, drag the folder into the window, press Enter.)

**Start the server.** Paste this and press Enter:

```bash
python3 -m http.server 8123
```

On Windows, if that says `python3` is not recognized, use `python` instead
of `python3`. It prints one line like `Serving HTTP on :: port 8123` and
then sits there — that's correct, it's running. **Leave this window open**
for as long as you want to play; closing it stops the game server (your
save is not affected).

**Open the game.** In any browser on that computer go to
**http://localhost:8123**. You should see the starter picker.

### D3. Play it on your phone (3 minutes)

The phone opens the same page over Wi-Fi. It works while the computer and
the server window from D2 are on.

1. **Find your computer's Wi-Fi address.**
   - **Windows**: in the black window from D2 you can't type (the server
     is using it), so open a second one the same way and type `ipconfig`.
     Look for **IPv4 Address** under your Wi-Fi adapter, e.g.
     `192.168.0.12`.
   - **Mac**: System Settings → Wi-Fi → click **Details…** next to your
     network → the **IP address** line, e.g. `192.168.0.12`.
2. Make sure the phone is on the **same Wi-Fi** (not mobile data, not a
   guest network).
3. On the phone, open Safari (iPhone) or Chrome (Android) and type
   **`http://192.168.0.12:8123`** with your own address in place of the
   numbers. Note the `http://` — phones sometimes assume `https` and then
   fail.
4. The game appears. To make it feel like an app:
   - **iPhone/iPad**: tap the Share button (square with an arrow) → **Add
     to Home Screen** → **Add**. It gets its own icon and opens full-screen
     without the browser bar.
   - **Android**: Chrome menu (⋮) → **Add to Home screen**.

Two things worth knowing:

- **Your save lives in the phone's browser**, tied to that exact address.
  If your computer's Wi-Fi address changes (some routers reshuffle them),
  the phone sees a "new" site with an empty save. The fix is to give the
  computer a fixed address in your router (usually called *DHCP
  reservation* or *static lease* — look it up for your router model), or
  simply use the same address again once it comes back.
- **The Mac's firewall** may ask whether to allow Python to accept
  connections the first time. Allow it, or the phone can't reach the
  server. On Windows the same question pops up as a "Windows Defender
  Firewall" dialog — tick **Private networks** and click **Allow access**.

### D4. Add the characters (5 minutes, once)

The game downloads without any Pokémon art or sounds, on purpose (see the
[README on sprites](../README.md#sprites)). You add them yourself, and the
game keeps them in the browser's own storage so this is done once per
device. No scripts needed for the sprites:

1. On the computer, go to
   [github.com/socquique/TamaPoke](https://github.com/socquique/TamaPoke) →
   green **Code** button → **Download ZIP**. Unzip it.
2. Inside, open `tools/sdcard/mons`. That folder holds one `.bin` file per
   species: `p001.bin`, `p002.bin`, … (normal) and `ps001.bin`, … (shiny).
3. Get those files to the device you play on. On the computer they're
   already there. For the phone, AirDrop the `mons` folder (Mac → iPhone),
   or put it in iCloud Drive / Google Drive / any cloud app the phone's
   Files app can see.
4. In the game, tap **"Load sprites…"** (top right corner of the page).
5. In the file picker that opens, **select all the `.bin` files at once**
   (on iPhone: open the folder in the picker, tap **Select** at the top,
   then **Select All**). Confirm. A count appears at the bottom of the page
   as they load.
6. Done — the characters appear immediately. You can ignore `thumbs.bin`
   here; the browser build draws its own thumbnails from the full sprites.

Do the same later for the two optional buttons:

- **"Load dex text…"** — the little encyclopedia descriptions on the dex
  detail screen's second page. These come from `Scripts/fetch_dex_entries.sh`
  in this repository, which needs a terminal; if that's not for you, skip
  it — nothing else depends on it.
- **"Load cries…"** — each species' cry, playable from the dex detail
  screen. From `Scripts/fetch_cries.sh`, which also needs `ffmpeg` on the
  computer. Also optional. Cries only play when the sound setting is on
  full (the same rule as the iOS app).

Everything you pick stays in **that browser on that device** and is never
uploaded anywhere. Clearing the browser's site data, using a private
window, or switching browsers means picking the files again.

### D5. Updating later

When this repository changes, repeat D1 to download the new zip and
replace the files in your `itamapoke` folder (keep the folder name and the
`8123` port so the address stays the same). Your save and your loaded
sprites are in the browser, not in that folder, so they survive the swap.

### D6. Optional: a real installed app instead of a home-screen bookmark

The home-screen bookmark from D3 needs the computer running. If you want
the game fully self-contained on the phone, `browser_ver/native/` has two
tiny wrappers — a WKWebView target for Xcode (needs a Mac, works with a
free Apple ID, same 7-day rule as Path A) and an Android Studio project
(any computer, no expiry). Both bundle the `web` folder inside the app.
Step-by-step in [`browser_ver/native/README.md`](../browser_ver/native/README.md).
This is the only part of Path D that involves developer tools.

### Building the core yourself (developers only)

Not needed for any step above. If you'd rather compile than download:

```bash
git clone --depth 1 https://github.com/emscripten-core/emsdk.git
cd emsdk && ./emsdk install latest && ./emsdk activate latest
source ./emsdk_env.sh
cd /path/to/iTamaPoke
bash browser_ver/build.sh        # writes browser_ver/web/tp_core.{js,wasm}
```

`emsdk` needs Python 3.10+ (`python3 --version`); macOS's bundled one is
often 3.9, in which case `brew install python@3.11` and run
`./emsdk install latest` through that interpreter. Re-run `build.sh` after
every `git pull` that touches `upstream-expanded/` or `browser_ver/core/`
— the compiled core is not committed, and stale one shows up as a single
screen throwing rather than the page failing to load.

### Path D troubleshooting

**Blank dark page with "loading…" that never changes.** You opened
`index.html` by double-clicking it. Serve it as in D2 and use the
`http://localhost:8123` address.

**Phone shows "cannot connect" / "site can't be reached".** In order: is
the server window from D2 still open? Same Wi-Fi? Did you type `http://`
and the `:8123`? Firewall allowed (D3)? Some routers block devices from
seeing each other ("AP isolation" / "client isolation") — that setting has
to be off.

**No character art, just a stand-in shape or a "?".** The sprites haven't
been loaded on *this* device/browser yet — D4, and it's per device.

**Sound doesn't play.** The game starts in silent mode, and browsers block
audio until you tap something. Swipe down for settings and tap the sound
pill to FULL.

**My save disappeared on the phone.** The address changed — see the note
in D3. The old save comes back when the old address does.

---

## Troubleshooting

**"Unable to install" / install just fails silently.** Free Apple IDs allow
3 sideloaded apps at once — check you're not over that limit with other apps.

**The app opens but immediately closes.** Usually means the developer trust
step (Path A, step 4) hasn't been done yet.

**No creature, just a placeholder.** The sprite files aren't in the right
place — double check the folder is named exactly `mons` and sits directly
inside the app's Files folder, and that you fully restarted the app after
adding files.

**Pokédex screen is empty.** Missing `thumbs.bin` specifically — it's easy
to miss since it's one extra file among 151+.

**Apple Watch shows a placeholder even after waiting.** Open the watch app
directly and leave it on screen for a minute — delivery from the phone can
lag while the watch isn't actively being looked at, which is a known
characteristic of how Apple's phone-to-watch file transfer works, not
something specific to this app.

**Something else looks broken.** This is genuinely possible — see the
warning at the top of this page. Feel free to open an issue on this
repository describing what you saw.
