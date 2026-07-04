import XCTest
@testable import RedCodeNetworking

final class SettingsAPIClientTests: XCTestCase {
    func testFetchGeneralSettingsDecodesRuntimeSettings() async throws {
        let transport = QueueHTTPTransport(responses: [
            .json(
                """
                {
                  "app_name": "RedCode IM",
                  "message_runtime": {
                    "server_storage_mode": "relay_only",
                    "content_audit_mode": "e2ee",
                    "updated_at": "2026-07-04T10:00:00Z",
                    "updated_by": "admin"
                  }
                }
                """
            ),
        ])
        let client = SettingsAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let settings = try await client.fetchGeneralSettings()

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8010/settings/general")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(settings.appName, "RedCode IM")
        XCTAssertEqual(settings.messageRuntime.serverStorageMode, "relay_only")
        XCTAssertEqual(settings.messageRuntime.contentAuditMode, "e2ee")
    }

    func testFetchDocumentsUsePublicSettingsRoutes() async throws {
        let transport = QueueHTTPTransport(responses: [
            .json(#"{"title":"隐私协议","content":"<p>privacy</p>","updated_at":"2026-07-04T10:00:00Z"}"#),
            .json(#"{"title":"用户协议","content":"<p>terms</p>","updated_at":null}"#),
        ])
        let client = SettingsAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let privacy = try await client.fetchDocument(.privacyPolicy)
        let agreement = try await client.fetchDocument(.userAgreement)

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.map { $0.url?.path }, [
            "/settings/privacy-policy",
            "/settings/user-agreement",
        ])
        XCTAssertEqual(privacy.title, "隐私协议")
        XCTAssertEqual(agreement.content, "<p>terms</p>")
    }

    func testSubmitFeedbackTrimsPayloadAndSendsBearerToken() async throws {
        let transport = QueueHTTPTransport(responses: [
            .json(#"{"success":true,"message":"反馈提交成功，感谢您的支持！"}"#),
        ])
        let client = SettingsAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let response = try await client.submitFeedback(
            token: "access-token",
            content: " hello ",
            contact: " user@example.test "
        )

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(request.url?.path, "/feedbacks")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertEqual(json["content"], "hello")
        XCTAssertEqual(json["contact"], "user@example.test")
        XCTAssertTrue(response.success)
    }

    func testVersionCheckAndDownloadURLUseBackendContract() async throws {
        let transport = QueueHTTPTransport(responses: [
            .json(
                """
                {
                  "has_update": true,
                  "current_version": "0.1.0",
                  "version": {
                    "id": "v1",
                    "platform": "ios",
                    "version": "0.2.0",
                    "build_number": 2,
                    "channel": "stable",
                    "download_key": "releases/ios/app.ipa",
                    "app_store_url": "https://apps.example.test/redcode",
                    "mandatory": true,
                    "is_active": true,
                    "created_at": "2026-07-04T10:00:00Z",
                    "updated_at": "2026-07-04T10:00:00Z"
                  }
                }
                """
            ),
            .json(#"{"success":true,"message":"ok","download_url":"https://cdn.example.test/app.ipa"}"#),
        ])
        let client = SettingsAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let result = try await client.checkLatestVersion(currentVersion: "0.1.0", channel: "stable")
        let downloadURL = try await client.fetchVersionDownloadURL(id: "v1", expiresInSeconds: 120)

        let requests = await transport.recordedRequests()
        XCTAssertEqual(
            requests.first?.url?.absoluteString,
            "http://127.0.0.1:8010/versions/latest?platform=ios&channel=stable&current_version=0.1.0"
        )
        XCTAssertEqual(
            requests.last?.url?.absoluteString,
            "http://127.0.0.1:8010/versions/download?id=v1&expires_in_seconds=120"
        )
        XCTAssertTrue(result.hasUpdate)
        XCTAssertEqual(result.latest?.version, "0.2.0")
        XCTAssertEqual(result.latest?.appStoreURL, "https://apps.example.test/redcode")
        XCTAssertEqual(downloadURL, "https://cdn.example.test/app.ipa")
    }
}

private struct QueueHTTPResponse: Sendable {
    let data: Data
    let statusCode: Int

    static func json(_ value: String, statusCode: Int = 200) -> QueueHTTPResponse {
        QueueHTTPResponse(data: Data(value.utf8), statusCode: statusCode)
    }
}

private actor QueueHTTPTransport: HTTPTransport {
    private var responses: [QueueHTTPResponse]
    private var requests: [URLRequest] = []

    init(responses: [QueueHTTPResponse]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let next = responses.removeFirst()
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
