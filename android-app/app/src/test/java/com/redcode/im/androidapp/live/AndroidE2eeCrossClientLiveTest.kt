package com.redcode.im.androidapp.live

import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import com.redcode.im.androidapp.data.chat.HttpChatRemoteDataSource
import com.redcode.im.androidapp.e2ee.E2eeCommandClient
import com.redcode.im.androidapp.e2ee.E2eeCommandSessionCore
import com.redcode.im.androidapp.e2ee.E2eeDeviceLifecycle
import com.redcode.im.androidapp.e2ee.E2eeDirectMessageCoordinator
import com.redcode.im.androidapp.e2ee.E2eeDirectMessageException
import com.redcode.im.androidapp.e2ee.E2eeIncomingMessage
import com.redcode.im.androidapp.e2ee.E2eeMessageSource
import com.redcode.im.androidapp.e2ee.E2eeSecureStateStore
import com.redcode.im.androidapp.e2ee.HttpE2eeMlsApi
import com.redcode.im.androidapp.e2ee.InMemoryE2eeStateBlobStore
import com.redcode.im.androidapp.e2ee.InMemoryE2eeStateCipher
import com.redcode.im.androidapp.network.APIClient
import com.redcode.im.androidapp.network.HttpRequest
import com.redcode.im.androidapp.network.HttpResponse
import com.redcode.im.androidapp.network.HttpTransport
import com.redcode.im.androidapp.network.JavaNetHttpTransport
import com.redcode.im.androidapp.network.NetworkFailure
import java.net.HttpURLConnection
import java.net.URL
import java.util.Base64
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import kotlin.time.Duration.Companion.seconds

class AndroidE2eeCrossClientLiveTest {
    @Test
    fun exchangesCiphertextBidirectionallyWithH5() =
        runBlocking {
            assumeTrue(
                "Set RED_CODE_ANDROID_E2EE_LIVE=1 with coordination settings",
                System.getenv("RED_CODE_ANDROID_E2EE_LIVE") == "1",
            )
            withTimeout(90.seconds) { exchangeWithH5() }
        }

    @Test
    fun exchangesCiphertextBidirectionallyWithIOS() =
        runBlocking {
            assumeTrue(
                "Set RED_CODE_ANDROID_E2EE_LIVE=1 with coordination settings",
                System.getenv("RED_CODE_ANDROID_E2EE_LIVE") == "1",
            )
            withTimeout(90.seconds) { exchangeWithIOS() }
        }

    private suspend fun exchangeWithH5() {
        val coordination = CoordinationClient.fromEnvironment()
        val fixture = coordination.fixture()
        val environment =
            RedCodeEnvironment(
                apiBaseUrl = fixture.apiBaseUrl,
                wsUrl = fixture.apiBaseUrl.replaceFirst("http", "ws") + "/ws",
            )
        val apiClient = APIClient(environment, LiveDiagnosticTransport())
        val mlsApi = HttpE2eeMlsApi(apiClient)
        val core = E2eeCommandClient()
        val storage =
            E2eeSecureStateStore(
                InMemoryE2eeStateCipher(),
                InMemoryE2eeStateBlobStore(),
                core::validateProtocolState,
            )
        val lifecycle = E2eeDeviceLifecycle(storage, mlsApi, core)
        val coordinator =
            E2eeDirectMessageCoordinator(
                storage,
                lifecycle,
                mlsApi,
                E2eeCommandSessionCore(core),
            )
        val chat = HttpChatRemoteDataSource(apiClient)

        val profile = lifecycle.ensureReady(fixture.accountId, "Android E2EE live", fixture.token)
        assertEquals("active", profile.deviceStatus)

        val androidMessageId =
            coordinator.sendText(
                fixture.accountId,
                "Android E2EE live",
                fixture.roomId,
                fixture.peerUserId,
                fixture.androidMarker,
                fixture.token,
            )
        coordination.publish("android-sent", mapOf("message_id" to androidMessageId))

        val h5MessageId = coordination.waitFor("h5-sent").getValue("message_id")
        val encrypted =
            chat.loadMessages(fixture.roomId, fixture.token, limit = 50)
                .first { it.id == h5MessageId }
        assertFalse(encrypted.encryptedContent.isNullOrBlank())
        val decrypted =
            coordinator.decryptIncoming(
                fixture.accountId,
                "Android E2EE live",
                E2eeIncomingMessage(
                    h5MessageId,
                    fixture.roomId,
                    Base64.getDecoder().decode(encrypted.encryptedContent),
                    source = E2eeMessageSource.History,
                ),
                fixture.token,
            )
        assertEquals(fixture.h5Marker, decrypted.text)
        coordination.publish("android-received", mapOf("message_id" to h5MessageId))
    }

