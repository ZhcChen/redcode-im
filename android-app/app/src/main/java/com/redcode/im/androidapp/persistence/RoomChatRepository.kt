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
}
