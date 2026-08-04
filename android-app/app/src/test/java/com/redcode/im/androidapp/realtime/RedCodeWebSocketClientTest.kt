package com.redcode.im.androidapp.realtime

import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class RedCodeWebSocketClientTest {
    @Test
    fun buildWebSocketUrl_forcesJsonFormatAndWebSocketScheme() {
        assertEquals(
            "ws://127.0.0.1:8010/ws?foo=bar&format=json",
            RedCodeWebSocketClient.buildWebSocketUrl("http://127.0.0.1:8010/ws?foo=bar&format=proto"),
        )
        assertEquals(
            "wss://example.test/ws?format=json",
            RedCodeWebSocketClient.buildWebSocketUrl("https://example.test/ws"),
        )
    }

    @Test
    fun connect_sendsAuthAndPingFrames() =
        runTest {
            val connector = FakeWebSocketConnector()
            val client = client(connector, pingIntervalMillis = 100)

            client.connect(" access-token ")
            connector.open()
            advanceTimeBy(100)
            runCurrent()

            assertEquals("ws://10.0.2.2:8010/ws?format=json", connector.lastUrl)
            assertEquals(WebSocketConnectionStatus.Connected, client.status.value)
            assertEquals("""{"type":"auth","token":"access-token"}""", connector.socket.sent[0])
            assertEquals("""{"type":"ping"}""", connector.socket.sent[1])
            client.disconnect()
        }

    @Test
    fun authJoinLeaveTypingAndEvents_updateConnectionState() =
        runTest {
            val connector = FakeWebSocketConnector()
            val client = client(connector)

            client.connect("token")
            connector.open()
            client.ensureRoomsSubscribed(listOf("room-a", "room-b"))
            connector.message("""{"type":"authed","user_id":"user-1","conn_id":"conn-1"}""")
            connector.message("""{"type":"joined","room_id":"room-a"}""")
            client.setTyping("room-a", true)
            client.ensureRoomsSubscribed(listOf("room-b"), pruneMissing = true)
            connector.message("""{"type":"left","room_id":"room-a"}""")

            val roomAJoins = connector.socket.sent.count { it == """{"type":"join","room_id":"room-a"}""" }
            assertEquals(WebSocketConnectionStatus.Authenticated, client.status.value)
            assertEquals("conn-1", client.connectionId)
            assertEquals(setOf("room-b"), client.desiredRoomsSnapshot())
            assertEquals(emptySet<String>(), client.subscribedRoomsSnapshot())
            assertEquals(1, roomAJoins)
            assertTrue(connector.socket.sent.contains("""{"type":"join","room_id":"room-a"}"""))
            assertTrue(connector.socket.sent.contains("""{"type":"join","room_id":"room-b"}"""))
            assertTrue(connector.socket.sent.contains("""{"type":"typing","room_id":"room-a","is_typing":true}"""))
            assertTrue(connector.socket.sent.contains("""{"type":"leave","room_id":"room-a"}"""))
            assertEquals("left", client.events.value?.type)
            client.disconnect()
        }

    @Test
    fun serverErrorAndBlankToken_setErrorState() =
        runTest {
            val connector = FakeWebSocketConnector()
            val client = client(connector)

            client.connect(" ")
            assertEquals(WebSocketConnectionStatus.Error, client.status.value)
            assertEquals("用户未登录", client.lastError)

            client.connect("token")
            connector.open()
            connector.message("""{"type":"error","message":"bad auth"}""")

            assertEquals(WebSocketConnectionStatus.Error, client.status.value)
            assertEquals("bad auth", client.lastError)
            client.disconnect()
        }

    @Test
    fun activeConnectClosingInvalidFramesAndTypingGuardsAreHandled() =
        runTest {
            val connector = FakeWebSocketConnector()
            val client = client(connector)

            client.setTyping(" ", true)
            client.connect("token")
            client.connect("other-token")
            connector.open()
            connector.closing()
            connector.message("not-json")

            assertEquals(1, connector.connectCount)
            assertEquals(1, connector.socket.closeCount)
            assertEquals(null, client.events.value)
            client.disconnect()
        }

    @Test
    fun disconnectCancelsSocketWhenGracefulCloseFails() =
        runTest {
            val connector = FakeWebSocketConnector()
            val client = client(connector)

            client.connect("token")
            connector.open()
            connector.socket.closeResult = false
            client.disconnect()

            assertEquals(1, connector.socket.cancelCount)
            assertEquals(WebSocketConnectionStatus.Disconnected, client.status.value)
        }

    @Test
    fun failureSchedulesReconnectUnlessManuallyDisconnected() =
        runTest {
            val connector = FakeWebSocketConnector()
            val client = client(connector, reconnectDelaysMillis = listOf(100))

            client.connect("token")
            connector.open()
            connector.fail(IllegalStateException("network down"))
            connector.close(0)
            advanceTimeBy(100)
            runCurrent()

            assertEquals(2, connector.connectCount)
            assertEquals("network down", client.lastError)

            connector.open()
            client.disconnect()
            connector.close()
            advanceTimeBy(200)

            assertEquals(2, connector.connectCount)
            assertEquals(WebSocketConnectionStatus.Disconnected, client.status.value)
        }

    @Test
    fun staleCallbacksAfterReconnectAreIgnored() =
        runTest {
            val connector = FakeWebSocketConnector()
            val client = client(connector, reconnectDelaysMillis = listOf(100, 100))

            client.connect("old-token")
            connector.open(0)
            client.disconnect()
            client.connect("new-token")
            connector.open(1)
            connector.close(0)
            connector.fail(IllegalStateException("stale failure"), index = 0)
            advanceTimeBy(200)
            runCurrent()

            assertEquals(2, connector.connectCount)
            assertEquals(WebSocketConnectionStatus.Connected, client.status.value)
            assertEquals("""{"type":"auth","token":"new-token"}""", connector.socket.sent[0])
            client.disconnect()
        }

    private fun TestScope.client(
        connector: FakeWebSocketConnector,
        pingIntervalMillis: Long = 30_000,
        reconnectDelaysMillis: List<Long> = listOf(1_000),
    ): RedCodeWebSocketClient =
        RedCodeWebSocketClient(
            environment = RedCodeEnvironment.localEmulator(),
            connector = connector,
            scope = this,
            pingIntervalMillis = pingIntervalMillis,
            reconnectDelaysMillis = reconnectDelaysMillis,
        )
}

