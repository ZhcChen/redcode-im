package com.redcode.im.androidapp.data.contacts

import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.Contact
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class RemoteContactsRepository(
    private val remoteDataSource: FriendRemoteDataSource,
    private val session: StateFlow<AuthSession?>,
) : ContactsRepository {
    private val state = MutableStateFlow<List<Contact>>(emptyList())
    override val contacts = state.asStateFlow()

    override suspend fun refreshContacts() {
        state.value =
            remoteDataSource
                .fetchFriends(requireToken())
                .map { it.toContact() }
                .sortedBy { it.displayName.lowercase() }
    }

    override suspend fun search(query: String): List<Contact> =
        remoteDataSource
            .searchUsers(keyword = query, token = requireToken())
            .map { it.toContact() }
            .sortedBy { it.displayName.lowercase() }

    override suspend fun addLocalContact(contact: Contact) {
        sendFriendRequest(contact.userId)
    }

    override suspend fun sendFriendRequest(targetUserId: String, message: String?) {
        remoteDataSource.sendFriendRequest(targetUserId = targetUserId, message = message, token = requireToken())
    }

    override suspend fun respondFriendRequest(requestId: String, accept: Boolean) {
        remoteDataSource.respondFriendRequest(requestId = requestId, accept = accept, token = requireToken())
        if (accept) refreshContacts()
    }

    override suspend fun ensurePrivateChat(friendUserId: String): String =
        remoteDataSource.ensurePrivateChat(friendUserId = friendUserId, token = requireToken()).roomId

    private fun requireToken(): String =
        session.value?.tokens?.accessToken?.takeIf { it.isNotBlank() }
            ?: throw IllegalStateException("请先登录")
}
