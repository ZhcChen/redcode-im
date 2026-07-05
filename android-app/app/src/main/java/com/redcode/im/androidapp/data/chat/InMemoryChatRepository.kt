package com.redcode.im.androidapp.data.chat

import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatRoomType
import com.redcode.im.androidapp.core.model.ChatSummary
import com.redcode.im.androidapp.core.model.MessageReactionSummary
import com.redcode.im.androidapp.core.model.MessageStatus
import java.time.Instant
import java.util.UUID
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map

class InMemoryChatRepository(
    private val maxMessagesPerRoom: Int = 200,
) : ChatRepository {
    private val seedSummaries =
        listOf(
            ChatSummary(
                roomId = "room-general",
                title = "RedCode 测试群",
                roomType = ChatRoomType.Group,
                lastMessagePreview = "原生 Android 迁移基座已就绪",
                unreadCount = 1,
                updatedAt = Instant.parse("2026-07-04T00:00:00Z"),
            ),
        )
    private val seedMessages =
        mapOf(
            "room-general" to
                listOf(
                    ChatMessage(
                        id = "seed-1",
                        roomId = "room-general",
                        senderId = "system",
                        senderName = "RedCode",
                        text = "原生 Android 迁移基座已就绪",
                        status = MessageStatus.Sent,
                        createdAt = Instant.parse("2026-07-04T00:00:00Z"),
                    ),
                ),
        )
    private val summaries =
        MutableStateFlow(seedSummaries)
    private val messageState =
        MutableStateFlow(seedMessages)

    override val chats: Flow<List<ChatSummary>> = summaries.asStateFlow()

    override fun messages(roomId: String): Flow<List<ChatMessage>> =
        messageState.map { it[roomId].orEmpty() }

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
        val quotedMessage =
            quotedMessageId?.let { quoteId ->
                messageState.value[roomId].orEmpty().firstOrNull { it.id == quoteId }?.toQuote()
            }
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
        val nextMessages = (messageState.value[roomId].orEmpty() + message).takeLast(maxMessagesPerRoom)
        messageState.value = messageState.value + (roomId to nextMessages)
        summaries.value =
            summaries.value
                .map { summary ->
                    if (summary.roomId == roomId) {
                        summary.copy(lastMessagePreview = normalized, updatedAt = now)
                    } else {
                        summary
                    }
                }
                .sortedWith(compareByDescending<ChatSummary> { it.isPinned }.thenByDescending { it.updatedAt })
        return message
    }

    override suspend fun markRead(roomId: String) {
        summaries.value =
            summaries.value.map { summary ->
                if (summary.roomId == roomId) summary.copy(unreadCount = 0) else summary
            }
    }

    override suspend fun deleteMessage(roomId: String, messageId: String): ChatMessage? {
        var updated: ChatMessage? = null
        messageState.value =
            messageState.value + (
                roomId to
                    messageState.value[roomId].orEmpty().map { message ->
                        if (message.id == messageId) {
                            message.copy(text = "消息已删除", isDeleted = true).also { updated = it }
                        } else {
                            message
                        }
                    }
            )
        return updated
    }

    override suspend fun setMessagePinned(roomId: String, messageId: String, pinned: Boolean): ChatMessage? {
        var updated: ChatMessage? = null
        val now = Instant.now()
        messageState.value =
            messageState.value + (
                roomId to
                    messageState.value[roomId].orEmpty().map { message ->
                        if (message.id == messageId) {
                            message.copy(
                                isPinned = pinned,
                                pinnedAt = if (pinned) now else null,
                                pinnedBy = if (pinned) "local" else null,
                            ).also { updated = it }
                        } else {
                            message
                        }
                    }
            )
        return updated
    }

    override suspend fun setReaction(
        roomId: String,
        messageId: String,
        reactionKey: String,
        selected: Boolean,
    ): List<MessageReactionSummary> {
        val current = messageState.value[roomId].orEmpty().firstOrNull { it.id == messageId } ?: return emptyList()
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
        messageState.value =
            messageState.value + (
                roomId to messageState.value[roomId].orEmpty().map { if (it.id == messageId) it.copy(reactions = reactions) else it }
            )
        return reactions
    }

    override suspend fun clearLocalState() {
        summaries.value = emptyList()
        messageState.value = emptyMap()
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
}
