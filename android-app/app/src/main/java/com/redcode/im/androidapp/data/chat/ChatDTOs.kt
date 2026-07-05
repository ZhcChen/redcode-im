package com.redcode.im.androidapp.data.chat

import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatRoomType
import com.redcode.im.androidapp.core.model.ChatSummary
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
        )
}

@Serializable
data class SendTextMessageRequest(
    val content: String,
    @SerialName("quoted_message_id")
    val quotedMessageId: String? = null,
)

@Serializable
data class MarkMessageReadRequest(
    @SerialName("message_id")
    val messageId: String,
)

@Serializable
data class SendMessageResponse(
    val message: BackendChatMessage,
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

private fun parseInstant(value: String?): Instant =
    value
        ?.takeIf { it.isNotBlank() }
        ?.let { runCatching { Instant.parse(it) }.getOrNull() }
        ?: Instant.EPOCH

private fun firstNotBlank(vararg values: String?): String =
    values.firstOrNull { !it.isNullOrBlank() }.orEmpty()