private class FakeWebSocketConnector : WebSocketConnector {
    val socket: FakeWebSocket
        get() = sockets.last()
    private val sockets = mutableListOf<FakeWebSocket>()
    private val listeners = mutableListOf<RedCodeWebSocketListener>()
    var lastUrl = ""
    var connectCount = 0

    override fun connect(url: String, listener: RedCodeWebSocketListener): RedCodeWebSocket {
        val socket = FakeWebSocket()
        sockets += socket
        listeners += listener
        lastUrl = url
        connectCount += 1
        return socket
    }

    fun open(index: Int = listeners.lastIndex) {
        listeners.getOrNull(index)?.onOpen(sockets[index])
    }

    fun message(text: String, index: Int = listeners.lastIndex) {
        listeners.getOrNull(index)?.onMessage(text)
    }

    fun fail(error: Throwable, index: Int = listeners.lastIndex) {
        listeners.getOrNull(index)?.onFailure(error)
    }

    fun closing(index: Int = listeners.lastIndex) {
        listeners.getOrNull(index)?.onClosing(1000, "closing")
    }

    fun close(index: Int = listeners.lastIndex) {
        listeners.getOrNull(index)?.onClosed(1000, "closed")
    }
}

private class FakeWebSocket : RedCodeWebSocket {
    val sent = mutableListOf<String>()
    var closeCount = 0
    var cancelCount = 0
    var closeResult = true

    override fun send(text: String): Boolean {
        sent += text
        return true
    }

    override fun close(code: Int, reason: String?): Boolean {
        closeCount += 1
        return closeResult
    }

    override fun cancel() {
        cancelCount += 1
    }
}
