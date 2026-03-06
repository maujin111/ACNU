package com.example.anfibius_uwu.nfc

import android.app.Activity
import android.content.Context
import android.nfc.NfcAdapter
import android.nfc.Tag
import com.example.anfibius_uwu.utils.Hex

class NfcReader(private val context: Context){

    private val adapter: NfcAdapter? = NfcAdapter.getDefaultAdapter(context)

    fun readOnce(activity: Activity?, callback:(String)->Unit){
        if (activity == null) return

        adapter?.enableReaderMode(
            activity,
            { tag: Tag ->
                val uid = Hex.bytes(tag.id)
                callback(uid)
                adapter.disableReaderMode(activity)
            },
            NfcAdapter.FLAG_READER_NFC_A or
            NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK,
            null
        )
    }
}
