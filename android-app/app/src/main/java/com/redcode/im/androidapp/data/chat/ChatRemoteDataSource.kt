package com.redcode.im.androidapp.data.chat

interface ChatRemoteDataSource {
    suspend fun fetchChats(token: String): List<BackendChatSummary>

    suspend fun loadMessages(roomId: String, token: String, limit: Int = 50, beforeId: String? = null, sinceId: String? = null): List<BackendChatMessage>

    suspend fun sendTextMessage(roomId: String, content: String, token: String, quotedMessageId: String? = null): BackendChatMessage

    suspend fun markMessagesRead(roomId: String, messageId: String, token: String)
}
