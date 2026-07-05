package com.redcode.im.androidapp.persistence

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatMessageQuote
import com.redcode.im.androidapp.core.model.MessageAttachment
import com.redcode.im.androidapp.core.model.MessagePart
import com.redcode.im.androidapp.core.model.MessagePartType
import com.redcode.im.androidapp.core.model.MessageReactionSummary
import com.redcode.im.androidapp.core.model.MessageStatus
import java.time.Instant
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
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
    val partsJson: String = "[]",
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
            parts = decodeParts(partsJson),
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
                partsJson = encodeParts(message.parts),
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

        fun encodeParts(parts: List<MessagePart>): String =
            JsonArray(
                parts.map { part ->
                    val values =
                        mutableMapOf<String, JsonElement>(
                            "position" to JsonPrimitive(part.position),
                            "type" to JsonPrimitive(part.type.name),
                        )
                    part.text?.let { values["text"] = JsonPrimitive(it) }
                    part.attachment?.let { attachment ->
                        val attachmentValues =
                            mutableMapOf<String, JsonElement>(
                                "key" to JsonPrimitive(attachment.key),
                            )
                        attachment.name?.let { attachmentValues["name"] = JsonPrimitive(it) }
                        attachment.mime?.let { attachmentValues["mime"] = JsonPrimitive(it) }
                        attachment.size?.let { attachmentValues["size"] = JsonPrimitive(it) }
                        attachment.width?.let { attachmentValues["width"] = JsonPrimitive(it) }
                        attachment.height?.let { attachmentValues["height"] = JsonPrimitive(it) }
                        attachment.durationMs?.let { attachmentValues["duration_ms"] = JsonPrimitive(it) }
                        attachment.thumbnailKey?.let { attachmentValues["thumbnail_key"] = JsonPrimitive(it) }
                        attachment.localPath?.let { attachmentValues["local_path"] = JsonPrimitive(it) }
                        values["attachment"] = JsonObject(attachmentValues)
                    }
                    JsonObject(values)
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

        private fun decodeParts(value: String): List<MessagePart> =
            try {
                json.parseToJsonElement(value).jsonArray.mapNotNull { element ->
                    val obj = element.jsonObject
                    val type = obj["type"]?.jsonPrimitive?.contentOrNull.toMessagePartType()
                    val attachmentObj = obj["attachment"]?.jsonObject
                    val attachment =
                        attachmentObj?.let {
                            val key = it["key"]?.jsonPrimitive?.contentOrNull?.takeIf { key -> key.isNotBlank() } ?: return@let null
                            MessageAttachment(
                                key = key,
                                name = it["name"]?.jsonPrimitive?.contentOrNull,
                                mime = it["mime"]?.jsonPrimitive?.contentOrNull,
                                size = it["size"]?.jsonPrimitive?.longOrNull,
                                width = it["width"]?.jsonPrimitive?.longOrNull?.toInt(),
                                height = it["height"]?.jsonPrimitive?.longOrNull?.toInt(),
                                durationMs = it["duration_ms"]?.jsonPrimitive?.longOrNull?.toInt(),
                                thumbnailKey = it["thumbnail_key"]?.jsonPrimitive?.contentOrNull,
                                localPath = it["local_path"]?.jsonPrimitive?.contentOrNull,
                            )
                        }
                    MessagePart(
                        position = obj["position"]?.jsonPrimitive?.longOrNull?.toInt() ?: 0,
                        type = type,
                        text = obj["text"]?.jsonPrimitive?.contentOrNull,
                        attachment = attachment,
                    )
                }
            } catch (_: Exception) {
                emptyList()
            }

        private fun String?.toMessagePartType(): MessagePartType =
            when (this) {
                MessagePartType.Image.name -> MessagePartType.Image
                MessagePartType.Video.name -> MessagePartType.Video
                MessagePartType.Audio.name -> MessagePartType.Audio
                MessagePartType.File.name -> MessagePartType.File
                else -> MessagePartType.Text
            }
    }
}
