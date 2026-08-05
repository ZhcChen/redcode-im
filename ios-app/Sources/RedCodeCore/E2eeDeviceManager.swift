import Foundation

public protocol E2eeDeviceApprovalSigning: Sendable {
    func signDeviceApproval(state: Data, payload: Data) throws -> E2eeCommandResult
}

extension E2eeCommandClient: E2eeDeviceApprovalSigning {}

public actor E2eeDeviceManager {
    private let storage: any E2eeDeviceStateStorage
    private let api: any E2eeMLSApi
    private let signer: any E2eeDeviceApprovalSigning

    public init(
        storage: any E2eeDeviceStateStorage,
        api: any E2eeMLSApi,
        signer: any E2eeDeviceApprovalSigning = E2eeCommandClient()
    ) {
        self.storage = storage
        self.api = api
        self.signer = signer
    }

    public func listDevices(token: String) async throws -> [E2eeDeviceInfo] {
        try await api.listDevices(token: token)
    }

    public func approveDevice(accountID: String, target: E2eeDeviceInfo, token: String) async throws -> E2eeDeviceInfo {
        guard let profile = try await storage.readProfile(accountID: accountID) else { throw E2eeDirectMessageError("E2EE 设备档案缺失") }
        guard profile.deviceStatus == "active" else { throw E2eeDirectMessageError("待批准或已撤销设备不能批准其他设备") }
        guard let state = try await storage.readState(accountID: accountID) else { throw E2eeDirectMessageError("E2EE 设备状态缺失") }
        guard let fingerprint = Data(base64Encoded: target.credentialFingerprint) else { throw E2eeDirectMessageError("E2EE 设备指纹格式无效") }
        guard target.protocolVersion == 1, fingerprint.count == 32 else { throw E2eeDirectMessageError("E2EE 设备协议或指纹无效") }
        let payload = try deviceApprovalPayload(userID: accountID, approverDeviceID: profile.deviceId, targetDeviceID: target.id, protocolVersion: target.protocolVersion, credentialFingerprint: fingerprint)
        let signature = try signer.signDeviceApproval(state: state, payload: payload).field(0)
        return try await api.approveDevice(targetDeviceID: target.id, approverDeviceID: profile.deviceId, signature: signature, token: token)
    }

    public func revokeDevice(deviceID: String, token: String) async throws -> E2eeDeviceInfo {
        try await api.revokeDevice(deviceID: deviceID, token: token)
    }
}

public func deviceApprovalPayload(userID: String, approverDeviceID: String, targetDeviceID: String, protocolVersion: Int, credentialFingerprint: Data) throws -> Data {
    guard (1...Int(UInt16.max)).contains(protocolVersion), credentialFingerprint.count <= Int(UInt16.max) else { throw E2eeDirectMessageError("E2EE 批准负载参数无效") }
    var output = Data("redcode-im/e2ee/device-approval/v1\u{0}".utf8)
    for value in [userID, approverDeviceID, targetDeviceID] {
        guard let uuid = UUID(uuidString: value) else { throw E2eeDirectMessageError("E2EE 设备 UUID 格式无效") }
        var bytes = uuid.uuid; withUnsafeBytes(of: &bytes) { output.append(contentsOf: $0) }
    }
    var version = UInt16(protocolVersion).bigEndian; var length = UInt16(credentialFingerprint.count).bigEndian
    withUnsafeBytes(of: &version) { output.append(contentsOf: $0) }; withUnsafeBytes(of: &length) { output.append(contentsOf: $0) }
    output.append(credentialFingerprint); return output
}
