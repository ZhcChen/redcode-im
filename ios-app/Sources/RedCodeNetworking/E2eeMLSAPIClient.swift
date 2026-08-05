import CryptoKit
import Foundation
import RedCodeCore

/// e2ee-core MLS 服务端 API（与 H5 e2ee-mls-api-service 对齐）。
public struct E2eeMLSAPIClient: E2eeMLSApi {
    private let apiClient: APIClient
    private let platform: String
    private let version: String
    private let build: String

    public init(
        apiClient: APIClient,
        platform: String = "ios",
        version: String = "2.0.0",
        build: String = "dev"
    ) {
        self.apiClient = apiClient
        self.platform = platform
        self.version = version
        self.build = build
    }

    public func fetchRootIdentity(userID: String, token: String) async throws -> Data? {
        do {
            let response: RootIdentityResponse = try await apiClient.get(
                APIEndpoint(path: "/e2ee/mls/identities/\(urlEncode(userID))"),
                bearerToken: token
            )
            return Data(base64Encoded: response.publicKey)
        } catch let failure as NetworkFailure where failure.kind == .notFound {
            return nil
        }
    }

    public func registerDevice(
        deviceID: String,
        deviceLabel: String,
        material: E2eeRegistrationMaterial,
        token: String
    ) async throws -> String {
        let response: RegisterDeviceResponse = try await apiClient.post(
            APIEndpoint(method: .post, path: "/e2ee/mls/devices"),
            body: RegisterDeviceRequest(
                deviceID: deviceID,
                deviceLabel: deviceLabel,
                rootPublicKey: base64(material.rootPublicKey),
                rootFingerprint: base64(material.rootFingerprint),
                credential: base64(material.credential),
                credentialFingerprint: base64(material.credentialFingerprint),
                approvalPublicKey: base64(material.approvalPublicKey),
                protocolVersion: 1,
                clientPlatform: platform,
                clientVersion: version,
                clientBuild: build
            ),
            bearerToken: token
        )
        return response.status
    }

    public func publishKeyPackages(deviceID: String, keyPackages: [Data], token: String) async throws -> Int {
        guard !keyPackages.isEmpty else {
            throw E2eeCommandError(message: "E2EE KeyPackage 批次不能为空")
        }
        guard keyPackages.count <= 100 else {
            throw E2eeCommandError(message: "E2EE KeyPackage 单批最多 100 个")
        }
        let expiresAt = ISO8601DateFormatter().string(
            from: Date().addingTimeInterval(7 * 24 * 60 * 60)
        )
        let payloads = keyPackages.map { keyPackage in
            KeyPackagePayload(
                id: UUID().uuidString,
                packageRef: base64(Data(SHA256.hash(data: keyPackage))),
                keyPackage: base64(keyPackage),
                protocolVersion: 1,
                expiresAt: expiresAt
            )
        }
        let response: PublishKeyPackagesResponse = try await apiClient.post(
            APIEndpoint(method: .post, path: "/e2ee/mls/devices/\(deviceID)/key-packages"),
            body: PublishKeyPackagesRequest(packages: payloads),
            bearerToken: token
        )
        return response.inserted
    }

    public func fetchKeyPackageInventory(deviceID: String, token: String) async throws -> E2eeKeyPackageInventory {
        let response: KeyPackageInventoryResponse = try await apiClient.get(
            APIEndpoint(path: "/e2ee/mls/devices/\(deviceID)/key-packages"),
            bearerToken: token
        )
        return E2eeKeyPackageInventory(
            available: response.available,
            maxAvailable: response.maxAvailable
        )
    }

    public func listDevices(token: String) async throws -> [E2eeDeviceInfo] {
        let rows: [DeviceRow] = try await apiClient.get(
            APIEndpoint(path: "/e2ee/mls/devices"),
            bearerToken: token
        )
        return rows.map {
            E2eeDeviceInfo(
                id: $0.id,
                deviceLabel: $0.deviceLabel,
                protocolVersion: $0.protocolVersion,
                credentialFingerprint: $0.credentialFingerprint,
                status: $0.status
            )
        }
    }

