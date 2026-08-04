package com.redcode.im.androidapp.data.rooms

interface RoomRemoteDataSource {
    suspend fun createGroup(name: String, description: String?, memberIds: List<String>, token: String): BackendRoomInfo

    suspend fun listRooms(token: String): List<BackendRoomInfo>

    suspend fun getRoom(roomId: String, token: String): BackendRoomInfo

    suspend fun updateRoom(roomId: String, name: String?, description: String?, token: String): BackendRoomInfo

    suspend fun dissolveRoom(roomId: String, token: String)

    suspend fun leaveRoom(roomId: String, token: String)

    suspend fun listMembers(roomId: String, token: String): List<BackendRoomMember>

    suspend fun addMembers(roomId: String, userIds: List<String>, token: String): AddGroupMembersResponse

    suspend fun removeMember(roomId: String, userId: String, token: String)

    suspend fun fetchGroupSettings(roomId: String, token: String): GroupSettingsResponse

    suspend fun updateGroupSettings(roomId: String, request: UpdateGroupSettingsRequest, token: String): GroupSettingsResponse

    suspend fun updateGlobalMute(roomId: String, enabled: Boolean, reason: String?, durationMinutes: Int?, token: String): GroupSettingsResponse

    suspend fun updateNotificationSettings(roomId: String, notificationSettings: Int, token: String)

    suspend fun setRoomPinned(roomId: String, pinned: Boolean, token: String)

    suspend fun listAdmins(roomId: String, token: String): List<BackendGroupAdmin>

    suspend fun appointAdmin(roomId: String, userId: String, token: String): BackendGroupAdmin

    suspend fun removeAdmin(roomId: String, adminId: String, token: String)

    suspend fun listMutes(roomId: String, token: String): List<BackendGroupMute>

    suspend fun muteUser(roomId: String, userId: String, reason: String?, muteDurationHours: Int?, token: String): BackendGroupMute

    suspend fun unmuteUser(roomId: String, userId: String, token: String)

    suspend fun listRules(roomId: String, token: String): List<BackendGroupRule>

    suspend fun createRule(roomId: String, title: String, content: String, token: String): BackendGroupRule

    suspend fun updateRule(roomId: String, ruleId: String, title: String?, content: String?, isActive: Boolean?, token: String): BackendGroupRule

    suspend fun deleteRule(roomId: String, ruleId: String, token: String)

    suspend fun listJoinRequests(roomId: String, token: String): List<BackendGroupJoinRequest>

    suspend fun createJoinRequest(roomId: String, message: String?, token: String): BackendGroupJoinRequest

    suspend fun reviewJoinRequest(roomId: String, requestId: String, status: String, reviewMessage: String?, token: String): BackendGroupJoinRequest

    suspend fun listOperationLogs(roomId: String, limit: Int, offset: Int, token: String): List<BackendGroupOperationLog>
}
