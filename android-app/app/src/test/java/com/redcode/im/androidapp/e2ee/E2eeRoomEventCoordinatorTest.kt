package com.redcode.im.androidapp.e2ee

import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.AuthUser
import com.redcode.im.androidapp.core.model.TokenPair
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class E2eeRoomEventCoordinatorTest {
    @Test
    fun plaintextRuntimeDoesNotMutateMls() = runTest {
        val reconciler = RecordingGroupReconciler()
        val coordinator = coordinator(E2eeSessionStatus.Plaintext, reconciler)

        coordinator.reconcile("room-1")

        assertEquals(emptyList<String>(), reconciler.calls)
    }

    @Test
    fun readyRuntimeReconcilesWithAuthenticatedAccountAndToken() = runTest {
        val reconciler = RecordingGroupReconciler()
        val coordinator = coordinator(
            E2eeSessionStatus.Ready(accountId = "account-a", deviceId = "device-a"),
            reconciler,
        )

        coordinator.reconcile("room-1")

        assertEquals(listOf("account-a:room-1:access-token"), reconciler.calls)
    }

    @Test
    fun accountMismatchFailsClosed() {
        val reconciler = RecordingGroupReconciler()
        val session = MutableStateFlow(session(accountId = "account-b"))
        val status = MutableStateFlow<E2eeSessionStatus>(
            E2eeSessionStatus.Ready(accountId = "account-a", deviceId = "device-a"),
        )
        val coordinator = E2eeRoomEventCoordinator(session, status, reconciler)

        assertThrows(E2eeDirectMessageException::class.java) {
            runTest { coordinator.reconcile("room-1") }
        }
        assertEquals(emptyList<String>(), reconciler.calls)
    }

    private fun coordinator(status: E2eeSessionStatus, reconciler: RecordingGroupReconciler) =
        E2eeRoomEventCoordinator(
            session = MutableStateFlow(session()),
            status = MutableStateFlow(status),
            coordinator = reconciler,
        )

    private fun session(accountId: String = "account-a") =
        AuthSession(
            user = AuthUser(accountId, "alice", "Alice"),
            tokens = TokenPair("access-token", "refresh-token"),
        )
}

private class RecordingGroupReconciler : E2eeGroupReconciling {
    val calls = mutableListOf<String>()

    override suspend fun reconcileGroup(accountId: String, roomId: String, token: String) {
        calls += "$accountId:$roomId:$token"
    }
}
