package com.redcode.im.androidapp.realtime

import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import java.net.URI
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonPrimitive

enum class WebSocketConnectionStatus {
    Connecting,
    Connected,
    Authenticated,
    Disconnected,
    Error,
}

data class WebSocketServerEvent(
    val type: String,
    val payload: JsonObject,
)

class RedCodeWebSocketClient(
    private val environment: RedCodeEnvironment,
    private val connector: WebSocketConnector = OkHttpWebSocketConnector(),
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
    private val json: Json =
        Json {
            ignoreUnknownKeys = true
        },
    private val pingIntervalMillis: Long = 30_000,
    private val reconnectDelaysMillis: List<Long> = listOf(1_000, 2_000, 5_000, 5_000, 5_000),
) {
    private val statusState = MutableStateFlow(WebSocketConnectionStatus.Disconnected)
    private val eventState = MutableStateFlow<WebSocketServerEvent?>(null)
    private val desiredRooms = linkedSetOf<String>()
    private val subscribedRooms = linkedSetOf<String>()
    private val pendingRooms = linkedSetOf<String>()
    private var socket: RedCodeWebSocket? = null
    private var pingJob: Job? = null
    private var reconnectJob: Job? = null
    private var manualClose = false
    private var authToken: String? = null
    private var reconnectAttempts = 0
    private var connectionGeneration = 0

    val status: StateFlow<WebSocketConnectionStatus> = statusState.asStateFlow()
    val events: StateFlow<WebSocketServerEvent?> = eventState.asStateFlow()
    var connectionId: String? = null
        private set
    var lastError: String? = null
        private set

    @Synchronized
    fun connect(token: String) {
        val normalized = token.trim()
        if (normalized.isBlank()) {
            lastError = "用户未登录"
            statusState.value = WebSocketConnectionStatus.Error
            return
        }
        if (statusState.value in setOf(WebSocketConnectionStatus.Connecting, WebSocketConnectionStatus.Connected, WebSocketConnectionStatus.Authenticated)) {
            return
        }

        authToken = normalized
        manualClose = false
        reconnectJob?.cancel()
        val generation = nextGeneration()
        statusState.value = WebSocketConnectionStatus.Connecting
        socket =
            connector.connect(
                buildWebSocketUrl(environment.wsUrl),
                object : RedCodeWebSocketListener {
                    override fun onOpen(webSocket: RedCodeWebSocket) {
                        handleOpen(generation, webSocket, normalized)
                    }

                    override fun onMessage(text: String) {
                        handleTextFrame(generation, text)
                    }

                    override fun onClosing(code: Int, reason: String) {
                        handleClosing(generation, code, reason)
                    }

                    override fun onClosed(code: Int, reason: String) {
                        handleClosed(generation)
                    }

                    override fun onFailure(error: Throwable) {
                        handleFailure(generation, error)
                    }
                },
            )
    }

    @Synchronized
    fun disconnect() {
        manualClose = true
        reconnectJob?.cancel()
        stopPing()
        nextGeneration()
        desiredRooms.clear()
        subscribedRooms.clear()
        pendingRooms.clear()
        connectionId = null
        val currentSocket = socket
        if (currentSocket?.close(1000, "client disconnect") != true) {
            currentSocket?.cancel()
        }
        socket = null
        statusState.value = WebSocketConnectionStatus.Disconnected
    }

    @Synchronized
    fun ensureRoomsSubscribed(roomIds: Iterable<String>, pruneMissing: Boolean = false) {
        val targets = roomIds.map { it.trim() }.filter { it.isNotBlank() }.toSet()
        if (pruneMissing) {
            val removed = desiredRooms.filterNot { it in targets }
            removed.forEach { roomId ->
                desiredRooms.remove(roomId)
                subscribedRooms.remove(roomId)
                pendingRooms.remove(roomId)
                sendLeave(roomId)
            }
        }
        targets.forEach { roomId ->
            desiredRooms.add(roomId)
            if (statusState.value == WebSocketConnectionStatus.Authenticated &&
                roomId !in subscribedRooms &&
                roomId !in pendingRooms
            ) {
                pendingRooms.add(roomId)
                sendJoin(roomId)
            }
        }
    }

    @Synchronized
    fun setTyping(roomId: String, isTyping: Boolean) {
        val normalized = roomId.trim()
        if (normalized.isBlank() || statusState.value != WebSocketConnectionStatus.Authenticated || normalized !in subscribedRooms) {
            return
        }
        sendPayload(
            mapOf(
                "type" to JsonPrimitive("typing"),
                "room_id" to JsonPrimitive(normalized),
                "is_typing" to JsonPrimitive(isTyping),
            ),
        )
    }

    @Synchronized
    fun subscribedRoomsSnapshot(): Set<String> = subscribedRooms.toSet()

    @Synchronized
    fun desiredRoomsSnapshot(): Set<String> = desiredRooms.toSet()

    @Synchronized
    private fun handleOpen(generation: Int, webSocket: RedCodeWebSocket, token: String) {
        if (!isCurrentGeneration(generation)) {
            webSocket.close(1000, "stale connection")
            return
        }
        socket = webSocket
        statusState.value = WebSocketConnectionStatus.Connected
        sendPayload(mapOf("type" to JsonPrimitive("auth"), "token" to JsonPrimitive(token)))
        startPing()
    }

    @Synchronized
    private fun handleClosing(generation: Int, code: Int, reason: String) {
        if (!isCurrentGeneration(generation)) return
        socket?.close(code, reason)
    }

    @Synchronized
    private fun handleFailure(generation: Int, error: Throwable) {
        if (!isCurrentGeneration(generation)) return
        lastError = error.message ?: "WebSocket 连接异常"
        statusState.value = WebSocketConnectionStatus.Error
        handleClosed(generation)
    }

    @Synchronized
    private fun handleTextFrame(generation: Int, text: String) {
        if (!isCurrentGeneration(generation)) return
        val payload =
            runCatching { json.parseToJsonElement(text) as? JsonObject }
                .getOrNull()
                ?: return
        val type = payload["type"]?.jsonPrimitive?.contentOrNull ?: return
        val event = WebSocketServerEvent(type = type, payload = payload)
        when (type) {
            "authed" -> {
                connectionId = payload["conn_id"]?.jsonPrimitive?.contentOrNull
                reconnectAttempts = 0
                statusState.value = WebSocketConnectionStatus.Authenticated
                ensureRoomsSubscribed(desiredRooms)
            }
            "joined" -> {
                val roomId = payload["room_id"]?.jsonPrimitive?.contentOrNull
                if (!roomId.isNullOrBlank()) {
                    pendingRooms.remove(roomId)
                    subscribedRooms.add(roomId)
                }
            }
            "left" -> {
                val roomId = payload["room_id"]?.jsonPrimitive?.contentOrNull
                if (!roomId.isNullOrBlank()) {
                    pendingRooms.remove(roomId)
                    subscribedRooms.remove(roomId)
                }
            }
            "error" -> {
                lastError = payload["message"]?.jsonPrimitive?.contentOrNull ?: "WebSocket 服务端错误"
                statusState.value = WebSocketConnectionStatus.Error
            }
        }
        eventState.value = event
    }

    @Synchronized
    private fun handleClosed(generation: Int) {
        if (!isCurrentGeneration(generation)) return
        if (socket == null && statusState.value == WebSocketConnectionStatus.Disconnected) return
        stopPing()
        socket = null
        subscribedRooms.clear()
        pendingRooms.clear()
        connectionId = null
        if (manualClose) {
            statusState.value = WebSocketConnectionStatus.Disconnected
            return
        }
        statusState.value = WebSocketConnectionStatus.Disconnected
        scheduleReconnect()
    }

    @Synchronized
    private fun scheduleReconnect() {
        val token = authToken ?: return
        if (reconnectAttempts >= reconnectDelaysMillis.size) return
        val delayMillis = reconnectDelaysMillis[reconnectAttempts]
        reconnectAttempts += 1
        reconnectJob?.cancel()
        reconnectJob =
            scope.launch {
                delay(delayMillis)
                connect(token)
            }
    }

    @Synchronized
    private fun startPing() {
        stopPing()
        pingJob =
            scope.launch {
                while (true) {
                    delay(pingIntervalMillis)
                    sendPayload(mapOf("type" to JsonPrimitive("ping")))
                }
            }
    }

    @Synchronized
    private fun stopPing() {
        pingJob?.cancel()
        pingJob = null
    }

    private fun sendJoin(roomId: String) {
        sendPayload(mapOf("type" to JsonPrimitive("join"), "room_id" to JsonPrimitive(roomId)))
    }

    private fun sendLeave(roomId: String) {
        sendPayload(mapOf("type" to JsonPrimitive("leave"), "room_id" to JsonPrimitive(roomId)))
    }

    @Synchronized
    private fun sendPayload(payload: Map<String, JsonElement>): Boolean =
        socket?.send(JsonObject(payload).toString()) ?: false

    private fun nextGeneration(): Int {
        connectionGeneration += 1
        return connectionGeneration
    }

    private fun isCurrentGeneration(generation: Int): Boolean = generation == connectionGeneration

    companion object {
        fun buildWebSocketUrl(rawUrl: String): String {
            val uri = URI(rawUrl)
            val scheme =
                when (uri.scheme?.lowercase()) {
                    "http" -> "ws"
                    "https" -> "wss"
                    else -> uri.scheme ?: "ws"
                }
            val query =
                uri.rawQuery
                    ?.split("&")
                    ?.filter { it.isNotBlank() && !it.startsWith("format=") }
                    .orEmpty() + "format=json"
            return URI(
                scheme,
                uri.userInfo,
                uri.host,
                uri.port,
                uri.path?.ifBlank { "/ws" } ?: "/ws",
                query.joinToString("&"),
                uri.fragment,
            ).toString()
        }
    }
}

private val JsonPrimitive.contentOrNull: String?
    get() = runCatching { content }.getOrNull()
