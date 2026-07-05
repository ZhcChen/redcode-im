package com.redcode.im.androidapp.persistence

import com.redcode.im.androidapp.core.model.AddMembersResult
import com.redcode.im.androidapp.core.model.AuthSession
import com.redcode.im.androidapp.core.model.GroupAdmin
import com.redcode.im.androidapp.core.model.GroupJoinRequest
import com.redcode.im.androidapp.core.model.GroupMute
import com.redcode.im.androidapp.core.model.GroupOperationLog
import com.redcode.im.androidapp.core.model.GroupRule
import com.redcode.im.androidapp.core.model.GroupSettingsSnapshot
import com.redcode.im.androidapp.core.model.RoomInfo
import com.redcode.im.androidapp.core.model.RoomMember
import com.redcode.im.androidapp.data.rooms.RoomRemoteDataSource
import com.redcode.im.androidapp.data.rooms.RoomRepository
import com.redcode.im.androidapp.data.rooms.UpdateGroupSettingsRequest
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.StateFlow

class CachedRemoteRoomRepository(
    private val remoteDataSource: RoomRemoteDataSource,
    private val session: StateFlow<AuthSession?>,
    private val localRepository: RoomGroupRepository,
) : RoomRepository {
    override val rooms: Flow<List<RoomInfo>> = localRepository.rooms

    override fun members(roomId: String): Flow<List<RoomMember>> =
        localRepository.members(roomId)

    override fun settings(roomId: String): Flow<GroupSettingsSnapshot?> =
        localRepository.settings(roomId)

    override suspend fun refreshRooms() {
        val rooms =
            remoteDataSource
                .listRooms(requireToken())
                .map { it.toDomain() }
                .sortedBy { it.name.lowercase() }
        localRepository.replaceRooms(rooms)
    }

    override suspend fun createGroup(name: String, description: String?, memberIds: List<String>): RoomInfo {
        val normalized = name.trim()
        require(normalized.isNotBlank()) { "群名称不能为空" }
        require(memberIds.isNotEmpty()) { "至少选择 1 个成员" }
        val room =
            remoteDataSource
                .createGroup(
                    name = normalized,
                    description = description?.trim()?.takeIf { it.isNotBlank() },
                    memberIds = memberIds.distinct(),
                    token = requireToken(),
                )
                .toDomain()
        localRepository.upsertRoom(room)
        refreshMembers(room.id)
        fetchGroupSettings(room.id)
        return room
    }

    override suspend fun getRoom(roomId: String): RoomInfo {
        val room = remoteDataSource.getRoom(roomId = roomId, token = requireToken()).toDomain()
        localRepository.upsertRoom(room)
        return room
    }

    override suspend fun updateRoom(roomId: String, name: String?, description: String?): RoomInfo {
        val room =
            remoteDataSource
                .updateRoom(roomId = roomId, name = name, description = description, token = requireToken())
                .toDomain()
        localRepository.upsertRoom(room)
        return room
    }

    override suspend fun dissolveRoom(roomId: String) {
        remoteDataSource.dissolveRoom(roomId = roomId, token = requireToken())
        localRepository.removeRoom(roomId)
    }

    override suspend fun leaveRoom(roomId: String) {
        remoteDataSource.leaveRoom(roomId = roomId, token = requireToken())
        localRepository.removeRoom(roomId)
    }

    override suspend fun refreshMembers(roomId: String): List<RoomMember> {
        val members =
            remoteDataSource
                .listMembers(roomId = roomId, token = requireToken())
                .map { it.toDomain() }
                .sortedWith(compareBy<RoomMember> { it.role.rank() }.thenBy { it.displayName.lowercase() })
        localRepository.replaceMembers(roomId, members)
        return members
    }

    override suspend fun addMembers(roomId: String, userIds: List<String>): AddMembersResult {
        val result =
            remoteDataSource
                .addMembers(roomId = roomId, userIds = userIds.distinct(), token = requireToken())
                .toDomain()
        refreshMembers(roomId)
        return result
    }

    override suspend fun removeMember(roomId: String, userId: String) {
        remoteDataSource.removeMember(roomId = roomId, userId = userId, token = requireToken())
        localRepository.removeMember(roomId, userId)
    }

    override suspend fun fetchGroupSettings(roomId: String): GroupSettingsSnapshot {
        val snapshot =
            remoteDataSource
                .fetchGroupSettings(roomId = roomId, token = requireToken())
                .toDomain()
        localRepository.upsertSettings(snapshot)
        return snapshot
    }

    override suspend fun updateGroupSettings(
        roomId: String,
        joinApprovalRequired: Boolean?,
        memberCanInvite: Boolean?,
        memberCanAddFriends: Boolean?,
        requireAdminToAddFriends: Boolean?,
        maxMembers: Int?,
    ): GroupSettingsSnapshot {
        val snapshot =
            remoteDataSource
                .updateGroupSettings(
                    roomId = roomId,
                    request =
                        UpdateGroupSettingsRequest(
                            joinApprovalRequired = joinApprovalRequired,
                            memberCanInvite = memberCanInvite,
                            memberCanAddFriends = memberCanAddFriends,
                            requireAdminToAddFriends = requireAdminToAddFriends,
                            maxMembers = maxMembers,
                        ),
                    token = requireToken(),
                )
                .toDomain()
        localRepository.upsertSettings(snapshot)
        return snapshot
    }

    override suspend fun updateGlobalMute(roomId: String, enabled: Boolean, reason: String?, durationMinutes: Int?): GroupSettingsSnapshot {
        val snapshot =
            remoteDataSource
                .updateGlobalMute(roomId = roomId, enabled = enabled, reason = reason, durationMinutes = durationMinutes, token = requireToken())
                .toDomain()
        localRepository.upsertSettings(snapshot)
        return snapshot
    }

    override suspend fun updateNotificationSettings(roomId: String, notificationSettings: Int) {
        remoteDataSource.updateNotificationSettings(roomId = roomId, notificationSettings = notificationSettings, token = requireToken())
    }

    override suspend fun setRoomPinned(roomId: String, pinned: Boolean) {
        remoteDataSource.setRoomPinned(roomId = roomId, pinned = pinned, token = requireToken())
    }

    override suspend fun listAdmins(roomId: String): List<GroupAdmin> =
        remoteDataSource.listAdmins(roomId = roomId, token = requireToken()).map { it.toDomain() }

    override suspend fun appointAdmin(roomId: String, userId: String): GroupAdmin =
        remoteDataSource.appointAdmin(roomId = roomId, userId = userId, token = requireToken()).toDomain()

    override suspend fun removeAdmin(roomId: String, adminId: String) {
        remoteDataSource.removeAdmin(roomId = roomId, adminId = adminId, token = requireToken())
    }

    override suspend fun listMutes(roomId: String): List<GroupMute> =
        remoteDataSource.listMutes(roomId = roomId, token = requireToken()).map { it.toDomain() }

    override suspend fun muteUser(roomId: String, userId: String, reason: String?, muteDurationHours: Int?): GroupMute =
        remoteDataSource.muteUser(
            roomId = roomId,
            userId = userId,
            reason = reason,
            muteDurationHours = muteDurationHours,
            token = requireToken(),
        ).toDomain()

    override suspend fun unmuteUser(roomId: String, userId: String) {
        remoteDataSource.unmuteUser(roomId = roomId, userId = userId, token = requireToken())
    }

    override suspend fun listRules(roomId: String): List<GroupRule> =
        remoteDataSource.listRules(roomId = roomId, token = requireToken()).map { it.toDomain() }

    override suspend fun createRule(roomId: String, title: String, content: String): GroupRule =
        remoteDataSource.createRule(roomId = roomId, title = title, content = content, token = requireToken()).toDomain()

    override suspend fun updateRule(roomId: String, ruleId: String, title: String?, content: String?, isActive: Boolean?): GroupRule =
        remoteDataSource
            .updateRule(roomId = roomId, ruleId = ruleId, title = title, content = content, isActive = isActive, token = requireToken())
            .toDomain()

    override suspend fun deleteRule(roomId: String, ruleId: String) {
        remoteDataSource.deleteRule(roomId = roomId, ruleId = ruleId, token = requireToken())
    }

    override suspend fun listJoinRequests(roomId: String): List<GroupJoinRequest> =
        remoteDataSource.listJoinRequests(roomId = roomId, token = requireToken()).map { it.toDomain() }

    override suspend fun createJoinRequest(roomId: String, message: String?): GroupJoinRequest =
        remoteDataSource.createJoinRequest(roomId = roomId, message = message, token = requireToken()).toDomain()

    override suspend fun reviewJoinRequest(roomId: String, requestId: String, status: String, reviewMessage: String?): GroupJoinRequest =
        remoteDataSource
            .reviewJoinRequest(roomId = roomId, requestId = requestId, status = status, reviewMessage = reviewMessage, token = requireToken())
            .toDomain()

    override suspend fun listOperationLogs(roomId: String, limit: Int, offset: Int): List<GroupOperationLog> =
        remoteDataSource.listOperationLogs(roomId = roomId, limit = limit, offset = offset, token = requireToken()).map { it.toDomain() }

    override suspend fun clearLocalState() {
        localRepository.clear()
    }

    private fun requireToken(): String =
        session.value?.tokens?.accessToken?.takeIf { it.isNotBlank() }
            ?: throw IllegalStateException("请先登录")

    private fun String.rank(): Int =
        when (lowercase()) {
            "owner" -> 0
            "admin" -> 1
            else -> 2
        }
}
