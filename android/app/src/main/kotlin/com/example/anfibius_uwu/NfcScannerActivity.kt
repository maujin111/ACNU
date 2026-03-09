package com.example.anfibius_uwu

import android.app.Activity
import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.view.Gravity
import android.widget.Button
import com.example.anfibius_uwu.utils.Hex
import com.example.anfibius_uwu.service.NfcForegroundService

class NfcScannerActivity : Activity() {

    private var nfcAdapter: NfcAdapter? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Estilo diálogo pequeño y centrado
        setContentView(R.layout.activity_nfc_scan_dialog)
        
        val layoutParams = window.attributes
        layoutParams.gravity = Gravity.CENTER
        layoutParams.width = WindowManager.LayoutParams.MATCH_PARENT
        window.attributes = layoutParams
        
        // Mantener la pantalla encendida y visible sobre el bloqueo
        window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                       WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                       WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        findViewById<Button>(R.id.btnCancel).setOnClickListener { finish() }

        nfcAdapter = NfcAdapter.getDefaultAdapter(this)
        
        if (nfcAdapter == null) {
            finish()
            return
        }

        // Si ya hay un Tag en el Intent que lo despertó, procésalo de inmediato
        if (intent != null) {
            processIntent(intent)
        }
    }

    override fun onResume() {
        super.onResume()
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
            NfcAdapter.ACTION_TAG_DISCOVERED == action) {
            
            val tag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(NfcAdapter.EXTRA_TAG, Tag::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
            }

            tag?.let {
                val uid = Hex.bytes(it.id)
                NfcForegroundService.sendCardResult(uid)
                finish() // Cierra el mini-widget al terminar
            }
        }
    }

    private fun enableReaderMode() {
        // Estas banderas son vitales para BLOQUEAR a Honor Wallet
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