package com.example.anfibius_uwu.service

import android.app.*
import android.content.Intent
import android.nfc.NfcAdapter
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat
import com.example.anfibius_uwu.socket.SocketManager
import com.example.anfibius_uwu.nfc.NfcReader
import java.lang.ref.WeakReference

class NfcForegroundService : Service() {

    companion object {
        var currentActivity: WeakReference<Activity>? = null
        private var instance: WeakReference<NfcForegroundService>? = null
        private var lastMeseroId: Int = -1

        fun sendCardResult(uid: String) {
            instance?.get()?.let { service ->
                service.socket.sendCard(uid, lastMeseroId)
            }
        }
    }

    private lateinit var socket: SocketManager
    private lateinit var nfcReader: NfcReader

    override fun onCreate() {
        super.onCreate()
        instance = WeakReference(this)

        createChannel()
        startForeground(1, notification())

        socket = SocketManager()
        nfcReader = NfcReader(this)

        socket.onScanRequest = { meseroId ->
            lastMeseroId = meseroId
            
            // LANZAMIENTO DE ALTA PRIORIDAD (FULL SCREEN INTENT)
            // Esto es lo que usan las alarmas para saltarse los bloqueos de Honor
            val intent = Intent(this, Class.forName("com.example.anfibius_uwu.NfcScannerActivity")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_NO_USER_ACTION)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            
            val pendingIntent = PendingIntent.getActivity(
                this, 0, intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )

            showScanNotification(pendingIntent)
            
            // Intentar también el lanzamiento directo como respaldo
            try {
                startActivity(intent)
            } catch (e: Exception) {
                // Si falla el directo, el FullScreenIntent de la notificación debería actuar
            }
            
            val vibrator = getSystemService(Vibrator::class.java)
            vibrator?.let {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    it.vibrate(VibrationEffect.createOneShot(500, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION")
                    it.vibrate(500)
                }
            }
        }
    }

    private fun showScanNotification(fullScreenIntent: PendingIntent) {
        val notification = NotificationCompat.Builder(this, "nfc_pos")
            .setContentTitle("LECTURA NFC REQUERIDA")
            .setContentText("Acerque la tarjeta ahora para procesar")
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setPriority(NotificationCompat.PRIORITY_MAX) // Máxima prioridad
            .setCategory(NotificationCompat.CATEGORY_ALARM) // Categoría de alarma para que el sistema la priorice
            .setFullScreenIntent(fullScreenIntent, true) // ESTO ES LA CLAVE
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 500, 200, 500))
            .build()
        
        val manager = getSystemService(NotificationManager::class.java)
        manager?.notify(2, notification)
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
            .setOngoing(true)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "nfc_pos",
                "NFC POS",
                NotificationManager.IMPORTANCE_HIGH // Importancia alta para permitir overlays
            )
            channel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }
}