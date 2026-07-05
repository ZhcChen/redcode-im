package com.redcode.im.androidapp.data.chat

import com.redcode.im.androidapp.network.APIClient

class HttpChatRemoteDataSource(
    private val apiClient: APIClient,
) : ChatRemoteDataSource {
    override suspend fun fetchChats(token: String): List<BackendChatSummary> =
        apiClient.get(ChatAPIEndpoint.chats, bearerToken = token)

    override suspend fun loadMessages(
        roomId: String,
        token: String,
        limit: Int,
        beforeId: String?,
        sinceId: String?,
    ): List<BackendChatMessage> =
        apiClient.get(
            ChatAPIEndpoint.messages(roomId = roomId, limit = limit, beforeId = beforeId, sinceId = sinceId),
            bearerToken = token,
        )

    override suspend fun sendTextMessage(roomId: String, content: String, token: String, quotedMessageId: String?): BackendChatMessage =
        apiClient
            .post<SendTextMessageRequest, SendMessageResponse>(
                ChatAPIEndpoint.sendMessage(roomId),
                SendTextMessageRequest(content = content, quotedMessageId = quotedMessageId),
                bearerToken = token,
            )
            .message

    override suspend fun markMessagesRead(roomId: String, messageId: String, token: String) {
        apiClient.post<MarkMessageReadRequest, kotlinx.serialization.json.JsonObject>(
            ChatAPIEndpoint.markMessagesRead(roomId),
            MarkMessageReadRequest(messageId),
            bearerToken = token,
        )
    }
}
