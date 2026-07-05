package com.redcode.im.androidapp.persistence

import com.redcode.im.androidapp.core.model.Contact
import com.redcode.im.androidapp.data.contacts.ContactsRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

class RoomContactsRepository(
    private val contactDao: ContactDao,
) : ContactsRepository {
    override val contacts: Flow<List<Contact>> =
        contactDao.observeContacts().map { contacts -> contacts.map { it.toDomain() } }

    override suspend fun search(query: String): List<Contact> {
        val normalized = query.trim()
        if (normalized.isBlank()) return emptyList()
        return contactDao.search(normalized).map { it.toDomain() }
    }

    override suspend fun addLocalContact(contact: Contact) {
        contactDao.upsert(ContactEntity.fromDomain(contact))
    }

    suspend fun replaceContacts(contacts: List<Contact>) {
        contactDao.replaceAll(contacts.map(ContactEntity::fromDomain))
    }

    suspend fun remove(userId: String) {
        contactDao.remove(userId)
    }

    suspend fun clear() {
        contactDao.clear()
    }
}
