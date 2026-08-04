package com.redcode.im.androidapp.realtime

import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatMessageQuote
import com.redcode.im.androidapp.core.model.MessageAttachment
import com.redcode.im.androidapp.core.model.MessagePart
import com.redcode.im.androidapp.core.model.MessagePartType
import com.redcode.im.androidapp.core.model.MessageStatus
import com.redcode.im.androidapp.data.chat.ChatRepository
import com.redcode.im.androidapp.data.contacts.ContactsRepository
import com.redcode.im.androidapp.persistence.RoomChatRepository
import java.time.Instant
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.longOrNull

class RealtimeEventProcessor(
    private val chatCache: RealtimeChatCache,
    private val contactsRepository: ContactsRepository,
    private val currentUserIdProvider: () -> String?,
) {
    var lastError: String? = null
        private set

    suspend fun handle(event: WebSocketServerEvent) {
        runCatching {
            when (event.type) {
                "message" -> applyMessage(event.payload)
                "message_read" -> applyMessageRead(event.payload)
                "message_update" -> applyMessageUpdate(event.payload)
                "pin_update" -> applyPinUpdate(event.payload)
                "reaction_update" -> applyReactionUpdate(event.payload)
                "room_created", "room_updated" -> chatCache.refreshChats()
                "room_history_cleared", "group_dissolved" -> removeRoom(event.payload)
                "friend_request_update" -> contactsRepository.refreshFriendRequests()
            }
        }.onFailure { error ->
            lastError = error.message ?: "WebSocket 事件处理失败"
        }
    }

    private suspend fun applyMessage(payload: JsonObject) {
        val message = payload.toChatMessage() ?: return
        chatCache.applyIncomingMessage(message, currentUserIdProvider())
    }

    private suspend fun applyMessageRead(payload: JsonObject) {
        val roomId = payload.string("room_id") ?: return
        val readerId = payload.string("reader_id") ?: return
        if (readerId == currentUserIdProvider()) {
            chatCache.markRead(roomId)
        }
    }

    private suspend fun applyMessageUpdate(payload: JsonObject) {
        if (payload.boolean("is_deleted") != true) return
        val roomId = payload.string("room_id") ?: return
        val messageId = payload.string("message_id") ?: return
        chatCache.markMessageDeleted(roomId = roomId, messageId = messageId)
    }

    private suspend fun applyPinUpdate(payload: JsonObject) {
        val roomId = payload.string("room_id") ?: return
        val messageId = payload.string("message_id") ?: return
        val isPinned = payload.boolean("is_pinned") ?: false
        chatCache.updateMessagePin(
            roomId = roomId,
            messageId = messageId,
            pinned = isPinned,
            pinnedAt = if (isPinned) parseInstantOrNull(payload.string("pinned_at")) else null,
            pinnedBy = if (isPinned) payload.string("pinned_by") else null,
        )
    }

    private suspend fun applyReactionUpdate(payload: JsonObject) {
        val roomId = payload.string("room_id") ?: return
        val messageId = payload.string("message_id") ?: return
        val reactionKey = payload.string("reaction_key") ?: return
        val userId = payload.string("user_id") ?: return
        val added = payload.string("action") != "remove"
        chatCache.applyReactionUpdate(
            roomId = roomId,
            messageId = messageId,
            reactionKey = reactionKey,
            userId = userId,
            added = added,
            currentUserId = currentUserIdProvider(),
        )
    }

    private suspend fun removeRoom(payload: JsonObject) {
        val roomId = payload.string("room_id") ?: return
        chatCache.removeRoom(roomId)
    }
}

interface RealtimeChatCache {
    suspend fun applyIncomingMessage(message: ChatMessage, currentUserId: String?)

    suspend fun markRead(roomId: String)

    suspend fun markMessageDeleted(roomId: String, messageId: String)

    suspend fun updateMessagePin(roomId: String, messageId: String, pinned: Boolean, pinnedAt: Instant?, pinnedBy: String?)

    suspend fun applyReactionUpdate(
        roomId: String,
        messageId: String,
        reactionKey: String,
        userId: String,
        added: Boolean,
        currentUserId: String?,
    )

    suspend fun removeRoom(roomId: String)

    suspend fun refreshChats()
}

class RoomRealtimeChatCache(
    private val chatRepository: ChatRepository,
    private val localRepository: RoomChatRepository,
) : RealtimeChatCache {
    override suspend fun applyIncomingMessage(message: ChatMessage, currentUserId: String?) {
        localRepository.applyIncomingMessage(message = message, currentUserId = currentUserId)
    }

    override suspend fun markRead(roomId: String) {
        localRepository.markRead(roomId)
    }

    override suspend fun markMessageDeleted(roomId: String, messageId: String) {
        localRepository.markMessageDeleted(roomId = roomId, messageId = messageId)
    }

    override suspend fun updateMessagePin(roomId: String, messageId: String, pinned: Boolean, pinnedAt: Instant?, pinnedBy: String?) {
        localRepository.updateMessagePin(
            roomId = roomId,
            messageId = messageId,
            pinned = pinned,
            pinnedAt = pinnedAt,
            pinnedBy = pinnedBy,
        )
    }

    override suspend fun applyReactionUpdate(
        roomId: String,
        messageId: String,
        reactionKey: String,
        userId: String,
        added: Boolean,
        currentUserId: String?,
    ) {
        localRepository.applyReactionUpdate(
            roomId = roomId,
            messageId = messageId,
            reactionKey = reactionKey,
            userId = userId,
            added = added,
            currentUserId = currentUserId,
        )
    }

    override suspend fun removeRoom(roomId: String) {
        localRepository.removeRoom(roomId)
    }

    override suspend fun refreshChats() {
        chatRepository.refreshChats()
    }
}