    public func fetchIdentity(userID: String, token: String) async throws -> E2eeRootIdentity {
        let row: DirectRootIdentityResponse = try await apiClient.get(APIEndpoint(path: "/e2ee/mls/identities/\(urlEncode(userID))"), bearerToken: token)
        guard row.userID == userID, row.protocolVersion == 1, let publicKey = Data(base64Encoded: row.rootPublicKey), let fingerprint = Data(base64Encoded: row.rootFingerprint) else {
            throw E2eeCommandError(message: "E2EE 根身份响应格式无效")
        }
        return E2eeRootIdentity(userID: row.userID, publicKey: publicKey, fingerprint: fingerprint, protocolVersion: row.protocolVersion)
    }

    public func listRoomMemberDevices(roomID: String, token: String) async throws -> [E2eeRoomMemberDevices] {
        let rows: [RoomMemberDevicesResponse] = try await apiClient.get(APIEndpoint(path: "/rooms/\(roomID)/e2ee/members"), bearerToken: token)
        return try rows.map { row in
            E2eeRoomMemberDevices(userID: row.userID, devices: try row.devices.map { device in
                guard let fingerprint = Data(base64Encoded: device.credentialFingerprint) else { throw E2eeCommandError(message: "E2EE 设备指纹格式无效") }
                return E2eePeerDevice(id: device.id, protocolVersion: device.protocolVersion, credentialFingerprint: fingerprint)
            })
        }
    }

    public func getRoomEpoch(roomID: String, token: String) async throws -> E2eeRoomEpoch {
        let row: RoomEpochResponse = try await apiClient.get(APIEndpoint(path: "/rooms/\(roomID)/e2ee/epoch"), bearerToken: token)
        return E2eeRoomEpoch(membershipRevision: row.membershipRevision, activeEpoch: row.activeEpoch, status: row.status)
    }

    public func claimKeyPackage(roomID: String, consumerDeviceID: String, targetDeviceID: String, token: String) async throws -> E2eeClaimedKeyPackage {
        let row: ClaimedKeyPackageResponse = try await apiClient.post(
            APIEndpoint(method: .post, path: "/e2ee/mls/devices/\(targetDeviceID)/key-packages/claim"),
            body: ClaimKeyPackageRequest(roomID: roomID, consumerDeviceID: consumerDeviceID), bearerToken: token
        )
        guard let keyPackage = Data(base64Encoded: row.keyPackage) else { throw E2eeCommandError(message: "E2EE KeyPackage 格式无效") }
        return E2eeClaimedKeyPackage(id: row.id, deviceID: row.deviceID, keyPackage: keyPackage)
    }

    public func submitControlMessage(_ message: E2eeOutgoingControlMessage, token: String) async throws {
        try await apiClient.postNoResponse(
            APIEndpoint(method: .post, path: "/rooms/\(message.roomID)/e2ee/control-messages"),
            body: SubmitControlRequest(message), bearerToken: token
        )
    }

    public func listControlMessages(roomID: String, deviceID: String, afterSequence: UInt64, token: String) async throws -> [E2eeControlMessage] {
        let rows: [ControlMessageResponse] = try await apiClient.get(
            APIEndpoint(path: "/rooms/\(roomID)/e2ee/control-messages", queryItems: [URLQueryItem(name: "device_id", value: deviceID), URLQueryItem(name: "after_sequence", value: String(afterSequence)), URLQueryItem(name: "limit", value: "100")]), bearerToken: token
        )
        return try rows.map { row in
            guard let envelope = Data(base64Encoded: row.envelope) else { throw E2eeCommandError(message: "E2EE 控制消息格式无效") }
            return E2eeControlMessage(id: row.id, epoch: row.epoch, membershipRevision: row.membershipRevision, contentType: row.contentType, envelope: envelope, sequenceNumber: row.sequenceNumber)
        }
    }

    public func consumeControlMessage(roomID: String, messageID: String, deviceID: String, token: String) async throws {
        try await apiClient.postNoResponse(APIEndpoint(method: .post, path: "/rooms/\(roomID)/e2ee/control-messages/\(messageID)/consume"), body: ConsumeControlRequest(deviceID: deviceID), bearerToken: token)
    }

