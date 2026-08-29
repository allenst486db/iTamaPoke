# Install guide (no coding knowledge needed)

[한국어](INSTALL.ko.md) · with screenshots: [Install guide (HTML)](INSTALL.html)

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
├─ No (most people) ─────────────────────────► Path A: Free install
│                                                (Mac or Windows, ~15 min)
│
└─ Yes ──────────────────────────────────────► Path B: Signed install
                                                 (Mac or Windows, ~10 min,
                                                 no re-signing ever)
```

There's also **Path C**, building it yourself with Xcode — only relevant if
you already have a Mac with Xcode and want to bake sprites directly into the
app instead of adding them afterward — and **Path D**, a separate browser
build (`browser_ver/`) that runs the same game logic in a web page or a
thin native shell instead of the iOS/watchOS app, if that's what you're
after.

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

## Path D — Browser build, installed on your own phone/tablet

`browser_ver/` compiles the same C++ game logic to WebAssembly and runs it
in a web page — no App Store, no sideloading, no 7-day expiry. It doesn't
share save data, sprites, or dex text with the iOS app; it's a fully
separate build. **The point of this path is to get it running as an app on
your own iPhone/iPad or Android device**, not just in a desktop browser —
that needs a computer (Mac for the iOS shell, any OS for Android) to
*build* it once, same as the iOS app itself needs Xcode, but the result
installs and runs entirely on your phone afterward.

### 1. Build the web core (on your computer, once)

**Prerequisite:** you've already cloned this repository (same as Path C —
`git clone --recurse-submodules https://github.com/allenst486db/iTamaPoke` and `cd iTamaPoke`). All paths below
are relative to the iTamaPoke folder.

```bash
# One-time: install the Emscripten SDK
# (clone it anywhere outside or inside the iTamaPoke folder, either works)
git clone --depth 1 https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install latest
./emsdk activate latest
source ./emsdk_env.sh

# Go back to the iTamaPoke repository folder (wherever you cloned it)
cd /path/to/iTamaPoke

# Build the core -> browser_ver/web/tp_core.{js,wasm}
bash browser_ver/build.sh
```

`emsdk` needs Python 3.10+; if your system Python is older, a portable
build from
[astral-sh/python-build-standalone](https://github.com/astral-sh/python-build-standalone)
works fine just to run `emsdk.py` (Emscripten uses its own bundled Python
after that).

### 2. Put it on your phone: a native shell, not a browser tab

`browser_ver/native/` has everything for this — a minimal **WKWebView**
(iOS/iPadOS) shell you drop into a new Xcode target, and a ready-to-open
**WebView** (Android) Gradle project. Both load `browser_ver/web/` as
local files bundled *inside* the app itself — no server running anywhere,
no network permission, nothing left on a computer once it's installed.
Full step-by-step in `browser_ver/native/README.md`; short version:

- **iOS/iPadOS**: open `TamaPoke.xcodeproj` in Xcode → File → New → Target…
  → iOS App → drag in `browser_ver/native/ios/WebShellApp.swift` and this
  folder's `Info.plist` → drag the whole `browser_ver/web` folder into the
  target **as a folder reference** (blue folder icon, not a group) → build
  and run on your connected iPhone/iPad, same as the main app.
- **Android**: open `browser_ver/native/android/` directly in Android
  Studio → copy `browser_ver/web/` into `app/src/main/assets/web/` → run
  on your connected phone.

That's the app on your device. Everything below (sprites, dex text) is
picked once inside that installed app, exactly like on a desktop browser.

### Quick preview on your computer (optional, not the point of this path)

If you just want to click around before wrapping it in a native shell:

```bash
# Serve it locally (not file:// -- the WASM load needs a real origin)
cd browser_ver/web && python3 -m http.server 8123
# then open http://localhost:8123 in a desktop browser
```

### Adding sprites (in detail)

The browser build has no Files app to drop files into — instead, **you
pick the files directly inside the page itself**:

1. On a computer, run `Scripts/fetch_sprites.sh` (same script Path C
   uses) to get `.bin` files — one per species, named `p<dex>.bin`
   (normal) and `ps<dex>.bin` (shiny).
2. Get those `.bin` files onto the device you're actually running the app
   on. If that's the same computer, they're already there. If it's your
   phone/tablet running the native shell from step 2 above, get them onto
   it however you'd move any file — AirDrop, cable, a cloud drive app —
   same as moving sprites onto the iOS app in Path A step 5.
3. In the app, tap **"Load sprites…"** (top right).
3. In the file picker, **select every `.bin` file you want at once** —
   multi-select, not a folder drag. (Deliberately not a folder picker:
   iOS Safari's folder-select is unreliable, so this build always uses a
   plain multi-file select instead, on every platform.)
4. The files are stored in **this browser's own IndexedDB** (local
   storage tied to this browser, this device) and stay there across
   reloads — you only need to pick them once per browser.
5. Picking a file again for a species you already loaded just overwrites
   it; nothing needs deleting first.

Switching browsers (Safari → Chrome), using a private/incognito window, or
clearing this site's data empties that IndexedDB — just click "Load
sprites…" again when that happens. The `.bin` files themselves stay on
your computer either way; nothing is ever uploaded anywhere.

### Adding dex entry text (optional)

Same idea, a second button: run `Scripts/fetch_dex_entries.sh` to get
`dex_entries_<lang>.txt`, then click **"Load dex text…"** and multi-select
the file(s). It shows up on the dex detail screen's second page (tap the
right-hand page dot).

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
