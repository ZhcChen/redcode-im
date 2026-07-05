package com.redcode.im.androidapp.data.chat

import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatSummary
import com.redcode.im.androidapp.core.model.MessageReactionSummary
import kotlinx.coroutines.flow.Flow

interface ChatRepository {
    val chats: Flow<List<ChatSummary>>

    fun messages(roomId: String): Flow<List<ChatMessage>>

    suspend fun refreshChats() = Unit

    suspend fun refreshMessages(roomId: String, limit: Int = 50) = Unit

    suspend fun loadOlderMessages(roomId: String, limit: Int = 50): Boolean = false

    suspend fun sendText(
        roomId: String,
        senderId: String,
        senderName: String,
        text: String,
        quotedMessageId: String? = null,
    ): ChatMessage

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