    public func sendEncryptedMessage(_ message: E2eeEncryptedMessageRequest, token: String) async throws -> String {
        let response: SendEncryptedResponse = try await apiClient.post(
            APIEndpoint(method: .post, path: "/rooms/\(message.roomID)/messages/encrypted"),
            body: SendEncryptedRequest(message), bearerToken: token
        )
        return response.message.id
    }

    public func approveDevice(targetDeviceID: String, approverDeviceID: String, signature: Data, token: String) async throws -> E2eeDeviceInfo {
        let row: DeviceRow = try await apiClient.post(
            APIEndpoint(method: .post, path: "/e2ee/mls/devices/\(targetDeviceID)/approve"),
            body: ApproveDeviceRequest(approverDeviceID: approverDeviceID, signature: signature.base64EncodedString()), bearerToken: token
        )
        return E2eeDeviceInfo(id: row.id, deviceLabel: row.deviceLabel, protocolVersion: row.protocolVersion, credentialFingerprint: row.credentialFingerprint, status: row.status)
    }

    public func revokeDevice(deviceID: String, token: String) async throws -> E2eeDeviceInfo {
        let row: DeviceRow = try await apiClient.delete(APIEndpoint(method: .delete, path: "/e2ee/mls/devices/\(deviceID)"), bearerToken: token)
        return E2eeDeviceInfo(id: row.id, deviceLabel: row.deviceLabel, protocolVersion: row.protocolVersion, credentialFingerprint: row.credentialFingerprint, status: row.status)
    }

    private func base64(_ data: Data) -> String {
        data.base64EncodedString()
    }

    private func urlEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}

private struct RootIdentityResponse: Decodable, Sendable {
    let publicKey: String

    enum CodingKeys: String, CodingKey {
        case publicKey = "root_public_key"
    }
}

private struct RegisterDeviceRequest: Encodable, Sendable {
    let deviceID: String
    let deviceLabel: String
    let rootPublicKey: String
    let rootFingerprint: String
    let credential: String
    let credentialFingerprint: String
    let approvalPublicKey: String
    let protocolVersion: Int
    let clientPlatform: String
    let clientVersion: String
    let clientBuild: String

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case deviceLabel = "device_label"
        case rootPublicKey = "root_public_key"
        case rootFingerprint = "root_fingerprint"
        case credential
        case credentialFingerprint = "credential_fingerprint"
        case approvalPublicKey = "approval_public_key"
        case protocolVersion = "protocol_version"
        case clientPlatform = "client_platform"
        case clientVersion = "client_version"
        case clientBuild = "client_build"
    }
}

private struct RegisterDeviceResponse: Decodable, Sendable {
    let status: String
}

private struct KeyPackagePayload: Encodable, Sendable {
    let id: String
    let packageRef: String
    let keyPackage: String
    let protocolVersion: Int
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case packageRef = "package_ref"
        case keyPackage = "key_package"
        case protocolVersion = "protocol_version"
        case expiresAt = "expires_at"
    }
}

private struct PublishKeyPackagesRequest: Encodable, Sendable {
    let packages: [KeyPackagePayload]
}

private struct PublishKeyPackagesResponse: Decodable, Sendable {
    let inserted: Int
}

private struct KeyPackageInventoryResponse: Decodable, Sendable {
    let available: Int
    let maxAvailable: Int

    enum CodingKeys: String, CodingKey {
        case available
        case maxAvailable = "max_available"
    }
}

private struct DeviceRow: Decodable, Sendable {
    let id: String
    let deviceLabel: String
    let protocolVersion: Int
    let credentialFingerprint: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case deviceLabel = "device_label"
        case protocolVersion = "protocol_version"
        case credentialFingerprint = "credential_fingerprint"
        case status
    }
}

