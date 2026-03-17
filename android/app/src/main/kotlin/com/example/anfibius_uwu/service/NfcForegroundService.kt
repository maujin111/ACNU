package com.example.anfibius_uwu.service

import android.app.*
import android.content.Intent
import android.nfc.NfcAdapter
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import androidx.core.app.NotificationCompat
import com.example.anfibius_uwu.socket.SocketManager
import com.example.anfibius_uwu.nfc.NfcReader
import java.lang.ref.WeakReference

class NfcForegroundService : Service() {

    companion object {
        private const val TAG = "ANFIBIUS_SERVICE"
        private const val SCAN_WINDOW_MS = 30000L // 30 segundos
        
        var currentActivity: WeakReference<Activity>? = null
        private var instance: WeakReference<NfcForegroundService>? = null
        private var lastMeseroId: Int = -1
        private var lastRequestTimestamp: Long = 0

        // Función para verificar si estamos dentro de la ventana de 30 segundos
        fun isScanWindowActive(): Boolean {
            val now = System.currentTimeMillis()
            val isActive = (now - lastRequestTimestamp) < SCAN_WINDOW_MS
            if (!isActive) {
                Log.d(TAG, "Ventana de escaneo inactiva. Han pasado ${ (now - lastRequestTimestamp) / 1000 } segundos.")
            }
            return isActive
        }

        fun sendCardResult(uid: String) {
            if (isScanWindowActive()) {
                instance?.get()?.let { service ->
                    service.socket.sendCard(uid, lastMeseroId)
                    // Una vez enviado, cerramos la ventana para que no envíe duplicados
                    lastRequestTimestamp = 0 
                    Log.d(TAG, "Resultado enviado y ventana de escaneo cerrada.")
                }
            } else {
                Log.w(TAG, "Se detectó una tarjeta pero NO hay una petición activa (fuera de los 30s).")
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
            lastRequestTimestamp = System.currentTimeMillis() // INICIAR VENTANA DE 30 SEGUNDOS
            
            Log.d(TAG, "Nueva petición de escaneo recibida. Ventana de 30s iniciada para mesero: $meseroId")

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
            
            try {
                startActivity(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Error lanzando actividad: ${e.message}")
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
            .setContentTitle("LECTURA NFC SOLICITADA")
            .setContentText("Tienes 30 segundos para acercar la tarjeta")
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(fullScreenIntent, true)
            .setAutoCancel(true)
            .setTimeoutAfter(SCAN_WINDOW_MS) // La notificación desaparece sola tras 30s
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
                NotificationManager.IMPORTANCE_HIGH
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }
}