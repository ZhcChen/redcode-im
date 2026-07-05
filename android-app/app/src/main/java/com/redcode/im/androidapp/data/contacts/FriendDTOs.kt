package com.redcode.im.androidapp.data.contacts

import com.redcode.im.androidapp.core.model.Contact
import com.redcode.im.androidapp.core.model.FriendRequest
import com.redcode.im.androidapp.core.model.FriendRequestStatus
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class BackendUser(
    val id: String,
    val username: String? = null,
    val email: String? = null,
    val nickname: String? = null,
    @SerialName("avatar_url")
    val avatarUrl: String? = null,
) {
    fun toContact(remark: String? = null): Contact {
        val accountName = firstNotBlank(username, email, id)
        return Contact(
            userId = id,
            accountName = accountName,
            displayName = firstNotBlank(remark, nickname, username, email, id),
            avatarUrl = avatarUrl,
        )
    }
}

@Serializable
data class BackendFriendInfo(
    val id: String = "",
    val user: BackendUser,
    val remark: String? = null,
    @SerialName("friend_remark")
    val friendRemark: String? = null,
) {
    fun toContact(): Contact =
        user.toContact(remark = firstNotBlank(friendRemark, remark).ifBlank { null })
}

@Serializable
data class BackendFriendRequest(
    val id: String,
    val requester: BackendUser,
    val addressee: BackendUser,
    val status: String = "pending",
    val message: String? = null,
    @SerialName("is_incoming")
    val isIncoming: Boolean = false,
) {
    fun toDomain(): FriendRequest {
        val user = if (isIncoming) requester else addressee
        return FriendRequest(
            id = id,
            status = status.toFriendRequestStatus(),
            counterpartyUserId = user.id,
            counterpartyDisplayName = user.toContact().displayName,
            message = message,
            isIncoming = isIncoming,
        )
    }
}

@Serializable
data class CreateFriendRequestPayload(
    @SerialName("target_user_id")
    val targetUserId: String,
    val message: String? = null,
)

@Serializable
data class RespondFriendRequestPayload(
    val action: String,
)

@Serializable
data class EnsurePrivateChatResponse(
    @SerialName("room_id")
    val roomId: String,
    @SerialName("room_name")
    val roomName: String? = null,
)

private fun String?.toFriendRequestStatus(): FriendRequestStatus =
    when (this?.lowercase()) {
        "accepted" -> FriendRequestStatus.Accepted
        "declined" -> FriendRequestStatus.Declined
        else -> FriendRequestStatus.Pending
    }

private fun firstNotBlank(vararg values: String?): String =
    values.firstOrNull { !it.isNullOrBlank() }.orEmpty()
