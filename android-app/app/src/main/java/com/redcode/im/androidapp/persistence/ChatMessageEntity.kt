package com.redcode.im.androidapp.persistence

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.MessageStatus
import java.time.Instant

@Entity(
    tableName = "chat_messages",
    indices = [Index(value = ["roomId", "createdAtMillis"])],
)
data class ChatMessageEntity(
    @PrimaryKey val id: String,
    val roomId: String,
    val senderId: String,
    val senderName: String,
    val text: String,
    val status: String,
    val createdAtMillis: Long,
) {
    fun toDomain(): ChatMessage =
        ChatMessage(
            id = id,
            roomId = roomId,
            senderId = senderId,
            senderName = senderName,
            text = text,
            status = MessageStatus.valueOf(status),
            createdAt = Instant.ofEpochMilli(createdAtMillis),
        )

    companion object {
        fun fromDomain(message: ChatMessage): ChatMessageEntity =
            ChatMessageEntity(
                id = message.id,
                roomId = message.roomId,
                senderId = message.senderId,
                senderName = message.senderName,
                text = message.text,
                status = message.status.name,
                createdAtMillis = message.createdAt.toEpochMilli(),
            )
    }
}
