import Foundation
import XCTest

@testable import RedCodeCore
@testable import RedCodeNetworking
@testable import RedCodeStorage

final class IOSE2eeCrossClientLiveTests: XCTestCase {
    func testExchangesCiphertextBidirectionallyWithH5() async throws {
        guard ProcessInfo.processInfo.environment["RED_CODE_IOS_E2EE_LIVE"] == "1" else {
            throw XCTSkip("Set RED_CODE_IOS_E2EE_LIVE=1 with coordination settings")
        }

        let coordination = try CoordinationClient.fromEnvironment()
        let fixture = try await coordination.fixture()
        let apiURL = try XCTUnwrap(URL(string: fixture.apiBaseURL))
        let wsURL = try XCTUnwrap(URL(string: fixture.apiBaseURL.replacingOccurrences(of: "http", with: "ws") + "/ws"))
        let environment = try RedCodeEnvironment(kind: .test, apiBaseURL: apiURL, webSocketURL: wsURL)
        let apiClient = APIClient(environment: environment)
        let mlsAPI = E2eeMLSAPIClient(apiClient: apiClient)
        let core = E2eeCommandClient()
        let storage = E2eeSecureStateStore(
            cipher: CryptoKitE2eeStateCipher(keyStore: InMemoryKeyValueStore()),
            blobs: InMemoryE2eeStateBlobStore(),
            validateProtocolState: core.validateProtocolState
        )
        let lifecycle = E2eeDeviceLifecycle(storage: storage, mlsApi: mlsAPI, core: core)
        let coordinator = E2eeDirectMessageCoordinator(
            storage: storage,
            lifecycle: lifecycle,
            api: mlsAPI,
            core: core
        )
        let chat = ChatAPIClient(apiClient: apiClient)

        let profile = try await lifecycle.ensureReady(
            accountID: fixture.accountID,
            deviceLabel: "iOS E2EE live",
            token: fixture.token
        )
        XCTAssertEqual(profile.deviceStatus, "active")
        let replenished = try await lifecycle.topUpKeyPackages(
            accountID: fixture.accountID,
            token: fixture.token
        )
        XCTAssertGreaterThan(replenished, 0)

        let iosMessageID = try await coordinator.sendText(
            accountID: fixture.accountID,
            deviceLabel: "iOS E2EE live",
            roomID: fixture.roomID,
            peerUserID: fixture.peerUserID,
            text: fixture.iosMarker,
            token: fixture.token
        )
        try await coordination.publish("ios-sent", payload: ["message_id": iosMessageID])

        let h5MessageID = try await coordination.waitFor("h5-ios-sent")["message_id"].required("message_id")
        let encrypted = try await chat.loadMessages(
            roomID: fixture.roomID,
            token: fixture.token,
            limit: 50
        ).first { $0.id == h5MessageID }
        let ciphertext = try XCTUnwrap(encrypted?.encryptedContent).base64Data()
        let decrypted = try await coordinator.decryptIncoming(
            accountID: fixture.accountID,
            deviceLabel: "iOS E2EE live",
            input: E2eeIncomingMessage(
                messageID: h5MessageID,
                roomID: fixture.roomID,
                ciphertext: ciphertext,
                source: .history
            ),
            token: fixture.token
        )
        XCTAssertEqual(decrypted.text, fixture.h5Marker)
        try await coordination.publish("ios-received", payload: ["message_id": h5MessageID])
    }

    func testExchangesCiphertextBidirectionallyWithAndroid() async throws {
        guard ProcessInfo.processInfo.environment["RED_CODE_IOS_E2EE_LIVE"] == "1" else {
            throw XCTSkip("Set RED_CODE_IOS_E2EE_LIVE=1 with coordination settings")
        }

        let coordination = try CoordinationClient.fromEnvironment()
        let fixture = try await coordination.fixture()
        let iosToken = try fixture.iosToken.required("ios_token")
        let iosAccountID = try fixture.iosAccountID.required("ios_account_id")
        let androidAccountID = try fixture.androidAccountID.required("android_account_id")
        let iosMarker = fixture.iosMarker
        let androidMarker = try fixture.androidMarker.required("android_marker")
        let client = try makeClient(fixture: fixture)

        let profile = try await client.lifecycle.ensureReady(
            accountID: iosAccountID,
            deviceLabel: "iOS E2EE live",
            token: iosToken
        )
        XCTAssertEqual(profile.deviceStatus, "active")
        let replenished = try await client.lifecycle.topUpKeyPackages(
            accountID: iosAccountID,
            token: iosToken
        )
        XCTAssertGreaterThan(replenished, 0)
        try await coordination.publish("ios-native-ready", payload: ["device_id": profile.deviceId])

        let androidMessageID = try await coordination.waitFor("android-to-ios-sent")["message_id"].required("message_id")
        let encrypted = try await client.chat.loadMessages(
            roomID: fixture.roomID,
            token: iosToken,
            limit: 50
        ).first { $0.id == androidMessageID }
        let ciphertext = try XCTUnwrap(encrypted?.encryptedContent).base64Data()
        let decrypted = try await client.coordinator.decryptIncoming(
            accountID: iosAccountID,
            deviceLabel: "iOS E2EE live",
            input: E2eeIncomingMessage(
                messageID: androidMessageID,
                roomID: fixture.roomID,
                ciphertext: ciphertext,
                source: .history
            ),
            token: iosToken
        )
        XCTAssertEqual(decrypted.text, androidMarker)
        try await coordination.publish("ios-native-received", payload: ["message_id": androidMessageID])

        let iosMessageID = try await client.coordinator.sendText(
            accountID: iosAccountID,
            deviceLabel: "iOS E2EE live",
            roomID: fixture.roomID,
            peerUserID: androidAccountID,
            text: iosMarker,
            token: iosToken
        )
        try await coordination.publish("ios-to-android-sent", payload: ["message_id": iosMessageID])
        let firstReceived = try await coordination.waitFor("android-first-received")["message_id"].required("message_id")
        XCTAssertEqual(firstReceived, iosMessageID)

        _ = try await coordination.waitFor("android-restart-ready")
        let afterRestartMessageID = try await client.coordinator.sendText(
            accountID: iosAccountID,
            deviceLabel: "iOS E2EE live",
            roomID: fixture.roomID,
            peerUserID: androidAccountID,
            text: try fixture.iosRestartMarker.required("ios_restart_marker"),
            token: iosToken
        )
        try await coordination.publish("ios-after-restart-sent", payload: ["message_id": afterRestartMessageID])
        let received = try await coordination.waitFor("android-native-received")["message_id"].required("message_id")
        XCTAssertEqual(received, afterRestartMessageID)
    }