private struct DirectRootIdentityResponse: Decodable, Sendable {
    let userID: String; let rootPublicKey: String; let rootFingerprint: String; let protocolVersion: Int
    enum CodingKeys: String, CodingKey { case userID = "user_id"; case rootPublicKey = "root_public_key"; case rootFingerprint = "root_fingerprint"; case protocolVersion = "protocol_version" }
}
private struct PeerDeviceResponse: Decodable, Sendable { let id: String; let protocolVersion: Int; let credentialFingerprint: String; enum CodingKeys: String, CodingKey { case id; case protocolVersion = "protocol_version"; case credentialFingerprint = "credential_fingerprint" } }
private struct RoomMemberDevicesResponse: Decodable, Sendable { let userID: String; let devices: [PeerDeviceResponse]; enum CodingKeys: String, CodingKey { case userID = "user_id"; case devices } }
private struct RoomEpochResponse: Decodable, Sendable { let membershipRevision: UInt64; let activeEpoch: UInt64; let status: String; enum CodingKeys: String, CodingKey { case membershipRevision = "membership_revision"; case activeEpoch = "active_epoch"; case status } }
private struct ClaimKeyPackageRequest: Encodable, Sendable { let roomID: String; let consumerDeviceID: String; enum CodingKeys: String, CodingKey { case roomID = "room_id"; case consumerDeviceID = "consumer_device_id" } }
private struct ClaimedKeyPackageResponse: Decodable, Sendable { let id: String; let deviceID: String; let keyPackage: String; enum CodingKeys: String, CodingKey { case id; case deviceID = "device_id"; case keyPackage = "key_package" } }
private struct SubmitControlRequest: Encodable, Sendable {
    let id: String; let epoch: UInt64; let membershipRevision: UInt64; let senderDeviceID: String; let recipientDeviceID: String?; let contentType: String; let envelope: String; let idempotencyKey: String
    init(_ value: E2eeOutgoingControlMessage) { id = value.messageID; epoch = value.epoch; membershipRevision = value.membershipRevision; senderDeviceID = value.senderDeviceID; recipientDeviceID = value.recipientDeviceID; contentType = value.contentType; envelope = value.envelope.base64EncodedString(); idempotencyKey = value.messageID }
    enum CodingKeys: String, CodingKey { case id, epoch, envelope; case membershipRevision = "membership_revision"; case senderDeviceID = "sender_device_id"; case recipientDeviceID = "recipient_device_id"; case contentType = "content_type"; case idempotencyKey = "idempotency_key" }
}
private struct ControlMessageResponse: Decodable, Sendable { let id: String; let epoch: UInt64; let membershipRevision: UInt64; let contentType: String; let envelope: String; let sequenceNumber: UInt64; enum CodingKeys: String, CodingKey { case id, epoch, envelope; case membershipRevision = "membership_revision"; case contentType = "content_type"; case sequenceNumber = "sequence_no" } }
private struct ConsumeControlRequest: Encodable, Sendable { let deviceID: String; enum CodingKeys: String, CodingKey { case deviceID = "device_id" } }
private struct EncryptionMetadataRequest: Encodable, Sendable { let protocolName = "mls"; let version = 1; let epoch: UInt64; let senderDeviceID: String; let contentType = "application"; let controlMessageID: String; enum CodingKeys: String, CodingKey { case protocolName = "protocol"; case version, epoch; case senderDeviceID = "sender_device_id"; case contentType = "content_type"; case controlMessageID = "control_message_id" } }
private struct SendEncryptedRequest: Encodable, Sendable { let encryptedContent: String; let encryptionMetadata: EncryptionMetadataRequest; let idempotencyKey: String; init(_ value: E2eeEncryptedMessageRequest) { encryptedContent = value.ciphertext.base64EncodedString(); encryptionMetadata = EncryptionMetadataRequest(epoch: value.epoch, senderDeviceID: value.senderDeviceID, controlMessageID: value.controlMessageID); idempotencyKey = value.idempotencyKey }; enum CodingKeys: String, CodingKey { case encryptedContent = "encrypted_content"; case encryptionMetadata = "encryption_metadata"; case idempotencyKey = "idempotency_key" } }
private struct SentMessageResponse: Decodable, Sendable { let id: String }
private struct SendEncryptedResponse: Decodable, Sendable { let message: SentMessageResponse }
private struct ApproveDeviceRequest: Encodable, Sendable { let approverDeviceID: String; let signature: String; enum CodingKeys: String, CodingKey { case approverDeviceID = "approver_device_id"; case signature } }
