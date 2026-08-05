package com.redcode.im.androidapp.e2ee

import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.data.chat.BackendChatMessage
import java.util.Base64
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class E2eeIncomingMessageException(message: String, cause: Throwable? = null) : Exception(message, cause)

interface IncomingChatMessageResolver {
    suspend fun resolve(
        message: BackendChatMessage,
        source: E2eeMessageSource,
        cachedMessage: ChatMessage? = null,
    ): ChatMessage

    suspend fun rememberResolved(message: ChatMessage) = Unit
}

object PlaintextIncomingMessageResolver : IncomingChatMessageResolver {
    override suspend fun resolve(
        message: BackendChatMessage,
        source: E2eeMessageSource,
        cachedMessage: ChatMessage?,
    ): ChatMessage = message.toDomain()
}

class E2eeIncomingMessageResolver(
    private val session: StateFlow<AuthSession?>,
    private val e2eeStatus: StateFlow<E2eeSessionStatus>,
    private val decryptor: E2eeIncomingDecryptor,
    private val deviceLabel: String,
) : IncomingChatMessageResolver {
    private val mutex = Mutex()
    private val resolvedMessages = LinkedHashMap<String, ChatMessage>()

    override suspend fun resolve(
        message: BackendChatMessage,
        source: E2eeMessageSource,
        cachedMessage: ChatMessage?,
    ): ChatMessage = mutex.withLock {
        if (message.isDeleted) return@withLock message.toDomain()
        val encryptedContent = message.encryptedContent
        val metadata = message.encryptionMetadata
        if (encryptedContent == null && metadata == null) return@withLock message.toDomain()
        if (encryptedContent.isNullOrBlank() || metadata == null) {
            throw E2eeIncomingMessageException("E2EE 消息密文与 metadata 不完整")
        }
        if (
            metadata.protocol != "mls" ||
            metadata.version != 1 ||
            metadata.epoch <= 0 ||
            metadata.senderDeviceId.isBlank() ||
            metadata.contentType != "application"
        ) {
            throw E2eeIncomingMessageException("E2EE 消息 metadata 无效")
        }
        val activeSession = session.value ?: throw E2eeIncomingMessageException("E2EE 消息解密需要登录态")
        when (val status = e2eeStatus.value) {
            E2eeSessionStatus.Plaintext, is E2eeSessionStatus.Ready -> Unit
            is E2eeSessionStatus.Blocked -> throw E2eeIncomingMessageException(status.message)
            E2eeSessionStatus.SignedOut -> throw E2eeIncomingMessageException("E2EE 会话未登录")
        }
        if (cachedMessage?.id == message.id) {
            val resolved =
                message.toDomain().copy(
                    text = cachedMessage.text,
                    parts = cachedMessage.parts,
                )
            remember(activeSession.user.id, resolved)
            return@withLock resolved
        }
        val cacheKey = cacheKey(activeSession.user.id, message.id)
        resolvedMessages[cacheKey]?.let { cached ->
            return@withLock message.toDomain().copy(text = cached.text, parts = cached.parts)
        }
        val ciphertext =
            try {
                Base64.getDecoder().decode(encryptedContent)
            } catch (error: IllegalArgumentException) {
                throw E2eeIncomingMessageException("E2EE 消息密文 Base64 无效", error)
            }
        if (ciphertext.isEmpty()) throw E2eeIncomingMessageException("E2EE 消息密文不能为空")
        val decrypted =
            try {
                decryptor.decryptIncoming(
                    accountId = activeSession.user.id,
                    deviceLabel = deviceLabel,
                    input = E2eeIncomingMessage(message.id, message.roomId, ciphertext, source = source),
                    token = activeSession.tokens.accessToken,
                )
            } catch (error: E2eeIncomingMessageException) {
                throw error
            } catch (error: Exception) {
                throw E2eeIncomingMessageException("E2EE 消息解密失败", error)
            }
        if (
            decrypted.messageId != message.id ||
            decrypted.roomId != message.roomId ||
            decrypted.epoch != metadata.epoch ||
            !decrypted.encrypted
        ) {
            throw E2eeIncomingMessageException("E2EE 解密结果与消息不匹配")
        }
        val resolved = message.toDomain().copy(text = decrypted.text)
        remember(activeSession.user.id, resolved)
        resolved
    }

    override suspend fun rememberResolved(message: ChatMessage) = mutex.withLock {
        val accountId = session.value?.user?.id ?: return@withLock
        remember(accountId, message)
    }

    private fun remember(accountId: String, message: ChatMessage) {
        resolvedMessages[cacheKey(accountId, message.id)] = message
        while (resolvedMessages.size > MAX_RESOLVED_MESSAGES) {
            resolvedMessages.remove(resolvedMessages.keys.first())
        }
    }

    private fun cacheKey(accountId: String, messageId: String) = "$accountId:$messageId"

    private companion object {
        const val MAX_RESOLVED_MESSAGES = 2_000
    }
}