    private func makeClient(fixture: CoordinationFixture) throws -> LiveE2eeClient {
        let apiURL = try XCTUnwrap(URL(string: fixture.apiBaseURL))
        let wsURL = try XCTUnwrap(URL(string: fixture.apiBaseURL.replacingOccurrences(of: "http", with: "ws") + "/ws"))
        let environment = try RedCodeEnvironment(kind: .test, apiBaseURL: apiURL, webSocketURL: wsURL)
        let apiClient = APIClient(environment: environment)
        let mlsAPI = E2eeMLSAPIClient(apiClient: apiClient)
        let core = E2eeCommandClient()
        let storage = E2eeSecureStateStore(
            cipher: CryptoKitE2eeStateCipher(keyStore: InMemoryKeyValueStore()),
            blobs: InMemoryE2eeStateBlobStore(),
            validateProtocolState: core.validateProtocolState
        )
        let lifecycle = E2eeDeviceLifecycle(storage: storage, mlsApi: mlsAPI, core: core)
        return LiveE2eeClient(
            lifecycle: lifecycle,
            coordinator: E2eeDirectMessageCoordinator(storage: storage, lifecycle: lifecycle, api: mlsAPI, core: core),
            chat: ChatAPIClient(apiClient: apiClient)
        )
    }
}

private struct LiveE2eeClient {
    let lifecycle: E2eeDeviceLifecycle
    let coordinator: E2eeDirectMessageCoordinator
    let chat: ChatAPIClient
}

private struct CoordinationFixture: Decodable, Sendable {
    let token: String
    let accountID: String
    let peerUserID: String
    let roomID: String
    let iosMarker: String
    let h5Marker: String
    let apiBaseURL: String
    let iosToken: String?
    let iosAccountID: String?
    let androidAccountID: String?
    let androidMarker: String?
    let iosRestartMarker: String?

    enum CodingKeys: String, CodingKey {
        case token
        case accountID = "account_id"
        case peerUserID = "peer_user_id"
        case roomID = "room_id"
        case iosMarker = "ios_marker"
        case h5Marker = "h5_marker"
        case apiBaseURL = "api_base_url"
        case iosToken = "ios_token"
        case iosAccountID = "ios_account_id"
        case androidAccountID = "android_account_id"
        case androidMarker = "android_marker"
        case iosRestartMarker = "ios_restart_marker"
    }
}

private struct CoordinationClient: Sendable {
    let baseURL: URL
    let secret: String

    static func fromEnvironment() throws -> CoordinationClient {
        let environment = ProcessInfo.processInfo.environment
        guard let rawURL = environment["E2EE_COORDINATION_URL"], let url = URL(string: rawURL) else {
            throw CoordinationError("E2EE_COORDINATION_URL 无效")
        }
        guard let secret = environment["E2EE_COORDINATION_SECRET"], !secret.isEmpty else {
            throw CoordinationError("E2EE_COORDINATION_SECRET 缺失")
        }
        return CoordinationClient(baseURL: url, secret: secret)
    }

    func fixture() async throws -> CoordinationFixture {
        let (data, status) = try await request("fixture")
        guard status == 200 else { throw CoordinationError("Coordination fixture failed: \(status)") }
        return try JSONDecoder().decode(CoordinationFixture.self, from: data)
    }

    func publish(_ step: String, payload: [String: String]) async throws {
        let (data, status) = try await request(step, body: JSONEncoder().encode(payload))
        guard (200...299).contains(status) else {
            throw CoordinationError("Coordination POST \(step) failed: \(status), \(String(data: data, encoding: .utf8) ?? "")")
        }
    }

    func waitFor(_ step: String) async throws -> [String: String] {
        for _ in 0..<150 {
            let (data, status) = try await request(step)
            if status == 200 {
                return try JSONDecoder().decode([String: String].self, from: data)
            }
            guard status == 204 else { throw CoordinationError("Coordination GET \(step) failed: \(status)") }
            try await Task.sleep(for: .milliseconds(200))
        }
        throw CoordinationError("Coordination timeout: \(step)")
    }

    private func request(_ path: String, body: Data? = nil) async throws -> (Data, Int) {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.timeoutInterval = 10
        request.httpMethod = body == nil ? "GET" : "POST"
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw CoordinationError("Coordination 响应无效") }
        return (data, response.statusCode)
    }
}

private struct CoordinationError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}

private extension Optional where Wrapped == String {
    func required(_ field: String) throws -> String {
        guard let self, !self.isEmpty else { throw CoordinationError("Coordination 缺少字段：\(field)") }
        return self
    }
}

private extension String {
    func base64Data() throws -> Data {
        guard let data = Data(base64Encoded: self) else { throw CoordinationError("消息密文 Base64 无效") }
        return data
    }
}
