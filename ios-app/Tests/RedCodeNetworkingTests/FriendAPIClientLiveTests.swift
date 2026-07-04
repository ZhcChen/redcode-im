import XCTest
@testable import RedCodeCore
@testable import RedCodeNetworking

final class FriendAPIClientLiveTests: XCTestCase {
    func testLiveH5IOSFriendInteropAgainstComposeAPI() async throws {
        guard ProcessInfo.processInfo.environment["RED_CODE_IOS_LIVE_FRIEND_SMOKE"] == "1" else {
            throw XCTSkip("Set RED_CODE_IOS_LIVE_FRIEND_SMOKE=1 when the local Compose API is running")
        }

        let environment = RedCodeEnvironment.simulatorDevelopment()
        let authClient = AuthAPIClient(environment: environment)
        let friendClient = FriendAPIClient(environment: environment)
        let chatClient = ChatAPIClient(environment: environment)
        let suffix = UUID().uuidString.lowercased().prefix(8)
        let h5Session = try await registerAndLogin(
            authClient: authClient,
            username: "h5friend\(suffix)",
            password: "secret123"
        )
        let iosSession = try await registerAndLogin(
            authClient: authClient,
            username: "iosfriend\(suffix)",
            password: "secret123"
        )

        let searchResults = try await friendClient.searchUsers(
            keyword: h5Session.user.username,
            limit: 10,
            token: iosSession.token
        )
        let targetUser = try XCTUnwrap(searchResults.first { $0.id == h5Session.user.id })
        let request = try await friendClient.sendFriendRequest(
            targetUserID: targetUser.id,
            message: "hello from ios \(suffix)",
            token: iosSession.token
        )
        let h5IncomingRequests = try await friendClient.fetchFriendRequests(
            direction: "incoming",
            status: "pending",
            token: h5Session.token
        )
        let incoming = try XCTUnwrap(h5IncomingRequests.first { $0.id == request.id })
        let accepted = try await friendClient.respondFriendRequest(
            requestID: incoming.id,
            action: .accept,
            token: h5Session.token
        )

        let iosFriends = try await friendClient.fetchFriends(token: iosSession.token)
        let h5Friends = try await friendClient.fetchFriends(token: h5Session.token)
        let privateChat = try await friendClient.ensurePrivateChat(
            friendUserID: h5Session.user.id,
            token: iosSession.token
        )
        let text = "private hello \(suffix)"
        let sentMessage = try await chatClient.sendTextMessage(
            roomID: privateChat.roomID,
            content: text,
            token: iosSession.token
        )
        let h5VisibleMessages = try await chatClient.loadMessages(
            roomID: privateChat.roomID,
            token: h5Session.token,
            limit: 20
        )
        let iosVisibleMessages = try await chatClient.loadMessages(
            roomID: privateChat.roomID,
            token: iosSession.token,
            limit: 20
        )

        XCTAssertEqual(accepted.status, .accepted)
        XCTAssertTrue(iosFriends.contains { $0.user.id == h5Session.user.id })
        XCTAssertTrue(h5Friends.contains { $0.user.id == iosSession.user.id })
        XCTAssertEqual(privateChat.roomType, .privateChat)
        XCTAssertEqual(privateChat.friendID, h5Session.user.id)
        XCTAssertEqual(sentMessage.content, text)
        XCTAssertTrue(h5VisibleMessages.contains { $0.id == sentMessage.id && $0.content == text })
        XCTAssertTrue(iosVisibleMessages.contains { $0.id == sentMessage.id && $0.content == text })
    }

    private func registerAndLogin(
        authClient: AuthAPIClient,
        username: String,
        password: String
    ) async throws -> AuthSession {
        _ = try await authClient.register(username: username, password: password, nickname: username)
        return try await authClient.login(username: username, password: password)
    }
}
