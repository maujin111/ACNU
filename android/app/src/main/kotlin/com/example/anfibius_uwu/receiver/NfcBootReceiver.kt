package com.example.anfibius_uwu.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.example.anfibius_uwu.service.NfcForegroundService

class NfcBootReceiver: BroadcastReceiver(){

    override fun onReceive(context: Context, intent: Intent) {
        if(intent.action == Intent.ACTION_BOOT_COMPLETED){
            val serviceIntent = Intent(context, NfcForegroundService::class.java)
            context.startForegroundService(serviceIntent)
        }
    }
}
