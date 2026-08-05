package com.redcode.im.androidapp.e2ee

import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.AuthUser
import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.MessageStatus
import com.redcode.im.androidapp.core.model.TokenPair
import com.redcode.im.androidapp.data.chat.BackendChatMessage
import com.redcode.im.androidapp.data.chat.ChatEncryptionMetadata
import java.time.Instant
import java.util.Base64
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class IncomingChatMessageResolverTest {
    private val session =
        MutableStateFlow<AuthSession?>(
            AuthSession(
                user = AuthUser(id = "account-a", accountName = "alice", displayName = "Alice"),
                tokens = TokenPair(accessToken = "token", refreshToken = "refresh"),
            ),
        )
    private val status = MutableStateFlow<E2eeSessionStatus>(E2eeSessionStatus.Ready("account-a", "device-a"))
    private val decryptor = RecordingDecryptor()
    private val resolver = E2eeIncomingMessageResolver(session, status, decryptor, "Android")

    @Test
    fun plaintextMessageMapsWithoutCallingDecryptor() = runTest {
        val resolved = resolver.resolve(message(content = "plain"), E2eeMessageSource.History)

        assertEquals("plain", resolved.text)
        assertEquals(0, decryptor.calls)
    }

    @Test
    fun validMlsMessageDecryptsAndDuplicateUsesResolvedCache() = runTest {
        val encrypted = encryptedMessage()

        val history = resolver.resolve(encrypted, E2eeMessageSource.History)
        val websocket = resolver.resolve(encrypted, E2eeMessageSource.WebSocket)

        assertEquals("secret", history.text)
        assertEquals(history, websocket)
        assertEquals(1, decryptor.calls)
        assertTrue(decryptor.lastCiphertext!!.contentEquals(byteArrayOf(9)))
    }

    @Test
    fun plaintextRuntimeCanLazilyDecryptExistingEncryptedHistory() = runTest {
        status.value = E2eeSessionStatus.Plaintext

        val resolved = resolver.resolve(encryptedMessage(), E2eeMessageSource.History)

        assertEquals("secret", resolved.text)
        assertEquals(1, decryptor.calls)
    }

    @Test
    fun blockedRuntimeRejectsEncryptedMessage() = runTest {
        status.value = E2eeSessionStatus.Blocked("runtime unavailable")

        val error = runCatching {
            resolver.resolve(encryptedMessage(), E2eeMessageSource.WebSocket)
        }.exceptionOrNull()

        assertTrue(error is E2eeIncomingMessageException)
        assertEquals(0, decryptor.calls)
    }

    @Test
    fun incompleteOrInvalidMetadataFailsClosed() = runTest {
        val incomplete = message(encryptedContent = Base64.getEncoder().encodeToString(byteArrayOf(9)))
        val invalid = encryptedMessage(metadata = metadata().copy(contentType = "attachment"))

        assertTrue(
            runCatching { resolver.resolve(incomplete, E2eeMessageSource.History) }.exceptionOrNull()
                is E2eeIncomingMessageException,
        )
        assertTrue(
            runCatching { resolver.resolve(invalid, E2eeMessageSource.History) }.exceptionOrNull()
                is E2eeIncomingMessageException,
        )
        assertEquals(0, decryptor.calls)
    }

    @Test
    fun cachedOutgoingMessageAvoidsDecryptingOwnCiphertext() = runTest {
        val cached =
            ChatMessage(
                id = "m-1",
                roomId = "room-1",
                senderId = "account-a",
                senderName = "alice",
                text = "sent locally",
                status = MessageStatus.Sent,
                createdAt = Instant.parse("2026-08-05T00:00:00Z"),
            )

        val resolved =
            resolver.resolve(
                encryptedMessage(senderId = "account-a").copy(isPinned = true, pinnedBy = "account-a"),
                E2eeMessageSource.History,
                cached,
            )

        assertEquals(cached.id, resolved.id)
        assertEquals(cached.text, resolved.text)
        assertTrue(resolved.isPinned)
        assertEquals("account-a", resolved.pinnedBy)
        assertEquals(0, decryptor.calls)
    }

    @Test
    fun rememberedOutgoingMessageResolvesWebSocketEchoWithoutOwnDecrypt() = runTest {
        val sent =
            ChatMessage(
                id = "m-1",
                roomId = "room-1",
                senderId = "account-a",
                senderName = "alice",
                text = "sent locally",
                status = MessageStatus.Sent,
                createdAt = Instant.parse("2026-08-05T00:00:00Z"),
            )
        resolver.rememberResolved(sent)

        val resolved = resolver.resolve(encryptedMessage(senderId = "account-a"), E2eeMessageSource.WebSocket)

        assertEquals("sent locally", resolved.text)
        assertEquals(0, decryptor.calls)
    }

    private fun encryptedMessage(
        senderId: String = "account-b",
        metadata: ChatEncryptionMetadata = metadata(),
    ) = message(
        senderId = senderId,
        encryptedContent = Base64.getEncoder().encodeToString(byteArrayOf(9)),
        encryptionMetadata = metadata,
    )

    private fun message(
        senderId: String = "account-b",
        content: String = "",
        encryptedContent: String? = null,
        encryptionMetadata: ChatEncryptionMetadata? = null,
    ) = BackendChatMessage(
        id = "m-1",
        roomId = "room-1",
        senderId = senderId,
        senderUsername = "bob",
        content = content,
        createdAt = "2026-08-05T00:00:00Z",
        encryptedContent = encryptedContent,
        encryptionMetadata = encryptionMetadata,
    )

    private fun metadata() =
        ChatEncryptionMetadata(
            protocol = "mls",
            version = 1,
            epoch = 1,
            senderDeviceId = "device-b",
            contentType = "application",
            controlMessageId = "commit-1",
        )

    private class RecordingDecryptor : E2eeIncomingDecryptor {
        var calls = 0
        var lastCiphertext: ByteArray? = null

        override suspend fun decryptIncoming(
            accountId: String,
            deviceLabel: String,
            input: E2eeIncomingMessage,
            token: String,
        ): E2eeDecryptedMessage {
            calls += 1
            lastCiphertext = input.ciphertext
            return E2eeDecryptedMessage(input.messageId, input.roomId, "secret", 1, true)
        }
    }
}
