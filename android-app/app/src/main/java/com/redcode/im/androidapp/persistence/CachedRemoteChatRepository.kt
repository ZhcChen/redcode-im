package com.redcode.im.androidapp.persistence

import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.ChatSummary
import com.redcode.im.androidapp.data.chat.ChatRemoteDataSource
import com.redcode.im.androidapp.data.chat.ChatRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first

class CachedRemoteChatRepository(
    private val remoteDataSource: ChatRemoteDataSource,
    private val session: StateFlow<AuthSession?>,
    private val localRepository: RoomChatRepository,
) : ChatRepository {
    override val chats: Flow<List<ChatSummary>> = localRepository.chats

    override fun messages(roomId: String): Flow<List<ChatMessage>> =
        localRepository.messages(roomId)

    override suspend fun refreshChats() {
        val summaries =
            remoteDataSource
                .fetchChats(requireToken())
                .map { it.toDomain() }
                .sortedWith(compareByDescending<ChatSummary> { it.isPinned }.thenByDescending { it.updatedAt })
        localRepository.replaceSummaries(summaries)
    }

    override suspend fun refreshMessages(roomId: String, limit: Int) {
        val messages =
            remoteDataSource
                .loadMessages(roomId = roomId, token = requireToken(), limit = limit)
                .map { it.toDomain() }
                .sortedBy { it.createdAt }
        localRepository.replaceMessages(roomId, messages)
    }

    override suspend fun sendText(roomId: String, senderId: String, senderName: String, text: String): ChatMessage {
        val normalized = text.trim()
        require(normalized.isNotBlank()) { "消息不能为空" }
        val sent =
            remoteDataSource
                .sendTextMessage(roomId = roomId, content = normalized, token = requireToken())
                .toDomain()
        localRepository.upsertMessage(sent)
        refreshChats()
        return sent
    }

    override suspend fun markRead(roomId: String) {
        val latest = localRepository.messages(roomId).first().lastOrNull() ?: return
        remoteDataSource.markMessagesRead(roomId = roomId, messageId = latest.id, token = requireToken())
        localRepository.markRead(roomId)
    }

    override suspend fun clearLocalState() {
        localRepository.clear()
    }

    private fun requireToken(): String =
        session.value?.tokens?.accessToken?.takeIf { it.isNotBlank() }
            ?: throw IllegalStateException("请先登录")
}
