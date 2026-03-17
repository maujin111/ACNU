package com.example.anfibius_uwu.socket

import okhttp3.*
import org.json.JSONObject
import java.util.concurrent.TimeUnit
import java.security.cert.X509Certificate
import javax.net.ssl.*
import android.util.Log

class SocketManager {

    private var socket: WebSocket? = null
    private var reconnectDelay = 2000L
    private val TAG = "ANFIBIUS_SOCKET"

    var onScanRequest: ((Int) -> Unit)? = null

    // Cliente OkHttp configurado para ignorar errores de certificado SSL
    private val client: OkHttpClient by lazy {
        try {
            val trustAllCerts = arrayOf<TrustManager>(object : X509TrustManager {
                override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) {}
                override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {}
                override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
            })

            val sslContext = SSLContext.getInstance("SSL")
            sslContext.init(null, trustAllCerts, java.security.SecureRandom())
            
            val sslSocketFactory = sslContext.socketFactory

            OkHttpClient.Builder()
                .sslSocketFactory(sslSocketFactory, trustAllCerts[0] as X509TrustManager)
                .hostnameVerifier { _, _ -> true }
                .readTimeout(0, TimeUnit.MILLISECONDS)
                .connectTimeout(10, TimeUnit.SECONDS)
                .build()
        } catch (e: Exception) {
            Log.e(TAG, "Error creando cliente SSL inseguro: ${e.message}")
            OkHttpClient.Builder().build()
        }
    }

    fun connect(sala: String) {
        val url = "wss://soporte.anfibius.net:3300/$sala"
        Log.d(TAG, "Intentando conectar socket nativo a: $url")

        val request = Request.Builder()
            .url(url)
            .build()

        socket = client.newWebSocket(request, object: WebSocketListener(){

            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d(TAG, "Socket nativo CONECTADO exitosamente")
                reconnectDelay = 2000
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                Log.d(TAG, "Mensaje recibido nativo: $text")
                try {
                    val json = JSONObject(text)
                    if (json.has("type") && (json.getString("type") == "nfc" || json.getString("type") == "NFC")) {
                        val meseroId = if (json.has("id")) json.getInt("id") else -1
                        Log.d(TAG, "Solicitud NFC detectada para mesero: $meseroId")
                        onScanRequest?.invoke(meseroId)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error parseando mensaje: ${e.message}")
                }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e(TAG, "Fallo en el socket nativo: ${t.message}")
                reconnect(sala)
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "Socket nativo cerrándose: $reason")
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "Socket nativo CERRADO")
            }
        })
    }

    private fun reconnect(sala: String){
        Log.d(TAG, "Reconectando socket nativo en $reconnectDelay ms...")
        Thread{
            try {
                Thread.sleep(reconnectDelay)
                reconnectDelay = (reconnectDelay * 1.5).toLong().coerceAtMost(30000)
                connect(sala)
            } catch (e: Exception) {
                Log.e(TAG, "Error en hilo de reconexión: ${e.message}")
            }
        }.start()
    }

    fun sendCard(uid: String, mesero: Int){
        val json = JSONObject()
        json.put("type", "RES_NFC")
        json.put("uid", uid)
        json.put("id", mesero)
        
        val message = json.toString()
        Log.d(TAG, "Enviando respuesta NFC por socket nativo: $message")
        
        val sent = socket?.send(message) ?: false
        if (sent) {
            Log.d(TAG, "Mensaje enviado exitosamente al servidor")
        } else {
            Log.e(TAG, "Error CRÍTICO: No se pudo enviar el mensaje por el socket (¿está desconectado?)")
        }
    }
}