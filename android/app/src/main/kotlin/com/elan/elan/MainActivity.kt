package com.elan.elan

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Opens the phone's dialler pre-filled with a number (hospitals, 112).
        // ACTION_DIAL needs no CALL_PHONE permission: the user taps call.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "elan/phone")
            .setMethodCallHandler { call, result ->
                if (call.method != "dial") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val number = call.argument<String>("number").orEmpty()
                try {
                    startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:" + Uri.encode(number))))
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }
    }
}
