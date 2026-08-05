package com.redcode.im.androidapp.e2ee

import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.AuthUser
import com.redcode.im.androidapp.core.model.TokenPair
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class E2eeAttachmentMessageRouterTest {
    private val roomId = "11111111-2222-4333-8444-555555555555"
    private val partKey = "00000000-0000-4000-8000-000000000001"
    private val session =
        MutableStateFlow<AuthSession?>(
            AuthSession(
                AuthUser("account-a", "alice", "Alice"),
                TokenPair("token", "refresh"),
            ),
        )
    private val status = MutableStateFlow<E2eeSessionStatus>(E2eeSessionStatus.Ready("account-a", "device-a"))
    private val coordinator = RecordingAttachmentCoordinator()
    private val router =
        E2eeAttachmentMessageRouter(
            session,
            status,
            coordinator,
            "Android",
            newPartKey = { partKey },
        )

    @Test
    fun readyRuntimeEncryptsUploadAndDecryptsOnlyWithBoundAad() = runTest {
        val plaintext = "secret attachment".toByteArray()
        val prepared =
            router.prepareUpload(
                roomId,
                "messages/room/files/secret.bin",
                "secret.bin",
                "application/octet-stream",
                plaintext.size.toLong(),
                0,
                plaintext,
            )!!
        coordinator.storedPart = prepared.part

        assertFalse(prepared.ciphertext.contentEquals(plaintext))
        assertEquals(plaintext.size + 16, prepared.ciphertext.size)
        assertArrayEquals(
            plaintext,
            router.decryptDownload(roomId, "m-1", prepared.part.objectKey, prepared.ciphertext),
        )
        val tampered = runCatching {
            router.decryptDownload(
                "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "m-1",
                prepared.part.objectKey,
                prepared.ciphertext,
            )
        }.exceptionOrNull()
        assertTrue(tampered is E2eeDirectMessageException)
    }

    @Test
    fun readyRuntimeRejectsDownloadWhenSecureAttachmentMetadataIsMissing() = runTest {
        val failure = runCatching {
            router.decryptDownload(
                roomId,
                "m-missing",
                "messages/room/files/missing.bin",
                "ciphertext".encodeToByteArray(),
            )
        }.exceptionOrNull()

        assertTrue(failure is E2eeDirectMessageException)
    }

    @Test
    fun plaintextRuntimeLeavesExistingAttachmentPathUntouched() = runTest {
        status.value = E2eeSessionStatus.Plaintext

        assertNull(router.prepareUpload(roomId, "key", "name", "mime", 1, 0, byteArrayOf(1)))
        assertNull(router.send(roomId, null, emptyList(), null, retry = false))
    }

    @Test
    fun readyRuntimeSendsAttachmentOnlyThroughCoordinator() = runTest {
        val prepared =
            router.prepareUpload(
                roomId,
                "messages/room/images/a.png",
                "a.png",
                "image/png",
                1,
                0,
                byteArrayOf(1),
            )!!

        val id = router.send(roomId, "account-b", listOf(prepared.part), "caption", retry = false)

        assertEquals("m-encrypted", id)
        assertEquals("account-a:Android:$roomId:account-b:caption:token", coordinator.lastSend)
    }

    @Test
    fun blockedRuntimeFailsClosedBeforeCryptoOrCoordinator() = runTest {
        status.value = E2eeSessionStatus.Blocked("device revoked")

        val failure = runCatching {
            router.prepareUpload(roomId, "key", "name", "mime", 1, 0, byteArrayOf(1))
        }.exceptionOrNull()

        assertTrue(failure is E2eeOutgoingMessageException)
        assertNull(coordinator.lastSend)
    }

    @Test
    fun readyRuntimeRejectsAttachmentQuoteInsteadOfDroppingIt() = runTest {
        val failure = runCatching {
            router.send(
                roomId,
                "account-b",
                listOf(samplePart()),
                null,
                retry = false,
                quotedMessageId = "m-quoted",
            )
        }.exceptionOrNull()

        assertTrue(failure is E2eeOutgoingMessageException)
        assertNull(coordinator.lastSend)
    }

    private fun samplePart() =
        E2eeAttachmentPart(
            partKey,
            "messages/room/files/a.bin",
            "a.bin",
            "application/octet-stream",
            1,
            0,
            ByteArray(12),
            ByteArray(32),
        )

    private class RecordingAttachmentCoordinator : E2eeAttachmentCoordinator {
        var storedPart: E2eeAttachmentPart? = null
        var lastSend: String? = null

        override suspend fun sendAttachment(
            accountId: String,
            deviceLabel: String,
            roomId: String,
            peerUserId: String?,
            parts: List<E2eeAttachmentPart>,
            text: String?,
            token: String,
        ): String {
            storedPart = parts.single()
            lastSend = "$accountId:$deviceLabel:$roomId:$peerUserId:$text:$token"
            return "m-encrypted"
        }

        override suspend fun retryPendingSend(accountId: String, token: String) = "m-retried"

        override suspend fun hasPendingSend(accountId: String) = false

        override suspend fun findAttachmentPart(accountId: String, messageId: String, objectKey: String) =
            storedPart?.takeIf { it.objectKey == objectKey }
    }
}
