package com.redcode.im.androidapp.persistence

import com.redcode.im.androidapp.core.model.AddMembersResult
import com.redcode.im.androidapp.core.model.GroupSettingsInfo
import com.redcode.im.androidapp.core.model.GroupSettingsSnapshot
import com.redcode.im.androidapp.core.model.RoomInfo
import com.redcode.im.androidapp.core.model.RoomMember
import com.redcode.im.androidapp.data.rooms.RoomRepository
import java.time.Instant
import java.util.UUID
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

class RoomGroupRepository(
    private val roomDao: RoomDao,
) : RoomRepository {
    override val rooms: Flow<List<RoomInfo>> =
        roomDao.observeRooms().map { rooms -> rooms.map { it.toDomain() } }

    override fun members(roomId: String): Flow<List<RoomMember>> =
        roomDao.observeMembers(roomId).map { members -> members.map { it.toDomain() } }

    override fun settings(roomId: String): Flow<GroupSettingsSnapshot?> =
        roomDao.observeSettings(roomId).map { it?.toDomain() }

    override suspend fun createGroup(name: String, description: String?, memberIds: List<String>): RoomInfo {
        val normalized = name.trim()
        require(normalized.isNotBlank()) { "群名称不能为空" }
        require(memberIds.isNotEmpty()) { "至少选择 1 个成员" }
        val now = Instant.now()
        val room =
            RoomInfo(
                id = "local-room-${UUID.randomUUID()}",
                name = normalized,
                description = description?.trim()?.takeIf { it.isNotBlank() },
                ownerId = "local-owner",
                createdAt = now,
                updatedAt = now,
            )
        upsertRoom(room)
        replaceMembers(
            room.id,
            listOf(RoomMember(userId = "local-owner", username = "me", role = "owner")) +
                memberIds.distinct().map { RoomMember(userId = it, username = it) },
        )
        upsertSettings(GroupSettingsSnapshot(GroupSettingsInfo(roomId = room.id)))
        return room
    }

    override suspend fun getRoom(roomId: String): RoomInfo? =
        roomDao.findRoom(roomId)?.toDomain()

    override suspend fun updateRoom(roomId: String, name: String?, description: String?): RoomInfo {
        val current = getRoom(roomId) ?: error("群聊不存在")
        val updated =
            current.copy(
                name = name?.trim()?.takeIf { it.isNotBlank() } ?: current.name,
                description = description?.trim(),
                updatedAt = Instant.now(),
            )
        upsertRoom(updated)
        return updated
    }

    override suspend fun dissolveRoom(roomId: String) {
        roomDao.removeRoom(roomId)
    }

    override suspend fun leaveRoom(roomId: String) {
        roomDao.removeRoom(roomId)
    }

    override suspend fun refreshMembers(roomId: String): List<RoomMember> =
        emptyList()

    override suspend fun addMembers(roomId: String, userIds: List<String>): AddMembersResult {
        val members = userIds.distinct().map { RoomMember(userId = it, username = it) }
        roomDao.upsertMembers(members.map { RoomMemberEntity.fromDomain(roomId, it) })
        return AddMembersResult(addedUserIds = userIds.distinct())
    }

    override suspend fun removeMember(roomId: String, userId: String) {
        roomDao.removeMember(roomId, userId)
    }

    override suspend fun fetchGroupSettings(roomId: String): GroupSettingsSnapshot =
        GroupSettingsSnapshot(GroupSettingsInfo(roomId = roomId)).also { upsertSettings(it) }

    override suspend fun updateGroupSettings(
        roomId: String,
        joinApprovalRequired: Boolean?,
        memberCanInvite: Boolean?,
        memberCanAddFriends: Boolean?,
        requireAdminToAddFriends: Boolean?,
        maxMembers: Int?,
    ): GroupSettingsSnapshot {
        val current = fetchGroupSettings(roomId).settings
        val next =
            GroupSettingsSnapshot(
                current.copy(
                    joinApprovalRequired = joinApprovalRequired ?: current.joinApprovalRequired,
                    memberCanInvite = memberCanInvite ?: current.memberCanInvite,
                    memberCanAddFriends = memberCanAddFriends ?: current.memberCanAddFriends,
                    requireAdminToAddFriends = requireAdminToAddFriends ?: current.requireAdminToAddFriends,
                    maxMembers = maxMembers ?: current.maxMembers,
                ),
            )
        upsertSettings(next)
        return next
    }

    suspend fun upsertRoom(room: RoomInfo) {
        roomDao.upsertRoom(RoomInfoEntity.fromDomain(room))
    }

    suspend fun replaceRooms(rooms: List<RoomInfo>) {
        roomDao.replaceRooms(rooms.map(RoomInfoEntity::fromDomain))
    }

    suspend fun replaceMembers(roomId: String, members: List<RoomMember>) {
        roomDao.replaceMembers(roomId, members.map { RoomMemberEntity.fromDomain(roomId, it) })
    }

    suspend fun upsertSettings(snapshot: GroupSettingsSnapshot) {
        roomDao.upsertSettings(GroupSettingsEntity.fromDomain(snapshot))
    }

    suspend fun removeRoom(roomId: String) {
        roomDao.removeRoom(roomId)
    }

    suspend fun clear() {
        roomDao.clearAll()
    }

    override suspend fun clearLocalState() {
        clear()
    }
}
