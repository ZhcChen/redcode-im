package com.redcode.im.androidapp.data.rooms

import com.redcode.im.androidapp.network.APIClient
import com.redcode.im.androidapp.network.HTTPMethod
import kotlinx.serialization.json.JsonObject

class HttpRoomRemoteDataSource(
    private val apiClient: APIClient,
) : RoomRemoteDataSource {
    override suspend fun createGroup(name: String, description: String?, memberIds: List<String>, token: String): BackendRoomInfo =
        apiClient
            .post<CreateGroupRoomRequest, CreateRoomResponse>(
                RoomAPIEndpoint.createRoom,
                CreateGroupRoomRequest(
                    name = name.trim(),
                    description = description?.trim()?.takeIf { it.isNotBlank() },
                    memberIds = memberIds,
                ),
                bearerToken = token,
            )
            .room

    override suspend fun listRooms(token: String): List<BackendRoomInfo> =
        apiClient.get(RoomAPIEndpoint.listRooms, bearerToken = token)

    override suspend fun getRoom(roomId: String, token: String): BackendRoomInfo =
        apiClient.get<RoomDetailResponse>(RoomAPIEndpoint.room(roomId), bearerToken = token).room

    override suspend fun updateRoom(roomId: String, name: String?, description: String?, token: String): BackendRoomInfo =
        apiClient
            .patch<UpdateRoomRequest, UpdateRoomResponse>(
                RoomAPIEndpoint.room(roomId, HTTPMethod.PATCH),
                UpdateRoomRequest(
                    name = name?.trim()?.takeIf { it.isNotBlank() },
                    description = description?.trim(),
                ),
                bearerToken = token,
            )
            .room
            ?: getRoom(roomId, token)

    override suspend fun dissolveRoom(roomId: String, token: String) {
        apiClient.send<JsonObject>(RoomAPIEndpoint.room(roomId, HTTPMethod.DELETE), bearerToken = token)
    }

    override suspend fun leaveRoom(roomId: String, token: String) {
        apiClient.send<JsonObject>(RoomAPIEndpoint.leave(roomId), bearerToken = token)
    }

    override suspend fun listMembers(roomId: String, token: String): List<BackendRoomMember> =
        apiClient.get(RoomAPIEndpoint.members(roomId), bearerToken = token)

    override suspend fun addMembers(roomId: String, userIds: List<String>, token: String): AddGroupMembersResponse =
        apiClient.post(
            RoomAPIEndpoint.addMembers(roomId),
            AddGroupMembersRequest(userIds = userIds),
            bearerToken = token,
        )

    override suspend fun removeMember(roomId: String, userId: String, token: String) {
        apiClient.send<JsonObject>(RoomAPIEndpoint.member(roomId, userId), bearerToken = token)
    }

    override suspend fun fetchGroupSettings(roomId: String, token: String): GroupSettingsResponse =
        apiClient.get(RoomAPIEndpoint.settings(roomId), bearerToken = token)

    override suspend fun updateGroupSettings(roomId: String, request: UpdateGroupSettingsRequest, token: String): GroupSettingsResponse =
        apiClient.patch(RoomAPIEndpoint.settings(roomId, HTTPMethod.PATCH), request, bearerToken = token)

    override suspend fun updateGlobalMute(roomId: String, enabled: Boolean, reason: String?, durationMinutes: Int?, token: String): GroupSettingsResponse =
        apiClient.post(
            RoomAPIEndpoint.globalMute(roomId),
            UpdateGlobalMuteRequest(enabled = enabled, reason = reason, durationMinutes = durationMinutes),
            bearerToken = token,
        )

    override suspend fun updateNotificationSettings(roomId: String, notificationSettings: Int, token: String) {
        apiClient.post<UpdateNotificationSettingsRequest, JsonObject>(
            RoomAPIEndpoint.notificationSettings(roomId),
            UpdateNotificationSettingsRequest(notificationSettings),
            bearerToken = token,
        )
    }

    override suspend fun setRoomPinned(roomId: String, pinned: Boolean, token: String) {
        apiClient.send<JsonObject>(RoomAPIEndpoint.pin(roomId, pinned), bearerToken = token)
    }

    override suspend fun listAdmins(roomId: String, token: String): List<BackendGroupAdmin> =
        apiClient.get<ListAdminsResponse>(RoomAPIEndpoint.admins(roomId), bearerToken = token).admins

    override suspend fun appointAdmin(roomId: String, userId: String, token: String): BackendGroupAdmin =
        apiClient
            .post<AppointAdminRequest, AppointAdminResponse>(
                RoomAPIEndpoint.admins(roomId, HTTPMethod.POST),
                AppointAdminRequest(userId = userId),
                bearerToken = token,
            )
            .admin

    override suspend fun removeAdmin(roomId: String, adminId: String, token: String) {
        apiClient.sendNoResponse(RoomAPIEndpoint.admin(roomId, adminId), bearerToken = token)
    }

    override suspend fun listMutes(roomId: String, token: String): List<BackendGroupMute> =
        apiClient.get<ListMutedUsersResponse>(RoomAPIEndpoint.mutes(roomId), bearerToken = token).mutes

    override suspend fun muteUser(roomId: String, userId: String, reason: String?, muteDurationHours: Int?, token: String): BackendGroupMute =
        apiClient
            .post<MuteUserRequest, MuteUserResponse>(
                RoomAPIEndpoint.mutes(roomId, HTTPMethod.POST),
                MuteUserRequest(userId = userId, reason = reason, muteDurationHours = muteDurationHours),
                bearerToken = token,
            )
            .mute

    override suspend fun unmuteUser(roomId: String, userId: String, token: String) {
        apiClient.sendNoResponse(RoomAPIEndpoint.mute(roomId, userId), bearerToken = token)
    }

    override suspend fun listRules(roomId: String, token: String): List<BackendGroupRule> =
        apiClient.get<ListRulesResponse>(RoomAPIEndpoint.rules(roomId), bearerToken = token).rules

    override suspend fun createRule(roomId: String, title: String, content: String, token: String): BackendGroupRule =
        apiClient
            .post<CreateRuleRequest, CreateRuleResponse>(
                RoomAPIEndpoint.rules(roomId, HTTPMethod.POST),
                CreateRuleRequest(title = title.trim(), content = content.trim()),
                bearerToken = token,
            )
            .rule

    override suspend fun updateRule(
        roomId: String,
        ruleId: String,
        title: String?,
        content: String?,
        isActive: Boolean?,
        token: String,
    ): BackendGroupRule =
        apiClient
            .patch<UpdateRuleRequest, CreateRuleResponse>(
                RoomAPIEndpoint.rule(roomId, ruleId, HTTPMethod.PATCH),
                UpdateRuleRequest(
                    title = title?.trim()?.takeIf { it.isNotBlank() },
                    content = content?.trim()?.takeIf { it.isNotBlank() },
                    isActive = isActive,
                ),
                bearerToken = token,
            )
            .rule

    override suspend fun deleteRule(roomId: String, ruleId: String, token: String) {
        apiClient.sendNoResponse(RoomAPIEndpoint.rule(roomId, ruleId, HTTPMethod.DELETE), bearerToken = token)
    }

    override suspend fun listJoinRequests(roomId: String, token: String): List<BackendGroupJoinRequest> =
        apiClient.get<ListJoinRequestsResponse>(RoomAPIEndpoint.joinRequests(roomId), bearerToken = token).requests

    override suspend fun createJoinRequest(roomId: String, message: String?, token: String): BackendGroupJoinRequest =
        apiClient
            .post<CreateJoinRequestRequest, CreateJoinRequestResponse>(
                RoomAPIEndpoint.joinRequests(roomId, HTTPMethod.POST),
                CreateJoinRequestRequest(message = message),
                bearerToken = token,
            )
            .request

    override suspend fun reviewJoinRequest(roomId: String, requestId: String, status: String, reviewMessage: String?, token: String): BackendGroupJoinRequest =
        apiClient
            .patch<ReviewJoinRequestRequest, CreateJoinRequestResponse>(
                RoomAPIEndpoint.reviewJoinRequest(roomId, requestId),
                ReviewJoinRequestRequest(status = status, reviewMessage = reviewMessage),
                bearerToken = token,
            )
            .request

    override suspend fun listOperationLogs(roomId: String, limit: Int, offset: Int, token: String): List<BackendGroupOperationLog> =
        apiClient.get<ListOperationLogsResponse>(
            RoomAPIEndpoint.operationLogs(roomId, limit = limit, offset = offset),
            bearerToken = token,
        ).logs
}
