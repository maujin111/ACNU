package com.example.anfibius_uwu

import android.app.Activity
import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import com.example.anfibius_uwu.utils.Hex
import com.example.anfibius_uwu.service.NfcForegroundService

class NfcScannerActivity : Activity() {

    private var nfcAdapter: NfcAdapter? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Hacer la actividad invisible
        window.addFlags(WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or 
                       WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                       WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                       WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)

        nfcAdapter = NfcAdapter.getDefaultAdapter(this)
        
        if (nfcAdapter == null) {
            finish()
            return
        }

        // Si la actividad fue iniciada por un Intent de NFC (segundo plano)
        if (intent != null) {
            processIntent(intent)
        }

        enableReaderMode()
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        if (intent != null) {
            processIntent(intent)
        }
    }

    private fun processIntent(intent: Intent) {
        val action = intent.action
        if (NfcAdapter.ACTION_TECH_DISCOVERED == action || 
            NfcAdapter.ACTION_TAG_DISCOVERED == action ||
            NfcAdapter.ACTION_NDEF_DISCOVERED == action) {
            
            val tag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(NfcAdapter.EXTRA_TAG, Tag::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
            }

            tag?.let {
                val uid = Hex.bytes(it.id)
                NfcForegroundService.sendCardResult(uid)
                finish()
            }
        }
    }

    private fun enableReaderMode() {
        // Estas banderas son CRÍTICAS para bloquear Honor Wallet y sonidos del sistema
        val flags = NfcAdapter.FLAG_READER_NFC_A or
                    NfcAdapter.FLAG_READER_NFC_B or
                    NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK or
                    NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS

        nfcAdapter?.enableReaderMode(this, { tag: Tag ->
            val uid = Hex.bytes(tag.id)
            NfcForegroundService.sendCardResult(uid)
            runOnUiThread {
                finish()
            }
        }, flags, null)
    }

    override fun onPause() {
        super.onPause()
        nfcAdapter?.disableReaderMode(this)
    }
}
