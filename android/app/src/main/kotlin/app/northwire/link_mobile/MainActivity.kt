package app.northwire.link_mobile

import android.annotation.SuppressLint
import android.app.DownloadManager
import android.app.SearchManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.webkit.CookieManager
import android.webkit.URLUtil
import androidx.webkit.ProfileStore
import androidx.webkit.WebViewFeature
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// Link's Android side (lib/services/native.dart talks to it): downloads, private-tab storage,
// links opened from other apps, and the Tor VPN (TorVpn.kt).
class MainActivity : FlutterActivity() {
    // Must match PRIVATE_PROFILE in third_party/flutter_inappwebview_android (InAppWebView.java).
    private val privateProfile = "LinkPrivate"
    private var channel: MethodChannel? = null
    private val vpn by lazy { TorVpn(applicationContext) { method, args -> channel?.invokeMethod(method, args) } }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "link/native").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialUrl" -> {
                        result.success(linkFrom(intent))
                        intent = Intent(Intent.ACTION_MAIN) // handled; don't open it again
                    }
                    "privateSupported" -> result.success(WebViewFeature.isFeatureSupported(WebViewFeature.MULTI_PROFILE))
                    "clearPrivate" -> result.success(clearPrivate())
                    "download" -> result.success(download(call))
                    "vpnStart" -> { vpn.start(); result.success(vpn.status()) }
                    "vpnStop" -> { vpn.stop(); result.success(vpn.status()) }
                    "vpnStatus" -> result.success(vpn.status())
                    "vpnNewIdentity" -> result.success(vpn.newIdentity())
                    "openDownloads" -> {
                        startActivity(Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        vpn.stop()
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        linkFrom(intent)?.let { channel?.invokeMethod("openUrl", it) }
    }

    // A web link, shared text, or a web search started from another app.
    private fun linkFrom(intent: Intent?): String? = when (intent?.action) {
        Intent.ACTION_VIEW -> intent.dataString
        Intent.ACTION_SEND -> intent.getStringExtra(Intent.EXTRA_TEXT)
        Intent.ACTION_WEB_SEARCH -> intent.getStringExtra(SearchManager.QUERY)
        else -> null
    }

    @SuppressLint("RequiresFeature")
    private fun clearPrivate(): Boolean {
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.MULTI_PROFILE)) return false
        return try {
            ProfileStore.getInstance().deleteProfile(privateProfile)
        } catch (e: IllegalStateException) {
            false // a private tab is still open
        }
    }

    @SuppressLint("RequiresFeature")
    private fun download(call: MethodCall): Boolean {
        val url = call.argument<String>("url") ?: return false
        val mimeType = call.argument<String>("mimeType")
        val name = call.argument<String>("fileName")
            ?: URLUtil.guessFileName(url, call.argument<String>("contentDisposition"), mimeType)
        // The download needs the same cookies as the tab, so sign-in protected files work.
        val cookies = if (call.argument<Boolean>("private") == true && WebViewFeature.isFeatureSupported(WebViewFeature.MULTI_PROFILE)) {
            ProfileStore.getInstance().getProfile(privateProfile)?.cookieManager?.getCookie(url)
        } else {
            CookieManager.getInstance().getCookie(url)
        }
        return try {
            val request = DownloadManager.Request(Uri.parse(url)).apply {
                if (mimeType != null) setMimeType(mimeType)
                if (cookies != null) addRequestHeader("Cookie", cookies)
                call.argument<String>("userAgent")?.let { addRequestHeader("User-Agent", it) }
                setTitle(name)
                setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, name)
            }
            (getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager).enqueue(request)
            true
        } catch (e: Exception) {
            false
        }
    }
}
