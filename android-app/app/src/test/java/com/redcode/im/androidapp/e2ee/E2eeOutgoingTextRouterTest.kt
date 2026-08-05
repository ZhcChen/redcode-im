package com.redcode.im.androidapp.e2ee

import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.AuthUser
import com.redcode.im.androidapp.core.model.TokenPair
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class E2eeOutgoingTextRouterTest {
    private val session =
        MutableStateFlow<AuthSession?>(
            AuthSession(
                AuthUser("account-a", "alice", "Alice"),
                TokenPair("token", "refresh"),
            ),
        )
    private val status = MutableStateFlow<E2eeSessionStatus>(E2eeSessionStatus.Ready("account-a", "device-a"))
    private val sender = RecordingTextSender()
    private val router = E2eeOutgoingTextRouter(session, status, sender, "Android")

    @Test
    fun readyRuntimeSendsOnlyThroughCoordinator() = runTest {
        val messageId = router.send("room-1", "account-b", " secret ", retry = false)

        assertEquals("encrypted-message", messageId)
        assertEquals(listOf("account-a:Android:room-1:account-b: secret :token"), sender.sends)
        assertEquals(0, sender.retryCalls)
    }

    @Test
    fun plaintextRuntimeReturnsNullForExistingApiPath() = runTest {
        status.value = E2eeSessionStatus.Plaintext

        assertEquals(null, router.send("room-1", "account-b", "plain", retry = false))
        assertEquals(emptyList<String>(), sender.sends)
    }

    @Test
    fun blockedOrMismatchedSessionFailsClosed() = runTest {
        status.value = E2eeSessionStatus.Blocked("device revoked")
        val blocked = runCatching { router.send("room-1", "account-b", "secret", retry = false) }.exceptionOrNull()
        status.value = E2eeSessionStatus.Ready("another-account", "device-a")
        val mismatch = runCatching { router.send("room-1", "account-b", "secret", retry = false) }.exceptionOrNull()

        assertTrue(blocked is E2eeOutgoingMessageException)
        assertTrue(mismatch is E2eeOutgoingMessageException)
        assertEquals(emptyList<String>(), sender.sends)
    }

    @Test
    fun retryUsesPersistedCoordinatorPendingMessage() = runTest {
        sender.hasPending = true
        val messageId = router.send("room-1", "account-b", "secret", retry = true)

        assertEquals("retried-message", messageId)
        assertEquals(1, sender.retryCalls)
        assertEquals(emptyList<String>(), sender.sends)
    }

    @Test
    fun retryWithoutCoordinatorPendingEncryptsMessageAsNew() = runTest {
        val messageId = router.send("room-1", "account-b", "secret", retry = true)

        assertEquals("encrypted-message", messageId)
        assertEquals(0, sender.retryCalls)
        assertEquals(listOf("account-a:Android:room-1:account-b:secret:token"), sender.sends)
    }

    @Test
    fun readyRuntimeRejectsQuoteInsteadOfDroppingIt() = runTest {
        val failure = runCatching {
            router.send("room-1", "account-b", "secret", retry = false, quotedMessageId = "m-quoted")
        }.exceptionOrNull()

        assertTrue(failure is E2eeOutgoingMessageException)
        assertEquals(emptyList<String>(), sender.sends)
    }

    private class RecordingTextSender : E2eeTextSender {
        val sends = mutableListOf<String>()
        var retryCalls = 0
        var hasPending = false

        override suspend fun sendText(
            accountId: String,
            deviceLabel: String,
            roomId: String,
            peerUserId: String?,
            text: String,
            token: String,
        ): String {
            sends += "$accountId:$deviceLabel:$roomId:$peerUserId:$text:$token"
            return "encrypted-message"
        }

        override suspend fun retryPendingSend(accountId: String, token: String): String {
            retryCalls += 1
            return "retried-message"
        }

        override suspend fun hasPendingSend(accountId: String): Boolean = hasPending
    }
}
