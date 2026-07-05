package com.redcode.im.androidapp.feature.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.redcode.im.androidapp.core.model.AttachmentUploadPayload
import com.redcode.im.androidapp.core.model.MessageAttachment
import com.redcode.im.androidapp.core.model.ChatMessage
import com.redcode.im.androidapp.core.model.MessagePart
import com.redcode.im.androidapp.core.model.MessagePartType
import com.redcode.im.androidapp.data.chat.ChatRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ChatDetailFormState(
    val draft: String = "",
    val errorMessage: String? = null,
    val isLoadingOlder: Boolean = false,
    val hasOlderMessages: Boolean = true,
    val quotedMessage: ChatMessage? = null,
    val searchQuery: String = "",
    val searchResults: List<ChatMessage> = emptyList(),
    val isSearching: Boolean = false,
    val isUploadingAttachment: Boolean = false,
    val attachmentCacheStatus: Map<String, String> = emptyMap(),
)

data class ChatDetailUiState(
    val messages: List<ChatMessage> = emptyList(),
    val draft: String = "",
    val errorMessage: String? = null,
    val isLoadingOlder: Boolean = false,
    val hasOlderMessages: Boolean = true,
    val quotedMessage: ChatMessage? = null,
    val searchQuery: String = "",
    val searchResults: List<ChatMessage> = emptyList(),
    val isSearching: Boolean = false,
    val isUploadingAttachment: Boolean = false,
    val attachmentCacheStatus: Map<String, String> = emptyMap(),
)

