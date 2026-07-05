package com.redcode.im.androidapp.data.chat

import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatMessageQuote
import com.redcode.im.androidapp.core.model.ChatRoomType
import com.redcode.im.androidapp.core.model.ChatSummary
import com.redcode.im.androidapp.core.model.MessageAttachment
import com.redcode.im.androidapp.core.model.MessagePart
import com.redcode.im.androidapp.core.model.MessagePartType
import com.redcode.im.androidapp.core.model.MessageReactionSummary
import com.redcode.im.androidapp.core.model.MessageStatus
import java.time.Instant
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class BackendChatSummary(
    @SerialName("room_id")
    val roomId: String,
    val name: String? = null,
    @SerialName("room_type")
    val roomType: String? = null,
    @SerialName("avatar_url")
    val avatarUrl: String? = null,
    @SerialName("avatar_object_key")
    val avatarObjectKey: String? = null,
    @SerialName("room_avatar_object_key")
    val roomAvatarObjectKey: String? = null,
    @SerialName("unread_count")
    val unreadCount: Int = 0,
    @SerialName("is_pinned")
    val isPinned: Boolean = false,
    @SerialName("is_muted")
    val isMuted: Boolean = false,
    @SerialName("last_message")
    val lastMessage: BackendChatMessagePreview? = null,
    @SerialName("friend_nickname")
    val friendNickname: String? = null,
    @SerialName("friend_username")
    val friendUsername: String? = null,
    @SerialName("friend_remark")
    val friendRemark: String? = null,
    @SerialName("friend_user_id")
    val friendUserId: String? = null,
    @SerialName("friend_avatar_object_key")
    val friendAvatarObjectKey: String? = null,
) {
    fun toDomain(): ChatSummary {
        val type = roomType.toRoomType()
        val title =
            if (type == ChatRoomType.Direct) {
                firstNotBlank(friendRemark, friendNickname, friendUsername, name, "私聊")
            } else {
                firstNotBlank(name, "群聊")
            }
        return ChatSummary(
            roomId = roomId,
            title = title,
            roomType = type,
            lastMessagePreview = lastMessage?.content.orEmpty(),
            avatarUrl = avatarUrl,
            avatarObjectKey =
                if (type == ChatRoomType.Direct) {
                    firstNotBlankNullable(friendAvatarObjectKey, avatarObjectKey, roomAvatarObjectKey)
                } else {
                    firstNotBlankNullable(roomAvatarObjectKey, avatarObjectKey, friendAvatarObjectKey)
                },
            friendUserId = friendUserId?.takeIf { it.isNotBlank() },
            unreadCount = unreadCount,
            isPinned = isPinned,
            isMuted = isMuted,
            updatedAt = parseInstant(lastMessage?.createdAt),
        )
    }
}

@Serializable
data class BackendChatMessagePreview(
    val id: String,
    val content: String = "",
    @SerialName("message_type")
    val messageType: String? = null,
    @SerialName("created_at")
    val createdAt: String? = null,
    @SerialName("sender_id")
    val senderId: String? = null,
    @SerialName("sender_username")
    val senderUsername: String? = null,
    @SerialName("sender_nickname")
    val senderNickname: String? = null,
)

@Serializable
data class BackendChatMessage(
    val id: String,
    @SerialName("room_id")
    val roomId: String,
    @SerialName("sender_id")
    val senderId: String,
    @SerialName("sender_username")
    val senderUsername: String? = null,
    @SerialName("sender_nickname")
    val senderNickname: String? = null,
    val content: String = "",
    @SerialName("message_type")
    val messageType: String? = null,
    val status: String? = null,
    @SerialName("created_at")
    val createdAt: String? = null,
    @SerialName("is_deleted")
    val isDeleted: Boolean = false,
    @SerialName("is_pinned")
    val isPinned: Boolean = false,
    @SerialName("pinned_at")
    val pinnedAt: String? = null,
    @SerialName("pinned_by")
    val pinnedBy: String? = null,
    @SerialName("quoted_message")
    val quotedMessage: BackendQuotedMessage? = null,
    val parts: List<BackendMessagePart> = emptyList(),
) {
    fun toDomain(): ChatMessage =
        ChatMessage(
            id = id,
            roomId = roomId,
            senderId = senderId,
            senderName = firstNotBlank(senderNickname, senderUsername, senderId),
            text = if (isDeleted) "消息已删除" else content,
            status = status.toMessageStatus(),
            createdAt = parseInstant(createdAt),
            isDeleted = isDeleted,
            isPinned = isPinned,
            pinnedAt = parseNullableInstant(pinnedAt),
            pinnedBy = pinnedBy?.takeIf { it.isNotBlank() },
            quotedMessage = quotedMessage?.toDomain(),
            parts = parts.map { it.toDomain() },
        )
}

@Serializable
data class BackendMessageAttachment(
    val key: String,
    val name: String? = null,
    val mime: String? = null,
    val size: Long? = null,
    val width: Int? = null,
    val height: Int? = null,
    @SerialName("duration_ms")
    val durationMs: Int? = null,
    @SerialName("thumbnail_key")
    val thumbnailKey: String? = null,
) {
    fun toDomain(): MessageAttachment =
        MessageAttachment(
            key = key,
            name = name,
            mime = mime,
            size = size,
            width = width,
            height = height,
            durationMs = durationMs,
            thumbnailKey = thumbnailKey,
        )
}

@Serializable
data class BackendMessagePart(
    val position: Int = 0,
    @SerialName("part_type")
    val partType: String,
    val text: String? = null,
    val attachment: BackendMessageAttachment? = null,
) {
    fun toDomain(): MessagePart =
        MessagePart(
            position = position,
            type = partType.toMessagePartType(),
            text = text,
            attachment = attachment?.toDomain(),
        )
}

