package com.lisko.safety

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Isolated, transient FlutterActivity specifically for the LisKo Home Screen SOS Widget.
 * Configured with excludeFromRecents="true" and taskAffinity="com.lisko.safety.sos_widget".
 * Directly mounts initialRoute "/sos_emergency" to display the 5-second countdown overlay
 * without modifying MainActivity's task or session state.
 */
class SosEmergencyActivity : FlutterActivity() {
    private val CHANNEL = "com.lisko.safety/sos_emergency_activity"

    override fun getInitialRoute(): String {
        return "/sos_emergency"
    }

    private fun returnToHomeAndFinish() {
        try {
            val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(homeIntent)
        } catch (e: Throwable) {
            // Fallback
        }
        finish()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "finishSosActivity", "returnToHomeAndFinish" -> {
                    returnToHomeAndFinish()
                    result.success(true)
                }
                "openOnboardingAndFinish" -> {
                    val intent = Intent(this, MainActivity::class.java).apply {
                        putExtra("show_setup_required_notice", true)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    startActivity(intent)
                    finish()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
