package com.redcode.im.androidapp.feature.contacts

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.redcode.im.androidapp.core.model.Contact
import com.redcode.im.androidapp.core.model.FriendRequest
import com.redcode.im.androidapp.data.contacts.ContactsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ContactsFormState(
    val query: String = "",
    val searchResults: List<Contact> = emptyList(),
    val isRefreshing: Boolean = false,
    val isSearching: Boolean = false,
    val isSubmitting: Boolean = false,
    val errorMessage: String? = null,
)

data class ContactsUiState(
    val contacts: List<Contact> = emptyList(),
    val incomingRequests: List<FriendRequest> = emptyList(),
    val outgoingRequests: List<FriendRequest> = emptyList(),
    val query: String = "",
    val searchResults: List<Contact> = emptyList(),
    val isRefreshing: Boolean = false,
    val isSearching: Boolean = false,
    val isSubmitting: Boolean = false,
    val errorMessage: String? = null,
)

class ContactsViewModel(
    private val contactsRepository: ContactsRepository,
) : ViewModel() {
    private val formState = MutableStateFlow(ContactsFormState())
    val uiState: StateFlow<ContactsUiState> =
        combine(
            contactsRepository.contacts,
            contactsRepository.incomingRequests,
            contactsRepository.outgoingRequests,
            formState,
        ) { contacts, incomingRequests, outgoingRequests, form ->
            ContactsUiState(
                contacts = contacts,
                incomingRequests = incomingRequests,
                outgoingRequests = outgoingRequests,
                query = form.query,
                searchResults = form.searchResults,
                isRefreshing = form.isRefreshing,
                isSearching = form.isSearching,
                isSubmitting = form.isSubmitting,
                errorMessage = form.errorMessage,
            )
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ContactsUiState())

    init {
        refresh()
    }

    fun onQueryChange(value: String) {
        formState.update { it.copy(query = value, errorMessage = null) }
    }

    fun refresh() {
        viewModelScope.launch {
            formState.update { it.copy(isRefreshing = true, errorMessage = null) }
            runCatching {
                contactsRepository.refreshContacts()
                contactsRepository.refreshFriendRequests()
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "联系人加载失败") }
            }
            formState.update { it.copy(isRefreshing = false) }
        }
    }

    fun search() {
        viewModelScope.launch {
            formState.update { it.copy(isSearching = true, errorMessage = null) }
            runCatching {
                contactsRepository.search(formState.value.query)
            }.onSuccess { results ->
                formState.update { it.copy(searchResults = results) }
            }.onFailure { error ->
                formState.update { it.copy(searchResults = emptyList(), errorMessage = error.message ?: "搜索用户失败") }
            }
            formState.update { it.copy(isSearching = false) }
        }
    }

    fun addContact(contact: Contact) {
        viewModelScope.launch {
            formState.update { it.copy(isSubmitting = true, errorMessage = null) }
            runCatching {
                contactsRepository.sendFriendRequest(contact.userId)
            }.onSuccess {
                formState.update { it.copy(query = "", searchResults = emptyList()) }
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "发送好友申请失败") }
            }
            formState.update { it.copy(isSubmitting = false) }
        }
    }

    fun respondRequest(requestId: String, accept: Boolean) {
        viewModelScope.launch {
            formState.update { it.copy(isSubmitting = true, errorMessage = null) }
            runCatching {
                contactsRepository.respondFriendRequest(requestId, accept)
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "处理好友请求失败") }
            }
            formState.update { it.copy(isSubmitting = false) }
        }
    }

    fun openPrivateChat(contact: Contact, onOpened: (String) -> Unit) {
        viewModelScope.launch {
            formState.update { it.copy(isSubmitting = true, errorMessage = null) }
            runCatching {
                contactsRepository.ensurePrivateChat(contact.userId)
            }.onSuccess { roomId ->
                if (!roomId.isNullOrBlank()) {
                    onOpened(roomId)
                }
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "打开私聊失败") }
            }
            formState.update { it.copy(isSubmitting = false) }
        }
    }
}
