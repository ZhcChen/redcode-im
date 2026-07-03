import XCTest
@testable import RedCodeCore
@testable import RedCodeNetworking

final class AuthAPIClientLiveTests: XCTestCase {
    func testLiveAccountRegisterLoginAgainstComposeAPI() async throws {
        guard ProcessInfo.processInfo.environment["RED_CODE_IOS_LIVE_API_SMOKE"] == "1" else {
            throw XCTSkip("Set RED_CODE_IOS_LIVE_API_SMOKE=1 when the local Compose API is running")
        }

        let environment = RedCodeEnvironment.simulatorDevelopment()
        let client = AuthAPIClient(environment: environment)
        let suffix = UUID().uuidString.lowercased().prefix(8)
        let username = "ioslive\(suffix)"
        let password = "secret123"

        let registeredUser = try await client.register(
            username: username,
            password: password,
            nickname: username
        )
        let session = try await client.login(username: username, password: password)
        let currentUser = try await client.currentUser(token: session.token)

        XCTAssertEqual(registeredUser.username, username)
        XCTAssertEqual(session.user.username, username)
        XCTAssertEqual(currentUser.username, username)
        XCTAssertFalse(session.token.isEmpty)
        XCTAssertFalse(session.refreshToken?.isEmpty ?? true)
    }
}
