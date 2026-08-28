// Minimal WKWebView shell for the browser build: loads browser_ver/web/
// straight from the app bundle over a local file:// URL, no server, no
// network permission needed. Drop this into a new Xcode target -- see this
// folder's README.md for the exact steps (adding a target by hand from
// here would mean hand-writing project.pbxproj, which is far riskier than
// a few clicks in Xcode's own "New Target" flow).
//
// Hand-rolled rather than Capacitor/Cordova, per this project's own
// decision to keep the whole port dependency-free -- see
// browser_ver/README.md and the root LICENSE (personal use only, install
// on your own device, never distribute a build of this).

import SwiftUI
import WebKit

@main
struct WebShellApp: App {
    var body: some Scene {
        WindowGroup {
            WebShellView()
                .ignoresSafeArea()
        }
    }
}

struct WebShellView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Sound effects and haptics only need this to not be muted by the
        // system's "silent app audio" default for inline media playback.
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.bounces = false
        webView.scrollView.isScrollEnabled = false

        // The web/ folder is added to the target as a folder reference (blue
        // folder in Xcode, not yellow group) so it lands in the bundle with
        // its own directory structure intact -- tp_core.wasm and the .bin
        // sprite the user picks both need real relative paths to resolve.
        guard let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "web") else {
            assertionFailure("web/index.html not found in bundle -- did you add browser_ver/web as a folder reference?")
            return webView
        }
        // loadFileURL's second argument grants read access to the whole web/
        // directory, not just index.html, so tp_core.wasm/js/audio.js/
        // sprites.js resolve as sibling fetches.
        webView.loadFileURL(indexURL, allowingReadAccessTo: indexURL.deletingLastPathComponent())
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
