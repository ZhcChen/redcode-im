package com.redcode.im.androidapp.data.rooms

import com.redcode.im.androidapp.core.model.AddMembersResult
import com.redcode.im.androidapp.core.model.GroupAdmin
import com.redcode.im.androidapp.core.model.GroupJoinRequest
import com.redcode.im.androidapp.core.model.GroupMute
import com.redcode.im.androidapp.core.model.GroupOperationLog
import com.redcode.im.androidapp.core.model.GroupRule
import com.redcode.im.androidapp.core.model.GroupSettingsSnapshot
import com.redcode.im.androidapp.core.model.RoomInfo
import com.redcode.im.androidapp.core.model.RoomMember
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf

interface RoomRepository {
    val rooms: Flow<List<RoomInfo>>

    fun members(roomId: String): Flow<List<RoomMember>> = flowOf(emptyList())

    fun settings(roomId: String): Flow<GroupSettingsSnapshot?> = flowOf(null)

    suspend fun refreshRooms() = Unit

    suspend fun createGroup(name: String, description: String? = null, memberIds: List<String>): RoomInfo

    suspend fun getRoom(roomId: String): RoomInfo?

    suspend fun updateRoom(roomId: String, name: String? = null, description: String? = null): RoomInfo

    suspend fun dissolveRoom(roomId: String)

    suspend fun leaveRoom(roomId: String)

    suspend fun refreshMembers(roomId: String): List<RoomMember> = emptyList()

    suspend fun addMembers(roomId: String, userIds: List<String>): AddMembersResult =
        AddMembersResult(addedUserIds = emptyList(), skippedUserIds = userIds)

    suspend fun removeMember(roomId: String, userId: String) = Unit

    suspend fun fetchGroupSettings(roomId: String): GroupSettingsSnapshot? = null

    suspend fun updateGroupSettings(
        roomId: String,
        joinApprovalRequired: Boolean? = null,
        memberCanInvite: Boolean? = null,
        memberCanAddFriends: Boolean? = null,
        requireAdminToAddFriends: Boolean? = null,
        maxMembers: Int? = null,
    ): GroupSettingsSnapshot? = fetchGroupSettings(roomId)

    suspend fun updateGlobalMute(roomId: String, enabled: Boolean, reason: String? = null, durationMinutes: Int? = null): GroupSettingsSnapshot? =
        fetchGroupSettings(roomId)

    suspend fun updateNotificationSettings(roomId: String, notificationSettings: Int) = Unit

    suspend fun setRoomPinned(roomId: String, pinned: Boolean) = Unit

    suspend fun listAdmins(roomId: String): List<GroupAdmin> = emptyList()

    suspend fun appointAdmin(roomId: String, userId: String): GroupAdmin? = null

    suspend fun removeAdmin(roomId: String, adminId: String) = Unit

    suspend fun listMutes(roomId: String): List<GroupMute> = emptyList()

    suspend fun muteUser(roomId: String, userId: String, reason: String? = null, muteDurationHours: Int? = null): GroupMute? = null

    suspend fun unmuteUser(roomId: String, userId: String) = Unit

    suspend fun listRules(roomId: String): List<GroupRule> = emptyList()

    suspend fun createRule(roomId: String, title: String, content: String): GroupRule? = null

    suspend fun updateRule(roomId: String, ruleId: String, title: String? = null, content: String? = null, isActive: Boolean? = null): GroupRule? =
        null

    suspend fun deleteRule(roomId: String, ruleId: String) = Unit

    suspend fun listJoinRequests(roomId: String): List<GroupJoinRequest> = emptyList()

    suspend fun createJoinRequest(roomId: String, message: String? = null): GroupJoinRequest? = null

    suspend fun reviewJoinRequest(roomId: String, requestId: String, status: String, reviewMessage: String? = null): GroupJoinRequest? = null

    suspend fun listOperationLogs(roomId: String, limit: Int = 20, offset: Int = 0): List<GroupOperationLog> = emptyList()

    suspend fun clearLocalState() = Unit
}
