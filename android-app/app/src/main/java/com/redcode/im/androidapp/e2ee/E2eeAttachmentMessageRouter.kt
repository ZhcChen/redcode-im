package com.redcode.im.androidapp.e2ee

import com.redcode.im.androidapp.core.model.AuthSession
import java.util.UUID
import kotlinx.coroutines.flow.StateFlow

data class E2eePreparedAttachment(
    val ciphertext: ByteArray,
    val part: E2eeAttachmentPart,
)

interface E2eeAttachmentCoordinator {
    suspend fun sendAttachment(
        accountId: String,
        deviceLabel: String,
        roomId: String,
        peerUserId: String?,
        parts: List<E2eeAttachmentPart>,
        text: String?,
        token: String,
    ): String

    suspend fun retryPendingSend(accountId: String, token: String): String

    suspend fun hasPendingSend(accountId: String): Boolean

    suspend fun findAttachmentPart(accountId: String, messageId: String, objectKey: String): E2eeAttachmentPart?
}

interface AttachmentMessageRouter {
    suspend fun prepareUpload(
        roomId: String,
        objectKey: String,
        name: String,
        mimeType: String,
        size: Long,
        partPosition: Int,
        plaintext: ByteArray,
    ): E2eePreparedAttachment?

    suspend fun send(
        roomId: String,
        peerUserId: String?,
        parts: List<E2eeAttachmentPart>,
        text: String?,
        retry: Boolean,
        quotedMessageId: String? = null,
    ): String?

    suspend fun decryptDownload(
        roomId: String,
        messageId: String,
        objectKey: String,
        ciphertext: ByteArray,
    ): ByteArray?
}

object PlaintextAttachmentMessageRouter : AttachmentMessageRouter {
    override suspend fun prepareUpload(
        roomId: String,
        objectKey: String,
        name: String,
        mimeType: String,
        size: Long,
        partPosition: Int,
        plaintext: ByteArray,
    ): E2eePreparedAttachment? = null

    override suspend fun send(
        roomId: String,
        peerUserId: String?,
        parts: List<E2eeAttachmentPart>,
        text: String?,
        retry: Boolean,
        quotedMessageId: String?,
    ): String? = null

    override suspend fun decryptDownload(
        roomId: String,
        messageId: String,
        objectKey: String,
        ciphertext: ByteArray,
    ): ByteArray? = null
}

class E2eeAttachmentMessageRouter(
    private val session: StateFlow<AuthSession?>,
    private val e2eeStatus: StateFlow<E2eeSessionStatus>,
    private val coordinator: E2eeAttachmentCoordinator,
    private val deviceLabel: String,
    private val crypto: E2eeAttachmentCrypto = E2eeAttachmentCrypto(),
    private val newPartKey: () -> String = { UUID.randomUUID().toString() },
) : AttachmentMessageRouter {
    override suspend fun prepareUpload(
        roomId: String,
        objectKey: String,
        name: String,
        mimeType: String,
        size: Long,
        partPosition: Int,
        plaintext: ByteArray,
    ): E2eePreparedAttachment? {
        requireActiveE2eeSession() ?: return null
        val partKey = newPartKey()
        val aad = crypto.attachmentAad(roomId, partKey, partPosition, objectKey)
        val encrypted = crypto.encrypt(plaintext, aad)
        return E2eePreparedAttachment(
            ciphertext = encrypted.ciphertext,
            part =
                E2eeAttachmentPart(
                    partKey = partKey,
                    objectKey = objectKey,
                    name = name,
                    mimeType = mimeType,
                    size = size,
                    partPosition = partPosition,
                    nonce = encrypted.nonce,
                    dek = encrypted.dek,
                ),
        )
    }

    override suspend fun send(
        roomId: String,
        peerUserId: String?,
        parts: List<E2eeAttachmentPart>,
        text: String?,
        retry: Boolean,
        quotedMessageId: String?,
    ): String? {
        val active = requireActiveE2eeSession() ?: return null
        if (quotedMessageId != null) {
            throw E2eeOutgoingMessageException("E2EE 引用消息将在后续版本支持")
        }
        return if (retry && coordinator.hasPendingSend(active.user.id)) {
            coordinator.retryPendingSend(active.user.id, active.tokens.accessToken)
        } else {
            if (retry) throw E2eeOutgoingMessageException("E2EE 附件重试需要重新选择原文件")
            coordinator.sendAttachment(
                active.user.id,
                deviceLabel,
                roomId,
                peerUserId,
                parts,
                text,
                active.tokens.accessToken,
            )
        }
    }

    override suspend fun decryptDownload(
        roomId: String,
        messageId: String,
        objectKey: String,
        ciphertext: ByteArray,
    ): ByteArray? {
        val status = e2eeStatus.value
        val active = requireReadableSession(status)
        val part = coordinator.findAttachmentPart(active.user.id, messageId, objectKey)
        if (part == null) {
            if (status is E2eeSessionStatus.Ready) {
                throw E2eeDirectMessageException("E2EE 附件密钥材料缺失")
            }
            return null
        }
        val aad = crypto.attachmentAad(roomId, part.partKey, part.partPosition, part.objectKey)
        return crypto.decrypt(ciphertext, aad, part.nonce, part.dek)
    }

    private fun requireActiveE2eeSession(): AuthSession? {
        val status = e2eeStatus.value
        val active = requireReadableSession(status)
        return when (status) {
            E2eeSessionStatus.Plaintext -> null
            is E2eeSessionStatus.Ready -> active
            else -> error("unreachable")
        }
    }

    private fun requireReadableSession(status: E2eeSessionStatus = e2eeStatus.value): AuthSession {
        val active = session.value ?: throw E2eeOutgoingMessageException("E2EE 附件操作需要登录态")
        when (status) {
            E2eeSessionStatus.Plaintext -> Unit
            is E2eeSessionStatus.Ready -> {
                if (status.accountId != active.user.id) {
                    throw E2eeOutgoingMessageException("E2EE 会话账号与登录态不一致")
                }
            }
            is E2eeSessionStatus.Blocked -> throw E2eeOutgoingMessageException(status.message)
            E2eeSessionStatus.SignedOut -> throw E2eeOutgoingMessageException("E2EE 会话未登录")
        }
        return active
    }
}