@Serializable
data class BackendQuotedMessage(
    val id: String,
    @SerialName("room_id")
    val roomId: String,
    @SerialName("sender_id")
    val senderId: String,
    @SerialName("sender_username")
    val senderUsername: String? = null,
    @SerialName("sender_nickname")
    val senderNickname: String? = null,
    val content: String? = null,
    @SerialName("created_at")
    val createdAt: String? = null,
    @SerialName("is_deleted")
    val isDeleted: Boolean = false,
) {
    fun toDomain(): ChatMessageQuote =
        ChatMessageQuote(
            id = id,
            roomId = roomId,
            senderId = senderId,
            senderName = firstNotBlank(senderNickname, senderUsername, senderId),
            text = if (isDeleted) "消息已删除" else content.orEmpty(),
            createdAt = parseNullableInstant(createdAt),
            isDeleted = isDeleted,
        )
}

@Serializable
data class SendTextMessageRequest(
    val content: String,
    @SerialName("quoted_message_id")
    val quotedMessageId: String? = null,
)

@Serializable
data class SendRichMessageRequest(
    val content: String? = null,
    val parts: List<SendMessagePartRequest> = emptyList(),
    @SerialName("quoted_message_id")
    val quotedMessageId: String? = null,
)

@Serializable
data class SendMessagePartRequest(
    val type: String,
    val text: String? = null,
    val key: String? = null,
    val name: String? = null,
    val mime: String? = null,
    val size: Long? = null,
    val width: Int? = null,
    val height: Int? = null,
    @SerialName("duration_ms")
    val durationMs: Int? = null,
    @SerialName("thumbnail_key")
    val thumbnailKey: String? = null,
)

@Serializable
data class MessageAttachmentSignatureRequest(
    @SerialName("part_type")
    val partType: String,
    val filename: String? = null,
    @SerialName("content_type")
    val contentType: String? = null,
    @SerialName("file_size")
    val fileSize: Long? = null,
    @SerialName("hash_value")
    val hashValue: String? = null,
    @SerialName("hash_alg")
    val hashAlg: Int? = null,
)

@Serializable
data class MessageAttachmentSignatureResponse(
    val success: Boolean,
    val message: String = "",
    val key: String? = null,
    val signature: DirectUploadSignature? = null,
)

@Serializable
data class DirectUploadSignature(
    val url: String,
    val method: String = "PUT",
    val headers: Map<String, String> = emptyMap(),
    val key: String? = null,
)

@Serializable
data class MessageAttachmentCommitRequest(
    val key: String,
    @SerialName("hash_value")
    val hashValue: String? = null,
    @SerialName("hash_alg")
    val hashAlg: Int? = null,
    @SerialName("file_size")
    val fileSize: Long? = null,
)

@Serializable
data class MessageAttachmentCommitResponse(
    val success: Boolean,
    val message: String = "",
)

@Serializable
data class MessageAttachmentDownloadResponse(
    val success: Boolean,
    val message: String = "",
    @SerialName("download_url")
    val downloadUrl: String? = null,
)

@Serializable
data class MarkMessageReadRequest(
    @SerialName("message_id")
    val messageId: String,
)

@Serializable
data class UpdateNotificationSettingsRequest(
    @SerialName("notification_settings")
    val notificationSettings: Int,
)

@Serializable
data class AddReactionRequest(
    @SerialName("reaction_key")
    val reactionKey: String,
)

@Serializable
data class SendMessageResponse(
    val message: BackendChatMessage,
)

@Serializable
data class PinMessageResponse(
    @SerialName("room_id")
    val roomId: String,
    @SerialName("is_pinned")
    val isPinned: Boolean,
    val message: BackendChatMessage? = null,
    @SerialName("pinned_at")
    val pinnedAt: String? = null,
    @SerialName("pinned_by")
    val pinnedBy: String? = null,
)

@Serializable
data class ReactionResponse(
    val success: Boolean,
    val message: String = "",
    val summaries: List<MessageReactionSummary> = emptyList(),
)

private fun String?.toRoomType(): ChatRoomType =
    when (this?.lowercase()) {
        "group", "public" -> ChatRoomType.Group
        else -> ChatRoomType.Direct
    }

private fun String?.toMessageStatus(): MessageStatus =
    when (this?.lowercase()) {
        "sending" -> MessageStatus.Pending
        "failed" -> MessageStatus.Failed
        else -> MessageStatus.Sent
    }

fun MessagePartType.toWireName(): String =
    when (this) {
        MessagePartType.Text -> "text"
        MessagePartType.Image -> "image"
        MessagePartType.Video -> "video"
        MessagePartType.Audio -> "audio"
        MessagePartType.File -> "file"
    }

private fun String?.toMessagePartType(): MessagePartType =
    when (this?.lowercase()) {
        "image" -> MessagePartType.Image
        "video" -> MessagePartType.Video
        "audio", "voice" -> MessagePartType.Audio
        "file" -> MessagePartType.File
        else -> MessagePartType.Text
    }

private fun parseInstant(value: String?): Instant =
    value
        ?.takeIf { it.isNotBlank() }
        ?.let { runCatching { Instant.parse(it) }.getOrNull() }
        ?: Instant.EPOCH

private fun parseNullableInstant(value: String?): Instant? =
    value
        ?.takeIf { it.isNotBlank() }
        ?.let { runCatching { Instant.parse(it) }.getOrNull() }

private fun firstNotBlank(vararg values: String?): String =
    values.firstOrNull { !it.isNullOrBlank() }.orEmpty()

private fun firstNotBlankNullable(vararg values: String?): String? =
    values.firstOrNull { !it.isNullOrBlank() }
