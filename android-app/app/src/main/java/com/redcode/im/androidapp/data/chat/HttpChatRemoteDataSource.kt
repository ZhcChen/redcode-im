package com.redcode.im.androidapp.data.chat

import com.redcode.im.androidapp.core.model.MessageReactionSummary
import com.redcode.im.androidapp.core.model.MessagePart
import com.redcode.im.androidapp.core.model.MessagePartType
import com.redcode.im.androidapp.network.APIClient
import com.redcode.im.androidapp.network.HTTPMethod
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

    override suspend fun sendRichMessage(roomId: String, content: String?, parts: List<MessagePart>, token: String, quotedMessageId: String?): BackendChatMessage =
        apiClient
            .post<SendRichMessageRequest, SendMessageResponse>(
                ChatAPIEndpoint.sendMessage(roomId),
                SendRichMessageRequest(
                    content = content?.trim()?.takeIf { it.isNotBlank() },
                    parts = parts.map { it.toRequest() },
                    quotedMessageId = quotedMessageId,
                ),
                bearerToken = token,
            )
            .message

    override suspend fun requestAttachmentSignature(
        roomId: String,
        partType: String,
        filename: String?,
        contentType: String?,
        fileSize: Long?,
        token: String,
        hashValue: String?,
        hashAlg: Int?,
    ): MessageAttachmentSignatureResponse =
        apiClient.post(
            ChatAPIEndpoint.attachmentSignature(roomId),
            MessageAttachmentSignatureRequest(
                partType = partType,
                filename = filename,
                contentType = contentType,
                fileSize = fileSize,
                hashValue = hashValue,
                hashAlg = hashAlg,
            ),
            bearerToken = token,
        )

    override suspend fun commitAttachmentUpload(
        roomId: String,
        key: String,
        fileSize: Long?,
        token: String,
        hashValue: String?,
        hashAlg: Int?,
    ): MessageAttachmentCommitResponse =
        apiClient.post(
            ChatAPIEndpoint.attachmentCommit(roomId),
            MessageAttachmentCommitRequest(key = key, fileSize = fileSize, hashValue = hashValue, hashAlg = hashAlg),
            bearerToken = token,
        )

    override suspend fun uploadAttachmentBytes(signature: DirectUploadSignature, bytes: ByteArray, contentType: String?) {
        apiClient.uploadBytes(
            url = signature.url,
            method = signature.method.toHttpMethod(),
            headers = signature.headers,
            bytes = bytes,
            contentType = contentType,
        )
    }

    override suspend fun fetchAttachmentDownloadUrl(roomId: String, key: String, token: String, expiresInSeconds: Int): String? =
        apiClient
            .get<MessageAttachmentDownloadResponse>(
                ChatAPIEndpoint.attachmentDownload(roomId = roomId, key = key, expiresInSeconds = expiresInSeconds),
                bearerToken = token,
            )
            .downloadUrl

    override suspend fun markMessagesRead(roomId: String, messageId: String, token: String) {
        apiClient.post<MarkMessageReadRequest, JsonObject>(
            ChatAPIEndpoint.markMessagesRead(roomId),
            MarkMessageReadRequest(messageId),
            bearerToken = token,
        )
    }

    override suspend fun pinRoom(roomId: String, pinned: Boolean, token: String) {
        apiClient.send<JsonObject>(ChatAPIEndpoint.pinRoom(roomId, pinned), bearerToken = token)
    }

    override suspend fun updateNotificationSettings(roomId: String, notificationSettings: Int, token: String) {
        apiClient.post<UpdateNotificationSettingsRequest, JsonObject>(
            ChatAPIEndpoint.updateNotificationSettings(roomId),
            UpdateNotificationSettingsRequest(notificationSettings),
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

    private fun MessagePart.toRequest(): SendMessagePartRequest {
        val attachment = attachment
        return SendMessagePartRequest(
            type = type.toWireName(),
            text = text?.trim()?.takeIf { it.isNotBlank() },
            key = attachment?.key,
            name = attachment?.name,
            mime = attachment?.mime,
            size = attachment?.size,
            width = attachment?.width?.takeIf { type == MessagePartType.Image || type == MessagePartType.Video },
            height = attachment?.height?.takeIf { type == MessagePartType.Image || type == MessagePartType.Video },
            durationMs = attachment?.durationMs?.takeIf { type == MessagePartType.Audio || type == MessagePartType.Video },
            thumbnailKey = attachment?.thumbnailKey?.takeIf { type == MessagePartType.Image || type == MessagePartType.Video },
        )
    }

    private fun String.toHttpMethod(): HTTPMethod =
        when (uppercase()) {
            "POST" -> HTTPMethod.POST
            "PATCH" -> HTTPMethod.PATCH
            "DELETE" -> HTTPMethod.DELETE
            else -> HTTPMethod.PUT
        }
}
