package com.redcode.im.androidapp.data.contacts

import com.redcode.im.androidapp.core.model.Contact
import kotlinx.coroutines.flow.Flow

interface ContactsRepository {
    val contacts: Flow<List<Contact>>

    suspend fun search(query: String): List<Contact>

    suspend fun addLocalContact(contact: Contact)
}
