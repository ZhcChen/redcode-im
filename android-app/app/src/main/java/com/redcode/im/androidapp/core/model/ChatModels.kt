package com.redcode.im.androidapp.core.model

import java.time.Instant
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

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
    val isDeleted: Boolean = false,
    val isPinned: Boolean = false,
    val pinnedAt: Instant? = null,
    val pinnedBy: String? = null,
    val reactions: List<MessageReactionSummary> = emptyList(),
    val quotedMessage: ChatMessageQuote? = null,
    val parts: List<MessagePart> = emptyList(),
)

data class ChatMessageQuote(
    val id: String,
    val roomId: String,
    val senderId: String,
    val senderName: String,
    val text: String,
    val createdAt: Instant? = null,
    val isDeleted: Boolean = false,
)

enum class MessagePartType {
    Text,
    Image,
    Video,
    Audio,
    File,
}

data class MessageAttachment(
    val key: String,
    val name: String? = null,
    val mime: String? = null,
    val size: Long? = null,
    val width: Int? = null,
    val height: Int? = null,
    val durationMs: Int? = null,
    val thumbnailKey: String? = null,
    val localPath: String? = null,
) {
    val displayName: String =
        name?.takeIf { it.isNotBlank() } ?: key.substringAfterLast('/').ifBlank { "附件" }
}

class AttachmentUploadPayload(
    val bytes: ByteArray,
    val fileName: String,
    val mime: String? = null,
    val size: Long = bytes.size.toLong(),
    val width: Int? = null,
    val height: Int? = null,
    val durationMs: Int? = null,
    val thumbnailKey: String? = null,
)

data class MessagePart(
    val position: Int,
    val type: MessagePartType,
    val text: String? = null,
    val attachment: MessageAttachment? = null,
)

@Serializable
data class MessageReactionSummary(
    @SerialName("reaction_key")
    val reactionKey: String,
    val count: Long,
    @SerialName("has_self")
    val hasSelf: Boolean = false,
)
