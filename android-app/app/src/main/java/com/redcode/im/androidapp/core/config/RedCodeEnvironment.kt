package com.redcode.im.androidapp.core.config

data class RedCodeEnvironment(
    val apiBaseUrl: String,
    val wsUrl: String,
) {
    init {
        require(apiBaseUrl.startsWith("http://") || apiBaseUrl.startsWith("https://")) {
            "apiBaseUrl 必须使用 http/https"
        }
        require(wsUrl.startsWith("ws://") || wsUrl.startsWith("wss://")) {
            "wsUrl 必须使用 ws/wss"
        }
    }

    companion object {
        fun localEmulator(): RedCodeEnvironment =
            RedCodeEnvironment(
                apiBaseUrl = "http://10.0.2.2:8010",
                wsUrl = "ws://10.0.2.2:8010/ws",
            )
    }
}
