package com.example.anfibius_uwu.socket

import okhttp3.*
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class SocketManager {

    private var socket: WebSocket? = null
    private var reconnectDelay = 2000L

    var onScanRequest: ((Int) -> Unit)? = null

    private val client = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .build()

    fun connect(sala: String) {

        val request = Request.Builder()
            .url("wss://soporte.anfibius.net:3300/$sala")
            .build()

        socket = client.newWebSocket(request, object: WebSocketListener(){

            override fun onOpen(webSocket: WebSocket, response: Response) {
                reconnectDelay = 2000
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                android.util.Log.d("ANFIBIUS_SOCKET", "Mensaje recibido nativo: $text")
                try {
                    val json = JSONObject(text)

                    // Soporte para ambos formatos: array o objeto simple
                    if (json.has("type") && (json.getString("type") == "nfc" || json.getString("type") == "NFC")) {
                        val meseroId = if (json.has("id")) json.getInt("id") else -1
                        android.util.Log.d("ANFIBIUS_SOCKET", "Solicitud NFC detectada para mesero: $meseroId")
                        onScanRequest?.invoke(meseroId)
                    }
                } catch (e: Exception) {
                    android.util.Log.e("ANFIBIUS_SOCKET", "Error parseando mensaje: ${e.message}")
                }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                android.util.Log.e("ANFIBIUS_SOCKET", "Fallo en el socket nativo: ${t.message}")
                reconnect(sala)
            }

        })
    }

    private fun reconnect(sala: String){
        android.util.Log.d("ANFIBIUS_SOCKET", "Reconectando socket nativo en $reconnectDelay ms...")
        Thread{
            Thread.sleep(reconnectDelay)
            reconnectDelay = (reconnectDelay * 1.5).toLong().coerceAtMost(30000)
            connect(sala)
        }.start()
    }

    fun sendCard(uid: String, mesero: Int){
        val json = JSONObject()
        json.put("type", "RES_NFC")
        json.put("uid", uid)
        json.put("id", mesero)
        
        val message = json.toString()
        android.util.Log.d("ANFIBIUS_SOCKET", "Enviando respuesta NFC por socket nativo: $message")
        
        val sent = socket?.send(message) ?: false
        if (sent) {
            android.util.Log.d("ANFIBIUS_SOCKET", "Mensaje enviado exitosamente")
        } else {
            android.util.Log.e("ANFIBIUS_SOCKET", "Error al enviar el mensaje por socket")
        }
    }

}