    private suspend fun exchangeWithIOS() {
        val coordination = CoordinationClient.fromEnvironment()
        val fixture = coordination.fixture()
        val client = LiveE2eeClient(fixture)
        val profile = client.lifecycle.ensureReady(fixture.accountId, "Android E2EE live", fixture.token)
        assertEquals("active", profile.deviceStatus)
        coordination.waitFor("ios-native-ready")

        val androidMessageId =
            client.coordinator.sendText(
                fixture.accountId,
                "Android E2EE live",
                fixture.roomId,
                fixture.peerUserId,
                fixture.androidMarker,
                fixture.token,
            )
        coordination.publish("android-to-ios-sent", mapOf("message_id" to androidMessageId))

        val iosMessageId = coordination.waitFor("ios-to-android-sent").getValue("message_id")
        val encrypted =
            client.chat.loadMessages(fixture.roomId, fixture.token, limit = 50)
                .first { it.id == iosMessageId }
        val ciphertext = Base64.getDecoder().decode(requireNotNull(encrypted.encryptedContent))
        val decrypted =
            client.coordinator.decryptIncoming(
                fixture.accountId,
                "Android E2EE live",
                E2eeIncomingMessage(
                    iosMessageId,
                    fixture.roomId,
                    ciphertext,
                    source = E2eeMessageSource.History,
                ),
                fixture.token,
            )
        assertEquals(fixture.h5Marker, decrypted.text)
        coordination.publish("android-first-received", mapOf("message_id" to iosMessageId))

        val restarted = client.restartCoordinator()
        val duplicate =
            runCatching {
                restarted.decryptIncoming(
                    fixture.accountId,
                    "Android E2EE live",
                    E2eeIncomingMessage(
                        iosMessageId,
                        fixture.roomId,
                        ciphertext,
                        source = E2eeMessageSource.WebSocket,
                    ),
                    fixture.token,
                )
            }.exceptionOrNull()
        assertTrue(duplicate is E2eeDirectMessageException)

        val tamperedCiphertext = ciphertext.copyOf().also { bytes ->
            bytes[bytes.lastIndex] = bytes.last().toInt().xor(0x01).toByte()
        }
        val corrupted =
            runCatching {
                restarted.decryptIncoming(
                    fixture.accountId,
                    "Android E2EE live",
                    E2eeIncomingMessage(
                        "$iosMessageId-corrupted",
                        fixture.roomId,
                        tamperedCiphertext,
                        source = E2eeMessageSource.History,
                    ),
                    fixture.token,
                )
            }.exceptionOrNull()
        assertTrue(corrupted is E2eeDirectMessageException)
        coordination.publish("android-restart-ready", emptyMap())

        val afterRestartMessageId = coordination.waitFor("ios-after-restart-sent").getValue("message_id")
        val afterRestartEncrypted =
            client.chat.loadMessages(fixture.roomId, fixture.token, limit = 50)
                .first { it.id == afterRestartMessageId }
        val afterRestartDecrypted =
            restarted.decryptIncoming(
                fixture.accountId,
                "Android E2EE live",
                E2eeIncomingMessage(
                    afterRestartMessageId,
                    fixture.roomId,
                    Base64.getDecoder().decode(requireNotNull(afterRestartEncrypted.encryptedContent)),
                    source = E2eeMessageSource.History,
                ),
                fixture.token,
            )
        assertEquals(fixture.iosRestartMarker, afterRestartDecrypted.text)
        coordination.publish("android-native-received", mapOf("message_id" to afterRestartMessageId))
    }
}

