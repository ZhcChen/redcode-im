import XCTest
@testable import RedCodeCore
@testable import RedCodeNetworking

final class ChatAPIClientLiveTests: XCTestCase {
    func testLiveFetchChatsAgainstComposeAPI() async throws {
        guard ProcessInfo.processInfo.environment["RED_CODE_IOS_LIVE_CHAT_SMOKE"] == "1" else {
            throw XCTSkip("Set RED_CODE_IOS_LIVE_CHAT_SMOKE=1 when the local Compose API is running")
        }

        let environment = RedCodeEnvironment.simulatorDevelopment()
        let authClient = AuthAPIClient(environment: environment)
        let chatClient = ChatAPIClient(environment: environment)
        let suffix = UUID().uuidString.lowercased().prefix(8)
        let username = "ioschat\(suffix)"
        let password = "secret123"

        _ = try await authClient.register(username: username, password: password, nickname: username)
        let session = try await authClient.login(username: username, password: password)
        let chats = try await chatClient.fetchChats(token: session.token)

        XCTAssertFalse(session.token.isEmpty)
        XCTAssertFalse(chats.isEmpty)
        XCTAssertTrue(chats.allSatisfy { !$0.roomID.isEmpty })
    }

    func testLiveH5IOSChatInteropAgainstComposeAPI() async throws {
        guard ProcessInfo.processInfo.environment["RED_CODE_IOS_LIVE_CHAT_SMOKE"] == "1" else {
            throw XCTSkip("Set RED_CODE_IOS_LIVE_CHAT_SMOKE=1 when the local Compose API is running")
        }

        let environment = RedCodeEnvironment.simulatorDevelopment()
        let authClient = AuthAPIClient(environment: environment)
        let roomClient = RoomAPIClient(environment: environment)
        let chatClient = ChatAPIClient(environment: environment)
        let suffix = UUID().uuidString.lowercased().prefix(8)
        let h5Session = try await registerAndLogin(
            authClient: authClient,
            username: "h5ios\(suffix)",
            password: "secret123"
        )
        let iosSession = try await registerAndLogin(
            authClient: authClient,
            username: "iosh5\(suffix)",
            password: "secret123"
        )
        let room = try await roomClient.createGroup(
            name: "ios-h5 interop \(suffix)",
            description: "live smoke",
            memberIDs: [iosSession.user.id],
            token: h5Session.token
        )
        let h5Text = "hello from h5 \(suffix)"
        let iosText = "hello from ios \(suffix)"

        let h5Message = try await chatClient.sendTextMessage(
            roomID: room.id,
            content: h5Text,
            token: h5Session.token
        )
        let iosMessage = try await chatClient.sendTextMessage(
            roomID: room.id,
            content: iosText,
            token: iosSession.token
        )
        let iosVisibleMessages = try await chatClient.loadMessages(
            roomID: room.id,
            token: iosSession.token,
            limit: 20
        )
        let h5VisibleMessages = try await chatClient.loadMessages(
            roomID: room.id,
            token: h5Session.token,
            limit: 20
        )

        XCTAssertEqual(room.roomType, "group")
        XCTAssertEqual(h5Message.content, h5Text)
        XCTAssertEqual(iosMessage.content, iosText)
        XCTAssertTrue(iosVisibleMessages.contains { $0.id == h5Message.id && $0.content == h5Text })
        XCTAssertTrue(iosVisibleMessages.contains { $0.id == iosMessage.id && $0.content == iosText })
        XCTAssertTrue(h5VisibleMessages.contains { $0.id == h5Message.id && $0.content == h5Text })
        XCTAssertTrue(h5VisibleMessages.contains { $0.id == iosMessage.id && $0.content == iosText })

        try await chatClient.markMessagesAsRead(
            roomID: room.id,
            messageID: iosMessage.id,
            token: h5Session.token
        )
        try await chatClient.markMessagesAsRead(
            roomID: room.id,
            messageID: h5Message.id,
            token: iosSession.token
        )
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
