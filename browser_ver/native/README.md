# Native shells

Wrappers around `browser_ver/web/` for people who want an app icon rather
than a browser tab. As of v0.9.0 the web build is itself an installable
offline PWA (see `browser_ver/README.md`), so on iOS the shell here is no
longer the recommended route -- "Add to Home Screen" from Safari does the
same job with no Mac and no signing. The Android shell *is* the
recommended Android route: CI builds it into `iTamaPoke.apk` on every
push and puts it on the Pages site next to the web app.

Both are for **your own device only** -- see the root `LICENSE`.

## Android: `android/`

A minimal Gradle project, built by `.github/workflows/build-browser.yml`
(Gradle 8.7, JDK 17, `assembleDebug`). What the workflow does, if you want
to build it locally in Android Studio instead:

1. Copy `browser_ver/web/` (after `browser_ver/build.sh`) into
   `app/src/main/assets/web/`. This path is gitignored.
2. Put a launcher icon at `app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
   (the workflow resizes `Resources/DefaultAppIcon.png`; Android Studio's
   Image Asset tool works too). Also gitignored.
3. Open `browser_ver/native/android/` in Android Studio, let Gradle sync,
   run on your phone (`minSdk 26`, Android 8.0+).

`MainActivity.kt` serves the bundled folder through `WebViewAssetLoader`
at `https://appassets.androidplatform.net/assets/web/` -- a real https
origin, so IndexedDB (the save and the user's sprites) and the service
worker behave exactly as on the hosted site -- and implements
`onShowFileChooser`, without which the page's "Load sprites…" picker would
be a dead button in a WebView. No permissions are declared: picked files
arrive as `content://` URIs the WebView reads itself.

The debug signing key is what lets the APK install on any phone without a
keystore. Updating is "install the newer `.apk` over the old one"; the
save survives because it lives in the app's WebView storage.

## iOS: `ios/`

Kept for anyone who prefers a WKWebView target in Xcode (needs a Mac and a
free Apple ID, same 7-day rule as a sideloaded build). Not needed for the
normal install path.

1. Open `TamaPoke.xcodeproj`. File → New → Target… → iOS App (SwiftUI,
   Swift), name it e.g. `iTamaPokeWeb`, with its own bundle id.
2. Delete the generated `ContentView.swift` / `…App.swift`; drag
   `WebShellApp.swift` from this folder into the new target.
3. Replace the target's `Info.plist` with this folder's, or merge its keys.
4. Drag `browser_ver/web` (from the Finder) into the target as a **folder
   reference** (blue icon), so `WebShellView.swift`'s `subdirectory: "web"`
   lookup and the page's relative fetches resolve.
5. Run `browser_ver/build.sh` first if `web/tp_core.*` don't exist yet.
6. Build and run on your own device.
