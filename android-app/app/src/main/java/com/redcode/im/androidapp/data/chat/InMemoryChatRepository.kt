package com.redcode.im.androidapp.data.chat

import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatRoomType
import com.redcode.im.androidapp.core.model.ChatSummary
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
    private val summaries =
        MutableStateFlow(
            listOf(
                ChatSummary(
                    roomId = "room-general",
                    title = "RedCode 测试群",
                    roomType = ChatRoomType.Group,
                    lastMessagePreview = "原生 Android 迁移基座已就绪",
                    unreadCount = 1,
                    updatedAt = Instant.parse("2026-07-04T00:00:00Z"),
                ),
            ),
        )
    private val messageState =
        MutableStateFlow(
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
            ),
        )

    override val chats: Flow<List<ChatSummary>> = summaries.asStateFlow()

    override fun messages(roomId: String): Flow<List<ChatMessage>> =
        messageState.map { it[roomId].orEmpty() }

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
}
