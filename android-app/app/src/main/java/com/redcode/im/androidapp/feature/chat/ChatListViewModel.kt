package com.redcode.im.androidapp.feature.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.redcode.im.androidapp.core.model.ChatSummary
import com.redcode.im.androidapp.data.chat.ChatRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class ChatListViewModel(
    private val chatRepository: ChatRepository,
) : ViewModel() {
    val chats: StateFlow<List<ChatSummary>> =
        chatRepository.chats.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    init {
        viewModelScope.launch {
            runCatching {
                chatRepository.refreshChats()
            }
        }
    }

    fun togglePinned(chat: ChatSummary) {
        viewModelScope.launch {
            runCatching {
                chatRepository.setChatPinned(roomId = chat.roomId, pinned = !chat.isPinned)
                _errorMessage.value = null
            }.onFailure { error ->
                _errorMessage.update { error.message ?: "更新会话置顶失败" }
            }
        }
    }

    fun toggleMuted(chat: ChatSummary) {
        viewModelScope.launch {
            runCatching {
                chatRepository.setChatMuted(roomId = chat.roomId, muted = !chat.isMuted)
                _errorMessage.value = null
            }.onFailure { error ->
                _errorMessage.update { error.message ?: "更新免打扰失败" }
            }
        }
    }
}
