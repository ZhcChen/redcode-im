package com.redcode.im.androidapp.core.model

import java.time.Instant

enum class ChatRoomType {
    Direct,
    Group,
}

data class ChatSummary(
    val roomId: String,
    val title: String,
    val roomType: ChatRoomType,
    val lastMessagePreview: String,
    val unreadCount: Int = 0,
    val isPinned: Boolean = false,
    val isMuted: Boolean = false,
    val updatedAt: Instant = Instant.EPOCH,
)

enum class MessageStatus {
    Pending,
    Sent,
    Failed,
}

data class ChatMessage(
    val id: String,
    val roomId: String,
    val senderId: String,
    val senderName: String,
    val text: String,
    val status: MessageStatus,
    val createdAt: Instant,
)
