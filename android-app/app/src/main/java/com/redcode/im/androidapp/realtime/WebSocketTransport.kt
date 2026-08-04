package com.redcode.im.androidapp.realtime

interface RedCodeWebSocket {
    fun send(text: String): Boolean

    fun close(code: Int, reason: String?): Boolean

    fun cancel()
}

interface RedCodeWebSocketListener {
    fun onOpen(webSocket: RedCodeWebSocket)

    fun onMessage(text: String)

    fun onClosing(code: Int, reason: String)

    fun onClosed(code: Int, reason: String)

    fun onFailure(error: Throwable)
}

interface WebSocketConnector {
    fun connect(url: String, listener: RedCodeWebSocketListener): RedCodeWebSocket
}
