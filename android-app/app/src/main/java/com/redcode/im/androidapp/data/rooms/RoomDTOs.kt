package com.redcode.im.androidapp.data.rooms

import com.redcode.im.androidapp.core.model.AddMembersResult
import com.redcode.im.androidapp.core.model.GroupAdmin
import com.redcode.im.androidapp.core.model.GroupJoinRequest
import com.redcode.im.androidapp.core.model.GroupMute
import com.redcode.im.androidapp.core.model.GroupOperationLog
import com.redcode.im.androidapp.core.model.GroupRule
import com.redcode.im.androidapp.core.model.GroupSettingsInfo
import com.redcode.im.androidapp.core.model.GroupSettingsSnapshot
import com.redcode.im.androidapp.core.model.JoinRequestStatus
import com.redcode.im.androidapp.core.model.MyMuteInfo
import com.redcode.im.androidapp.core.model.RoomInfo
import com.redcode.im.androidapp.core.model.RoomMember
import java.time.Instant
import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonPrimitive

@Serializable
data class BackendRoomInfo(
    val id: String,
    val name: String,
    @SerialName("room_type")
    val roomType: String = "group",
    val description: String? = null,
    @SerialName("avatar_url")
    val avatarUrl: String? = null,
    @SerialName("avatar_object_key")
    val avatarObjectKey: String? = null,
    @SerialName("owner_id")
    val ownerId: String? = null,
    @SerialName("created_at")
    val createdAt: String? = null,
    @SerialName("updated_at")
    val updatedAt: String? = null,
) {
    fun toDomain(): RoomInfo =
        RoomInfo(
            id = id,
            name = name,
            roomType = roomType,
            description = description,
            avatarUrl = avatarUrl,
            avatarObjectKey = avatarObjectKey,
            ownerId = ownerId,
            createdAt = parseInstant(createdAt),
            updatedAt = parseInstant(updatedAt),
        )
}

@Serializable
data class BackendRoomMember(
    @SerialName("user_id")
    val userId: String,
    val username: String? = null,
    val nickname: String? = null,
    @SerialName("avatar_url")
    val avatarUrl: String? = null,
    @SerialName("avatar_object_key")
    val avatarObjectKey: String? = null,
    val role: String = "member",
    @SerialName("joined_at")
    val joinedAt: String? = null,
) {
    fun toDomain(): RoomMember =
        RoomMember(
            userId = userId,
            username = username ?: userId,
            nickname = nickname,
            avatarUrl = avatarUrl,
            avatarObjectKey = avatarObjectKey,
            role = role,
            joinedAt = parseInstant(joinedAt),
        )
}

@Serializable
data class BackendGroupSettings(
    @SerialName("room_id")
    val roomId: String,
    @SerialName("join_approval_required")
    val joinApprovalRequired: Boolean = false,
    @SerialName("member_can_invite")
    val memberCanInvite: Boolean = true,
    @SerialName("member_can_add_friends")
    val memberCanAddFriends: Boolean = true,
    @SerialName("require_admin_to_add_friends")
    val requireAdminToAddFriends: Boolean = false,
    @SerialName("max_members")
    val maxMembers: Int = 500,
    @SerialName("global_mute_enabled")
    val globalMuteEnabled: Boolean = false,
    @SerialName("global_mute_until")
    val globalMuteUntil: String? = null,
    @SerialName("global_mute_reason")
    val globalMuteReason: String? = null,
    @SerialName("global_mute_set_by")
    val globalMuteSetBy: String? = null,
) {
    fun toDomain(): GroupSettingsInfo =
        GroupSettingsInfo(
            roomId = roomId,
            joinApprovalRequired = joinApprovalRequired,
            memberCanInvite = memberCanInvite,
            memberCanAddFriends = memberCanAddFriends,
            requireAdminToAddFriends = requireAdminToAddFriends,
            maxMembers = maxMembers,
            globalMuteEnabled = globalMuteEnabled,
            globalMuteUntil = parseInstant(globalMuteUntil),
            globalMuteReason = globalMuteReason,
            globalMuteSetBy = globalMuteSetBy,
        )
}

@Serializable
data class BackendMyMuteInfo(
    @SerialName("is_muted")
    val isMuted: Boolean = false,
    val reason: String? = null,
    @SerialName("muted_at")
    val mutedAt: String? = null,
    @SerialName("mute_until")
    val muteUntil: String? = null,
) {
    fun toDomain(): MyMuteInfo =
        MyMuteInfo(
            isMuted = isMuted,
            reason = reason,
            mutedAt = parseInstant(mutedAt),
            muteUntil = parseInstant(muteUntil),
        )
}

