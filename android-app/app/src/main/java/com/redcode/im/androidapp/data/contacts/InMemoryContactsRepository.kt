package com.redcode.im.androidapp.data.contacts

import com.redcode.im.androidapp.core.model.Contact
import com.redcode.im.androidapp.core.model.FriendRequest
import com.redcode.im.androidapp.core.model.FriendRequestStatus
import java.util.UUID
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

class InMemoryContactsRepository : ContactsRepository {
    private val seedContacts =
        listOf(
            Contact(userId = "user-alice", accountName = "alice", displayName = "Alice"),
            Contact(userId = "user-bob", accountName = "bob", displayName = "Bob"),
        )
    private val seedIncoming =
        listOf(
            FriendRequest(
                id = "request-mia",
                status = FriendRequestStatus.Pending,
                counterpartyUserId = "user-mia",
                counterpartyDisplayName = "Mia",
                message = "一起做 Android 联调",
                isIncoming = true,
            ),
        )
    private val state =
        MutableStateFlow(seedContacts)
    private val incoming =
        MutableStateFlow(seedIncoming)
    private val outgoing = MutableStateFlow<List<FriendRequest>>(emptyList())

    override val contacts = state.asStateFlow()
    override val incomingRequests = incoming.asStateFlow()
    override val outgoingRequests = outgoing.asStateFlow()

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

    override suspend fun sendFriendRequest(targetUserId: String, message: String?) {
        val normalized = targetUserId.trim()
        if (normalized.isBlank()) return
        val request =
            FriendRequest(
                id = "outgoing-${UUID.randomUUID()}",
                status = FriendRequestStatus.Pending,
                counterpartyUserId = normalized,
                counterpartyDisplayName = normalized,
                message = message?.trim()?.takeIf { it.isNotBlank() },
                isIncoming = false,
            )
        outgoing.value = (listOf(request) + outgoing.value).distinctBy { it.counterpartyUserId }
    }

    override suspend fun respondFriendRequest(requestId: String, accept: Boolean) {
        val request = incoming.value.firstOrNull { it.id == requestId } ?: return
        val status = if (accept) FriendRequestStatus.Accepted else FriendRequestStatus.Declined
        incoming.value =
            incoming.value.map {
                if (it.id == requestId) it.copy(status = status) else it
            }
        if (accept) {
            addAcceptedContact(request)
        }
    }

    override suspend fun ensurePrivateChat(friendUserId: String): String? =
        friendUserId.trim().takeIf { it.isNotBlank() }?.let { "room-private-$it" }

    override suspend fun clearLocalState() {
        state.value = emptyList()
        incoming.value = emptyList()
        outgoing.value = emptyList()
    }

    private fun addAcceptedContact(request: FriendRequest) {
        state.value =
            (
                state.value.filterNot { it.userId == request.counterpartyUserId } +
                    Contact(
                        userId = request.counterpartyUserId,
                        accountName = request.counterpartyDisplayName,
                        displayName = request.counterpartyDisplayName,
                    )
            )
                .sortedBy { it.displayName.lowercase() }
    }
}
