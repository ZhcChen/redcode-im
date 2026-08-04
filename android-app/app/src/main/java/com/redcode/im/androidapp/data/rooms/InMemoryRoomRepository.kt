package com.redcode.im.androidapp.data.rooms

import com.redcode.im.androidapp.core.model.AddMembersResult
import com.redcode.im.androidapp.core.model.GroupOperationLog
import com.redcode.im.androidapp.core.model.GroupRule
import com.redcode.im.androidapp.core.model.GroupSettingsInfo
import com.redcode.im.androidapp.core.model.GroupSettingsSnapshot
import com.redcode.im.androidapp.core.model.RoomInfo
import com.redcode.im.androidapp.core.model.RoomMember
import java.time.Instant
import java.util.UUID
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map

class InMemoryRoomRepository : RoomRepository {
    private val roomsState = MutableStateFlow<List<RoomInfo>>(emptyList())
    private val membersState = MutableStateFlow<Map<String, List<RoomMember>>>(emptyMap())
    private val settingsState = MutableStateFlow<Map<String, GroupSettingsSnapshot>>(emptyMap())
    private val rulesState = MutableStateFlow<Map<String, List<GroupRule>>>(emptyMap())
    private val logsState = MutableStateFlow<Map<String, List<GroupOperationLog>>>(emptyMap())

    override val rooms: Flow<List<RoomInfo>> = roomsState

    override fun members(roomId: String): Flow<List<RoomMember>> =
        membersState.map { it[roomId].orEmpty() }

    override fun settings(roomId: String): Flow<GroupSettingsSnapshot?> =
        settingsState.map { it[roomId] }

    override suspend fun createGroup(name: String, description: String?, memberIds: List<String>): RoomInfo {
        val normalized = name.trim()
        require(normalized.isNotBlank()) { "群名称不能为空" }
        require(memberIds.isNotEmpty()) { "至少选择 1 个成员" }
        val room =
            RoomInfo(
                id = "local-room-${UUID.randomUUID()}",
                name = normalized,
                description = description?.trim()?.takeIf { it.isNotBlank() },
                ownerId = "local-owner",
                createdAt = Instant.now(),
                updatedAt = Instant.now(),
            )
        roomsState.value = roomsState.value + room
        membersState.value =
            membersState.value +
            (
                room.id to
                    listOf(RoomMember(userId = "local-owner", username = "me", role = "owner")) +
                    memberIds.distinct().map { RoomMember(userId = it, username = it, role = "member") }
            )
        settingsState.value = settingsState.value + (room.id to GroupSettingsSnapshot(GroupSettingsInfo(roomId = room.id)))
        appendLog(room.id, "create_group")
        return room
    }

    override suspend fun getRoom(roomId: String): RoomInfo? =
        roomsState.value.firstOrNull { it.id == roomId }

    override suspend fun updateRoom(roomId: String, name: String?, description: String?): RoomInfo {
        val current = getRoom(roomId) ?: error("群聊不存在")
        val updated =
            current.copy(
                name = name?.trim()?.takeIf { it.isNotBlank() } ?: current.name,
                description = description?.trim(),
                updatedAt = Instant.now(),
            )
        roomsState.value = roomsState.value.map { if (it.id == roomId) updated else it }
        appendLog(roomId, "update_group")
        return updated
    }

    override suspend fun dissolveRoom(roomId: String) {
        removeRoom(roomId)
    }

    override suspend fun leaveRoom(roomId: String) {
        removeRoom(roomId)
    }

    override suspend fun refreshMembers(roomId: String): List<RoomMember> =
        membersState.value[roomId].orEmpty()

    override suspend fun addMembers(roomId: String, userIds: List<String>): AddMembersResult {
        val current = membersState.value[roomId].orEmpty()
        val existing = current.map { it.userId }.toSet()
        val added =
            userIds
                .distinct()
                .filterNot { it in existing }
        membersState.value =
            membersState.value + (roomId to current + added.map { RoomMember(userId = it, username = it) })
        appendLog(roomId, "add_members")
        return AddMembersResult(addedUserIds = added, skippedUserIds = userIds.distinct().filter { it in existing })
    }

