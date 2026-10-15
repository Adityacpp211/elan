package com.elan.elan

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // "dial": open the phone's dialler pre-filled with a number (hospitals,
        // 112). ACTION_DIAL needs no CALL_PHONE permission: the user taps call.
        // "openUrl": open a web page (privacy policy) in the browser.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "elan/phone")
            .setMethodCallHandler { call, result ->
                val intent = when (call.method) {
                    "dial" -> Intent(Intent.ACTION_DIAL,
                        Uri.parse("tel:" + Uri.encode(call.argument<String>("number").orEmpty())))
                    "openUrl" -> {
                        val url = call.argument<String>("url").orEmpty()
                        if (!url.startsWith("http://") && !url.startsWith("https://")) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        Intent(Intent.ACTION_VIEW, Uri.parse(url))
                    }
                    else -> {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                }
                try {
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }
    }
}
