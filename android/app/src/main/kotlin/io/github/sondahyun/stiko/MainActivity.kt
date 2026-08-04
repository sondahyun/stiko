package io.github.sondahyun.stiko

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges widget deep links (stiko://sticker/<id>) to Dart over the same
 * "stiko/deeplink" channel that iOS uses, so tapping a widget row opens that
 * sticker in the app.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pendingUri: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Cold start: remember the URI the widget launched us with.
        pendingUri = intent?.dataString
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stiko/deeplink",
        )
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "getInitial") {
                result.success(pendingUri)
                pendingUri = null
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.dataString?.let { channel?.invokeMethod("open", it) }
    }
}
