import XCTest
@testable import RedCodeCore
@testable import RedCodeNetworking

final class APIEndpointTests: XCTestCase {
    func testBuildsEndpointURLFromEnvironment() throws {
        let environment = RedCodeEnvironment.simulatorDevelopment()
        let endpoint = APIEndpoint(
            path: "/chats",
            queryItems: [URLQueryItem(name: "limit", value: "20")]
        )

        let url = try endpoint.url(in: environment)

        XCTAssertEqual(url.absoluteString, "http://127.0.0.1:8010/chats?limit=20")
    }

    func testRejectsEmptyEndpointPath() {
        let environment = RedCodeEnvironment.simulatorDevelopment()
        let endpoint = APIEndpoint(path: "")

        XCTAssertThrowsError(try endpoint.url(in: environment)) { error in
            XCTAssertEqual(
                error as? RedCodeError,
                .configuration("API endpoint path cannot be empty")
            )
        }
    }

    func testWebSocketConfigurationUsesEnvironmentURL() {
        let environment = RedCodeEnvironment.simulatorDevelopment()
        let configuration = WebSocketConfiguration(
            environment: environment,
            accessToken: "token"
        )

        XCTAssertEqual(configuration.url.absoluteString, "ws://127.0.0.1:8010/ws")
        XCTAssertEqual(configuration.accessToken, "token")
        XCTAssertTrue(configuration.reconnectsAutomatically)
    }
}
