package com.redcode.im.androidapp.data.chat

import com.redcode.im.androidapp.core.model.MessageReactionSummary
import com.redcode.im.androidapp.network.APIClient
import kotlinx.serialization.json.JsonObject

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
        apiClient.post<MarkMessageReadRequest, JsonObject>(
            ChatAPIEndpoint.markMessagesRead(roomId),
            MarkMessageReadRequest(messageId),
            bearerToken = token,
        )
    }

    override suspend fun deleteMessage(roomId: String, messageId: String, token: String): BackendChatMessage =
        apiClient.send(ChatAPIEndpoint.deleteMessage(roomId, messageId), bearerToken = token)

    override suspend fun pinMessage(roomId: String, messageId: String, pinned: Boolean, token: String): BackendChatMessage? =
        apiClient
            .send<PinMessageResponse>(ChatAPIEndpoint.pinMessage(roomId, messageId, pinned), bearerToken = token)
            .message

    override suspend fun addReaction(roomId: String, messageId: String, reactionKey: String, token: String): List<MessageReactionSummary> =
        apiClient
            .post<AddReactionRequest, ReactionResponse>(
                ChatAPIEndpoint.addReaction(roomId, messageId),
                AddReactionRequest(reactionKey),
                bearerToken = token,
            )
            .summaries

    override suspend fun removeReaction(roomId: String, messageId: String, reactionKey: String, token: String): List<MessageReactionSummary> =
        apiClient
            .send<ReactionResponse>(
                ChatAPIEndpoint.removeReaction(roomId, messageId, reactionKey),
                bearerToken = token,
            )
            .summaries
}