private class LiveE2eeClient(fixture: CoordinationFixture) {
    private val environment =
        RedCodeEnvironment(
            apiBaseUrl = fixture.apiBaseUrl,
            wsUrl = fixture.apiBaseUrl.replaceFirst("http", "ws") + "/ws",
        )
    private val apiClient = APIClient(environment, LiveDiagnosticTransport())
    private val mlsApi = HttpE2eeMlsApi(apiClient)
    private val core = E2eeCommandClient()
    private val storage =
        E2eeSecureStateStore(
            InMemoryE2eeStateCipher(),
            InMemoryE2eeStateBlobStore(),
            core::validateProtocolState,
        )
    val lifecycle = E2eeDeviceLifecycle(storage, mlsApi, core)
    val coordinator = E2eeDirectMessageCoordinator(storage, lifecycle, mlsApi, E2eeCommandSessionCore(core))
    val chat = HttpChatRemoteDataSource(apiClient)

    fun restartCoordinator(): E2eeDirectMessageCoordinator {
        val restartedLifecycle = E2eeDeviceLifecycle(storage, mlsApi, core)
        return E2eeDirectMessageCoordinator(
            storage,
            restartedLifecycle,
            mlsApi,
            E2eeCommandSessionCore(core),
        )
    }
}

@Serializable
private data class CoordinationFixture(
    val token: String,
    val account_id: String,
    val peer_user_id: String,
    val room_id: String,
    val android_marker: String,
    val h5_marker: String,
    val ios_restart_marker: String = "",
    val api_base_url: String,
) {
    val accountId get() = account_id
    val peerUserId get() = peer_user_id
    val roomId get() = room_id
    val androidMarker get() = android_marker
    val h5Marker get() = h5_marker
    val iosRestartMarker get() = ios_restart_marker
    val apiBaseUrl get() = api_base_url
}

private class CoordinationClient(
    private val baseUrl: String,
    private val secret: String,
) {
    private val json = Json { ignoreUnknownKeys = true }

    fun fixture(): CoordinationFixture =
        json.decodeFromString(request("fixture").body)

    fun publish(step: String, payload: Map<String, String>) {
        val body = json.encodeToString(payload)
        val response = request(step, body)
        check(response.statusCode in 200..299) { "Coordination POST $step failed: ${response.statusCode}" }
    }

    suspend fun waitFor(step: String): Map<String, String> {
        repeat(150) {
            val response = request(step)
            if (response.statusCode == 200) {
                return json.decodeFromString(response.body)
            }
            check(response.statusCode == 204) { "Coordination GET $step failed: ${response.statusCode}" }
            delay(200)
        }
        error("Coordination timeout: $step")
    }

    private fun request(path: String, body: String? = null): CoordinationResponse {
        val connection = URL("$baseUrl/$path").openConnection() as HttpURLConnection
        return try {
            connection.connectTimeout = 5_000
            connection.readTimeout = 10_000
            connection.requestMethod = if (body == null) "GET" else "POST"
            connection.setRequestProperty("Authorization", "Bearer $secret")
            if (body != null) {
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/json")
                connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            }
            val statusCode = connection.responseCode
            val stream = if (statusCode >= 400) connection.errorStream else connection.inputStream
            CoordinationResponse(statusCode, stream?.bufferedReader()?.use { it.readText() }.orEmpty())
        } finally {
            connection.disconnect()
        }
    }

    companion object {
        fun fromEnvironment(): CoordinationClient {
            val url = requireNotNull(System.getenv("E2EE_COORDINATION_URL"))
            val secret = requireNotNull(System.getenv("E2EE_COORDINATION_SECRET"))
            return CoordinationClient(url, secret)
        }
    }
}

private data class CoordinationResponse(val statusCode: Int, val body: String)

private class LiveDiagnosticTransport(
    private val delegate: HttpTransport = JavaNetHttpTransport(),
) : HttpTransport {
    override suspend fun execute(request: HttpRequest): HttpResponse {
        val response = delegate.execute(request)
        if (response.statusCode !in 200..299) {
            throw NetworkFailure(
                response.statusCode,
                "${request.method} ${request.url} failed: ${response.body}",
            )
        }
        return response
    }
}
