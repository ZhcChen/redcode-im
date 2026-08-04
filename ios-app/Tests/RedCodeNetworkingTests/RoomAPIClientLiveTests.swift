import XCTest
@testable import RedCodeCore
@testable import RedCodeNetworking

final class RoomAPIClientLiveTests: XCTestCase {
    func testLiveGroupManagementAgainstComposeAPI() async throws {
        guard ProcessInfo.processInfo.environment["RED_CODE_IOS_LIVE_ROOM_SMOKE"] == "1" else {
            throw XCTSkip("Set RED_CODE_IOS_LIVE_ROOM_SMOKE=1 when the local Compose API is running")
        }

        let environment = RedCodeEnvironment.simulatorDevelopment()
        let authClient = AuthAPIClient(environment: environment)
        let roomClient = RoomAPIClient(environment: environment)
        let suffix = UUID().uuidString.lowercased().prefix(8)
        let owner = try await registerAndLogin(authClient: authClient, username: "iosowner\(suffix)")
        let member = try await registerAndLogin(authClient: authClient, username: "iosmember\(suffix)")
        let extra = try await registerAndLogin(authClient: authClient, username: "iosextra\(suffix)")

        let room = try await roomClient.createGroup(
            name: "ios group \(suffix)",
            description: "group management live smoke",
            memberIDs: [member.user.id],
            token: owner.token
        )
        let renamed = try await roomClient.updateRoom(
            roomID: room.id,
            name: "ios renamed \(suffix)",
            description: "updated",
            token: owner.token
        )
        let addResult = try await roomClient.addMembers(
            roomID: room.id,
            userIDs: [extra.user.id],
            token: owner.token
        )
        try await roomClient.updateNotificationSettings(roomID: room.id, notificationSettings: 2, token: owner.token)
        try await roomClient.setRoomPinned(roomID: room.id, pinned: true, token: owner.token)
        let admin = try await roomClient.appointAdmin(roomID: room.id, userID: extra.user.id, token: owner.token)
        let mute = try await roomClient.muteUser(
            roomID: room.id,
            userID: member.user.id,
            reason: "live smoke",
            muteDurationHours: 1,
            token: owner.token
        )
        let rule = try await roomClient.createRule(
            roomID: room.id,
            title: "Live Rule \(suffix)",
            content: "Keep the group deterministic",
            token: owner.token
        )
        let updatedRule = try await roomClient.updateRule(
            roomID: room.id,
            ruleID: rule.id,
            title: nil,
            content: nil,
            isActive: false,
            token: owner.token
        )

        let members = try await roomClient.listMembers(roomID: room.id, token: owner.token)
        let settings = try await roomClient.fetchGroupSettings(roomID: room.id, token: owner.token)
        let admins = try await roomClient.listAdmins(roomID: room.id, token: owner.token)
        let mutes = try await roomClient.listMutes(roomID: room.id, token: owner.token)
        let rules = try await roomClient.listRules(roomID: room.id, token: owner.token)
        let logs = try await roomClient.listOperationLogs(roomID: room.id, limit: 20, offset: 0, token: owner.token)

        XCTAssertEqual(room.roomType, "group")
        XCTAssertEqual(renamed.name, "ios renamed \(suffix)")
        XCTAssertTrue(addResult.addedUserIDs.contains(extra.user.id))
        XCTAssertTrue(members.contains { $0.userID == owner.user.id && $0.role == "owner" })
        XCTAssertTrue(members.contains { $0.userID == member.user.id })
        XCTAssertEqual(settings.settings.roomID, room.id)
        XCTAssertEqual(admin.adminID, extra.user.id)
        XCTAssertTrue(admins.contains { $0.adminID == extra.user.id })
        XCTAssertEqual(mute.userID, member.user.id)
        XCTAssertTrue(mutes.contains { $0.userID == member.user.id })
        XCTAssertFalse(updatedRule.isActive)
        XCTAssertTrue(rules.contains { $0.id == rule.id })
        XCTAssertFalse(logs.isEmpty)

        try await roomClient.unmuteUser(roomID: room.id, userID: member.user.id, token: owner.token)
        try await roomClient.removeAdmin(roomID: room.id, adminID: extra.user.id, token: owner.token)
        try await roomClient.deleteRule(roomID: room.id, ruleID: rule.id, token: owner.token)
        try await roomClient.leaveRoom(roomID: room.id, token: extra.token)
        try await roomClient.dissolveRoom(roomID: room.id, token: owner.token)
    }

    private func registerAndLogin(authClient: AuthAPIClient, username: String) async throws -> AuthSession {
        let password = "secret123"
        _ = try await authClient.register(username: username, password: password, nickname: username)
        return try await authClient.login(username: username, password: password)
    }
}
