package com.redcode.im.androidapp.data.chat

import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatSummary
import kotlinx.coroutines.flow.Flow

interface ChatRepository {
    val chats: Flow<List<ChatSummary>>

    fun messages(roomId: String): Flow<List<ChatMessage>>

    suspend fun refreshChats() = Unit

    suspend fun refreshMessages(roomId: String, limit: Int = 50) = Unit

    suspend fun sendText(roomId: String, senderId: String, senderName: String, text: String): ChatMessage

    suspend fun markRead(roomId: String)

    suspend fun clearLocalState() = Unit
}
