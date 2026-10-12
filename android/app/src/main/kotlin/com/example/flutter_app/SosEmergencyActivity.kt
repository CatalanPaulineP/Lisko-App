package com.example.flutter_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Isolated, transient FlutterActivity specifically for the LisKo Home Screen SOS Widget.
 * Configured with excludeFromRecents="true" and its own taskAffinity.
 * Directly mounts initialRoute "/sos_emergency" to display the 5-second countdown overlay
 * without modifying MainActivity's task, session state, or Recent Apps thumbnail.
 */
class SosEmergencyActivity : FlutterActivity() {
    private val CHANNEL = "com.example.flutter_app/sos_widget"

    override fun getInitialRoute(): String {
        return "/sos_emergency"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPendingSos" -> {
                    result.success(true)
                }
                "exitStandaloneSos" -> {
                    finish()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