@Serializable
data class GroupSettingsResponse(
    val settings: BackendGroupSettings,
    @SerialName("my_mute")
    val myMute: BackendMyMuteInfo? = null,
) {
    fun toDomain(): GroupSettingsSnapshot =
        GroupSettingsSnapshot(settings = settings.toDomain(), myMute = myMute?.toDomain())
}

@Serializable
data class BackendGroupAdmin(
    val id: String,
    @SerialName("room_id")
    val roomId: String,
    @SerialName("admin_id")
    val adminId: String,
    @SerialName("appointed_by")
    val appointedBy: String,
    val role: String = "admin",
    val permissions: List<String>? = null,
    @SerialName("appointed_at")
    val appointedAt: String? = null,
) {
    fun toDomain(): GroupAdmin =
        GroupAdmin(
            id = id,
            roomId = roomId,
            adminId = adminId,
            appointedBy = appointedBy,
            role = role,
            permissions = permissions.orEmpty(),
            appointedAt = parseInstant(appointedAt),
        )
}

@Serializable
data class BackendGroupMute(
    val id: String,
    @SerialName("room_id")
    val roomId: String,
    @SerialName("user_id")
    val userId: String,
    @SerialName("muted_by")
    val mutedBy: String,
    val reason: String? = null,
    @SerialName("mute_duration_hours")
    val muteDurationHours: Int = 24,
    @SerialName("muted_at")
    val mutedAt: String? = null,
    @SerialName("unmuted_at")
    val unmutedAt: String? = null,
    @SerialName("is_active")
    val isActive: Boolean = true,
) {
    fun toDomain(): GroupMute =
        GroupMute(
            id = id,
            roomId = roomId,
            userId = userId,
            mutedBy = mutedBy,
            reason = reason,
            muteDurationHours = muteDurationHours,
            mutedAt = parseInstant(mutedAt),
            unmutedAt = parseInstant(unmutedAt),
            isActive = isActive,
        )
}

@Serializable
data class BackendGroupRule(
    val id: String,
    @SerialName("room_id")
    val roomId: String,
    val title: String,
    val content: String,
    @SerialName("creator_id")
    val creatorId: String,
    @SerialName("order_index")
    val orderIndex: Int = 0,
    @SerialName("is_active")
    val isActive: Boolean = true,
    @SerialName("created_at")
    val createdAt: String? = null,
    @SerialName("updated_at")
    val updatedAt: String? = null,
) {
    fun toDomain(): GroupRule =
        GroupRule(
            id = id,
            roomId = roomId,
            title = title,
            content = content,
            creatorId = creatorId,
            orderIndex = orderIndex,
            isActive = isActive,
            createdAt = parseInstant(createdAt),
            updatedAt = parseInstant(updatedAt),
        )
}

@Serializable
data class BackendGroupJoinRequest(
    val id: String,
    @SerialName("room_id")
    val roomId: String,
    @SerialName("applicant_id")
    val applicantId: String,
    val message: String? = null,
    val status: JsonElement? = null,
    @SerialName("reviewer_id")
    val reviewerId: String? = null,
    @SerialName("review_message")
    val reviewMessage: String? = null,
    @SerialName("created_at")
    val createdAt: String? = null,
    @SerialName("reviewed_at")
    val reviewedAt: String? = null,
) {
    fun toDomain(): GroupJoinRequest =
        GroupJoinRequest(
            id = id,
            roomId = roomId,
            applicantId = applicantId,
            message = message,
            status = status.toJoinRequestStatus(),
            reviewerId = reviewerId,
            reviewMessage = reviewMessage,
            createdAt = parseInstant(createdAt),
            reviewedAt = parseInstant(reviewedAt),
        )
}

@Serializable
data class BackendGroupOperationLog(
    val id: String,
    @SerialName("room_id")
    val roomId: String,
    @SerialName("operator_id")
    val operatorId: String,
    @SerialName("target_user_id")
    val targetUserId: String? = null,
    @SerialName("operation_type")
    val operationType: String,
    @SerialName("operation_data")
    val operationData: JsonElement? = null,
    @SerialName("created_at")
    val createdAt: String? = null,
) {
    fun toDomain(): GroupOperationLog =
        GroupOperationLog(
            id = id,
            roomId = roomId,
            operatorId = operatorId,
            targetUserId = targetUserId,
            operationType = operationType,
            createdAt = parseInstant(createdAt),
        )
}

