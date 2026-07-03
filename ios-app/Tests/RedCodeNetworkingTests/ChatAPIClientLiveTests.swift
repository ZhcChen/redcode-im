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
}
