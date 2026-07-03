import XCTest
@testable import RedCodeCore

final class RedCodeEnvironmentTests: XCTestCase {
    func testSimulatorDevelopmentUsesLocalComposeAPI() {
        let environment = RedCodeEnvironment.simulatorDevelopment()

        XCTAssertEqual(environment.kind, .development)
        XCTAssertEqual(environment.apiBaseURL.absoluteString, "http://127.0.0.1:8010")
        XCTAssertEqual(environment.webSocketURL.absoluteString, "ws://127.0.0.1:8010/ws")
    }

    func testRejectsInvalidAPIURLScheme() {
        XCTAssertThrowsError(
            try RedCodeEnvironment(
                kind: .development,
                apiBaseURL: URL(string: "ftp://127.0.0.1:8010")!,
                webSocketURL: URL(string: "ws://127.0.0.1:8010/ws")!
            )
        ) { error in
            XCTAssertEqual(
                error as? RedCodeError,
                .configuration("API base URL must use http or https")
            )
        }
    }

    func testPlatformPolicyMatchesCurrentIOSBaseline() {
        XCTAssertEqual(RedCodePlatformPolicy.minimumIOSMajorVersion, 17)
        XCTAssertEqual(RedCodePlatformPolicy.swiftLanguageMode, "6")
        XCTAssertEqual(RedCodePlatformPolicy.defaultSimulatorHost, "127.0.0.1")
        XCTAssertEqual(RedCodePlatformPolicy.maxCachedMessagesPerRoom, 200)
    }
}