    override suspend fun removeMember(roomId: String, userId: String) {
        membersState.value =
            membersState.value + (roomId to membersState.value[roomId].orEmpty().filterNot { it.userId == userId })
        appendLog(roomId, "remove_member")
    }

    override suspend fun fetchGroupSettings(roomId: String): GroupSettingsSnapshot =
        settingsState.value[roomId] ?: GroupSettingsSnapshot(GroupSettingsInfo(roomId = roomId)).also {
            settingsState.value = settingsState.value + (roomId to it)
        }

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
        settingsState.value = settingsState.value + (roomId to next)
        appendLog(roomId, "update_group_settings")
        return next
    }

    override suspend fun updateGlobalMute(roomId: String, enabled: Boolean, reason: String?, durationMinutes: Int?): GroupSettingsSnapshot {
        val current = fetchGroupSettings(roomId).settings
        val next =
            GroupSettingsSnapshot(
                current.copy(
                    globalMuteEnabled = enabled,
                    globalMuteReason = if (enabled) reason else null,
                    globalMuteUntil = if (enabled && durationMinutes != null) Instant.now().plusSeconds(durationMinutes * 60L) else null,
                    globalMuteSetBy = if (enabled) "local-owner" else null,
                ),
            )
        settingsState.value = settingsState.value + (roomId to next)
        appendLog(roomId, if (enabled) "enable_global_mute" else "disable_global_mute")
        return next
    }

    override suspend fun listRules(roomId: String): List<GroupRule> =
        rulesState.value[roomId].orEmpty()

    override suspend fun createRule(roomId: String, title: String, content: String): GroupRule {
        val rule =
            GroupRule(
                id = "local-rule-${UUID.randomUUID()}",
                roomId = roomId,
                title = title.trim(),
                content = content.trim(),
                creatorId = "local-owner",
                createdAt = Instant.now(),
                updatedAt = Instant.now(),
            )
        rulesState.value = rulesState.value + (roomId to (rulesState.value[roomId].orEmpty() + rule))
        appendLog(roomId, "create_rule")
        return rule
    }

    override suspend fun updateRule(roomId: String, ruleId: String, title: String?, content: String?, isActive: Boolean?): GroupRule? {
        var updated: GroupRule? = null
        rulesState.value =
            rulesState.value +
            (
                roomId to
                    rulesState.value[roomId].orEmpty().map { rule ->
                        if (rule.id == ruleId) {
                            rule.copy(
                                title = title?.trim()?.takeIf { it.isNotBlank() } ?: rule.title,
                                content = content?.trim()?.takeIf { it.isNotBlank() } ?: rule.content,
                                isActive = isActive ?: rule.isActive,
                                updatedAt = Instant.now(),
                            ).also { updated = it }
                        } else {
                            rule
                        }
                    }
            )
        appendLog(roomId, "update_rule")
        return updated
    }

    override suspend fun deleteRule(roomId: String, ruleId: String) {
        rulesState.value = rulesState.value + (roomId to rulesState.value[roomId].orEmpty().filterNot { it.id == ruleId })
        appendLog(roomId, "delete_rule")
    }

    override suspend fun listOperationLogs(roomId: String, limit: Int, offset: Int): List<GroupOperationLog> =
        logsState.value[roomId].orEmpty().drop(offset.coerceAtLeast(0)).take(limit.coerceIn(1, 100))

    override suspend fun clearLocalState() {
        roomsState.value = emptyList()
        membersState.value = emptyMap()
        settingsState.value = emptyMap()
        rulesState.value = emptyMap()
        logsState.value = emptyMap()
    }

    private fun removeRoom(roomId: String) {
        roomsState.value = roomsState.value.filterNot { it.id == roomId }
        membersState.value = membersState.value - roomId
        settingsState.value = settingsState.value - roomId
        rulesState.value = rulesState.value - roomId
        logsState.value = logsState.value - roomId
    }

    private fun appendLog(roomId: String, operationType: String) {
        val log =
            GroupOperationLog(
                id = "local-log-${UUID.randomUUID()}",
                roomId = roomId,
                operatorId = "local-owner",
                operationType = operationType,
                createdAt = Instant.now(),
            )
        logsState.value = logsState.value + (roomId to (listOf(log) + logsState.value[roomId].orEmpty()))
    }
}
