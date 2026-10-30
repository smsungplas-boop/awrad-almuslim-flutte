package org.awrad.almuslim

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.awrad.almuslim/native")
            .setMethodCallHandler { call, result ->
                if (call.method != "overlay") { result.notImplemented(); return@setMethodCallHandler }
                val enabled = call.argument<Boolean>("enabled") ?: false
                if (!enabled) {
                    stopService(Intent(this, DhikrOverlayService::class.java))
                    result.success(true)
                } else if (!Settings.canDrawOverlays(this)) {
                    startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
                    result.success(false)
                } else {
                    val intent = Intent(this, DhikrOverlayService::class.java)
                    intent.putStringArrayListExtra("texts", ArrayList(call.argument<List<String>>("texts") ?: listOf("سبحان الله")))
                    intent.putExtra("seconds", call.argument<Int>("seconds") ?: 10)
                    if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                    result.success(true)
                }
            }
    }
}
