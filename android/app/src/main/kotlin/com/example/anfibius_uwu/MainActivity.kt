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
        if (adapter != null) {
            val flags = NfcAdapter.FLAG_READER_NFC_A or
                        NfcAdapter.FLAG_READER_NFC_B or
                        NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK or
                        NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS

            adapter.enableReaderMode(this, { tag ->
                val uid = com.example.anfibius_uwu.utils.Hex.bytes(tag.id)
                NfcForegroundService.sendCardResult(uid)
            }, flags, null)
        }
    }

    override fun onPause() {
        super.onPause()
        NfcForegroundService.currentActivity = null
        val adapter: NfcAdapter? = NfcAdapter.getDefaultAdapter(this)
        adapter?.disableReaderMode(this)
    }
}