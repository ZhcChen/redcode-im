import Foundation

/// 与 H5 device-profile.ts 对齐的本地设备档案（JSON envelope version=1）。
public struct E2eeDeviceProfile: Codable, Equatable, Sendable {
    public static let profileVersion = 1

    public let version: Int
    public let deviceId: String
    public let deviceLabel: String
    public var registered: Bool
    public var keyPackagePublished: Bool
    public var deviceStatus: String
    public var lastControlSequences: [String: UInt64]
    public var lastCommitMessageIds: [String: String]

    public init(
        deviceId: String,
        deviceLabel: String,
        registered: Bool = false,
        keyPackagePublished: Bool = false,
        deviceStatus: String = "active",
        lastControlSequences: [String: UInt64] = [:],
        lastCommitMessageIds: [String: String] = [:]
    ) {
        self.version = Self.profileVersion
        self.deviceId = deviceId
        self.deviceLabel = deviceLabel
        self.registered = registered
        self.keyPackagePublished = keyPackagePublished
        self.deviceStatus = deviceStatus
        self.lastControlSequences = lastControlSequences
        self.lastCommitMessageIds = lastCommitMessageIds
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case deviceId = "device_id"
        case deviceLabel = "device_label"
        case registered
        case keyPackagePublished = "key_package_published"
        case deviceStatus = "device_status"
        case lastControlSequences = "last_control_sequences"
        case lastCommitMessageIds = "last_commit_message_ids"
    }

    public func validate() -> Bool {
        version == Self.profileVersion
            && !deviceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && ["active", "pending_approval"].contains(deviceStatus)
    }
}

/// 注册/恢复设备的 MLS 登记材料，字段顺序与 e2ee-core 命令契约一致。
public struct E2eeRegistrationMaterial: Sendable {
    public let state: Data
    public let keyPackage: Data
    public let rootPublicKey: Data
    public let rootFingerprint: Data
    public let credential: Data
    public let credentialFingerprint: Data
    public let approvalPublicKey: Data

    public init(
        state: Data,
        keyPackage: Data,
        rootPublicKey: Data,
        rootFingerprint: Data,
        credential: Data,
        credentialFingerprint: Data,
        approvalPublicKey: Data
    ) {
        self.state = state
        self.keyPackage = keyPackage
        self.rootPublicKey = rootPublicKey
        self.rootFingerprint = rootFingerprint
        self.credential = credential
        self.credentialFingerprint = credentialFingerprint
        self.approvalPublicKey = approvalPublicKey
    }

    public static func fromInitialize(_ result: E2eeCommandResult) throws -> E2eeRegistrationMaterial {
        guard result.fieldCount == 7 else {
            throw E2eeCommandError(message: "E2EE 初始化响应字段数量无效")
        }
        return E2eeRegistrationMaterial(
            state: try result.field(0),
            keyPackage: try result.field(1),
            rootPublicKey: try result.field(2),
            rootFingerprint: try result.field(3),
            credential: try result.field(4),
            credentialFingerprint: try result.field(5),
            approvalPublicKey: try result.field(6)
        )
    }

    public static func fromPublicMaterial(_ result: E2eeCommandResult) throws -> E2eeRegistrationMaterial {
        guard result.fieldCount == 6 else {
            throw E2eeCommandError(message: "E2EE 公开材料响应字段数量无效")
        }
        return E2eeRegistrationMaterial(
            state: try result.field(0),
            keyPackage: Data(),
            rootPublicKey: try result.field(1),
            rootFingerprint: try result.field(2),
            credential: try result.field(3),
            credentialFingerprint: try result.field(4),
            approvalPublicKey: try result.field(5)
        )
    }
}
