package com.example.anfibius_uwu

import android.app.Activity
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Bundle
import android.view.WindowManager
import com.example.anfibius_uwu.utils.Hex
import com.example.anfibius_uwu.service.NfcForegroundService

class NfcScannerActivity : Activity() {

    private var nfcAdapter: NfcAdapter? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Hacer la actividad invisible y permitir que se ejecute sobre la pantalla de bloqueo
        window.addFlags(WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or 
                       WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                       WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                       WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)

        nfcAdapter = NfcAdapter.getDefaultAdapter(this)
        
        if (nfcAdapter == null) {
            finish()
            return
        }

        enableReaderMode()
    }

    private fun enableReaderMode() {
        val flags = NfcAdapter.FLAG_READER_NFC_A or
                    NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK or
                    NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS

        nfcAdapter?.enableReaderMode(this, { tag: Tag ->
            val uid = Hex.bytes(tag.id)
            
            // Enviar el resultado de vuelta al servicio o socket
            // Usamos un broadcast o una referencia estática para simplificar
            NfcForegroundService.sendCardResult(uid)
            
            // Cerrar la actividad inmediatamente después de leer
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
