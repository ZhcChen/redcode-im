package com.redcode.im.androidapp.e2ee

import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class E2eeDirectMessageCoordinatorTest {
    private lateinit var storage: E2eeSecureStateStore
    private lateinit var api: FakeApi
    private lateinit var core: FakeCore
    private lateinit var coordinator: E2eeDirectMessageCoordinator

    @Before
    fun setUp() {
        storage = E2eeSecureStateStore(InMemoryE2eeStateCipher(), InMemoryE2eeStateBlobStore()) { true }
        storage.write("account-a", byteArrayOf(1))
        storage.writeProfile(
            "account-a",
            E2eeDeviceProfile(
                deviceId = "device-a",
                deviceLabel = "Android",
                registered = true,
                keyPackagePublished = true,
                lastCommitMessageIds = mapOf("room-1" to "commit-1"),
            ),
        )
        api = FakeApi()
        core = FakeCore()
        coordinator = E2eeDirectMessageCoordinator(
            storage = storage,
            lifecycle = object : E2eeDirectDeviceLifecycle {
                override suspend fun ensureReady(accountId: String, deviceLabel: String, token: String) =
                    storage.readProfile(accountId)!!
            },
            api = api,
            core = core,
            newId = { "id-${api.ids.incrementAndGet()}" },
        )
    }

    @Test
    fun websocketAndHistoryUseSameDecryptEntryAndRejectDuplicateId() = runTest {
        val encrypted = coordinator.decryptIncoming(
            "account-a", "Android",
            E2eeIncomingMessage("m-1", "room-1", byteArrayOf(9), source = E2eeMessageSource.WebSocket),
            "token",
        )
        val legacy = coordinator.decryptIncoming(
            "account-a", "Android",
            E2eeIncomingMessage("m-2", "room-1", null, "legacy", E2eeMessageSource.History),
            "token",
        )

        assertEquals("secret", encrypted.text)
        assertTrue(encrypted.encrypted)
        assertEquals("legacy", legacy.text)
        assertFalse(legacy.encrypted)
        val duplicate = runCatching {
            coordinator.decryptIncoming(
                "account-a", "Android",
                E2eeIncomingMessage("m-1", "room-1", byteArrayOf(9), source = E2eeMessageSource.History),
                "token",
            )
        }.exceptionOrNull()
        assertTrue(duplicate is E2eeDirectMessageException)
        assertEquals(1, core.decryptCalls)
    }

    @Test
    fun damagedCiphertextFailsClosedWithoutAdvancingStateOrDedupe() = runTest {
        core.failDecrypt = true
        val failure = runCatching {
            coordinator.decryptIncoming(
                "account-a", "Android",
                E2eeIncomingMessage("m-bad", "room-1", byteArrayOf(0), source = E2eeMessageSource.WebSocket),
                "token",
            )
        }.exceptionOrNull()

        assertTrue(failure is E2eeDirectMessageException)
        assertTrue(storage.read("account-a")!!.contentEquals(byteArrayOf(1)))
        core.failDecrypt = false
        assertEquals(
            "secret",
            coordinator.decryptIncoming(
                "account-a", "Android",
                E2eeIncomingMessage("m-bad", "room-1", byteArrayOf(9), source = E2eeMessageSource.History),
                "token",
            ).text,
        )
    }

    @Test
    fun identityChangeBlocksSendAndKeepsPlaintextOutOfApi() = runTest {
        val first = coordinator.sendText("account-a", "Android", "room-1", "account-b", " first secret ", "token")
        assertEquals("server-message", first)
        assertFalse(api.lastCiphertext!!.toString(Charsets.UTF_8).contains("first secret"))

        api.identityFingerprint = ByteArray(32) { 7 }
        val failure = runCatching {
            coordinator.sendText("account-a", "Android", "room-1", "account-b", "second secret", "token")
        }.exceptionOrNull()
        assertTrue(failure is E2eeDirectMessageException)
        assertEquals(1, api.sendCalls)
    }

    @Test
    fun failedSendCanResumeAfterCoordinatorRestartWithSameIdempotencyKey() = runTest {
        api.failSend = true
        val failure = runCatching {
            coordinator.sendText("account-a", "Android", "room-1", "account-b", "survives restart", "token")
        }.exceptionOrNull()
        assertTrue(failure is IllegalStateException)
        val firstKey = api.lastIdempotencyKey
        assertTrue(storage.read("account-a")!!.contentEquals(byteArrayOf(1)))

        api.failSend = false
        val restarted = E2eeDirectMessageCoordinator(
            storage,
            object : E2eeDirectDeviceLifecycle {
                override suspend fun ensureReady(accountId: String, deviceLabel: String, token: String) = storage.readProfile(accountId)!!
            },
            api,
            core,
        )
        assertEquals("server-message", restarted.retryPendingSend("account-a", "token"))
        assertEquals(firstKey, api.lastIdempotencyKey)
        assertTrue(storage.read("account-a")!!.contentEquals(byteArrayOf(2)))
    }

    private class FakeCore : E2eeDirectSessionCore {
        var decryptCalls = 0
        var failDecrypt = false
        override fun createGroup(state: ByteArray, roomId: String) = result(byteArrayOf(2))
        override fun addMember(state: ByteArray, roomId: String, keyPackage: ByteArray) = result(byteArrayOf(3), byteArrayOf(4), byteArrayOf(5), epoch(1))
        override fun joinGroup(state: ByteArray, welcome: ByteArray) = result(byteArrayOf(3), epoch(1))
        override fun encrypt(state: ByteArray, roomId: String, plaintext: ByteArray) = result(byteArrayOf(2), byteArrayOf(99, 100), epoch(1))
        override fun decrypt(state: ByteArray, roomId: String, ciphertext: ByteArray): E2eeCommandResult {
            decryptCalls++
            if (failDecrypt) throw E2eeCommandException("damaged")
            return result(byteArrayOf(2), "{\"version\":1,\"type\":\"text\",\"text\":\"secret\"}".toByteArray(), epoch(1))
        }
        override fun processCommit(state: ByteArray, roomId: String, commit: ByteArray) = result(byteArrayOf(2), epoch(1))
        private fun result(vararg fields: ByteArray) = E2eeCommandResult(fields.toList())
        private fun epoch(value: Long) = ByteArray(8) { index -> (value ushr ((7 - index) * 8)).toByte() }
    }

    private class FakeApi : E2eeMlsApi {
        val ids = AtomicInteger()
        var identityFingerprint = ByteArray(32) { 1 }
        var sendCalls = 0
        var lastCiphertext: ByteArray? = null
        var lastIdempotencyKey: String? = null
        var failSend = false
        override suspend fun fetchRootIdentity(userId: String, token: String) = ByteArray(32)
        override suspend fun registerDevice(deviceId: String, deviceLabel: String, material: E2eeRegistrationMaterial, token: String) = "active"
        override suspend fun publishKeyPackages(deviceId: String, keyPackages: List<ByteArray>, token: String) = keyPackages.size
        override suspend fun fetchKeyPackageInventory(deviceId: String, token: String) = E2eeKeyPackageInventory(20, 100)
        override suspend fun listDevices(token: String) = listOf(E2eeDeviceInfo("device-a", status = "active"))
        override suspend fun fetchIdentity(userId: String, token: String) = E2eeRootIdentity(userId, ByteArray(32), identityFingerprint, 1)
        override suspend fun getRoomEpoch(roomId: String, token: String) = E2eeRoomEpoch(1, 1, "active")
        override suspend fun listControlMessages(roomId: String, deviceId: String, afterSequence: Long, token: String) = emptyList<E2eeControlMessage>()
        override suspend fun sendEncryptedMessage(message: E2eeEncryptedMessageRequest, token: String): String {
            sendCalls++
            lastCiphertext = message.ciphertext
            lastIdempotencyKey = message.idempotencyKey
            if (failSend) error("network")
            return "server-message"
        }
    }
}
