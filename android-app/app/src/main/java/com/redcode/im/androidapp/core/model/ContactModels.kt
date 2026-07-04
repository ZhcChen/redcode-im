package com.redcode.im.androidapp.core.model

data class Contact(
    val userId: String,
    val accountName: String,
    val displayName: String,
    val avatarUrl: String? = null,
)

enum class FriendRequestStatus {
    Pending,
    Accepted,
    Declined,
}

data class FriendRequest(
    val id: String,
    val fromUserId: String,
    val fromDisplayName: String,
    val status: FriendRequestStatus,
)
