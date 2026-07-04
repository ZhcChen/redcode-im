import Foundation
import RedCodeCore

public protocol RoomAPIService: Sendable {
    func createGroup(
        name: String,
        description: String?,
        memberIDs: [String],
        token: String
    ) async throws -> RoomInfo
    func listRooms(token: String) async throws -> [RoomInfo]
    func getRoom(roomID: String, token: String) async throws -> RoomInfo
    func updateRoom(roomID: String, name: String?, description: String?, token: String) async throws -> RoomInfo
    func dissolveRoom(roomID: String, token: String) async throws
    func leaveRoom(roomID: String, token: String) async throws
    func listMembers(roomID: String, token: String) async throws -> [RoomMember]
    func addMembers(roomID: String, userIDs: [String], token: String) async throws -> AddMembersResult
    func removeMember(roomID: String, userID: String, token: String) async throws
    func fetchGroupSettings(roomID: String, token: String) async throws -> GroupSettingsSnapshot
    func updateGroupSettings(
        roomID: String,
        request: UpdateGroupSettingsRequest,
        token: String
    ) async throws -> GroupSettingsSnapshot
    func updateGlobalMute(
        roomID: String,
        enabled: Bool,
        reason: String?,
        durationMinutes: Int?,
        token: String
    ) async throws -> GroupSettingsSnapshot
    func updateNotificationSettings(roomID: String, notificationSettings: Int, token: String) async throws
    func setRoomPinned(roomID: String, pinned: Bool, token: String) async throws
    func listAdmins(roomID: String, token: String) async throws -> [GroupAdmin]
    func appointAdmin(roomID: String, userID: String, token: String) async throws -> GroupAdmin
    func removeAdmin(roomID: String, adminID: String, token: String) async throws
    func listMutes(roomID: String, token: String) async throws -> [GroupMute]
    func muteUser(
        roomID: String,
        userID: String,
        reason: String?,
        muteDurationHours: Int?,
        token: String
    ) async throws -> GroupMute
    func unmuteUser(roomID: String, userID: String, token: String) async throws
    func listRules(roomID: String, token: String) async throws -> [GroupRule]
    func createRule(roomID: String, title: String, content: String, token: String) async throws -> GroupRule
    func updateRule(
        roomID: String,
        ruleID: String,
        title: String?,
        content: String?,
        isActive: Bool?,
        token: String
    ) async throws -> GroupRule
    func deleteRule(roomID: String, ruleID: String, token: String) async throws
    func listJoinRequests(roomID: String, token: String) async throws -> [GroupJoinRequest]
    func createJoinRequest(roomID: String, message: String?, token: String) async throws -> GroupJoinRequest
    func reviewJoinRequest(
        roomID: String,
        requestID: String,
        status: JoinRequestStatus,
        reviewMessage: String?,
        token: String
    ) async throws -> GroupJoinRequest
    func listOperationLogs(roomID: String, limit: Int, offset: Int, token: String) async throws -> [GroupOperationLog]
    func getGroupDetail(roomID: String, token: String) async throws -> GroupDetailInfo
}

public struct RoomAPIClient: RoomAPIService {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public init(environment: RedCodeEnvironment) {
        self.apiClient = APIClient(environment: environment)
    }

    public func createGroup(
        name: String,
        description: String? = nil,
        memberIDs: [String],
        token: String
    ) async throws -> RoomInfo {
        let request = CreateGroupRoomRequest(
            name: name,
            description: description,
            memberIDs: memberIDs
        )
        let response = try await apiClient.post(
            RoomAPIEndpoint.rooms,
            body: request,
            bearerToken: token,
            as: CreateRoomResponse.self
        )
        return response.room
    }

    public func listRooms(token: String) async throws -> [RoomInfo] {
        try await apiClient.get(
            RoomAPIEndpoint.listRooms,
            bearerToken: token,
            as: [RoomInfo].self
        )
    }

    public func getRoom(roomID: String, token: String) async throws -> RoomInfo {
        let response = try await apiClient.get(
            RoomAPIEndpoint.room(roomID),
            bearerToken: token,
            as: RoomDetailResponse.self
        )
        return response.room
    }

    public func updateRoom(
        roomID: String,
        name: String? = nil,
        description: String? = nil,
        token: String
    ) async throws -> RoomInfo {
        let response = try await apiClient.post(
            RoomAPIEndpoint.room(roomID, method: .patch),
            body: UpdateRoomRequest(name: name, description: description),
            bearerToken: token,
            as: UpdateRoomResponse.self
        )
        if let room = response.room {
            return room
        }
        return try await getRoom(roomID: roomID, token: token)
    }

