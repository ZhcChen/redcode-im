package com.redcode.im.androidapp.persistence

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.redcode.im.androidapp.core.model.ChatRoomType
import com.redcode.im.androidapp.core.model.ChatSummary
import java.time.Instant

@Entity(tableName = "chat_summaries")
data class ChatSummaryEntity(
    @PrimaryKey val roomId: String,
    val title: String,
    val roomType: String,
    val lastMessagePreview: String,
    val unreadCount: Int,
    val isPinned: Boolean,
    val isMuted: Boolean,
    val updatedAtMillis: Long,
) {
    fun toDomain(): ChatSummary =
        ChatSummary(
            roomId = roomId,
            title = title,
            roomType = ChatRoomType.valueOf(roomType),
            lastMessagePreview = lastMessagePreview,
            unreadCount = unreadCount,
            isPinned = isPinned,
            isMuted = isMuted,
            updatedAt = Instant.ofEpochMilli(updatedAtMillis),
        )

    companion object {
        fun fromDomain(summary: ChatSummary): ChatSummaryEntity =
            ChatSummaryEntity(
                roomId = summary.roomId,
                title = summary.title,
                roomType = summary.roomType.name,
                lastMessagePreview = summary.lastMessagePreview,
                unreadCount = summary.unreadCount,
                isPinned = summary.isPinned,
                isMuted = summary.isMuted,
                updatedAtMillis = summary.updatedAt.toEpochMilli(),
            )
    }
}
