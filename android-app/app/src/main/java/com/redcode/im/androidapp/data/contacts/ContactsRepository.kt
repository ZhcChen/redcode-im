package com.redcode.im.androidapp.data.contacts

import com.redcode.im.androidapp.core.model.Contact
import com.redcode.im.androidapp.core.model.FriendRequest
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf

interface ContactsRepository {
    val contacts: Flow<List<Contact>>

    val incomingRequests: Flow<List<FriendRequest>>
        get() = flowOf(emptyList())

    val outgoingRequests: Flow<List<FriendRequest>>
        get() = flowOf(emptyList())

    suspend fun refreshContacts() = Unit

    suspend fun refreshFriendRequests() = Unit

    suspend fun search(query: String): List<Contact>

    suspend fun addLocalContact(contact: Contact)

    suspend fun sendFriendRequest(targetUserId: String, message: String? = null) = Unit

    suspend fun respondFriendRequest(requestId: String, accept: Boolean) = Unit

    suspend fun ensurePrivateChat(friendUserId: String): String? = null

    suspend fun clearLocalState() = Unit
}