    public func dissolveRoom(roomID: String, token: String) async throws {
        try await apiClient.deleteNoResponse(
            RoomAPIEndpoint.room(roomID, method: .delete),
            bearerToken: token
        )
    }

    public func leaveRoom(roomID: String, token: String) async throws {
        try await apiClient.postNoResponse(
            RoomAPIEndpoint.leave(roomID: roomID),
            bearerToken: token
        )
    }

    public func listMembers(roomID: String, token: String) async throws -> [RoomMember] {
        try await apiClient.get(
            RoomAPIEndpoint.members(roomID: roomID),
            bearerToken: token,
            as: [RoomMember].self
        )
    }

    public func addMembers(roomID: String, userIDs: [String], token: String) async throws -> AddMembersResult {
        try await apiClient.post(
            RoomAPIEndpoint.addMembers(roomID: roomID),
            body: AddGroupMembersRequest(userIDs: userIDs),
            bearerToken: token,
            as: AddMembersResult.self
        )
    }

    public func removeMember(roomID: String, userID: String, token: String) async throws {
        try await apiClient.deleteNoResponse(
            RoomAPIEndpoint.member(roomID: roomID, userID: userID),
            bearerToken: token
        )
    }

    public func fetchGroupSettings(roomID: String, token: String) async throws -> GroupSettingsSnapshot {
        let response = try await apiClient.get(
            RoomAPIEndpoint.settings(roomID: roomID),
            bearerToken: token,
            as: GroupSettingsResponse.self
        )
        return GroupSettingsSnapshot(settings: response.settings, myMute: response.myMute)
    }

    public func updateGroupSettings(
        roomID: String,
        request: UpdateGroupSettingsRequest,
        token: String
    ) async throws -> GroupSettingsSnapshot {
        let response = try await apiClient.post(
            RoomAPIEndpoint.settings(roomID: roomID, method: .patch),
            body: request,
            bearerToken: token,
            as: GroupSettingsResponse.self
        )
        return GroupSettingsSnapshot(settings: response.settings, myMute: response.myMute)
    }

    public func updateGlobalMute(
        roomID: String,
        enabled: Bool,
        reason: String? = nil,
        durationMinutes: Int? = nil,
        token: String
    ) async throws -> GroupSettingsSnapshot {
        let response = try await apiClient.post(
            RoomAPIEndpoint.globalMute(roomID: roomID),
            body: UpdateGlobalMuteRequest(
                enabled: enabled,
                reason: reason,
                durationMinutes: durationMinutes
            ),
            bearerToken: token,
            as: GroupSettingsResponse.self
        )
        return GroupSettingsSnapshot(settings: response.settings, myMute: response.myMute)
    }

    public func updateNotificationSettings(
        roomID: String,
        notificationSettings: Int,
        token: String
    ) async throws {
        try await apiClient.postNoResponse(
            RoomAPIEndpoint.notificationSettings(roomID: roomID),
            body: UpdateNotificationSettingsRequest(notificationSettings: notificationSettings),
            bearerToken: token
        )
    }

    public func setRoomPinned(roomID: String, pinned: Bool, token: String) async throws {
        try await apiClient.sendRoomPin(roomID: roomID, pinned: pinned, token: token)
    }

    public func listAdmins(roomID: String, token: String) async throws -> [GroupAdmin] {
        let response = try await apiClient.get(
            RoomAPIEndpoint.admins(roomID: roomID),
            bearerToken: token,
            as: ListAdminsResponse.self
        )
        return response.admins
    }

    public func appointAdmin(roomID: String, userID: String, token: String) async throws -> GroupAdmin {
        let response = try await apiClient.post(
            RoomAPIEndpoint.admins(roomID: roomID, method: .post),
            body: AppointAdminRequest(userID: userID),
            bearerToken: token,
            as: AppointAdminResponse.self
        )
        return response.admin
    }

    public func removeAdmin(roomID: String, adminID: String, token: String) async throws {
        try await apiClient.deleteNoResponse(
            RoomAPIEndpoint.admin(roomID: roomID, adminID: adminID),
            bearerToken: token
        )
    }

    public func listMutes(roomID: String, token: String) async throws -> [GroupMute] {
        let response = try await apiClient.get(
            RoomAPIEndpoint.mutes(roomID: roomID),
            bearerToken: token,
            as: ListMutedUsersResponse.self
        )
        return response.mutes
    }

