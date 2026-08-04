package com.redcode.im.androidapp.persistence

import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.Contact
import com.redcode.im.androidapp.core.model.FriendRequest
import com.redcode.im.androidapp.core.model.FriendRequestStatus
import com.redcode.im.androidapp.data.contacts.ContactsRepository
import com.redcode.im.androidapp.data.contacts.FriendRemoteDataSource
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class CachedRemoteContactsRepository(
    private val remoteDataSource: FriendRemoteDataSource,
    private val session: StateFlow<AuthSession?>,
    private val localRepository: RoomContactsRepository,
) : ContactsRepository {
    private val incomingState = MutableStateFlow<List<FriendRequest>>(emptyList())
    private val outgoingState = MutableStateFlow<List<FriendRequest>>(emptyList())

    override val contacts: Flow<List<Contact>> = localRepository.contacts
    override val incomingRequests = incomingState.asStateFlow()
    override val outgoingRequests = outgoingState.asStateFlow()

    override suspend fun refreshContacts() {
        val contacts =
            remoteDataSource
                .fetchFriends(requireToken())
                .map { it.toContact() }
                .sortedBy { it.displayName.lowercase() }
        localRepository.replaceContacts(contacts)
    }

    override suspend fun refreshFriendRequests() {
        val token = requireToken()
        incomingState.value =
            remoteDataSource
                .fetchFriendRequests(direction = "incoming", status = "pending", token = token)
                .map { it.toDomain() }
        outgoingState.value =
            remoteDataSource
                .fetchFriendRequests(direction = "outgoing", status = "pending", token = token)
                .map { it.toDomain() }
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
        val request =
            remoteDataSource
                .sendFriendRequest(targetUserId = targetUserId, message = message, token = requireToken())
                .toDomain()
        outgoingState.value = upsertRequest(outgoingState.value, request)
    }

    override suspend fun respondFriendRequest(requestId: String, accept: Boolean) {
        val request =
            remoteDataSource
                .respondFriendRequest(requestId = requestId, accept = accept, token = requireToken())
                .toDomain()
        incomingState.value =
            incomingState.value
                .map { if (it.id == requestId) request else it }
                .filter { it.status == FriendRequestStatus.Pending }
        if (accept) refreshContacts()
    }

    override suspend fun ensurePrivateChat(friendUserId: String): String =
        remoteDataSource.ensurePrivateChat(friendUserId = friendUserId, token = requireToken()).roomId

    override suspend fun clearLocalState() {
        incomingState.value = emptyList()
        outgoingState.value = emptyList()
        localRepository.clear()
    }

    private fun requireToken(): String =
        session.value?.tokens?.accessToken?.takeIf { it.isNotBlank() }
            ?: throw IllegalStateException("请先登录")

    private fun upsertRequest(current: List<FriendRequest>, request: FriendRequest): List<FriendRequest> =
        (listOf(request) + current.filterNot { it.id == request.id })
            .filter { it.status == FriendRequestStatus.Pending }
}
