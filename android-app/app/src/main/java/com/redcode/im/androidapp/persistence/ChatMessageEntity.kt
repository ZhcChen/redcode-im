package com.redcode.im.androidapp.persistence

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatMessageQuote
import com.redcode.im.androidapp.core.model.MessageReactionSummary
import com.redcode.im.androidapp.core.model.MessageStatus
import java.time.Instant
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.longOrNull

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
    val isDeleted: Boolean = false,
    val isPinned: Boolean = false,
    val pinnedAtMillis: Long? = null,
    val pinnedBy: String? = null,
    val reactionsJson: String = "[]",
    val quotedMessageId: String? = null,
    val quotedRoomId: String? = null,
    val quotedSenderId: String? = null,
    val quotedSenderName: String? = null,
    val quotedText: String? = null,
    val quotedCreatedAtMillis: Long? = null,
    val quotedIsDeleted: Boolean = false,
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
            isDeleted = isDeleted,
            isPinned = isPinned,
            pinnedAt = pinnedAtMillis?.let(Instant::ofEpochMilli),
            pinnedBy = pinnedBy,
            reactions = decodeReactions(reactionsJson),
            quotedMessage =
                quotedMessageId?.let {
                    ChatMessageQuote(
                        id = it,
                        roomId = quotedRoomId.orEmpty(),
                        senderId = quotedSenderId.orEmpty(),
                        senderName = quotedSenderName.orEmpty(),
                        text = if (quotedIsDeleted) "消息已删除" else quotedText.orEmpty(),
                        createdAt = quotedCreatedAtMillis?.let(Instant::ofEpochMilli),
                        isDeleted = quotedIsDeleted,
                    )
                },
        )

    companion object {
        private val json =
            Json {
                ignoreUnknownKeys = true
            }

        fun fromDomain(message: ChatMessage): ChatMessageEntity =
            ChatMessageEntity(
                id = message.id,
                roomId = message.roomId,
                senderId = message.senderId,
                senderName = message.senderName,
                text = message.text,
                status = message.status.name,
                createdAtMillis = message.createdAt.toEpochMilli(),
                isDeleted = message.isDeleted,
                isPinned = message.isPinned,
                pinnedAtMillis = message.pinnedAt?.toEpochMilli(),
                pinnedBy = message.pinnedBy,
                reactionsJson = encodeReactions(message.reactions),
                quotedMessageId = message.quotedMessage?.id,
                quotedRoomId = message.quotedMessage?.roomId,
                quotedSenderId = message.quotedMessage?.senderId,
                quotedSenderName = message.quotedMessage?.senderName,
                quotedText = message.quotedMessage?.text,
                quotedCreatedAtMillis = message.quotedMessage?.createdAt?.toEpochMilli(),
                quotedIsDeleted = message.quotedMessage?.isDeleted == true,
            )

        fun encodeReactions(reactions: List<MessageReactionSummary>): String =
            JsonArray(
                reactions.map { reaction ->
                    JsonObject(
                        mapOf(
                            "reaction_key" to JsonPrimitive(reaction.reactionKey),
                            "count" to JsonPrimitive(reaction.count),
                            "has_self" to JsonPrimitive(reaction.hasSelf),
                        ),
                    )
                },
            ).toString()

        private fun decodeReactions(value: String): List<MessageReactionSummary> =
            try {
                json.parseToJsonElement(value).jsonArray.mapNotNull { element ->
                    val obj = element.jsonObject
                    val reactionKey = obj["reaction_key"]?.jsonPrimitive?.contentOrNull?.takeIf { it.isNotBlank() }
                    val count = obj["count"]?.jsonPrimitive?.longOrNull ?: 0L
                    if (reactionKey == null || count <= 0L) {
                        null
                    } else {
                        MessageReactionSummary(
                            reactionKey = reactionKey,
                            count = count,
                            hasSelf = obj["has_self"]?.jsonPrimitive?.booleanOrNull == true,
                        )
                    }
                }
            } catch (_: Exception) {
                emptyList()
            }
    }
}