private fun JsonObject.toChatMessage(): ChatMessage? {
    val id = string("message_id") ?: string("id") ?: return null
    val roomId = string("room_id") ?: return null
    val senderId = string("sender_id") ?: return null
    val senderName = firstNotBlank(string("sender_nickname"), string("sender_username"), senderId)
    val isDeleted = boolean("is_deleted") == true
    return ChatMessage(
        id = id,
        roomId = roomId,
        senderId = senderId,
        senderName = senderName,
        text = if (isDeleted) "消息已删除" else string("content").orEmpty(),
        status = MessageStatus.Sent,
        createdAt = parseInstant(string("timestamp") ?: string("created_at")),
        isDeleted = isDeleted,
        isPinned = boolean("is_pinned") == true,
        pinnedAt = parseInstantOrNull(string("pinned_at")),
        pinnedBy = string("pinned_by"),
        quotedMessage = jsonObject("quoted_message")?.toQuote(),
        parts = parts(),
    )
}

private fun JsonObject.toQuote(): ChatMessageQuote? {
    val id = string("message_id") ?: string("id") ?: return null
    val senderId = string("sender_id") ?: return null
    val isDeleted = boolean("is_deleted") == true
    return ChatMessageQuote(
        id = id,
        roomId = string("room_id").orEmpty(),
        senderId = senderId,
        senderName = firstNotBlank(string("sender_nickname"), string("sender_username"), senderId),
        text = if (isDeleted) "消息已删除" else string("content").orEmpty(),
        createdAt = parseInstantOrNull(string("timestamp") ?: string("created_at")),
        isDeleted = isDeleted,
    )
}

private fun JsonObject.string(key: String): String? =
    value(key)?.jsonPrimitive?.contentOrNull?.takeIf { it.isNotBlank() }

private fun JsonObject.boolean(key: String): Boolean? =
    value(key)?.jsonPrimitive?.booleanOrNull

private fun JsonObject.value(key: String): JsonElement? = this[key]?.takeIf { it !is JsonPrimitive || !it.isStringNull() }

private fun JsonObject.jsonObject(key: String): JsonObject? = value(key) as? JsonObject

private fun JsonObject.parts(): List<MessagePart> =
    runCatching {
        (value("parts") ?: value("attachments"))
            ?.jsonArray
            ?.mapNotNull { element ->
                val obj = element.jsonObject
                val type = (obj.string("part_type") ?: obj.string("type")).toPartType()
                val attachmentObj = obj.jsonObject("attachment") ?: obj
                val attachment =
                    attachmentObj.string("key")?.let { key ->
                        MessageAttachment(
                            key = key,
                            name = attachmentObj.string("name"),
                            mime = attachmentObj.string("mime"),
                            size = attachmentObj.long("size"),
                            width = attachmentObj.long("width")?.toInt(),
                            height = attachmentObj.long("height")?.toInt(),
                            durationMs = attachmentObj.long("duration_ms")?.toInt(),
                            thumbnailKey = attachmentObj.string("thumbnail_key"),
                        )
                    }
                MessagePart(
                    position = obj.long("position")?.toInt() ?: 0,
                    type = type,
                    text = obj.string("text"),
                    attachment = attachment,
                )
            }
            .orEmpty()
    }.getOrDefault(emptyList())

private fun JsonObject.long(key: String): Long? =
    value(key)?.jsonPrimitive?.longOrNull

private fun String?.toPartType(): MessagePartType =
    when (this?.lowercase()) {
        "image" -> MessagePartType.Image
        "video" -> MessagePartType.Video
        "audio", "voice" -> MessagePartType.Audio
        "file" -> MessagePartType.File
        else -> MessagePartType.Text
    }

private fun JsonPrimitive.isStringNull(): Boolean = contentOrNull == null || contentOrNull == "null"

private fun parseInstant(value: String?): Instant =
    value
        ?.let { runCatching { Instant.parse(it) }.getOrNull() }
        ?: Instant.EPOCH

private fun parseInstantOrNull(value: String?): Instant? =
    value
        ?.let { runCatching { Instant.parse(it) }.getOrNull() }

private fun firstNotBlank(vararg values: String?): String =
    values.firstOrNull { !it.isNullOrBlank() }.orEmpty()
