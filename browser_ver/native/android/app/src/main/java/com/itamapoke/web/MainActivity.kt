// Minimal WebView shell for the browser build: serves browser_ver/web/
// (copied into this module's assets/web/ by the CI workflow, or by hand --
// see this folder's README.md) from inside the APK. No server, no network
// permission. Hand-rolled rather than Capacitor/Cordova to keep the port
// dependency-free.
//
// Two things a bare WebView does not give you, both required here:
//
//  * A real https origin. Plain file:///android_asset/ URLs are a
//    second-class origin in Chromium -- IndexedDB (where the save and the
//    user's sprites live) and the service worker are unreliable or refused
//    there. WebViewAssetLoader maps the bundled files to
//    https://appassets.androidplatform.net/assets/..., which behaves like
//    any normal site, offline.
//
//  * A file chooser. `<input type="file">` in a WebView does nothing at
//    all unless the host app implements onShowFileChooser and hands the
//    picked URIs back. Without it "Load sprites…" would be a dead button,
//    and the whole point of this shell is that the player picks their own
//    sprite/cry/dex files on the phone.
package com.itamapoke.web

import android.annotation.SuppressLint
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.webkit.WebViewAssetLoader

class MainActivity : AppCompatActivity() {

    private var pendingChooser: ValueCallback<Array<Uri>>? = null

    // Receives whatever the system picker returns and forwards it to the
    // page's <input type="file" multiple>. A cancelled picker must still
    // resolve the callback (with null), or the input stays locked.
    private val pickFiles =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            val cb = pendingChooser ?: return@registerForActivityResult
            pendingChooser = null
            val uris = mutableListOf<Uri>()
            val data = result.data
            if (result.resultCode == RESULT_OK && data != null) {
                data.clipData?.let { clip ->
                    for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri)
                }
                if (uris.isEmpty()) data.data?.let { uris.add(it) }
            }
            cb.onReceiveValue(if (uris.isEmpty()) null else uris.toTypedArray())
        }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val webView = WebView(this)
        setContentView(webView)

        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true
        webView.settings.mediaPlaybackRequiresUserGesture = false
        webView.settings.allowFileAccess = false

        val assetLoader = WebViewAssetLoader.Builder()
            .addPathHandler("/assets/", WebViewAssetLoader.AssetsPathHandler(this))
            .build()

        webView.webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(
                view: WebView,
                request: WebResourceRequest
            ): WebResourceResponse? = assetLoader.shouldInterceptRequest(request.url)
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onShowFileChooser(
                webView: WebView,
                filePathCallback: ValueCallback<Array<Uri>>,
                fileChooserParams: FileChooserParams
            ): Boolean {
                pendingChooser?.onReceiveValue(null)
                pendingChooser = filePathCallback
                val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    // The page's accept= lists .bin/.txt/.m4a etc.; Android's
                    // picker filters by MIME, and "*/*" is the only value that
                    // reliably shows every one of those across file apps.
                    type = "*/*"
                    putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                }
                return try {
                    pickFiles.launch(Intent.createChooser(intent, "Select files"))
                    true
                } catch (e: Exception) {
                    pendingChooser = null
                    filePathCallback.onReceiveValue(null)
                    false
                }
            }
        }

        webView.loadUrl("https://appassets.androidplatform.net/assets/web/index.html")
    }

    override fun onDestroy() {
        super.onDestroy()
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}
