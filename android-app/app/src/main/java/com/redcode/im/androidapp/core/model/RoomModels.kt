package com.redcode.im.androidapp.core.model

import java.time.Instant

data class RoomInfo(
    val id: String,
    val name: String,
    val roomType: String = "group",
    val description: String? = null,
    val avatarUrl: String? = null,
    val ownerId: String? = null,
    val createdAt: Instant? = null,
    val updatedAt: Instant? = null,
)

data class RoomMember(
    val userId: String,
    val username: String,
    val nickname: String? = null,
    val avatarUrl: String? = null,
    val role: String = "member",
    val joinedAt: Instant? = null,
) {
    val displayName: String =
        nickname?.takeIf { it.isNotBlank() } ?: username.ifBlank { userId }
}

data class GroupSettingsInfo(
    val roomId: String,
    val joinApprovalRequired: Boolean = false,
    val memberCanInvite: Boolean = true,
    val memberCanAddFriends: Boolean = true,
    val requireAdminToAddFriends: Boolean = false,
    val maxMembers: Int = 500,
    val globalMuteEnabled: Boolean = false,
    val globalMuteUntil: Instant? = null,
    val globalMuteReason: String? = null,
    val globalMuteSetBy: String? = null,
)

data class MyMuteInfo(
    val isMuted: Boolean,
    val reason: String? = null,
    val mutedAt: Instant? = null,
    val muteUntil: Instant? = null,
)

data class GroupSettingsSnapshot(
    val settings: GroupSettingsInfo,
    val myMute: MyMuteInfo? = null,
)

data class AddMembersResult(
    val addedUserIds: List<String>,
    val skippedUserIds: List<String> = emptyList(),
)

data class GroupAdmin(
    val id: String,
    val roomId: String,
    val adminId: String,
    val appointedBy: String,
    val role: String = "admin",
    val permissions: List<String> = emptyList(),
    val appointedAt: Instant? = null,
)

data class GroupMute(
    val id: String,
    val roomId: String,
    val userId: String,
    val mutedBy: String,
    val reason: String? = null,
    val muteDurationHours: Int = 24,
    val mutedAt: Instant? = null,
    val unmutedAt: Instant? = null,
    val isActive: Boolean = true,
)

data class GroupRule(
    val id: String,
    val roomId: String,
    val title: String,
    val content: String,
    val creatorId: String,
    val orderIndex: Int = 0,
    val isActive: Boolean = true,
    val createdAt: Instant? = null,
    val updatedAt: Instant? = null,
)

enum class JoinRequestStatus {
    Pending,
    Approved,
    Rejected,
}

data class GroupJoinRequest(
    val id: String,
    val roomId: String,
    val applicantId: String,
    val message: String? = null,
    val status: JoinRequestStatus = JoinRequestStatus.Pending,
    val reviewerId: String? = null,
    val reviewMessage: String? = null,
    val createdAt: Instant? = null,
    val reviewedAt: Instant? = null,
)

data class GroupOperationLog(
    val id: String,
    val roomId: String,
    val operatorId: String,
    val targetUserId: String? = null,
    val operationType: String,
    val createdAt: Instant? = null,
)
