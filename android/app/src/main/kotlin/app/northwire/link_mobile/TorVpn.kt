package app.northwire.link_mobile

import android.annotation.SuppressLint
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.webkit.ProxyConfig
import androidx.webkit.ProxyController
import androidx.webkit.WebViewFeature
import org.torproject.jni.TorService

/**
 * Link's VPN: runs Tor inside the app and sends every web page through it.
 *
 * Nothing may leave outside Tor while it connects, so pages are pointed at a dead proxy right away
 * and only switched to Tor's SOCKS port once Tor has finished connecting. Hostnames go to Tor too
 * (SOCKS5 resolves them on the far side), so DNS doesn't leak either.
 */
class TorVpn(private val context: Context, private val report: (String, Map<String, Any?>) -> Unit) {
    private var service: TorService? = null
    private var poller: Thread? = null
    private val main = Handler(Looper.getMainLooper())

    @Volatile var state = "off" // off, starting, on
        private set
    @Volatile var progress = 0
        private set
    @Volatile var httpPort = 0
        private set

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            service = (binder as TorService.LocalBinder).service
            watchBootstrap()
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            service = null
            if (state != "off") fail("Tor stopped unexpectedly.")
        }
    }

    fun supported() = WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE)

    fun start() {
        if (state != "off") return
        if (!supported()) return fail("This phone's Android System WebView is too old for the VPN. Update it in the Play Store.")
        state = "starting"
        progress = 0
        // Port 1 never answers: pages fail instead of loading without Tor while it connects.
        setProxy("socks5://127.0.0.1:1")
        context.bindService(Intent(context, TorService::class.java), connection, Context.BIND_AUTO_CREATE)
        send()
    }

    fun stop() {
        if (state == "off") return
        state = "off"
        progress = 0
        httpPort = 0
        poller?.interrupt()
        poller = null
        try {
            context.unbindService(connection)
        } catch (e: IllegalArgumentException) {
            // already unbound
        }
        service = null
        clearProxy()
        send()
    }

    /** New Tor circuits, so sites see a different address. */
    fun newIdentity(): Boolean = try {
        service?.torControlConnection?.signal("NEWNYM")
        true
    } catch (e: Exception) {
        false
    }

    fun status(): Map<String, Any?> = mapOf("state" to state, "progress" to progress, "httpPort" to httpPort)

    // Tor reports its progress as "... BOOTSTRAP PROGRESS=45 ...".
    private fun watchBootstrap() {
        poller?.interrupt()
        poller = Thread {
            try {
                while (state == "starting") {
                    val tor = service ?: break
                    if (tor.torControlConnection == null) { // Tor is still launching
                        Thread.sleep(250)
                        continue
                    }
                    val phase = tor.getInfo("status/bootstrap-phase") ?: ""
                    val percent = Regex("PROGRESS=(\\d+)").find(phase)?.groupValues?.get(1)?.toInt() ?: 0
                    if (percent != progress) {
                        progress = percent
                        main.post { send() }
                    }
                    val socks = tor.socksPort
                    if (percent >= 100 && socks > 0) {
                        httpPort = tor.httpTunnelPort
                        main.post { connected(socks) }
                        break
                    }
                    Thread.sleep(400)
                }
            } catch (e: InterruptedException) {
                // stopped
            } catch (e: Exception) {
                main.post { fail("Tor couldn't start: ${e.message}") }
            }
        }.apply { isDaemon = true; start() }
    }

    private fun connected(socksPort: Int) {
        if (state != "starting") return
        setProxy("socks5://127.0.0.1:$socksPort") {
            state = "on"
            progress = 100
            send()
        }
    }

    private fun fail(message: String) {
        stop()
        report("vpnError", mapOf("message" to message))
    }

    private fun send() = report("vpnStatus", status())

    @SuppressLint("RequiresFeature")
    private fun setProxy(rule: String, done: () -> Unit = {}) {
        val config = ProxyConfig.Builder().addProxyRule(rule).build()
        ProxyController.getInstance().setProxyOverride(config, { it.run() }, done)
    }

    @SuppressLint("RequiresFeature")
    private fun clearProxy() {
        if (supported()) ProxyController.getInstance().clearProxyOverride({ it.run() }, {})
    }
}
