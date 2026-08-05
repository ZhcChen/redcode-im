import Foundation

public struct E2eeDeviceNotReadyError: Error, Equatable, Sendable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}

public struct E2eeKeyPackageInventory: Equatable, Sendable {
    public let available: Int
    public let maxAvailable: Int

    public init(available: Int, maxAvailable: Int) {
        self.available = available
        self.maxAvailable = maxAvailable
    }
}

public struct E2eeDeviceInfo: Equatable, Sendable {
    public let id: String
    public let deviceLabel: String
    public let protocolVersion: Int
    public let credentialFingerprint: String
    public let status: String

    public init(
        id: String,
        deviceLabel: String = "",
        protocolVersion: Int = 0,
        credentialFingerprint: String = "",
        status: String = ""
    ) {
        self.id = id
        self.deviceLabel = deviceLabel
        self.protocolVersion = protocolVersion
        self.credentialFingerprint = credentialFingerprint
        self.status = status
    }
}

/// 设备本地安全存储契约（RedCodeStorage.E2eeSecureStateStore 提供实现）。
public protocol E2eeDeviceStateStorage: Sendable {
    func readState(accountID: String) async throws -> Data?
    func writeState(accountID: String, state: Data) async throws
    func readProfile(accountID: String) async throws -> E2eeDeviceProfile?
    func writeProfile(accountID: String, profile: E2eeDeviceProfile) async throws
    func deleteProfile(accountID: String) async throws
}

/// MLS 服务端契约（RedCodeNetworking.E2eeMLSAPIClient 提供实现）。
public protocol E2eeMLSApi: Sendable {
    func fetchRootIdentity(userID: String, token: String) async throws -> Data?
    func registerDevice(
        deviceID: String,
        deviceLabel: String,
        material: E2eeRegistrationMaterial,
        token: String
    ) async throws -> String
    func publishKeyPackages(deviceID: String, keyPackages: [Data], token: String) async throws -> Int
    func fetchKeyPackageInventory(deviceID: String, token: String) async throws -> E2eeKeyPackageInventory
    func listDevices(token: String) async throws -> [E2eeDeviceInfo]
}

