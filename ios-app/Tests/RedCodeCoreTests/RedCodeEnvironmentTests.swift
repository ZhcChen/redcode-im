import XCTest
@testable import RedCodeCore

final class RedCodeEnvironmentTests: XCTestCase {
    func testSimulatorDevelopmentUsesLocalComposeAPI() {
        let environment = RedCodeEnvironment.simulatorDevelopment()

        XCTAssertEqual(environment.kind, .development)
        XCTAssertEqual(environment.apiBaseURL.absoluteString, "http://127.0.0.1:8010")
        XCTAssertEqual(environment.webSocketURL.absoluteString, "ws://127.0.0.1:8010/ws")
    }

    func testConfiguredDevelopmentFallsBackToSimulatorDefaults() throws {
        let environment = try RedCodeEnvironment.configuredDevelopment(
            processEnvironment: [:],
            infoDictionary: [:]
        )

        XCTAssertEqual(environment, .simulatorDevelopment())
    }

    func testConfiguredDevelopmentUsesProcessEnvironmentOverrides() throws {
        let environment = try RedCodeEnvironment.configuredDevelopment(
            processEnvironment: [
                "API_BASE_URL": " http://192.168.1.10:8010 ",
                "WS_URL": " ws://192.168.1.10:8010/ws ",
            ],
            infoDictionary: [
                "REDCODE_API_BASE_URL": "http://10.0.0.2:8010",
                "REDCODE_WS_URL": "ws://10.0.0.2:8010/ws",
            ]
        )

        XCTAssertEqual(environment.apiBaseURL.absoluteString, "http://192.168.1.10:8010")
        XCTAssertEqual(environment.webSocketURL.absoluteString, "ws://192.168.1.10:8010/ws")
    }

    func testConfiguredDevelopmentUsesInfoDictionaryOverrides() throws {
        let environment = try RedCodeEnvironment.configuredDevelopment(
            processEnvironment: [:],
            infoDictionary: [
                "REDCODE_API_BASE_URL": "http://10.0.0.2:8010",
                "REDCODE_WS_URL": "ws://10.0.0.2:8010/ws",
            ]
        )

        XCTAssertEqual(environment.apiBaseURL.absoluteString, "http://10.0.0.2:8010")
        XCTAssertEqual(environment.webSocketURL.absoluteString, "ws://10.0.0.2:8010/ws")
    }

    func testConfiguredDevelopmentRejectsInvalidOverrideScheme() {
        XCTAssertThrowsError(
            try RedCodeEnvironment.configuredDevelopment(
                processEnvironment: [
                    "API_BASE_URL": "ftp://192.168.1.10:8010",
                    "WS_URL": "ws://192.168.1.10:8010/ws",
                ],
                infoDictionary: [:]
            )
        ) { error in
            XCTAssertEqual(
                error as? RedCodeError,
                .configuration("API base URL must use http or https")
            )
        }
    }

    func testConfiguredDevelopmentRequiresAPIAndWebSocketTogether() {
        XCTAssertThrowsError(
            try RedCodeEnvironment.configuredDevelopment(
                processEnvironment: [
                    "API_BASE_URL": "http://192.168.1.10:8010",
                ],
                infoDictionary: [:]
            )
        ) { error in
            XCTAssertEqual(
                error as? RedCodeError,
                .configuration("API and WebSocket base URLs must be configured together")
            )
        }
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