class ChatDetailViewModel(
    private val chatRepository: ChatRepository,
    private val roomId: String,
    private val currentUserId: String,
    private val currentUserName: String,
) : ViewModel() {
    private val formState = MutableStateFlow(ChatDetailFormState())
    val uiState: StateFlow<ChatDetailUiState> =
        combine(chatRepository.messages(roomId), formState) { messages, form ->
            ChatDetailUiState(
                messages = messages,
                draft = form.draft,
                errorMessage = form.errorMessage,
                isLoadingOlder = form.isLoadingOlder,
                hasOlderMessages = form.hasOlderMessages,
                quotedMessage = form.quotedMessage,
                searchQuery = form.searchQuery,
                searchResults = form.searchResults,
                isSearching = form.isSearching,
                isUploadingAttachment = form.isUploadingAttachment,
                attachmentCacheStatus = form.attachmentCacheStatus,
            )
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ChatDetailUiState())

    init {
        viewModelScope.launch {
            runCatching {
                chatRepository.refreshMessages(roomId)
            }
        }
    }

    fun onDraftChange(value: String) {
        formState.update { it.copy(draft = value, errorMessage = null) }
    }

    fun showError(message: String) {
        formState.update { it.copy(errorMessage = message, isUploadingAttachment = false) }
    }

    fun quoteMessage(message: ChatMessage) {
        if (message.isDeleted || message.id.startsWith("local-")) return
        formState.update { it.copy(quotedMessage = message, errorMessage = null) }
    }

    fun clearQuote() {
        formState.update { it.copy(quotedMessage = null) }
    }

    fun onSearchQueryChange(value: String) {
        formState.update {
            it.copy(searchQuery = value, searchResults = emptyList(), errorMessage = null)
        }
    }

    fun clearSearch() {
        formState.update {
            it.copy(searchQuery = "", searchResults = emptyList(), isSearching = false, errorMessage = null)
        }
    }

    fun searchMessages() {
        val query = formState.value.searchQuery
        viewModelScope.launch {
            val normalized = query.trim()
            if (normalized.isBlank()) {
                formState.update {
                    it.copy(searchQuery = "", searchResults = emptyList(), isSearching = false, errorMessage = null)
                }
                return@launch
            }
            formState.update { it.copy(searchQuery = normalized, isSearching = true, errorMessage = null) }
            runCatching {
                chatRepository.searchMessages(roomId = roomId, query = normalized)
            }.onSuccess { results ->
                formState.update { it.copy(searchResults = results, isSearching = false) }
            }.onFailure { error ->
                formState.update {
                    it.copy(searchResults = emptyList(), isSearching = false, errorMessage = error.message ?: "搜索消息失败")
                }
            }
        }
    }

    fun loadOlderMessages() {
        if (formState.value.isLoadingOlder || !formState.value.hasOlderMessages) return
        viewModelScope.launch {
            formState.update { it.copy(isLoadingOlder = true, errorMessage = null) }
            runCatching {
                chatRepository.loadOlderMessages(roomId)
            }.onSuccess { loaded ->
                formState.update { it.copy(isLoadingOlder = false, hasOlderMessages = loaded) }
            }.onFailure { error ->
                formState.update { it.copy(isLoadingOlder = false, errorMessage = error.message ?: "加载历史消息失败") }
            }
        }
    }

    fun sendDraft() {
        val text = formState.value.draft
        val quotedMessageId = formState.value.quotedMessage?.id
        viewModelScope.launch {
            runCatching {
                chatRepository.sendText(
                    roomId = roomId,
                    senderId = currentUserId,
                    senderName = currentUserName,
                    text = text,
                    quotedMessageId = quotedMessageId,
                )
            }.onSuccess {
                formState.update { it.copy(draft = "", quotedMessage = null, errorMessage = null) }
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "发送失败") }
            }
        }
    }

    fun sendAttachmentReference(
        attachment: MessageAttachment,
        type: MessagePartType = MessagePartType.File,
        text: String? = formState.value.draft,
    ) {
        val quotedMessageId = formState.value.quotedMessage?.id
        viewModelScope.launch {
            runCatching {
                chatRepository.sendAttachmentReference(
                    roomId = roomId,
                    senderId = currentUserId,
                    senderName = currentUserName,
                    text = text,
                    parts =
                        listOf(
                            MessagePart(
                                position = 0,
                                type = type,
                                attachment = attachment,
                            ),
                        ),
                    quotedMessageId = quotedMessageId,
                )
            }.onSuccess {
                formState.update { it.copy(draft = "", quotedMessage = null, errorMessage = null) }
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "发送附件失败") }
            }
        }
    }

    fun uploadAndSendAttachment(
        file: AttachmentUploadPayload,
        type: MessagePartType,
        text: String? = formState.value.draft,
    ) {
        if (formState.value.isUploadingAttachment) return
        val quotedMessageId = formState.value.quotedMessage?.id
        viewModelScope.launch {
            formState.update { it.copy(isUploadingAttachment = true, errorMessage = null) }
            runCatching {
                chatRepository.uploadAndSendAttachment(
                    roomId = roomId,
                    senderId = currentUserId,
                    senderName = currentUserName,
                    file = file,
                    type = type,
                    text = text,
                    quotedMessageId = quotedMessageId,
                )
            }.onSuccess {
                formState.update {
                    it.copy(draft = "", quotedMessage = null, errorMessage = null, isUploadingAttachment = false)
                }
            }.onFailure { error ->
                formState.update {
                    it.copy(errorMessage = error.message ?: "上传附件失败", isUploadingAttachment = false)
                }
            }
        }
    }

    fun cacheAttachment(attachment: MessageAttachment) {
        viewModelScope.launch {
            formState.update {
                it.copy(
                    attachmentCacheStatus = it.attachmentCacheStatus + (attachment.key to "缓存中"),
                    errorMessage = null,
                )
            }
            runCatching {
                chatRepository.downloadAndCacheAttachment(roomId = roomId, attachment = attachment)
            }.onSuccess { cached ->
                formState.update {
                    it.copy(
                        attachmentCacheStatus =
                            it.attachmentCacheStatus + (attachment.key to (cached.localPath ?: "已缓存")),
                    )
                }
            }.onFailure { error ->
                formState.update {
                    it.copy(
                        attachmentCacheStatus = it.attachmentCacheStatus + (attachment.key to "缓存失败"),
                        errorMessage = error.message ?: "附件缓存失败",
                    )
                }
            }
        }
    }

    fun resendMessage(messageId: String) {
        viewModelScope.launch {
            runCatching {
                chatRepository.resendMessage(messageId)
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "重试失败") }
            }
        }
    }

    fun deleteMessage(messageId: String) {
        viewModelScope.launch {
            runCatching {
                chatRepository.deleteMessage(roomId = roomId, messageId = messageId)
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "删除消息失败") }
            }
        }
    }

    fun toggleMessagePinned(message: ChatMessage) {
        viewModelScope.launch {
            runCatching {
                chatRepository.setMessagePinned(roomId = roomId, messageId = message.id, pinned = !message.isPinned)
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: if (message.isPinned) "取消置顶失败" else "置顶消息失败") }
            }
        }
    }

    fun toggleThumbReaction(message: ChatMessage) {
        val selected = message.reactions.firstOrNull { it.reactionKey == "👍" }?.hasSelf != true
        viewModelScope.launch {
            runCatching {
                chatRepository.setReaction(roomId = roomId, messageId = message.id, reactionKey = "👍", selected = selected)
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "更新反应失败") }
            }
        }
    }

    fun markRead() {
        viewModelScope.launch {
            chatRepository.markRead(roomId)
        }
    }
}
