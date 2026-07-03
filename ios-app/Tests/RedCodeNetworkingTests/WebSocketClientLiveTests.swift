import XCTest
@testable import RedCodeCore
@testable import RedCodeNetworking

final class WebSocketClientLiveTests: XCTestCase {
    func testLiveWebSocketAuthenticatesAgainstComposeAPI() async throws {
        guard ProcessInfo.processInfo.environment["RED_CODE_IOS_LIVE_WS_SMOKE"] == "1" else {
            throw XCTSkip("Set RED_CODE_IOS_LIVE_WS_SMOKE=1 when the local Compose API is running")
        }

        let environment = RedCodeEnvironment.simulatorDevelopment()
        let authClient = AuthAPIClient(environment: environment)
        let suffix = UUID().uuidString.lowercased().prefix(8)
        let username = "iosws\(suffix)"
        let password = "secret123"

        _ = try await authClient.register(
            username: username,
            password: password,
            nickname: username
        )
        let session = try await authClient.login(username: username, password: password)
        let webSocketClient = WebSocketClient(
            configuration: WebSocketConfiguration(
                environment: environment,
                accessToken: session.token
            )
        )

        try await webSocketClient.connect()
        try await waitUntilAuthenticated(webSocketClient)

        let snapshot = await webSocketClient.snapshot()
        XCTAssertEqual(snapshot.status, .authenticated)
        XCTAssertNotNil(snapshot.connectionID)

        await webSocketClient.disconnect()
    }

    private func waitUntilAuthenticated(_ client: WebSocketClient) async throws {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            let snapshot = await client.snapshot()
            if snapshot.status == .authenticated {
                return
            }
            if snapshot.status == .error {
                XCTFail(snapshot.lastError)
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTFail("WebSocket did not authenticate before timeout")
    }
}
