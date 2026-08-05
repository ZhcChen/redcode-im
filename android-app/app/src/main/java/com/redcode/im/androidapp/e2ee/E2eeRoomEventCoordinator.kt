package com.redcode.im.androidapp.e2ee

import com.redcode.im.androidapp.core.model.AuthSession
import kotlinx.coroutines.flow.StateFlow

fun interface E2eeRoomEventHandling {
    suspend fun reconcile(roomId: String)
}

object PlaintextE2eeRoomEventHandler : E2eeRoomEventHandling {
    override suspend fun reconcile(roomId: String) = Unit
}

class E2eeRoomEventCoordinator(
    private val session: StateFlow<AuthSession?>,
    private val status: StateFlow<E2eeSessionStatus>,
    private val coordinator: E2eeGroupReconciling,
) : E2eeRoomEventHandling {
    override suspend fun reconcile(roomId: String) {
        require(roomId.isNotBlank()) { "E2EE 房间标识不能为空" }
        when (val current = status.value) {
            E2eeSessionStatus.Plaintext -> Unit
            E2eeSessionStatus.SignedOut -> throw E2eeDirectMessageException("E2EE 会话未登录")
            is E2eeSessionStatus.Blocked -> throw E2eeDirectMessageException(current.message)
            is E2eeSessionStatus.Ready -> {
                val authenticated = session.value
                    ?: throw E2eeDirectMessageException("E2EE 认证会话缺失")
                if (authenticated.user.id != current.accountId) {
                    throw E2eeDirectMessageException("E2EE 账号与认证会话不匹配")
                }
                coordinator.reconcileGroup(
                    accountId = current.accountId,
                    roomId = roomId,
                    token = authenticated.tokens.accessToken,
                )
            }
        }
    }
}