    public func muteUser(
        roomID: String,
        userID: String,
        reason: String? = nil,
        muteDurationHours: Int? = nil,
        token: String
    ) async throws -> GroupMute {
        let response = try await apiClient.post(
            RoomAPIEndpoint.mutes(roomID: roomID, method: .post),
            body: MuteUserRequest(userID: userID, reason: reason, muteDurationHours: muteDurationHours),
            bearerToken: token,
            as: MuteUserResponse.self
        )
        return response.mute
    }

    public func unmuteUser(roomID: String, userID: String, token: String) async throws {
        try await apiClient.deleteNoResponse(
            RoomAPIEndpoint.mute(roomID: roomID, mutedUserID: userID),
            bearerToken: token
        )
    }

    public func listRules(roomID: String, token: String) async throws -> [GroupRule] {
        let response = try await apiClient.get(
            RoomAPIEndpoint.rules(roomID: roomID),
            bearerToken: token,
            as: ListRulesResponse.self
        )
        return response.rules
    }

    public func createRule(roomID: String, title: String, content: String, token: String) async throws -> GroupRule {
        let response = try await apiClient.post(
            RoomAPIEndpoint.rules(roomID: roomID, method: .post),
            body: CreateRuleRequest(title: title, content: content),
            bearerToken: token,
            as: CreateRuleResponse.self
        )
        return response.rule
    }

    public func updateRule(
        roomID: String,
        ruleID: String,
        title: String? = nil,
        content: String? = nil,
        isActive: Bool? = nil,
        token: String
    ) async throws -> GroupRule {
        let response = try await apiClient.post(
            RoomAPIEndpoint.rule(roomID: roomID, ruleID: ruleID, method: .patch),
            body: UpdateRuleRequest(title: title, content: content, isActive: isActive),
            bearerToken: token,
            as: CreateRuleResponse.self
        )
        return response.rule
    }

    public func deleteRule(roomID: String, ruleID: String, token: String) async throws {
        try await apiClient.deleteNoResponse(
            RoomAPIEndpoint.rule(roomID: roomID, ruleID: ruleID, method: .delete),
            bearerToken: token
        )
    }

    public func listJoinRequests(roomID: String, token: String) async throws -> [GroupJoinRequest] {
        let response = try await apiClient.get(
            RoomAPIEndpoint.joinRequests(roomID: roomID),
            bearerToken: token,
            as: ListJoinRequestsResponse.self
        )
        return response.requests
    }

    public func createJoinRequest(roomID: String, message: String? = nil, token: String) async throws -> GroupJoinRequest {
        let response = try await apiClient.post(
            RoomAPIEndpoint.joinRequests(roomID: roomID, method: .post),
            body: CreateJoinRequestRequest(message: message),
            bearerToken: token,
            as: CreateJoinRequestResponse.self
        )
        return response.request
    }

    public func reviewJoinRequest(
        roomID: String,
        requestID: String,
        status: JoinRequestStatus,
        reviewMessage: String? = nil,
        token: String
    ) async throws -> GroupJoinRequest {
        let response = try await apiClient.post(
            RoomAPIEndpoint.reviewJoinRequest(roomID: roomID, requestID: requestID),
            body: ReviewJoinRequestRequest(status: status, reviewMessage: reviewMessage),
            bearerToken: token,
            as: CreateJoinRequestResponse.self
        )
        return response.request
    }

    public func listOperationLogs(
        roomID: String,
        limit: Int = 20,
        offset: Int = 0,
        token: String
    ) async throws -> [GroupOperationLog] {
        let response = try await apiClient.get(
            RoomAPIEndpoint.operationLogs(roomID: roomID, limit: limit, offset: offset),
            bearerToken: token,
            as: ListOperationLogsResponse.self
        )
        return response.logs
    }

    public func getGroupDetail(roomID: String, token: String) async throws -> GroupDetailInfo {
        let response = try await apiClient.get(
            RoomAPIEndpoint.detail(roomID: roomID),
            bearerToken: token,
            as: GroupDetailResponse.self
        )
        return response.info
    }
}

private extension APIClient {
    func sendRoomPin(roomID: String, pinned: Bool, token: String) async throws {
        let endpoint = RoomAPIEndpoint.pin(roomID: roomID, method: pinned ? .post : .delete)
        if pinned {
            try await postNoResponse(endpoint, bearerToken: token)
        } else {
            try await deleteNoResponse(endpoint, bearerToken: token)
        }
    }
}
