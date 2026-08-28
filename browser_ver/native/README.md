# Native shells

Two minimal, dependency-free wrappers that load `browser_ver/web/` from
local files (no server, no network permission) — the "feels like a real
app instead of a browser tab" option from the plan. Neither is a runnable
Xcode/Android Studio project by itself: `ios/` is source you drop into a
new target, `android/` is a real Gradle project skeleton you open directly.

Both are for **your own device only** — see the root `LICENSE`. Nothing
here should ever be built for distribution, TestFlight, or the Play Store.

## iOS: `ios/`

Xcode's own "New Target" wizard writes a correct `project.pbxproj` in a way
hand-editing one from scratch would not reliably reproduce, so this ships
source files to drop in rather than a second `.xcodeproj`:

1. Open `TamaPoke.xcodeproj`. File → New → Target… → iOS App (SwiftUI,
   Swift), name it e.g. `iTamaPokeWeb`. Give it its own bundle id
   (`com.<you>.itamapokeweb` or similar) so it installs alongside the main
   app rather than replacing it.
2. Delete the target's generated `ContentView.swift` and `…App.swift`.
   Drag `WebShellApp.swift` from this folder into the new target (check
   only the new target's membership).
3. Replace the new target's `Info.plist` with this folder's `Info.plist`,
   or merge the four keys in if you'd rather keep Xcode's generated one.
4. Drag `browser_ver/web` (the whole folder, from the Finder, not from
   inside Xcode) into the new target — when prompted, choose **"Create
   folder references"** (blue folder icon), not groups, and check only the
   new target's membership. This matters: a folder reference preserves
   `web/`'s own layout in the built bundle, which is what
   `WebShellView.swift`'s `subdirectory: "web"` lookup expects, and what
   lets `tp_core.wasm`/`audio.js`/`sprites.js` resolve as plain relative
   fetches from `index.html`.
5. Build `browser_ver/build.sh` first if `web/tp_core.js`/`.wasm` don't
   exist yet (they're gitignored — see `browser_ver/README.md`).
6. Build and run the new target on your own device or the simulator.

## Android: `android/`

A real (if minimal) Gradle project — open `browser_ver/native/android/` in
Android Studio directly.

1. Copy `browser_ver/web/` into `app/src/main/assets/web/` (create the
   `assets` folder if Android Studio hasn't already). Build
   `browser_ver/build.sh` first if `tp_core.js`/`.wasm` don't exist yet.
2. Open the folder in Android Studio, let it sync Gradle.
3. Run on your own device or an emulator (`minSdk 26` — anything from
   Android 8.0 on has a WebView modern enough for WASM streaming compile).

Nothing here re-copies `web/` automatically on every build; re-run step 1
after changing anything in `browser_ver/web/` or rebuilding the core.
