package com.redcode.im.androidapp.data.chat

import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatSummary
import com.redcode.im.androidapp.core.model.MessagePart
import com.redcode.im.androidapp.core.model.MessageReactionSummary
import kotlinx.coroutines.flow.Flow

interface ChatRepository {
    val chats: Flow<List<ChatSummary>>

    fun messages(roomId: String): Flow<List<ChatMessage>>

    suspend fun refreshChats() = Unit

    suspend fun refreshMessages(roomId: String, limit: Int = 50) = Unit

    suspend fun searchMessages(roomId: String, query: String, limit: Int = 50): List<ChatMessage> = emptyList()

    suspend fun loadOlderMessages(roomId: String, limit: Int = 50): Boolean = false

    suspend fun sendText(
        roomId: String,
        senderId: String,
        senderName: String,
        text: String,
        quotedMessageId: String? = null,
    ): ChatMessage

    suspend fun sendAttachmentReference(
        roomId: String,
        senderId: String,
        senderName: String,
        text: String? = null,
        parts: List<MessagePart>,
        quotedMessageId: String? = null,
    ): ChatMessage =
        sendText(roomId = roomId, senderId = senderId, senderName = senderName, text = text.orEmpty(), quotedMessageId = quotedMessageId)

    suspend fun fetchAttachmentDownloadUrl(roomId: String, key: String, expiresInSeconds: Int = 600): String? = null

    suspend fun resendMessage(messageId: String): ChatMessage? = null

    suspend fun markRead(roomId: String)

    suspend fun setChatPinned(roomId: String, pinned: Boolean) = Unit

    suspend fun setChatMuted(roomId: String, muted: Boolean) = Unit

    suspend fun deleteMessage(roomId: String, messageId: String): ChatMessage? = null

    suspend fun setMessagePinned(roomId: String, messageId: String, pinned: Boolean): ChatMessage? = null

    suspend fun setReaction(roomId: String, messageId: String, reactionKey: String, selected: Boolean): List<MessageReactionSummary> =
        emptyList()

    suspend fun clearLocalState() = Unit
}