@Serializable
data class CreateGroupRoomRequest(
    val name: String,
    val description: String? = null,
    @OptIn(ExperimentalSerializationApi::class)
    @EncodeDefault
    @SerialName("room_type")
    val roomType: String = "group",
    @SerialName("member_ids")
    val memberIds: List<String>,
)

@Serializable
data class UpdateRoomRequest(
    val name: String? = null,
    val description: String? = null,
)

@Serializable
data class AddGroupMembersRequest(
    @SerialName("user_ids")
    val userIds: List<String>,
)

@Serializable
data class UpdateNotificationSettingsRequest(
    @SerialName("notification_settings")
    val notificationSettings: Int,
)

@Serializable
data class UpdateGroupSettingsRequest(
    @SerialName("join_approval_required")
    val joinApprovalRequired: Boolean? = null,
    @SerialName("member_can_invite")
    val memberCanInvite: Boolean? = null,
    @SerialName("member_can_add_friends")
    val memberCanAddFriends: Boolean? = null,
    @SerialName("require_admin_to_add_friends")
    val requireAdminToAddFriends: Boolean? = null,
    @SerialName("max_members")
    val maxMembers: Int? = null,
)

@Serializable
data class UpdateGlobalMuteRequest(
    val enabled: Boolean,
    val reason: String? = null,
    @SerialName("duration_minutes")
    val durationMinutes: Int? = null,
)

@Serializable
data class AppointAdminRequest(
    @SerialName("user_id")
    val userId: String,
    @OptIn(ExperimentalSerializationApi::class)
    @EncodeDefault
    val role: String = "admin",
    val permissions: List<String>? = null,
)

@Serializable
data class MuteUserRequest(
    @SerialName("user_id")
    val userId: String,
    val reason: String? = null,
    @SerialName("mute_duration_hours")
    val muteDurationHours: Int? = null,
)

@Serializable
data class CreateRuleRequest(
    val title: String,
    val content: String,
    @SerialName("order_index")
    val orderIndex: Int? = null,
)

@Serializable
data class UpdateRuleRequest(
    val title: String? = null,
    val content: String? = null,
    @SerialName("order_index")
    val orderIndex: Int? = null,
    @SerialName("is_active")
    val isActive: Boolean? = null,
)

@Serializable
data class CreateJoinRequestRequest(
    val message: String? = null,
)

@Serializable
data class ReviewJoinRequestRequest(
    val status: String,
    @SerialName("review_message")
    val reviewMessage: String? = null,
)

@Serializable
data class CreateRoomResponse(val room: BackendRoomInfo)

@Serializable
data class RoomDetailResponse(val room: BackendRoomInfo)

@Serializable
data class UpdateRoomResponse(val room: BackendRoomInfo? = null)

@Serializable
data class AddGroupMembersResponse(
    @SerialName("added_user_ids")
    val addedUserIds: List<String> = emptyList(),
    @SerialName("skipped_user_ids")
    val skippedUserIds: List<String> = emptyList(),
) {
    fun toDomain(): AddMembersResult =
        AddMembersResult(addedUserIds = addedUserIds, skippedUserIds = skippedUserIds)
}

@Serializable
data class ListAdminsResponse(val admins: List<BackendGroupAdmin> = emptyList())

@Serializable
data class AppointAdminResponse(val admin: BackendGroupAdmin)

@Serializable
data class ListMutedUsersResponse(val mutes: List<BackendGroupMute> = emptyList())

@Serializable
data class MuteUserResponse(val mute: BackendGroupMute)

@Serializable
data class ListRulesResponse(val rules: List<BackendGroupRule> = emptyList())

@Serializable
data class CreateRuleResponse(val rule: BackendGroupRule)

@Serializable
data class ListJoinRequestsResponse(val requests: List<BackendGroupJoinRequest> = emptyList())

@Serializable
data class CreateJoinRequestResponse(val request: BackendGroupJoinRequest)

@Serializable
data class ListOperationLogsResponse(
    val logs: List<BackendGroupOperationLog> = emptyList(),
    val total: Long = 0,
)

private fun parseInstant(value: String?): Instant? =
    value
        ?.takeIf { it.isNotBlank() }
        ?.let { runCatching { Instant.parse(it) }.getOrNull() }

private fun JsonElement?.toJoinRequestStatus(): JoinRequestStatus {
    val primitive = this?.jsonPrimitive ?: return JoinRequestStatus.Pending
    return when (primitive.intOrNull ?: primitive.contentOrNull?.lowercase()) {
        1, "1", "approved" -> JoinRequestStatus.Approved
        2, "2", "rejected" -> JoinRequestStatus.Rejected
        else -> JoinRequestStatus.Pending
    }
}
