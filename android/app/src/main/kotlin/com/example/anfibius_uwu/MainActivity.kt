package com.example.anfibius_uwu

import android.content.Intent
import com.example.anfibius_uwu.service.NfcForegroundService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

class MainActivity : FlutterActivity() {

    private val CHANNEL = "nfc_pos"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val sala = call.argument<String>("sala") ?: "general"
                    val serviceIntent = Intent(this, NfcForegroundService::class.java).apply {
                        putExtra("sala", sala)
                    }
                    startForegroundService(serviceIntent)
                    result.success(null)
                }
                "stopService" -> {
                    val serviceIntent = Intent(this, NfcForegroundService::class.java)
                    stopService(serviceIntent)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        NfcForegroundService.currentActivity = WeakReference(this)
        // Eliminamos el enableReaderMode manual para que flutter_nfc_kit funcione
    }

    override fun onPause() {
        super.onPause()
        NfcForegroundService.currentActivity = null
    }
}