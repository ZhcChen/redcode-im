import XCTest
@testable import RedCodeFeatures
@testable import RedCodeNetworking
@testable import RedCodeStorage

@MainActor
final class GroupManagementControllerTests: XCTestCase {
    func testCreateGroupPersistsGroupAndReturnsChatSummary() async throws {
        let cache = SwiftDataGroupCacheStore(
            container: try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        )
        let api = MockRoomAPIService(
            createdRoom: RoomInfo(
                id: "room-1",
                name: "Team",
                roomType: "group",
                avatarObjectKey: "rooms/room-1/avatar.png",
                ownerID: "user-1"
            )
        )
        let controller = GroupManagementController(api: api, cacheStore: cache)

        let chat = try await controller.createGroup(
            name: " Team ",
            description: " smoke ",
            memberIDs: ["user-2", "user-3"],
            token: "access-token"
        )

        XCTAssertEqual(chat.roomID, "room-1")
        XCTAssertEqual(chat.displayName, "Team")
        XCTAssertEqual(chat.roomType, ChatType.group)
        XCTAssertEqual(chat.avatarObjectKey, "rooms/room-1/avatar.png")
        XCTAssertEqual(controller.groups.map { $0.roomID }, ["room-1"])
        XCTAssertEqual(try cache.loadGroups().map(\.roomID), ["room-1"])
        let calls = await api.recordedCalls()
        XCTAssertEqual(calls, [
            .createGroup(name: " Team ", description: " smoke ", memberIDs: ["user-2", "user-3"], token: "access-token"),
        ])
    }

    func testLoadGroupBundleLoadsRoomMembersSettingsAndCurrentRole() async throws {
        let cache = SwiftDataGroupCacheStore(
            container: try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        )
        let api = MockRoomAPIService(
            room: RoomInfo(id: "room-1", name: "Team", roomType: "group", ownerID: "owner"),
            members: [
                RoomMember(userID: "member", username: "member", role: "member"),
                RoomMember(userID: "me", username: "me", nickname: "Me", role: "admin"),
                RoomMember(userID: "owner", username: "owner", role: "owner"),
            ],
            settings: GroupSettingsSnapshot(
                settings: GroupSettingsInfo(roomID: "room-1", joinApprovalRequired: true, maxMembers: 100)
            )
        )
        let controller = GroupManagementController(api: api, cacheStore: cache)

        try await controller.loadGroupBundle(roomID: "room-1", token: "access-token", currentUserID: "me")

        XCTAssertEqual(controller.currentGroup?.name, "Team")
        XCTAssertEqual(controller.currentGroup?.currentUserRole, "admin")
        XCTAssertTrue(controller.canManage(currentUserID: "me"))
        XCTAssertEqual(controller.members.map(\.userID), ["owner", "me", "member"])
        XCTAssertEqual(controller.settingsSnapshot?.settings.maxMembers, 100)
        XCTAssertEqual(try cache.loadGroups().first?.currentUserRole, "admin")
    }

    func testRenameRollsBackWhenAPIRequestFails() async throws {
        let cache = SwiftDataGroupCacheStore(
            container: try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        )
        let api = MockRoomAPIService(
            room: RoomInfo(id: "room-1", name: "Old", roomType: "group", ownerID: "owner"),
            updateRoomError: TestFailure.updateFailed
        )
        let controller = GroupManagementController(api: api, cacheStore: cache)
        try await controller.loadGroupBundle(roomID: "room-1", token: "access-token", currentUserID: "owner")

        do {
            _ = try await controller.renameGroup(
                roomID: "room-1",
                name: "New",
                description: nil,
                token: "access-token"
            )
            XCTFail("Expected update failure")
        } catch TestFailure.updateFailed {
            // expected
        }

        XCTAssertEqual(controller.currentGroup?.name, "Old")
        XCTAssertNotNil(controller.errorMessage)
    }

    func testManagementActionsMutateLocalStateAfterSuccessfulCalls() async throws {
        let cache = SwiftDataGroupCacheStore(
            container: try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        )
        let api = MockRoomAPIService(
            admin: GroupAdmin(id: "admin-row", roomID: "room-1", adminID: "user-2", appointedBy: "owner"),
            mute: GroupMute(id: "mute-row", roomID: "room-1", userID: "user-3", mutedBy: "owner"),
            rule: GroupRule(id: "rule-1", roomID: "room-1", title: "Rule", content: "Be nice", creatorID: "owner"),
            joinRequest: GroupJoinRequest(id: "join-1", roomID: "room-1", applicantID: "user-4")
        )
        let controller = GroupManagementController(api: api, cacheStore: cache)

        try await controller.appointAdmin(roomID: "room-1", userID: "user-2", token: "access-token")
        try await controller.muteUser(roomID: "room-1", userID: "user-3", reason: "quiet", hours: 24, token: "access-token")
        try await controller.createRule(roomID: "room-1", title: "Rule", content: "Be nice", token: "access-token")
        try await controller.reviewJoinRequest(
            roomID: "room-1",
            requestID: "join-1",
            status: .approved,
            reviewMessage: nil,
            token: "access-token"
        )

        XCTAssertEqual(controller.admins.map(\.adminID), ["user-2"])
        XCTAssertEqual(controller.mutes.map(\.userID), ["user-3"])
        XCTAssertEqual(controller.rules.map(\.id), ["rule-1"])
        XCTAssertEqual(controller.joinRequests.map(\.status), [.approved])
    }
}

private enum RoomAPICall: Equatable, Sendable {
    case createGroup(name: String, description: String?, memberIDs: [String], token: String)
}

private enum TestFailure: Error {
    case updateFailed
}

