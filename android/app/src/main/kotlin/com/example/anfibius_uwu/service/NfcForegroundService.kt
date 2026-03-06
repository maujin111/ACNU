package com.example.anfibius_uwu.service

import android.app.*
import android.content.Intent
import android.nfc.NfcAdapter
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.example.anfibius_uwu.socket.SocketManager
import com.example.anfibius_uwu.nfc.NfcReader
import java.lang.ref.WeakReference

class NfcForegroundService : Service() {

    companion object {
        var currentActivity: WeakReference<Activity>? = null
    }

    private lateinit var socket: SocketManager
    private lateinit var nfcReader: NfcReader

    override fun onCreate() {
        super.onCreate()

        createChannel()
        startForeground(1, notification())

        socket = SocketManager()
        nfcReader = NfcReader(this)

        socket.onScanRequest = { meseroId ->
            val activity = currentActivity?.get()
            if (activity != null) {
                nfcReader.readOnce(activity) { uid ->
                    socket.sendCard(uid, meseroId)
                }
            } else {
                // Si no hay actividad, tal vez deberíamos lanzar una o mostrar una notificación
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val sala = intent?.getStringExtra("sala") ?: "general"
        socket.connect(sala)
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun notification(): Notification {
        val intent = Intent(this, Class.forName("com.example.anfibius_uwu.MainActivity"))
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent, 
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, "nfc_pos")
            .setContentTitle("NFC POS activo")
            .setContentText("Esperando comandos del servidor")
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "nfc_pos",
                "NFC POS",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }
}
