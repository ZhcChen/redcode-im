package com.redcode.im.androidapp.core.model

data class Contact(
    val userId: String,
    val accountName: String,
    val displayName: String,
    val avatarUrl: String? = null,
    val avatarObjectKey: String? = null,
)

enum class FriendRequestStatus {
    Pending,
    Accepted,
    Declined,
}

data class FriendRequest(
    val id: String,
    val status: FriendRequestStatus,
    val counterpartyUserId: String,
    val counterpartyDisplayName: String,
    val message: String? = null,
    val isIncoming: Boolean = true,
)
