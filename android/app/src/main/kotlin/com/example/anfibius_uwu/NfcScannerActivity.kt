package com.example.anfibius_uwu

import android.app.Activity
import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import android.view.Gravity
import android.widget.Button
import android.widget.Toast
import com.example.anfibius_uwu.utils.Hex
import com.example.anfibius_uwu.service.NfcForegroundService

class NfcScannerActivity : Activity() {

    private val TAG = "ANFIBIUS_NFC"
    private var nfcAdapter: NfcAdapter? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "Iniciando NfcScannerActivity...")
        
        try {
            setContentView(R.layout.activity_nfc_scan_dialog)
            Log.d(TAG, "Layout cargado correctamente")
        } catch (e: Exception) {
            Log.e(TAG, "Error cargando layout: ${e.message}")
        }

        // Configurar ventana como diálogo
        val layoutParams = window.attributes
        layoutParams.gravity = Gravity.CENTER
        window.attributes = layoutParams
        
        // Banderas críticas para Honor/Huawei
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                       WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                       WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                       WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)

        findViewById<Button>(R.id.btnCancel).setOnClickListener { 
            Log.d(TAG, "Escaneo cancelado por usuario")
            finish() 
        }

        nfcAdapter = NfcAdapter.getDefaultAdapter(this)
        
        if (nfcAdapter == null) {
            Log.e(TAG, "NFC no disponible en este dispositivo")
            Toast.makeText(this, "NFC no disponible", Toast.LENGTH_SHORT).show()
            finish()
            return
        }

        if (!nfcAdapter!!.isEnabled) {
            Log.w(TAG, "NFC está desactivado")
            Toast.makeText(this, "Por favor active el NFC", Toast.LENGTH_SHORT).show()
        }

        Log.d(TAG, "NfcScannerActivity lista y esperando tarjeta")
        
        // Procesar si ya viene con un Tag (despertado por el sistema)
        intent?.let { processIntent(it) }
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume: Activando modo lector")
        enableReaderMode()
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        Log.d(TAG, "onNewIntent recibido")
        intent?.let { processIntent(it) }
    }

    private fun processIntent(intent: Intent) {
        val action = intent.action
        Log.d(TAG, "Procesando Intent con acción: $action")
        
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
                Log.d(TAG, "¡Tarjeta detectada! UID: $uid")
                NfcForegroundService.sendCardResult(uid)
                Toast.makeText(this, "Tarjeta leída: $uid", Toast.LENGTH_SHORT).show()
                finish()
            }
        }
    }

    private fun enableReaderMode() {
        val flags = NfcAdapter.FLAG_READER_NFC_A or
                    NfcAdapter.FLAG_READER_NFC_B or
                    NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK or
                    NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS

        try {
            nfcAdapter?.enableReaderMode(this, { tag: Tag ->
                val uid = Hex.bytes(tag.id)
                Log.d(TAG, "Lectura exitosa en modo lector: $uid")
                NfcForegroundService.sendCardResult(uid)
                runOnUiThread {
                    Toast.makeText(this, "Tarjeta leída", Toast.LENGTH_SHORT).show()
                    finish()
                }
            }, flags, null)
        } catch (e: Exception) {
            Log.e(TAG, "Error activando modo lector: ${e.message}")
        }
    }

    override fun onPause() {
        super.onPause()
        Log.d(TAG, "onPause: Desactivando modo lector")
        nfcAdapter?.disableReaderMode(this)
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "onDestroy: Actividad cerrada")
    }
}