private actor MockRoomAPIService: RoomAPIService {
    private(set) var calls: [RoomAPICall] = []

    private let createdRoom: RoomInfo
    private let room: RoomInfo
    private let members: [RoomMember]
    private let settings: GroupSettingsSnapshot
    private let admin: GroupAdmin
    private let mute: GroupMute
    private let rule: GroupRule
    private let joinRequest: GroupJoinRequest
    private let updateRoomError: Error?

    init(
        createdRoom: RoomInfo = RoomInfo(id: "created-room", name: "Created", roomType: "group"),
        room: RoomInfo = RoomInfo(id: "room-1", name: "Team", roomType: "group", ownerID: "owner"),
        members: [RoomMember] = [],
        settings: GroupSettingsSnapshot = GroupSettingsSnapshot(settings: GroupSettingsInfo(roomID: "room-1")),
        admin: GroupAdmin = GroupAdmin(id: "admin", roomID: "room-1", adminID: "admin-user", appointedBy: "owner"),
        mute: GroupMute = GroupMute(id: "mute", roomID: "room-1", userID: "muted-user", mutedBy: "owner"),
        rule: GroupRule = GroupRule(id: "rule", roomID: "room-1", title: "Rule", content: "content", creatorID: "owner"),
        joinRequest: GroupJoinRequest = GroupJoinRequest(id: "join", roomID: "room-1", applicantID: "applicant"),
        updateRoomError: Error? = nil
    ) {
        self.createdRoom = createdRoom
        self.room = room
        self.members = members
        self.settings = settings
        self.admin = admin
        self.mute = mute
        self.rule = rule
        self.joinRequest = joinRequest
        self.updateRoomError = updateRoomError
    }

    func recordedCalls() -> [RoomAPICall] {
        calls
    }

    func createGroup(name: String, description: String?, memberIDs: [String], token: String) async throws -> RoomInfo {
        calls.append(.createGroup(name: name, description: description, memberIDs: memberIDs, token: token))
        return createdRoom
    }

    func listRooms(token: String) async throws -> [RoomInfo] {
        [room]
    }

    func getRoom(roomID: String, token: String) async throws -> RoomInfo {
        room
    }

    func updateRoom(roomID: String, name: String?, description: String?, token: String) async throws -> RoomInfo {
        if let updateRoomError {
            throw updateRoomError
        }
        return RoomInfo(id: roomID, name: name ?? room.name, roomType: "group", ownerID: room.ownerID)
    }

    func dissolveRoom(roomID: String, token: String) async throws {}

    func leaveRoom(roomID: String, token: String) async throws {}

    func listMembers(roomID: String, token: String) async throws -> [RoomMember] {
        members
    }

    func addMembers(roomID: String, userIDs: [String], token: String) async throws -> AddMembersResult {
        AddMembersResult(addedUserIDs: userIDs)
    }

    func removeMember(roomID: String, userID: String, token: String) async throws {}

    func fetchGroupSettings(roomID: String, token: String) async throws -> GroupSettingsSnapshot {
        settings
    }

    func updateGroupSettings(
        roomID: String,
        request: UpdateGroupSettingsRequest,
        token: String
    ) async throws -> GroupSettingsSnapshot {
        settings
    }

    func updateGlobalMute(
        roomID: String,
        enabled: Bool,
        reason: String?,
        durationMinutes: Int?,
        token: String
    ) async throws -> GroupSettingsSnapshot {
        GroupSettingsSnapshot(settings: GroupSettingsInfo(roomID: roomID, globalMuteEnabled: enabled))
    }

    func updateNotificationSettings(roomID: String, notificationSettings: Int, token: String) async throws {}

    func setRoomPinned(roomID: String, pinned: Bool, token: String) async throws {}

    func listAdmins(roomID: String, token: String) async throws -> [GroupAdmin] {
        []
    }

    func appointAdmin(roomID: String, userID: String, token: String) async throws -> GroupAdmin {
        admin
    }

    func removeAdmin(roomID: String, adminID: String, token: String) async throws {}

    func listMutes(roomID: String, token: String) async throws -> [GroupMute] {
        []
    }

    func muteUser(
        roomID: String,
        userID: String,
        reason: String?,
        muteDurationHours: Int?,
        token: String
    ) async throws -> GroupMute {
        mute
    }

    func unmuteUser(roomID: String, userID: String, token: String) async throws {}

    func listRules(roomID: String, token: String) async throws -> [GroupRule] {
        []
    }

    func createRule(roomID: String, title: String, content: String, token: String) async throws -> GroupRule {
        rule
    }

    func updateRule(
        roomID: String,
        ruleID: String,
        title: String?,
        content: String?,
        isActive: Bool?,
        token: String
    ) async throws -> GroupRule {
        rule
    }

    func deleteRule(roomID: String, ruleID: String, token: String) async throws {}

    func listJoinRequests(roomID: String, token: String) async throws -> [GroupJoinRequest] {
        []
    }

    func createJoinRequest(roomID: String, message: String?, token: String) async throws -> GroupJoinRequest {
        joinRequest
    }

    func reviewJoinRequest(
        roomID: String,
        requestID: String,
        status: JoinRequestStatus,
        reviewMessage: String?,
        token: String
    ) async throws -> GroupJoinRequest {
        GroupJoinRequest(
            id: joinRequest.id,
            roomID: joinRequest.roomID,
            applicantID: joinRequest.applicantID,
            message: joinRequest.message,
            status: status,
            reviewerID: "owner"
        )
    }

    func listOperationLogs(roomID: String, limit: Int, offset: Int, token: String) async throws -> [GroupOperationLog] {
        []
    }

    func getGroupDetail(roomID: String, token: String) async throws -> GroupDetailInfo {
        GroupDetailInfo(id: roomID, name: room.name, ownerID: room.ownerID ?? "owner")
    }
}
