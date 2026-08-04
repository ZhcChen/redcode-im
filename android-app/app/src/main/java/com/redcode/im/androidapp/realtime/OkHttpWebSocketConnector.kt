package com.redcode.im.androidapp.realtime

import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener

class OkHttpWebSocketConnector(
    private val client: OkHttpClient = OkHttpClient(),
) : WebSocketConnector {
    override fun connect(url: String, listener: RedCodeWebSocketListener): RedCodeWebSocket {
        val request = Request.Builder().url(url).build()
        val webSocket =
            client.newWebSocket(
                request,
                object : WebSocketListener() {
                    override fun onOpen(webSocket: WebSocket, response: Response) {
                        listener.onOpen(OkHttpRedCodeWebSocket(webSocket))
                    }

                    override fun onMessage(webSocket: WebSocket, text: String) {
                        listener.onMessage(text)
                    }

                    override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                        listener.onClosing(code, reason)
                    }

                    override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                        listener.onClosed(code, reason)
                    }

                    override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                        listener.onFailure(t)
                    }
                },
            )
        return OkHttpRedCodeWebSocket(webSocket)
    }
}

private class OkHttpRedCodeWebSocket(
    private val delegate: WebSocket,
) : RedCodeWebSocket {
    override fun send(text: String): Boolean = delegate.send(text)

    override fun close(code: Int, reason: String?): Boolean = delegate.close(code, reason)

    override fun cancel() {
        delegate.cancel()
    }
}
