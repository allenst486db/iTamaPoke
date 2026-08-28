// Minimal WebView shell for the browser build: loads browser_ver/web/
// (copied into this module's assets/web/ -- see this folder's README.md)
// over file:///android_asset/, no server, no network permission needed.
// Hand-rolled rather than Capacitor/Cordova, per this project's own
// decision to keep the whole port dependency-free -- see
// browser_ver/README.md and the root LICENSE (personal use only, install
// on your own device, never distribute a build of this).
package com.itamapoke.web

import android.annotation.SuppressLint
import android.os.Bundle
import android.view.WindowManager
import android.webkit.WebChromeClient
import android.webkit.WebView
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val webView = WebView(this)
        setContentView(webView)

        webView.settings.javaScriptEnabled = true
        // The core's WASM heap grows via ALLOW_MEMORY_GROWTH=1 (build.sh);
        // DOM storage backs the sprite/save IndexedDB the game already uses.
        webView.settings.domStorageEnabled = true
        webView.settings.allowFileAccess = true
        webView.settings.mediaPlaybackRequiresUserGesture = false
        // WASM streaming compile wants a real MIME type for .wasm, which the
        // asset loader's file-extension guess handles by default on recent
        // WebView versions; if a device's WebView is old enough not to,
        // tp_core.js's own fallback to ArrayBuffer instantiation covers it.
        webView.webChromeClient = WebChromeClient()

        webView.loadUrl("file:///android_asset/web/index.html")
    }

    override fun onDestroy() {
        super.onDestroy()
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}
