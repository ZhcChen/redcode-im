package com.redcode.im.androidapp.feature.contacts

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.redcode.im.androidapp.core.model.Contact
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
)

data class ContactsUiState(
    val contacts: List<Contact> = emptyList(),
    val query: String = "",
    val searchResults: List<Contact> = emptyList(),
)

class ContactsViewModel(
    private val contactsRepository: ContactsRepository,
) : ViewModel() {
    private val formState = MutableStateFlow(ContactsFormState())
    val uiState: StateFlow<ContactsUiState> =
        combine(contactsRepository.contacts, formState) { contacts, form ->
            ContactsUiState(
                contacts = contacts,
                query = form.query,
                searchResults = form.searchResults,
            )
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ContactsUiState())

    fun onQueryChange(value: String) {
        formState.update { it.copy(query = value) }
    }

    fun search() {
        viewModelScope.launch {
            val results = contactsRepository.search(formState.value.query)
            formState.update { it.copy(searchResults = results) }
        }
    }

    fun addContact(contact: Contact) {
        viewModelScope.launch {
            contactsRepository.addLocalContact(contact)
            formState.update { it.copy(query = "", searchResults = emptyList()) }
        }
    }
}
