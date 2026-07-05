package com.redcode.im.androidapp.data.chat

import com.redcode.im.androidapp.core.model.MessageReactionSummary

interface ChatRemoteDataSource {
    suspend fun fetchChats(token: String): List<BackendChatSummary>

    suspend fun loadMessages(roomId: String, token: String, limit: Int = 50, beforeId: String? = null, sinceId: String? = null): List<BackendChatMessage>

    suspend fun sendTextMessage(roomId: String, content: String, token: String, quotedMessageId: String? = null): BackendChatMessage

    suspend fun markMessagesRead(roomId: String, messageId: String, token: String)

    suspend fun pinRoom(roomId: String, pinned: Boolean, token: String)

    suspend fun updateNotificationSettings(roomId: String, notificationSettings: Int, token: String)

    suspend fun deleteMessage(roomId: String, messageId: String, token: String): BackendChatMessage

    suspend fun pinMessage(roomId: String, messageId: String, pinned: Boolean, token: String): BackendChatMessage?

    suspend fun addReaction(roomId: String, messageId: String, reactionKey: String, token: String): List<MessageReactionSummary>

    suspend fun removeReaction(roomId: String, messageId: String, reactionKey: String, token: String): List<MessageReactionSummary>
}
