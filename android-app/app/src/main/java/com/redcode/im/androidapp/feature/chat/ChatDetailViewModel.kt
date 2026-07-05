package com.redcode.im.androidapp.feature.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.redcode.im.androidapp.core.model.ChatMessage
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
)

data class ChatDetailUiState(
    val messages: List<ChatMessage> = emptyList(),
    val draft: String = "",
    val errorMessage: String? = null,
    val isLoadingOlder: Boolean = false,
    val hasOlderMessages: Boolean = true,
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
        viewModelScope.launch {
            runCatching {
                chatRepository.sendText(roomId, currentUserId, currentUserName, text)
            }.onSuccess {
                formState.update { it.copy(draft = "", errorMessage = null) }
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "发送失败") }
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

    fun markRead() {
        viewModelScope.launch {
            chatRepository.markRead(roomId)
        }
    }
}
