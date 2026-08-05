package com.redcode.im.androidapp.data.chat

import com.redcode.im.androidapp.core.model.AttachmentUploadPayload
import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatSummary
import com.redcode.im.androidapp.core.model.MessageAttachment
import com.redcode.im.androidapp.core.model.MessagePart
import com.redcode.im.androidapp.core.model.MessagePartType
import com.redcode.im.androidapp.core.model.MessageReactionSummary
import com.redcode.im.androidapp.core.model.MessageStatus
import com.redcode.im.androidapp.data.media.FileResourceCache
import com.redcode.im.androidapp.e2ee.E2eeMessageSource
import com.redcode.im.androidapp.e2ee.IncomingChatMessageResolver
import com.redcode.im.androidapp.e2ee.PlaintextIncomingMessageResolver
import com.redcode.im.androidapp.e2ee.OutgoingTextMessageRouter
import com.redcode.im.androidapp.e2ee.PlaintextOutgoingTextMessageRouter
import java.time.Instant
import java.util.UUID
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map

class RemoteChatRepository(
    private val remoteDataSource: ChatRemoteDataSource,
    private val session: StateFlow<AuthSession?>,
    private val attachmentFileCache: FileResourceCache? = null,
    incomingResolver: IncomingChatMessageResolver? = null,
    outgoingRouter: OutgoingTextMessageRouter? = null,
) : ChatRepository {
    private val incomingResolver = incomingResolver ?: PlaintextIncomingMessageResolver
    private val outgoingRouter = outgoingRouter ?: PlaintextOutgoingTextMessageRouter
    private val summaryState = MutableStateFlow<List<ChatSummary>>(emptyList())
    private val messageState = MutableStateFlow<Map<String, List<ChatMessage>>>(emptyMap())

    override val chats: Flow<List<ChatSummary>> = summaryState

    override fun messages(roomId: String): Flow<List<ChatMessage>> =
        messageState.map { it[roomId].orEmpty() }

    override suspend fun refreshChats() {
        summaryState.value =
            remoteDataSource
                .fetchChats(requireToken())
                .map { it.toDomain() }
                .sortedWith(compareByDescending<ChatSummary> { it.isPinned }.thenByDescending { it.updatedAt })
    }

    override suspend fun refreshMessages(roomId: String, limit: Int) {
        val messages =
            remoteDataSource
                .loadMessages(roomId = roomId, token = requireToken(), limit = limit)
                .map { incoming ->
                    val cached = messageState.value[roomId].orEmpty().firstOrNull { it.id == incoming.id }
                    val message = incomingResolver.resolve(incoming, E2eeMessageSource.History, cached)
                    message.withAttachmentLocalPathsFrom(messageState.value[roomId].orEmpty().firstOrNull { it.id == message.id })
                }
                .sortedBy { it.createdAt }
        messageState.value = messageState.value + (roomId to messages)
    }

    override suspend fun searchMessages(roomId: String, query: String, limit: Int): List<ChatMessage> {
        val normalized = query.trim()
        if (normalized.isBlank()) return emptyList()
        val cappedLimit = limit.coerceIn(1, 100)
        return messageState.value[roomId]
            .orEmpty()
            .asReversed()
            .filter { message ->
                !message.isDeleted &&
                    (
                        message.text.contains(normalized, ignoreCase = true) ||
                            message.senderName.contains(normalized, ignoreCase = true) ||
                            message.quotedMessage?.text?.contains(normalized, ignoreCase = true) == true ||
                            message.parts.any { part ->
                                part.text?.contains(normalized, ignoreCase = true) == true ||
                                    part.attachment?.displayName?.contains(normalized, ignoreCase = true) == true
                            }
                    )
            }
            .take(cappedLimit)
    }

    override suspend fun loadOlderMessages(roomId: String, limit: Int): Boolean {
        val currentMessages = messageState.value[roomId].orEmpty()
        val beforeId = currentMessages.firstOrNull()?.id ?: return false
        val existingIds = currentMessages.map { it.id }.toSet()
        val older =
            remoteDataSource
                .loadMessages(roomId = roomId, token = requireToken(), limit = limit, beforeId = beforeId)
                .map { incoming ->
                    val cached = currentMessages.firstOrNull { it.id == incoming.id }
                    val message = incomingResolver.resolve(incoming, E2eeMessageSource.History, cached)
                    message.withAttachmentLocalPathsFrom(currentMessages.firstOrNull { it.id == message.id })
                }
                .filterNot { it.id in existingIds }
        if (older.isEmpty()) return false
        val merged =
            (older + currentMessages)
                .distinctBy { it.id }
                .sortedBy { it.createdAt }
        messageState.value = messageState.value + (roomId to merged)
        return true
    }

    override suspend fun sendText(
        roomId: String,
        senderId: String,
        senderName: String,
        text: String,
        quotedMessageId: String?,
    ): ChatMessage {
        val normalized = text.trim()
        require(normalized.isNotBlank()) { "消息不能为空" }
        val quotedMessage =
            quotedMessageId?.let { quoteId ->
                messageState.value[roomId].orEmpty().firstOrNull { it.id == quoteId }?.toQuote()
            }
        val pending =
            ChatMessage(
                id = "local-${UUID.randomUUID()}",
                roomId = roomId,
                senderId = senderId,
                senderName = senderName,
                text = normalized,
                status = MessageStatus.Pending,
                createdAt = Instant.now(),
                quotedMessage = quotedMessage,
            )
        upsertLocalMessage(pending)
        return sendPending(pending, quotedMessageId = quotedMessageId, retry = false)
    }

    override suspend fun sendAttachmentReference(
        roomId: String,
        senderId: String,
        senderName: String,
        text: String?,
        parts: List<MessagePart>,
        quotedMessageId: String?,
    ): ChatMessage {
        val normalizedText = text?.trim().orEmpty()
        val normalizedParts = parts.normalizedForSend(normalizedText)
        require(normalizedText.isNotBlank() || normalizedParts.isNotEmpty()) { "消息内容不能为空" }
        val quotedMessage =
            quotedMessageId?.let { quoteId ->
                messageState.value[roomId].orEmpty().firstOrNull { it.id == quoteId }?.toQuote()
            }
        val pending =
            ChatMessage(
                id = "local-${UUID.randomUUID()}",
                roomId = roomId,
                senderId = senderId,
                senderName = senderName,
                text = previewText(normalizedText, normalizedParts),
                status = MessageStatus.Pending,
                createdAt = Instant.now(),
                quotedMessage = quotedMessage,
                parts = normalizedParts,
            )
        upsertLocalMessage(pending)
        return sendPending(pending, quotedMessageId = quotedMessageId, retry = false)
    }

    override suspend fun fetchAttachmentDownloadUrl(roomId: String, key: String, expiresInSeconds: Int): String? =
        remoteDataSource.fetchAttachmentDownloadUrl(
            roomId = roomId,
            key = key,
            token = requireToken(),
            expiresInSeconds = expiresInSeconds,
        )

    override suspend fun uploadAndSendAttachment(
        roomId: String,
        senderId: String,
        senderName: String,
        file: AttachmentUploadPayload,
        type: MessagePartType,
        text: String?,
        quotedMessageId: String?,
    ): ChatMessage {
        val token = requireToken()
        val descriptor =
            remoteDataSource.requestAttachmentSignature(
                roomId = roomId,
                partType = type.toWireName(),
                filename = file.fileName,
                contentType = file.mime,
                fileSize = file.size,
                token = token,
            )
        if (!descriptor.success) {
            error(descriptor.message.ifBlank { "获取上传签名失败" })
        }
        val key =
            descriptor.key
                ?.takeIf { it.isNotBlank() }
                ?: descriptor.signature?.key?.takeIf { it.isNotBlank() }
                ?: error("上传签名响应缺少 key")
        descriptor.signature?.let { signature ->
            remoteDataSource.uploadAttachmentBytes(signature = signature, bytes = file.bytes, contentType = file.mime)
        }
        val commit = remoteDataSource.commitAttachmentUpload(roomId = roomId, key = key, fileSize = file.size, token = token)
        if (!commit.success) {
            error(commit.message.ifBlank { "附件上传提交失败" })
        }
        val cached = attachmentFileCache?.put(key = key, bytes = file.bytes, expectedSize = file.size)
        return sendAttachmentReference(
            roomId = roomId,
            senderId = senderId,
            senderName = senderName,
            text = text,
            parts = listOf(file.toMessagePart(type = type, key = key, localPath = cached?.localPath)),
            quotedMessageId = quotedMessageId,
        )
    }

    override suspend fun downloadAndCacheAttachment(
        roomId: String,
        attachment: MessageAttachment,
        forceRefresh: Boolean,
    ): MessageAttachment {
        val cache = attachmentFileCache ?: return attachment
        val cached =
            if (forceRefresh) {
                null
            } else {
                cache.get(key = attachment.key, expectedSize = attachment.size)
            } ?: run {
                val downloadUrl =
                    fetchAttachmentDownloadUrl(roomId = roomId, key = attachment.key)
                        ?: error("附件下载地址不可用")
                val bytes = remoteDataSource.downloadAttachmentBytes(downloadUrl)
                cache.put(key = attachment.key, bytes = bytes, expectedSize = attachment.size ?: bytes.size.toLong())
            }
        updateAttachmentLocalPath(roomId = roomId, key = attachment.key, localPath = cached.localPath)
        return attachment.copy(localPath = cached.localPath)
    }

    override suspend fun resendMessage(messageId: String): ChatMessage? {
        val failed =
            messageState.value.values
                .flatten()
                .firstOrNull { it.id == messageId && it.status == MessageStatus.Failed }
                ?: return null
        val pending = failed.copy(status = MessageStatus.Pending, createdAt = Instant.now())
        upsertLocalMessage(pending)
        return sendPending(pending, quotedMessageId = failed.quotedMessage?.id, retry = true)
    }

    override suspend fun markRead(roomId: String) {
        val latest = messageState.value[roomId].orEmpty().lastOrNull() ?: return
        remoteDataSource.markMessagesRead(roomId = roomId, messageId = latest.id, token = requireToken())
        summaryState.value = summaryState.value.map { if (it.roomId == roomId) it.copy(unreadCount = 0) else it }
    }

    override suspend fun setChatPinned(roomId: String, pinned: Boolean) {
        remoteDataSource.pinRoom(roomId = roomId, pinned = pinned, token = requireToken())
        updateSummary(roomId) { it.copy(isPinned = pinned) }
    }

    override suspend fun setChatMuted(roomId: String, muted: Boolean) {
        remoteDataSource.updateNotificationSettings(roomId = roomId, notificationSettings = if (muted) 2 else 0, token = requireToken())
        updateSummary(roomId) { it.copy(isMuted = muted) }
    }

    override suspend fun deleteMessage(roomId: String, messageId: String): ChatMessage {
        val deleted =
            remoteDataSource
                .deleteMessage(roomId = roomId, messageId = messageId, token = requireToken())
                .toDomain()
        upsertLocalMessage(deleted)
        refreshChats()
        return deleted
    }

    override suspend fun setMessagePinned(roomId: String, messageId: String, pinned: Boolean): ChatMessage? {
        val cached = messageState.value[roomId].orEmpty().firstOrNull { it.id == messageId }
        val updated =
            remoteDataSource
                .pinMessage(roomId = roomId, messageId = messageId, pinned = pinned, token = requireToken())
                ?.let { incoming -> incomingResolver.resolve(incoming, E2eeMessageSource.History, cached) }
        if (updated != null) {
            upsertLocalMessage(updated)
        } else {
            updateLocalMessage(roomId, messageId) {
                it.copy(isPinned = false, pinnedAt = null, pinnedBy = null)
            }
        }
        return updated ?: messageState.value[roomId].orEmpty().firstOrNull { it.id == messageId }
    }

    override suspend fun setReaction(
        roomId: String,
        messageId: String,
        reactionKey: String,
        selected: Boolean,
    ): List<MessageReactionSummary> {
        val reactions =
            if (selected) {
                remoteDataSource.addReaction(roomId = roomId, messageId = messageId, reactionKey = reactionKey, token = requireToken())
            } else {
                remoteDataSource.removeReaction(roomId = roomId, messageId = messageId, reactionKey = reactionKey, token = requireToken())
            }
        updateLocalMessage(roomId, messageId) { it.copy(reactions = reactions) }
        return reactions
    }

    override suspend fun clearLocalState() {
        summaryState.value = emptyList()
        messageState.value = emptyMap()
    }

    private suspend fun sendPending(pending: ChatMessage, quotedMessageId: String?, retry: Boolean): ChatMessage {
        return runCatching {
            if (pending.parts.isEmpty()) {
                val peerUserId = summaryState.value.firstOrNull { it.roomId == pending.roomId }?.friendUserId
                val encryptedId = outgoingRouter.send(pending.roomId, peerUserId, pending.text, retry)
                if (encryptedId != null) {
                    pending.copy(id = encryptedId, status = MessageStatus.Sent).also {
                        incomingResolver.rememberResolved(it)
                    }
                } else {
                    remoteDataSource
                        .sendTextMessage(roomId = pending.roomId, content = pending.text, token = requireToken(), quotedMessageId = quotedMessageId)
                        .toDomain()
                }
            } else {
                remoteDataSource
                    .sendRichMessage(
                        roomId = pending.roomId,
                        content = pending.parts.firstOrNull { it.type == MessagePartType.Text }?.text,
                        parts = pending.parts.filterNot { it.type == MessagePartType.Text },
                        token = requireToken(),
                        quotedMessageId = quotedMessageId,
                    ).toDomain()
            }
                .withAttachmentLocalPathsFrom(pending)
        }.fold(
            onSuccess = { sent ->
                removeLocalMessage(pending.roomId, pending.id)
                upsertLocalMessage(sent)
                refreshChats()
                sent
            },
            onFailure = { error ->
                upsertLocalMessage(pending.copy(status = MessageStatus.Failed))
                throw error
            },
        )
    }

    private fun List<MessagePart>.normalizedForSend(text: String): List<MessagePart> {
        val normalized = mutableListOf<MessagePart>()
        if (text.isNotBlank()) {
            normalized += MessagePart(position = 0, type = MessagePartType.Text, text = text)
        }
        filter { it.type != MessagePartType.Text && it.attachment?.key?.isNotBlank() == true }
            .forEach { part ->
                normalized += part.copy(position = normalized.size)
            }
        return normalized
    }

    private fun previewText(text: String, parts: List<MessagePart>): String {
        val segments = mutableListOf<String>()
        if (text.isNotBlank()) segments += text
        parts.filterNot { it.type == MessagePartType.Text }.forEach { part ->
            segments +=
                when (part.type) {
                    MessagePartType.Image -> "[图片]"
                    MessagePartType.Video -> "[视频]"
                    MessagePartType.Audio -> "[语音]"
                    MessagePartType.File -> "[文件]"
                    MessagePartType.Text -> part.text.orEmpty()
                }
        }
        return segments.joinToString(" ").ifBlank { "[消息]" }
    }

    private fun AttachmentUploadPayload.toMessagePart(type: MessagePartType, key: String, localPath: String? = null): MessagePart =
        MessagePart(
            position = 0,
            type = type,
            attachment =
                MessageAttachment(
                    key = key,
                    name = fileName,
                    mime = mime,
                    size = size,
                    width = width,
                    height = height,
                    durationMs = durationMs,
                    thumbnailKey = thumbnailKey,
                    localPath = localPath,
                ),
        )

    private fun upsertLocalMessage(message: ChatMessage) {
        val nextMessages =
            (
                messageState.value[message.roomId].orEmpty().filterNot { it.id == message.id } +
                    message
            ).sortedBy { it.createdAt }
        messageState.value = messageState.value + (message.roomId to nextMessages)
    }

    private fun removeLocalMessage(roomId: String, messageId: String) {
        messageState.value =
            messageState.value +
            (roomId to messageState.value[roomId].orEmpty().filterNot { it.id == messageId })
    }

    private fun updateLocalMessage(roomId: String, messageId: String, transform: (ChatMessage) -> ChatMessage) {
        messageState.value =
            messageState.value +
            (roomId to messageState.value[roomId].orEmpty().map { if (it.id == messageId) transform(it) else it })
    }

    private fun updateAttachmentLocalPath(roomId: String, key: String, localPath: String) {
        messageState.value =
            messageState.value +
            (
                roomId to messageState.value[roomId].orEmpty().map { message ->
                    if (message.parts.any { it.attachment?.key == key }) {
                        message.withAttachmentLocalPath(key = key, localPath = localPath)
                    } else {
                        message
                    }
                }
            )
    }

    private fun updateSummary(roomId: String, transform: (ChatSummary) -> ChatSummary) {
        summaryState.value =
            summaryState.value
                .map { if (it.roomId == roomId) transform(it) else it }
                .sortedWith(compareByDescending<ChatSummary> { it.isPinned }.thenByDescending { it.updatedAt })
    }

    private fun requireToken(): String =
        session.value?.tokens?.accessToken?.takeIf { it.isNotBlank() }
            ?: throw IllegalStateException("请先登录")

    private fun ChatMessage.toQuote(): com.redcode.im.androidapp.core.model.ChatMessageQuote =
        com.redcode.im.androidapp.core.model.ChatMessageQuote(
            id = id,
            roomId = roomId,
            senderId = senderId,
            senderName = senderName,
            text = text,
            createdAt = createdAt,
            isDeleted = isDeleted,
        )
}
