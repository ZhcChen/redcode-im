import XCTest
@testable import RedCodeCore
@testable import RedCodeNetworking

final class AuthAPIClientTests: XCTestCase {
    func testRegisterUsesAccountPayloadAndDecodesUser() async throws {
        let transport = QueueHTTPTransport(responses: [
            .json(#"{"id":"u1","username":"bear","nickname":"Bear"}"#),
        ])
        let client = AuthAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let user = try await client.register(username: " Bear ", password: "secret123", nickname: "Bear")
        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])

        XCTAssertEqual(request.url?.path, "/auth/register")
        XCTAssertEqual(json["username"], "bear")
        XCTAssertEqual(json["password"], "secret123")
        XCTAssertEqual(json["nickname"], "Bear")
        XCTAssertEqual(user.id, "u1")
        XCTAssertEqual(user.displayName, "Bear")
    }

    func testLoginDecodesAccessAndRefreshToken() async throws {
        let transport = QueueHTTPTransport(responses: [
            .json(
                """
                {"token":"access-token","refresh_token":"refresh-token","user":{"id":"u1","username":"bear"}}
                """
            ),
        ])
        let client = AuthAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let session = try await client.login(username: " Bear ", password: "secret123")
        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)

        XCTAssertEqual(request.url?.path, "/auth/login")
        XCTAssertEqual(session.token, "access-token")
        XCTAssertEqual(session.refreshToken, "refresh-token")
        XCTAssertEqual(session.user.username, "bear")
    }

    func testCurrentUserSendsBearerToken() async throws {
        let transport = QueueHTTPTransport(responses: [
            .json(#"{"id":"u1","username":"bear"}"#),
        ])
        let client = AuthAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let user = try await client.currentUser(token: "access-token")
        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)

        XCTAssertEqual(request.url?.path, "/auth/me")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertEqual(user.id, "u1")
    }

    func testRefreshUsesRefreshTokenPayload() async throws {
        let transport = QueueHTTPTransport(responses: [
            .json(
                """
                {"token":"new-token","refresh_token":"refresh-token","user":{"id":"u1","username":"bear"}}
                """
            ),
        ])
        let client = AuthAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let session = try await client.refresh(refreshToken: "refresh-token")
        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])

        XCTAssertEqual(request.url?.path, "/auth/refresh")
        XCTAssertEqual(json["refresh_token"], "refresh-token")
        XCTAssertEqual(session.token, "new-token")
    }

    func testChangePasswordUsesAuthenticatedPasswordEndpoint() async throws {
        let transport = QueueHTTPTransport(responses: [
            .empty(statusCode: 204),
        ])
        let client = AuthAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        try await client.changePassword(
            token: "access-token",
            oldPassword: "old-password",
            newPassword: "new-password"
        )

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])

        XCTAssertEqual(request.url?.path, "/users/me/password")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertEqual(json["old_password"], "old-password")
        XCTAssertEqual(json["new_password"], "new-password")
    }

    func testResetPasswordWithSMSUsesAuthenticatedResetEndpoint() async throws {
        let transport = QueueHTTPTransport(responses: [
            .json(#"{"success":true,"message":"密码已重置，请使用新密码登录"}"#),
        ])
        let client = AuthAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let response = try await client.resetPasswordWithSMS(
            token: "access-token",
            phone: " bear ",
            code: " 123456 ",
            newPassword: " new-password "
        )

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])

        XCTAssertEqual(request.url?.path, "/auth/password/reset")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertEqual(json["phone"], "bear")
        XCTAssertEqual(json["code"], "123456")
        XCTAssertEqual(json["new_password"], "new-password")
        XCTAssertEqual(response.message, "密码已重置，请使用新密码登录")
    }

    func testUpdateProfileUsesAuthenticatedUsersMeEndpoint() async throws {
        let transport = QueueHTTPTransport(responses: [
            .json(#"{"id":"u1","username":"bear","nickname":"New Bear","avatar_object_key":"users/u1/avatar.png"}"#),
        ])
        let client = AuthAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let user = try await client.updateProfile(
            token: "access-token",
            nickname: " New Bear ",
            avatarURL: nil,
            avatarObjectKey: " users/u1/avatar.png "
        )

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])

        XCTAssertEqual(request.url?.path, "/users/me")
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertEqual(json["nickname"], "New Bear")
        XCTAssertEqual(json["avatar_object_key"], "users/u1/avatar.png")
        XCTAssertEqual(user.nickname, "New Bear")
    }
}

private struct QueueHTTPResponse: Sendable {
    let data: Data
    let statusCode: Int

    static func json(_ value: String, statusCode: Int = 200) -> QueueHTTPResponse {
        QueueHTTPResponse(data: Data(value.utf8), statusCode: statusCode)
    }

    static func empty(statusCode: Int) -> QueueHTTPResponse {
        QueueHTTPResponse(data: Data(), statusCode: statusCode)
    }
}

private actor QueueHTTPTransport: HTTPTransport {
    private var responses: [QueueHTTPResponse]
    private(set) var requests: [URLRequest] = []

    init(responses: [QueueHTTPResponse]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let next = responses.isEmpty ? .empty(statusCode: 500) : responses.removeFirst()
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: next.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: [:]
        )!
        return (next.data, response)
    }

    func recordedRequests() -> [URLRequest] {
        requests
    }
}
