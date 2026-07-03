import XCTest
@testable import RedCodeCore
@testable import RedCodeNetworking

final class APIClientTests: XCTestCase {
    func testPostEncodesJSONBodyAndHeaders() async throws {
        let transport = MockHTTPTransport(
            data: Data(
                """
                {"token":"access-token","refresh_token":"refresh-token","user":{"id":"u1","username":"bear"}}
                """.utf8
            ),
            statusCode: 200
        )
        let client = APIClient(environment: .simulatorDevelopment(), transport: transport)

        let session = try await client.post(
            AuthAPIEndpoint.login,
            body: try AccountLoginRequest(username: " Bear ", password: "secret123"),
            as: AuthSession.self
        )

        let recordedRequest = await transport.recordedLastRequest()
        let request = try XCTUnwrap(recordedRequest)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])

        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8010/auth/login")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(json["username"], "bear")
        XCTAssertEqual(json["password"], "secret123")
        XCTAssertEqual(session.token, "access-token")
        XCTAssertEqual(session.refreshToken, "refresh-token")
        XCTAssertEqual(session.user.username, "bear")
    }

    func testGetInjectsBearerToken() async throws {
        let transport = MockHTTPTransport(
            data: Data(#"{"id":"u1","username":"bear"}"#.utf8),
            statusCode: 200
        )
        let client = APIClient(environment: .simulatorDevelopment(), transport: transport)

        let user = try await client.get(
            AuthAPIEndpoint.me,
            bearerToken: "access-token",
            as: AuthUser.self
        )

        let recordedRequest = await transport.recordedLastRequest()
        let request = try XCTUnwrap(recordedRequest)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertNil(request.httpBody)
        XCTAssertEqual(user.id, "u1")
    }

    func testHTTPErrorUsesBackendMessage() async throws {
        let transport = MockHTTPTransport(
            data: Data(#"{"message":"账号或密码错误"}"#.utf8),
            statusCode: 401
        )
        let client = APIClient(environment: .simulatorDevelopment(), transport: transport)

        do {
            _ = try await client.get(AuthAPIEndpoint.me, as: AuthUser.self)
            XCTFail("Expected request to throw")
        } catch let error as RedCodeError {
            XCTAssertEqual(error, .network("账号或密码错误"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInvalidJSONResponseIsNetworkDecodeError() async throws {
        let transport = MockHTTPTransport(data: Data("{".utf8), statusCode: 200)
        let client = APIClient(environment: .simulatorDevelopment(), transport: transport)

        do {
            _ = try await client.get(AuthAPIEndpoint.me, as: AuthUser.self)
            XCTFail("Expected decode failure")
        } catch let error as RedCodeError {
            XCTAssertEqual(error, .network("响应解析失败"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTransportFailureIsWrappedAsNetworkError() async throws {
        let transport = ThrowingHTTPTransport(error: URLError(.notConnectedToInternet))
        let client = APIClient(environment: .simulatorDevelopment(), transport: transport)

        do {
            _ = try await client.get(AuthAPIEndpoint.me, as: AuthUser.self)
            XCTFail("Expected transport failure")
        } catch let error as RedCodeError {
            guard case .network(let message) = error else {
                return XCTFail("Expected network error, got \(error)")
            }
            XCTAssertFalse(message.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNoResponseAcceptsSuccessStatus() async throws {
        let transport = MockHTTPTransport(data: Data(), statusCode: 204)
        let client = APIClient(environment: .simulatorDevelopment(), transport: transport)

        try await client.postNoResponse(
            AuthAPIEndpoint.changePassword,
            body: ChangePasswordRequest(oldPassword: "old-password", newPassword: "new-password"),
            bearerToken: "access-token"
        )

        let recordedRequest = await transport.recordedLastRequest()
        let request = try XCTUnwrap(recordedRequest)
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8010/users/me/password")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
    }
}

private actor MockHTTPTransport: HTTPTransport {
    private let data: Data
    private let statusCode: Int
    private(set) var lastRequest: URLRequest?

    init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: [:]
        )!
        return (data, response)
    }

    func recordedLastRequest() -> URLRequest? {
        lastRequest
    }
}

private struct ThrowingHTTPTransport: HTTPTransport {
    let error: Error

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        throw error
    }
}
