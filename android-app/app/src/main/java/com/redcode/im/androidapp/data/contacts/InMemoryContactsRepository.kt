package com.redcode.im.androidapp.data.contacts

import com.redcode.im.androidapp.core.model.Contact
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

class InMemoryContactsRepository : ContactsRepository {
    private val state =
        MutableStateFlow(
            listOf(
                Contact(userId = "user-alice", accountName = "alice", displayName = "Alice"),
                Contact(userId = "user-bob", accountName = "bob", displayName = "Bob"),
            ),
        )
    override val contacts = state.asStateFlow()

    override suspend fun search(query: String): List<Contact> {
        val normalized = query.trim()
        if (normalized.isBlank()) return emptyList()
        return state.value.filter {
            it.accountName.contains(normalized, ignoreCase = true) ||
                it.displayName.contains(normalized, ignoreCase = true)
        }
    }

    override suspend fun addLocalContact(contact: Contact) {
        state.value =
            (state.value.filterNot { it.userId == contact.userId } + contact)
                .sortedBy { it.displayName.lowercase() }
    }
}
