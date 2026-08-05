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
        case publicKey = "public_key"
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