/// 设备注册与 KeyPackage 低水位补充（对齐 H5 E2eeDeviceLifecycle）。
public actor E2eeDeviceLifecycle {
    private let storage: any E2eeDeviceStateStorage
    private let mlsApi: any E2eeMLSApi
    private let core: E2eeCommandClient
    private let newDeviceID: @Sendable () -> String
    private let nowMillis: @Sendable () -> Int64
    private var replenishLocks: [String: Task<Int, Error>] = [:]
    private var nextRetryAt: [String: Int64] = [:]

    public init(
        storage: any E2eeDeviceStateStorage,
        mlsApi: any E2eeMLSApi,
        core: E2eeCommandClient = E2eeCommandClient(),
        newDeviceID: @escaping @Sendable () -> String = { UUID().uuidString },
        nowMillis: @escaping @Sendable () -> Int64 = {
            Int64(Date().timeIntervalSince1970 * 1_000)
        }
    ) {
        self.storage = storage
        self.mlsApi = mlsApi
        self.core = core
        self.newDeviceID = newDeviceID
        self.nowMillis = nowMillis
    }

    public func ensureReady(accountID: String, deviceLabel: String, token: String) async throws -> E2eeDeviceProfile {
        let state = try await storage.readState(accountID: accountID)
        var profile = try await storage.readProfile(accountID: accountID)
        if state != nil && profile == nil {
            throw E2eeDeviceNotReadyError(message: "E2EE 设备状态不完整，拒绝重新生成身份")
        }
        if state == nil && profile?.registered == true {
            throw E2eeDeviceNotReadyError(message: "E2EE 已注册设备状态缺失，拒绝重新生成身份")
        }

        let material: E2eeRegistrationMaterial
        var currentState = state
        if currentState == nil {
            let rootPublicKey = try await mlsApi.fetchRootIdentity(userID: accountID, token: token)
            profile = profile ?? E2eeDeviceProfile(
                deviceId: newDeviceID(),
                deviceLabel: deviceLabel
            )
            try await storage.writeProfile(accountID: accountID, profile: profile!)
            let result = try core.initialize(
                deviceIdentity: "\(accountID)/\(profile!.deviceId)",
                rootPublicKey: rootPublicKey
            )
            material = try E2eeRegistrationMaterial.fromInitialize(result)
            currentState = material.state
            try await storage.writeState(accountID: accountID, state: currentState!)
        } else {
            material = try E2eeRegistrationMaterial.fromPublicMaterial(core.publicMaterial(state: currentState!))
        }
        guard let readyState = currentState else {
            throw E2eeDeviceNotReadyError(message: "E2EE 设备状态缺失")
        }

        guard let baseProfile = profile else {
            throw E2eeDeviceNotReadyError(message: "E2EE 设备档案缺失")
        }
        var readyProfile = baseProfile

        if !readyProfile.registered {
            let status = try await mlsApi.registerDevice(
                deviceID: readyProfile.deviceId,
                deviceLabel: readyProfile.deviceLabel,
                material: material,
                token: token
            )
            if status == "pending_approval" {
                readyProfile.registered = true
                readyProfile.keyPackagePublished = false
                readyProfile.deviceStatus = "pending_approval"
                try await storage.writeProfile(accountID: accountID, profile: readyProfile)
                return readyProfile
            }
            readyProfile.registered = true
            readyProfile.deviceStatus = "active"
            try await storage.writeProfile(accountID: accountID, profile: readyProfile)
        }

        if readyProfile.deviceStatus == "pending_approval" {
            let devices = try await mlsApi.listDevices(token: token)
            let current = devices.first { $0.id == readyProfile.deviceId }
            guard current?.status == "active" else {
                return readyProfile
            }
            readyProfile.deviceStatus = "active"
            try await storage.writeProfile(accountID: accountID, profile: readyProfile)
        }

        if readyProfile.deviceStatus != "pending_approval" && !readyProfile.keyPackagePublished {
            let generated = try core.generateKeyPackage(state: readyState)
            try await storage.writeState(accountID: accountID, state: generated.field(0))
            _ = try await mlsApi.publishKeyPackages(
                deviceID: readyProfile.deviceId,
                keyPackages: [try generated.field(1)],
                token: token
            )
            readyProfile.keyPackagePublished = true
            readyProfile.deviceStatus = "active"
            try await storage.writeProfile(accountID: accountID, profile: readyProfile)
        }
        return readyProfile
    }

    /// 账号级单飞的低水位补充；失败进入 60s 退避窗口。
    public func topUpKeyPackages(accountID: String, token: String) async throws -> Int {
        if let existing = replenishLocks[accountID] {
            return try await existing.value
        }
        let task = Task { [weak self] in
            guard let self else {
                throw E2eeDeviceNotReadyError(message: "E2EE 设备生命周期已释放")
            }
            return try await self.doTopUp(accountID: accountID, token: token)
        }
        replenishLocks[accountID] = task
        do {
            let result = try await task.value
            replenishLocks.removeValue(forKey: accountID)
            return result
        } catch {
            replenishLocks.removeValue(forKey: accountID)
            throw error
        }
    }

    private func doTopUp(accountID: String, token: String) async throws -> Int {
        guard let profile = try await storage.readProfile(accountID: accountID) else {
            throw E2eeDeviceNotReadyError(message: "E2EE 设备未完成初始化，无法补充 KeyPackage")
        }
        if !profile.registered || profile.deviceStatus == "pending_approval" || !profile.keyPackagePublished {
            if profile.deviceStatus == "pending_approval" {
                throw E2eeDeviceNotReadyError(message: "E2EE 设备待批准，批准后才能补充 KeyPackage")
            }
            throw E2eeDeviceNotReadyError(message: "E2EE 设备未完成初始化，无法补充 KeyPackage")
        }
        let now = nowMillis()
        if let retryAt = nextRetryAt[accountID], now < retryAt {
            return 0
        }

        let inventory = try await mlsApi.fetchKeyPackageInventory(deviceID: profile.deviceId, token: token)
        if inventory.available >= Self.keyPackageLowWatermark {
            nextRetryAt.removeValue(forKey: accountID)
            return 0
        }
        let needed = min(Self.keyPackageTarget - inventory.available, Self.keyPackageBatchLimit)
        guard needed > 0 else {
            nextRetryAt.removeValue(forKey: accountID)
            return 0
        }

        do {
            guard var state = try await storage.readState(accountID: accountID) else {
                throw E2eeDeviceNotReadyError(message: "E2EE 设备状态缺失")
            }
            var keyPackages: [Data] = []
            for _ in 0..<needed {
                let generated = try core.generateKeyPackage(state: state)
                state = try generated.field(0)
                keyPackages.append(try generated.field(1))
            }
            try await storage.writeState(accountID: accountID, state: state)
            let inserted = try await mlsApi.publishKeyPackages(
                deviceID: profile.deviceId,
                keyPackages: keyPackages,
                token: token
            )
            nextRetryAt.removeValue(forKey: accountID)
            return inserted
        } catch {
            nextRetryAt[accountID] = now + Self.replenishRetryAfterMs
            throw error
        }
    }

    private static let keyPackageLowWatermark = 10
    private static let keyPackageTarget = 40
    private static let keyPackageBatchLimit = 20
    private static let replenishRetryAfterMs: Int64 = 60_000
}
