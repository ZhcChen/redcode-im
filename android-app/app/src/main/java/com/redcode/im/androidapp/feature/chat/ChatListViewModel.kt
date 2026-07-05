package com.redcode.im.androidapp.feature.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.redcode.im.androidapp.core.model.ChatSummary
import com.redcode.im.androidapp.data.chat.ChatRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class ChatListViewModel(
    private val chatRepository: ChatRepository,
) : ViewModel() {
    val chats: StateFlow<List<ChatSummary>> =
        chatRepository.chats.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    init {
        viewModelScope.launch {
            runCatching {
                chatRepository.refreshChats()
            }
        }
    }
}
