package com.redcode.im.androidapp.e2ee

import com.redcode.im.androidapp.core.model.AuthSession
import kotlinx.coroutines.flow.StateFlow

class E2eeOutgoingMessageException(message: String) : Exception(message)

interface OutgoingTextMessageRouter {
    /** 返回 null 表示当前 runtime 应继续使用既有 plaintext API。 */
    suspend fun send(
        roomId: String,
        peerUserId: String?,
        text: String,
        retry: Boolean,
        quotedMessageId: String? = null,
    ): String?
}

object PlaintextOutgoingTextMessageRouter : OutgoingTextMessageRouter {
    override suspend fun send(
        roomId: String,
        peerUserId: String?,
        text: String,
        retry: Boolean,
        quotedMessageId: String?,
    ): String? = null
}

class E2eeOutgoingTextRouter(
    private val session: StateFlow<AuthSession?>,
    private val e2eeStatus: StateFlow<E2eeSessionStatus>,
    private val sender: E2eeTextSender,
    private val deviceLabel: String,
) : OutgoingTextMessageRouter {
    override suspend fun send(
        roomId: String,
        peerUserId: String?,
        text: String,
        retry: Boolean,
        quotedMessageId: String?,
    ): String? {
        when (val status = e2eeStatus.value) {
            E2eeSessionStatus.Plaintext -> return null
            E2eeSessionStatus.SignedOut -> throw E2eeOutgoingMessageException("E2EE 会话未登录")
            is E2eeSessionStatus.Blocked -> throw E2eeOutgoingMessageException(status.message)
            is E2eeSessionStatus.Ready -> {
                if (quotedMessageId != null) {
                    throw E2eeOutgoingMessageException("E2EE 引用消息将在后续版本支持")
                }
                val activeSession = session.value ?: throw E2eeOutgoingMessageException("E2EE 消息发送需要登录态")
                if (status.accountId != activeSession.user.id) {
                    throw E2eeOutgoingMessageException("E2EE 会话账号与登录态不一致")
                }
                return if (retry && sender.hasPendingSend(activeSession.user.id)) {
                    sender.retryPendingSend(activeSession.user.id, activeSession.tokens.accessToken)
                } else {
                    sender.sendText(
                        accountId = activeSession.user.id,
                        deviceLabel = deviceLabel,
                        roomId = roomId,
                        peerUserId = peerUserId,
                        text = text,
                        token = activeSession.tokens.accessToken,
                    )
                }
            }
        }
    }
}
