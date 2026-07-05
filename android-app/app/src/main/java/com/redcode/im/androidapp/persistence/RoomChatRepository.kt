package com.redcode.im.androidapp.persistence

import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatRoomType
import com.redcode.im.androidapp.core.model.ChatSummary
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

    override suspend fun sendText(roomId: String, senderId: String, senderName: String, text: String): ChatMessage {
        val normalized = text.trim()
        require(normalized.isNotBlank()) { "消息不能为空" }
        val now = Instant.now()
        val message =
            ChatMessage(
                id = UUID.randomUUID().toString(),
                roomId = roomId,
                senderId = senderId,
                senderName = senderName,
                text = normalized,
                status = MessageStatus.Sent,
                createdAt = now,
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

    override suspend fun markRead(roomId: String) {
        chatDao.markRead(roomId)
    }

    suspend fun upsertSummary(summary: ChatSummary) {
        chatDao.upsertSummary(ChatSummaryEntity.fromDomain(summary))
    }

    suspend fun replaceSummaries(summaries: List<ChatSummary>) {
        chatDao.replaceSummaries(summaries.map(ChatSummaryEntity::fromDomain))
    }

    suspend fun upsertMessage(message: ChatMessage) {
        chatDao.upsertMessage(ChatMessageEntity.fromDomain(message))
        chatDao.pruneMessages(message.roomId, maxMessagesPerRoom)
    }

    suspend fun applyIncomingMessage(message: ChatMessage, currentUserId: String?) {
        val alreadyCached = chatDao.hasMessage(message.id)
        chatDao.upsertMessage(ChatMessageEntity.fromDomain(message))
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
        chatDao.updateMessageText(roomId = roomId, messageId = messageId, text = "消息已删除")
    }

    suspend fun replaceMessages(roomId: String, messages: List<ChatMessage>) {
        chatDao.replaceMessages(
            roomId = roomId,
            messages = messages.map(ChatMessageEntity::fromDomain),
            keep = maxMessagesPerRoom,
        )
    }

    suspend fun clear() {
        chatDao.clearAll()
    }

    override suspend fun clearLocalState() {
        clear()
    }

    suspend fun removeRoom(roomId: String) {
        chatDao.deleteRoom(roomId)
    }
}
