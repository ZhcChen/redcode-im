package com.redcode.im.androidapp.persistence

import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatRoomType
import com.redcode.im.androidapp.core.model.ChatSummary
import com.redcode.im.androidapp.core.model.MessagePart
import com.redcode.im.androidapp.core.model.MessagePartType
import com.redcode.im.androidapp.core.model.MessageReactionSummary
import com.redcode.im.androidapp.core.model.MessageStatus
import com.redcode.im.androidapp.data.chat.ChatRepository
import java.time.Instant
import java.util.UUID
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

class RoomChatRepository(
    private val chatDao: ChatDao,
    private val maxMessagesPerRoom: Int = 200,
) : ChatRepository {
    override val chats: Flow<List<ChatSummary>> =
        chatDao.observeSummaries().map { summaries -> summaries.map { it.toDomain() } }

    override fun messages(roomId: String): Flow<List<ChatMessage>> =
        chatDao.observeMessages(roomId).map { messages -> messages.map { it.toDomain() } }

    override suspend fun searchMessages(roomId: String, query: String, limit: Int): List<ChatMessage> {
        val normalized = query.trim()
        if (normalized.isBlank()) return emptyList()
        return chatDao
            .searchMessages(roomId = roomId, pattern = normalized.toLikePattern(), limit = limit.coerceIn(1, 100))
            .map { it.toDomain() }
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
        val now = Instant.now()
        val quotedMessage = quotedMessageId?.let { findMessage(it)?.toQuote() }
        val message =
            ChatMessage(
                id = UUID.randomUUID().toString(),
                roomId = roomId,
                senderId = senderId,
                senderName = senderName,
                text = normalized,
                status = MessageStatus.Sent,
                createdAt = now,
                quotedMessage = quotedMessage,
            )
        chatDao.upsertMessage(ChatMessageEntity.fromDomain(message))
        chatDao.upsertSummary(
            ChatSummaryEntity.fromDomain(
                ChatSummary(
                    roomId = roomId,
                    title = roomId,
                    roomType = ChatRoomType.Group,
                    lastMessagePreview = normalized,
                    updatedAt = now,
                ),
            ),
        )
        chatDao.pruneMessages(roomId, maxMessagesPerRoom)
        return message
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
        val now = Instant.now()
        val quotedMessage = quotedMessageId?.let { findMessage(it)?.toQuote() }
        val message =
            ChatMessage(
                id = UUID.randomUUID().toString(),
                roomId = roomId,
                senderId = senderId,
                senderName = senderName,
                text = previewText(normalizedText, normalizedParts),
                status = MessageStatus.Sent,
                createdAt = now,
                quotedMessage = quotedMessage,
                parts = normalizedParts,
            )
        chatDao.upsertMessage(ChatMessageEntity.fromDomain(message))
        chatDao.upsertSummary(
            ChatSummaryEntity.fromDomain(
                ChatSummary(
                    roomId = roomId,
                    title = roomId,
                    roomType = ChatRoomType.Group,
                    lastMessagePreview = message.text,
                    updatedAt = now,
                ),
            ),
        )
        chatDao.pruneMessages(roomId, maxMessagesPerRoom)
        return message
    }

    override suspend fun markRead(roomId: String) {
        chatDao.markRead(roomId)
    }

    suspend fun upsertSummary(summary: ChatSummary) {
        chatDao.upsertSummary(ChatSummaryEntity.fromDomain(summary))
    }

    suspend fun replaceSummaries(summaries: List<ChatSummary>) {
        chatDao.replaceSummaries(summaries.map(ChatSummaryEntity::fromDomain))
    }

    suspend fun updateSummary(roomId: String, transform: (ChatSummary) -> ChatSummary) {
        val current = chatDao.findSummary(roomId)?.toDomain() ?: return
        chatDao.upsertSummary(ChatSummaryEntity.fromDomain(transform(current)))
    }

    suspend fun upsertMessage(message: ChatMessage) {
        upsertMessageEntity(preserveCachedReactions(message))
    }

    suspend fun findMessage(messageId: String): ChatMessage? =
        chatDao.findMessage(messageId)?.toDomain()

    suspend fun updateMessageStatus(messageId: String, status: MessageStatus) {
        chatDao.updateMessageStatus(messageId = messageId, status = status.name)
    }

    suspend fun removeMessage(messageId: String) {
        chatDao.deleteMessage(messageId)
    }

    suspend fun applyIncomingMessage(message: ChatMessage, currentUserId: String?) {
        val existing = chatDao.findMessage(message.id)?.toDomain()
        val alreadyCached = existing != null
        val cachedPinIsMissingFromEvent =
            !message.isDeleted &&
                !message.isPinned &&
                message.pinnedAt == null &&
                message.pinnedBy == null &&
                existing?.isPinned == true
        val messageForCache =
            message.copy(
                isPinned = if (cachedPinIsMissingFromEvent) true else message.isPinned,
                pinnedAt = if (cachedPinIsMissingFromEvent) existing?.pinnedAt else message.pinnedAt,
                pinnedBy = if (cachedPinIsMissingFromEvent) existing?.pinnedBy else message.pinnedBy,
                reactions = if (message.reactions.isEmpty()) existing?.reactions.orEmpty() else message.reactions,
            )
        chatDao.upsertMessage(ChatMessageEntity.fromDomain(messageForCache))
        val currentSummary = chatDao.findSummary(message.roomId)?.toDomain()
        val isSelf = message.senderId == currentUserId
        val nextUnread =
            when {
                currentSummary == null -> if (isSelf || alreadyCached) 0 else 1
                isSelf || alreadyCached -> currentSummary.unreadCount
                else -> currentSummary.unreadCount + 1
            }
        val nextSummary =
            currentSummary
                ?.let { summary ->
                    if (message.createdAt >= summary.updatedAt) {
                        summary.copy(
                            lastMessagePreview = message.text,
                            unreadCount = nextUnread,
                            updatedAt = message.createdAt,
                        )
                    } else {
                        summary.copy(unreadCount = nextUnread)
                    }
                }
                ?: ChatSummary(
                    roomId = message.roomId,
                    title = message.senderName.ifBlank { "新会话" },
                    roomType = ChatRoomType.Direct,
                    lastMessagePreview = message.text,
                    unreadCount = nextUnread,
                    updatedAt = message.createdAt,
                )
        chatDao.upsertSummary(ChatSummaryEntity.fromDomain(nextSummary))
        chatDao.pruneMessages(message.roomId, maxMessagesPerRoom)
    }

    suspend fun markMessageDeleted(roomId: String, messageId: String) {
        chatDao.updateMessageDeleted(roomId = roomId, messageId = messageId, text = "消息已删除")
    }

    suspend fun updateMessagePin(roomId: String, messageId: String, pinned: Boolean, pinnedAt: Instant?, pinnedBy: String?) {
        chatDao.updateMessagePin(
            roomId = roomId,
            messageId = messageId,
            isPinned = pinned,
            pinnedAtMillis = pinnedAt?.toEpochMilli(),
            pinnedBy = pinnedBy,
        )
    }

    suspend fun updateMessageReactions(roomId: String, messageId: String, reactions: List<MessageReactionSummary>) {
        chatDao.updateMessageReactions(
            roomId = roomId,
            messageId = messageId,
            reactionsJson = ChatMessageEntity.encodeReactions(reactions),
        )
    }

    suspend fun applyReactionUpdate(
        roomId: String,
        messageId: String,
        reactionKey: String,
        userId: String,
        added: Boolean,
        currentUserId: String?,
    ) {
        val current = findMessage(messageId) ?: return
        val isSelf = userId == currentUserId
        val reactions = current.reactions.toMutableList()
        val index = reactions.indexOfFirst { it.reactionKey == reactionKey }
        if (added) {
            if (index >= 0) {
                val existing = reactions[index]
                val shouldIncrement = !isSelf || !existing.hasSelf
                reactions[index] =
                    existing.copy(
                        count = existing.count + if (shouldIncrement) 1L else 0L,
                        hasSelf = existing.hasSelf || isSelf,
                    )
            } else {
                reactions += MessageReactionSummary(reactionKey = reactionKey, count = 1L, hasSelf = isSelf)
            }
        } else if (index >= 0) {
            val existing = reactions[index]
            val shouldDecrement = !isSelf || existing.hasSelf
            val nextCount = (existing.count - if (shouldDecrement) 1L else 0L).coerceAtLeast(0L)
            if (nextCount == 0L) {
                reactions.removeAt(index)
            } else {
                reactions[index] = existing.copy(count = nextCount, hasSelf = existing.hasSelf && !isSelf)
            }
        }
        updateMessageReactions(roomId = roomId, messageId = messageId, reactions = reactions)
    }

    override suspend fun resendMessage(messageId: String): ChatMessage? {
        val failed = findMessage(messageId)?.takeIf { it.status == MessageStatus.Failed } ?: return null
        val sent = failed.copy(status = MessageStatus.Sent, createdAt = Instant.now())
        applyIncomingMessage(sent, currentUserId = failed.senderId)
        return sent
    }

    suspend fun replaceMessages(roomId: String, messages: List<ChatMessage>) {
        val mergedMessages = messages.map { preserveCachedReactions(it) }
        chatDao.replaceMessages(
            roomId = roomId,
            messages = mergedMessages.map(ChatMessageEntity::fromDomain),
            keep = maxMessagesPerRoom,
        )
    }

    private suspend fun preserveCachedReactions(message: ChatMessage): ChatMessage {
        if (message.reactions.isNotEmpty()) return message
        val existing = findMessage(message.id) ?: return message
        return if (existing.reactions.isEmpty()) message else message.copy(reactions = existing.reactions)
    }

    private suspend fun upsertMessageEntity(message: ChatMessage) {
        chatDao.upsertMessage(ChatMessageEntity.fromDomain(message))
        chatDao.pruneMessages(message.roomId, maxMessagesPerRoom)
    }

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

    suspend fun clear() {
        chatDao.clearAll()
    }

    override suspend fun clearLocalState() {
        clear()
    }

    override suspend fun setChatPinned(roomId: String, pinned: Boolean) {
        updateSummary(roomId) { it.copy(isPinned = pinned) }
    }

    override suspend fun setChatMuted(roomId: String, muted: Boolean) {
        updateSummary(roomId) { it.copy(isMuted = muted) }
    }

    override suspend fun deleteMessage(roomId: String, messageId: String): ChatMessage? {
        markMessageDeleted(roomId = roomId, messageId = messageId)
        return findMessage(messageId)
    }

    override suspend fun setMessagePinned(roomId: String, messageId: String, pinned: Boolean): ChatMessage? {
        updateMessagePin(
            roomId = roomId,
            messageId = messageId,
            pinned = pinned,
            pinnedAt = if (pinned) Instant.now() else null,
            pinnedBy = if (pinned) "local" else null,
        )
        return findMessage(messageId)
    }

    override suspend fun setReaction(
        roomId: String,
        messageId: String,
        reactionKey: String,
        selected: Boolean,
    ): List<MessageReactionSummary> {
        val current = findMessage(messageId) ?: return emptyList()
        val reactions = current.reactions.toMutableList()
        val index = reactions.indexOfFirst { it.reactionKey == reactionKey }
        if (selected) {
            if (index >= 0) {
                val existing = reactions[index]
                reactions[index] = existing.copy(count = maxOf(existing.count, 1), hasSelf = true)
            } else {
                reactions += MessageReactionSummary(reactionKey = reactionKey, count = 1L, hasSelf = true)
            }
        } else if (index >= 0) {
            val existing = reactions[index]
            val nextCount = (existing.count - if (existing.hasSelf) 1L else 0L).coerceAtLeast(0L)
            if (nextCount == 0L) {
                reactions.removeAt(index)
            } else {
                reactions[index] = existing.copy(count = nextCount, hasSelf = false)
            }
        }
        updateMessageReactions(roomId = roomId, messageId = messageId, reactions = reactions)
        return reactions
    }

    suspend fun removeRoom(roomId: String) {
        chatDao.deleteRoom(roomId)
    }

    private fun String.toLikePattern(): String =
        "%" +
            replace("\\", "\\\\")
                .replace("%", "\\%")
                .replace("_", "\\_") +
            "%"

    private fun List<MessagePart>.normalizedForSend(text: String): List<MessagePart> {
        val normalized = mutableListOf<MessagePart>()
        if (text.isNotBlank()) normalized += MessagePart(position = 0, type = MessagePartType.Text, text = text)
        filter { it.type != MessagePartType.Text && it.attachment?.key?.isNotBlank() == true }
            .forEach { normalized += it.copy(position = normalized.size) }
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
}
