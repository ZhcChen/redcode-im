package com.redcode.im.androidapp.persistence

import com.redcode.im.androidapp.core.model.AttachmentUploadPayload
import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatSummary
import com.redcode.im.androidapp.core.model.MessageAttachment
import com.redcode.im.androidapp.core.model.MessagePart
import com.redcode.im.androidapp.core.model.MessagePartType
import com.redcode.im.androidapp.core.model.MessageReactionSummary
import com.redcode.im.androidapp.core.model.MessageStatus
import com.redcode.im.androidapp.data.chat.ChatRemoteDataSource
import com.redcode.im.androidapp.data.chat.ChatRepository
import com.redcode.im.androidapp.data.chat.toWireName
import java.time.Instant
import java.util.UUID
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first

class CachedRemoteChatRepository(
    private val remoteDataSource: ChatRemoteDataSource,
    private val session: StateFlow<AuthSession?>,
    private val localRepository: RoomChatRepository,
) : ChatRepository {
    override val chats: Flow<List<ChatSummary>> = localRepository.chats

    override fun messages(roomId: String): Flow<List<ChatMessage>> =
        localRepository.messages(roomId)

    override suspend fun refreshChats() {
        val summaries =
            remoteDataSource
                .fetchChats(requireToken())
                .map { it.toDomain() }
                .sortedWith(compareByDescending<ChatSummary> { it.isPinned }.thenByDescending { it.updatedAt })
        localRepository.replaceSummaries(summaries)
    }

    override suspend fun refreshMessages(roomId: String, limit: Int) {
        val messages =
            remoteDataSource
                .loadMessages(roomId = roomId, token = requireToken(), limit = limit)
                .map { it.toDomain() }
                .sortedBy { it.createdAt }
        localRepository.replaceMessages(roomId, messages)
    }

    override suspend fun searchMessages(roomId: String, query: String, limit: Int): List<ChatMessage> =
        localRepository.searchMessages(roomId = roomId, query = query, limit = limit)

    override suspend fun loadOlderMessages(roomId: String, limit: Int): Boolean {
        val currentMessages = localRepository.messages(roomId).first()
        val beforeId = currentMessages.firstOrNull()?.id ?: return false
        val existingIds = currentMessages.map { it.id }.toSet()
        val older =
            remoteDataSource
                .loadMessages(roomId = roomId, token = requireToken(), limit = limit, beforeId = beforeId)
                .map { it.toDomain() }
                .filterNot { it.id in existingIds }
        if (older.isEmpty()) return false
        older.sortedBy { it.createdAt }.forEach { localRepository.upsertMessage(it) }
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
        val quotedMessage = quotedMessageId?.let { localRepository.findMessage(it)?.toQuote() }
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
        localRepository.applyIncomingMessage(pending, currentUserId = senderId)
        return sendPending(pending, quotedMessageId = quotedMessageId)
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
        val quotedMessage = quotedMessageId?.let { localRepository.findMessage(it)?.toQuote() }
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
        localRepository.applyIncomingMessage(pending, currentUserId = senderId)
        return sendPending(pending, quotedMessageId = quotedMessageId)
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
        return sendAttachmentReference(
            roomId = roomId,
            senderId = senderId,
            senderName = senderName,
            text = text,
            parts = listOf(file.toMessagePart(type = type, key = key)),
            quotedMessageId = quotedMessageId,
        )
    }

    override suspend fun resendMessage(messageId: String): ChatMessage? {
        val failed = localRepository.findMessage(messageId)?.takeIf { it.status == MessageStatus.Failed } ?: return null
        localRepository.updateMessageStatus(messageId = failed.id, status = MessageStatus.Pending)
        return sendPending(failed.copy(status = MessageStatus.Pending, createdAt = Instant.now()), quotedMessageId = failed.quotedMessage?.id)
    }

    override suspend fun markRead(roomId: String) {
        val latest = localRepository.messages(roomId).first().lastOrNull() ?: return
        remoteDataSource.markMessagesRead(roomId = roomId, messageId = latest.id, token = requireToken())
        localRepository.markRead(roomId)
    }

    override suspend fun setChatPinned(roomId: String, pinned: Boolean) {
        remoteDataSource.pinRoom(roomId = roomId, pinned = pinned, token = requireToken())
        localRepository.updateSummary(roomId) { it.copy(isPinned = pinned) }
    }

    override suspend fun setChatMuted(roomId: String, muted: Boolean) {
        remoteDataSource.updateNotificationSettings(roomId = roomId, notificationSettings = if (muted) 2 else 0, token = requireToken())
        localRepository.updateSummary(roomId) { it.copy(isMuted = muted) }
    }

    override suspend fun deleteMessage(roomId: String, messageId: String): ChatMessage {
        val deleted =
            remoteDataSource
                .deleteMessage(roomId = roomId, messageId = messageId, token = requireToken())
                .toDomain()
        localRepository.upsertMessage(deleted)
        refreshChats()
        return deleted
    }

    override suspend fun setMessagePinned(roomId: String, messageId: String, pinned: Boolean): ChatMessage? {
        val updated =
            remoteDataSource
                .pinMessage(roomId = roomId, messageId = messageId, pinned = pinned, token = requireToken())
                ?.toDomain()
        if (updated != null) {
            localRepository.upsertMessage(updated)
        } else {
            localRepository.updateMessagePin(roomId = roomId, messageId = messageId, pinned = false, pinnedAt = null, pinnedBy = null)
        }
        return updated ?: localRepository.findMessage(messageId)
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
        localRepository.updateMessageReactions(roomId = roomId, messageId = messageId, reactions = reactions)
        return reactions
    }

    override suspend fun clearLocalState() {
        localRepository.clear()
    }

    private suspend fun sendPending(pending: ChatMessage, quotedMessageId: String?): ChatMessage {
        return runCatching {
            if (pending.parts.isEmpty()) {
                remoteDataSource
                    .sendTextMessage(roomId = pending.roomId, content = pending.text, token = requireToken(), quotedMessageId = quotedMessageId)
            } else {
                remoteDataSource
                    .sendRichMessage(
                        roomId = pending.roomId,
                        content = pending.parts.firstOrNull { it.type == MessagePartType.Text }?.text,
                        parts = pending.parts.filterNot { it.type == MessagePartType.Text },
                        token = requireToken(),
                        quotedMessageId = quotedMessageId,
                    )
            }
                .toDomain()
        }.fold(
            onSuccess = { sent ->
                localRepository.removeMessage(pending.id)
                localRepository.applyIncomingMessage(sent, currentUserId = pending.senderId)
                refreshChats()
                sent
            },
            onFailure = { error ->
                localRepository.updateMessageStatus(messageId = pending.id, status = MessageStatus.Failed)
                throw error
            },
        )
    }

    private fun requireToken(): String =
        session.value?.tokens?.accessToken?.takeIf { it.isNotBlank() }
            ?: throw IllegalStateException("请先登录")

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

    private fun AttachmentUploadPayload.toMessagePart(type: MessagePartType, key: String): MessagePart =
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
                ),
        )

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
