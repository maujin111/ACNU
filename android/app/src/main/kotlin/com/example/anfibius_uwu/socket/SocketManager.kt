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

                val json = JSONObject(text)

                if(json.has("type") && json.getString("type") == "nfc"){
                    val mesero = json.getInt("id")
                    onScanRequest?.invoke(mesero)
                }

            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                reconnect(sala)
            }

        })
    }

    private fun reconnect(sala: String){
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
        // Cambiado 'mesero' por 'id' para mantener consistencia
        json.put("id", mesero)

        socket?.send(json.toString())
    }

}
