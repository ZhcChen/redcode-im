package com.redcode.im.androidapp.realtime

import com.redcode.im.androidapp.core.model.ChatMessage
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
import kotlinx.serialization.json.jsonPrimitive

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

    private suspend fun removeRoom(payload: JsonObject) {
        val roomId = payload.string("room_id") ?: return
        chatCache.removeRoom(roomId)
    }
}

interface RealtimeChatCache {
    suspend fun applyIncomingMessage(message: ChatMessage, currentUserId: String?)

    suspend fun markRead(roomId: String)

    suspend fun markMessageDeleted(roomId: String, messageId: String)

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
    )
}

private fun JsonObject.string(key: String): String? =
    value(key)?.jsonPrimitive?.contentOrNull?.takeIf { it.isNotBlank() }

private fun JsonObject.boolean(key: String): Boolean? =
    value(key)?.jsonPrimitive?.booleanOrNull

private fun JsonObject.value(key: String): JsonElement? = this[key]?.takeIf { it !is JsonPrimitive || !it.isStringNull() }

private fun JsonPrimitive.isStringNull(): Boolean = contentOrNull == null || contentOrNull == "null"

private fun parseInstant(value: String?): Instant =
    value
        ?.let { runCatching { Instant.parse(it) }.getOrNull() }
        ?: Instant.EPOCH

private fun firstNotBlank(vararg values: String?): String =
    values.firstOrNull { !it.isNullOrBlank() }.orEmpty()
