package com.example.anfibius_uwu

import android.content.Intent
import android.net.Uri
import android.provider.Settings
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
                "checkOverlayPermission" -> {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                        result.success(Settings.canDrawOverlays(this))
                    } else {
                        result.success(true)
                    }
                }
                "requestOverlayPermission" -> {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivityForResult(intent, 1234)
                        result.success(true)
                    } else {
                        result.success(true)
                    }
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