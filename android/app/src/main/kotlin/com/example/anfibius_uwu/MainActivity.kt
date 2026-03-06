package com.example.anfibius_uwu

import android.app.PendingIntent
import android.content.Intent
import android.nfc.NfcAdapter
import android.os.Bundle
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
        
        val adapter: NfcAdapter? = NfcAdapter.getDefaultAdapter(this)
        val pendingIntent: PendingIntent = PendingIntent.getActivity(
                this, 0, Intent(this, javaClass).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_IMMUTABLE)
        adapter?.enableForegroundDispatch(this, pendingIntent, null, null)
    }

    override fun onPause() {
        super.onPause()
        NfcForegroundService.currentActivity = null
        
        val adapter: NfcAdapter? = NfcAdapter.getDefaultAdapter(this)
        adapter?.disableForegroundDispatch(this)
    }
}