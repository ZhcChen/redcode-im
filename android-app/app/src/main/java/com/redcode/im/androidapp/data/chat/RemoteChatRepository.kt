package com.redcode.im.androidapp.data.chat

import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatSummary
import com.redcode.im.androidapp.core.model.MessageStatus
import java.time.Instant
import java.util.UUID
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map

class RemoteChatRepository(
    private val remoteDataSource: ChatRemoteDataSource,
    private val session: StateFlow<AuthSession?>,
) : ChatRepository {
    private val summaryState = MutableStateFlow<List<ChatSummary>>(emptyList())
    private val messageState = MutableStateFlow<Map<String, List<ChatMessage>>>(emptyMap())

    override val chats: Flow<List<ChatSummary>> = summaryState

    override fun messages(roomId: String): Flow<List<ChatMessage>> =
        messageState.map { it[roomId].orEmpty() }

    override suspend fun refreshChats() {
        summaryState.value =
            remoteDataSource
                .fetchChats(requireToken())
                .map { it.toDomain() }
                .sortedWith(compareByDescending<ChatSummary> { it.isPinned }.thenByDescending { it.updatedAt })
    }

    override suspend fun refreshMessages(roomId: String, limit: Int) {
        val messages =
            remoteDataSource
                .loadMessages(roomId = roomId, token = requireToken(), limit = limit)
                .map { it.toDomain() }
                .sortedBy { it.createdAt }
        messageState.value = messageState.value + (roomId to messages)
    }

    override suspend fun sendText(roomId: String, senderId: String, senderName: String, text: String): ChatMessage {
        val normalized = text.trim()
        require(normalized.isNotBlank()) { "消息不能为空" }
        val pending =
            ChatMessage(
                id = "local-${UUID.randomUUID()}",
                roomId = roomId,
                senderId = senderId,
                senderName = senderName,
                text = normalized,
                status = MessageStatus.Pending,
                createdAt = Instant.now(),
            )
        upsertLocalMessage(pending)
        return sendPending(pending)
    }

    override suspend fun resendMessage(messageId: String): ChatMessage? {
        val failed =
            messageState.value.values
                .flatten()
                .firstOrNull { it.id == messageId && it.status == MessageStatus.Failed }
                ?: return null
        val pending = failed.copy(status = MessageStatus.Pending, createdAt = Instant.now())
        upsertLocalMessage(pending)
        return sendPending(pending)
    }

    override suspend fun markRead(roomId: String) {
        val latest = messageState.value[roomId].orEmpty().lastOrNull() ?: return
        remoteDataSource.markMessagesRead(roomId = roomId, messageId = latest.id, token = requireToken())
        summaryState.value = summaryState.value.map { if (it.roomId == roomId) it.copy(unreadCount = 0) else it }
    }

    override suspend fun clearLocalState() {
        summaryState.value = emptyList()
        messageState.value = emptyMap()
    }

    private suspend fun sendPending(pending: ChatMessage): ChatMessage {
        return runCatching {
            remoteDataSource
                .sendTextMessage(roomId = pending.roomId, content = pending.text, token = requireToken())
                .toDomain()
        }.fold(
            onSuccess = { sent ->
                removeLocalMessage(pending.roomId, pending.id)
                upsertLocalMessage(sent)
                refreshChats()
                sent
            },
            onFailure = { error ->
                upsertLocalMessage(pending.copy(status = MessageStatus.Failed))
                throw error
            },
        )
    }

    private fun upsertLocalMessage(message: ChatMessage) {
        val nextMessages =
            (
                messageState.value[message.roomId].orEmpty().filterNot { it.id == message.id } +
                    message
            ).sortedBy { it.createdAt }
        messageState.value = messageState.value + (message.roomId to nextMessages)
    }

    private fun removeLocalMessage(roomId: String, messageId: String) {
        messageState.value =
            messageState.value +
            (roomId to messageState.value[roomId].orEmpty().filterNot { it.id == messageId })
    }

    private fun requireToken(): String =
        session.value?.tokens?.accessToken?.takeIf { it.isNotBlank() }
            ?: throw IllegalStateException("请先登录")
}
