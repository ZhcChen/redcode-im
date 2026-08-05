import CryptoKit
import Foundation
import GRDB
import RedCodeCore
import Security

/// E2EE 协议状态存储的 fail closed 错误。
public enum E2eeSecureStateError: Error, Equatable, Sendable {
    case corrupted(String)
    case unavailable(String)
}

/// E2EE 协议状态的 AES-GCM 密文记录，版本/布局与 H5 secure-state-storage 对齐：
/// version=1、12 字节 nonce、ciphertext（含 128 位 GCM tag），AAD 绑定账号。
public struct E2eeEncryptedStateRecord: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "redCodeE2eeStateRecord"

    public var accountID: String
    public var version: Int
    public var nonce: Data
    public var ciphertext: Data

    public init(accountID: String, version: Int, nonce: Data, ciphertext: Data) {
        self.accountID = accountID
        self.version = version
        self.nonce = nonce
        self.ciphertext = ciphertext
    }
}

/// 附加密文记录（设备档案等），(accountID, blobKey) 复合主键。
public struct E2eeEncryptedBlobRecord: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "redCodeE2eeBlobRecord"

    public var accountID: String
    public var blobKey: String
    public var version: Int
    public var nonce: Data
    public var ciphertext: Data

    public init(accountID: String, blobKey: String, version: Int, nonce: Data, ciphertext: Data) {
        self.accountID = accountID
        self.blobKey = blobKey
        self.version = version
        self.nonce = nonce
        self.ciphertext = ciphertext
    }
}

/// 与 H5 secure-state-storage 一致的 AAD 前缀构造。
public enum E2eeSecureStateAAD {
    public static func state(_ accountID: String) -> Data {
        Data("redcode-im/e2ee-state/v1\u{0}".utf8) +
            Data(accountID.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
    }

    public static func profile(_ accountID: String) -> Data {
        Data("redcode-im/e2ee-device-profile/v1\u{0}".utf8) +
            Data(accountID.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
    }

    public static func metadata(_ accountID: String, key: String) -> Data {
        Data("redcode-im/e2ee-metadata/v1\u{0}".utf8) +
            Data(accountID.trimmingCharacters(in: .whitespacesAndNewlines).utf8) + Data([0]) +
            Data(key.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
    }
}

/// 按账号提供包装密钥的加解密原语。
public protocol E2eeStateCipher: Sendable {
    func encrypt(accountID: String, plaintext: Data, aad: Data) async throws -> E2eeEncryptedStateRecord
    func decrypt(accountID: String, record: E2eeEncryptedStateRecord, aad: Data) async throws -> Data
    func deleteKey(accountID: String) async throws
}

/// 密文记录持久化层。
public protocol E2eeStateBlobStore: Sendable {
    func save(_ record: E2eeEncryptedStateRecord) async throws
    func load(accountID: String) async throws -> E2eeEncryptedStateRecord?
    func delete(accountID: String) async throws
    func saveBlob(accountID: String, key: String, record: E2eeEncryptedStateRecord) async throws
    func loadBlob(accountID: String, key: String) async throws -> E2eeEncryptedStateRecord?
    func deleteBlob(accountID: String, key: String) async throws
}

/// Keychain 保存 256 位对称包装密钥，CryptoKit AES-GCM 加密 RCST 状态。
/// 密钥仅存于 Keychain（AfterFirstUnlockThisDeviceOnly），密文带随机 nonce
/// 与账号绑定 AAD；密钥缺失、篡改、版本不匹配一律 fail closed。
public actor CryptoKitE2eeStateCipher: E2eeStateCipher {
    private let keyStore: any KeyValueStore

    public init(keyStore: any KeyValueStore) {
        self.keyStore = keyStore
    }

    public func encrypt(accountID: String, plaintext: Data, aad: Data) async throws -> E2eeEncryptedStateRecord {
        let key = try await key(for: accountID)
        let nonce = try randomNonce()
        let sealed = try AES.GCM.seal(
            plaintext,
            using: key,
            nonce: nonce,
            authenticating: aad
        )
        guard let combined = sealed.combined else {
            throw E2eeSecureStateError.unavailable("AES-GCM 密文组合失败")
        }
        return E2eeEncryptedStateRecord(
            accountID: accountID,
            version: Self.stateVersion,
            nonce: Data(nonce),
            ciphertext: combined
        )
    }

    public func decrypt(accountID: String, record: E2eeEncryptedStateRecord, aad: Data) async throws -> Data {
        guard record.version == Self.stateVersion else {
            throw E2eeSecureStateError.corrupted("E2EE 状态版本不匹配")
        }
        guard
            let encoded = try await keyStore.string(forKey: Self.keyName(accountID)),
            let keyData = Data(base64Encoded: encoded)
        else {
            throw E2eeSecureStateError.corrupted("E2EE 包装密钥缺失")
        }
        let key = SymmetricKey(data: keyData)
        do {
            let sealed = try AES.GCM.SealedBox(combined: record.ciphertext)
            return try AES.GCM.open(sealed, using: key, authenticating: aad)
        } catch {
            throw E2eeSecureStateError.corrupted("E2EE 状态密文校验失败")
        }
    }

    public func deleteKey(accountID: String) async throws {
        try await keyStore.removeValue(forKey: Self.keyName(accountID))
    }

    static func keyName(_ accountID: String) -> String {
        "redcode_e2ee_state_\(accountID.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    private func key(for accountID: String) async throws -> SymmetricKey {
        if
            let encoded = try await keyStore.string(forKey: Self.keyName(accountID)),
            let keyData = Data(base64Encoded: encoded)
        {
            return SymmetricKey(data: keyData)
        }
        let key = SymmetricKey(size: .bits256)
        let encoded = key.withUnsafeBytes { Data($0) }.base64EncodedString()
        try await keyStore.setString(encoded, forKey: Self.keyName(accountID))
        return key
    }

    private func randomNonce() throws -> AES.GCM.Nonce {
        var nonceBytes = Data(count: 12)
        let status = nonceBytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, 12, buffer.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw E2eeSecureStateError.unavailable("安全随机数生成失败")
        }
        return try AES.GCM.Nonce(data: nonceBytes)
    }

    private static let stateVersion = 1
}

/// GRDB 实现的密文 blob 存储（表：redCodeE2eeStateRecord）。
@MainActor
public final class GRDBE2eeStateBlobStore: E2eeStateBlobStore {
    private let database: RedCodeDatabase

    public init(database: RedCodeDatabase) {
        self.database = database
    }

    public func save(_ record: E2eeEncryptedStateRecord) async throws {
        try await database.dbQueue.write { db in
            try record.upsert(db)
        }
    }

    public func load(accountID: String) async throws -> E2eeEncryptedStateRecord? {
        try await database.dbQueue.read { db in
            try E2eeEncryptedStateRecord.fetchOne(db, key: accountID)
        }
    }

    public func delete(accountID: String) async throws {
        try await database.dbQueue.write { db in
            _ = try E2eeEncryptedStateRecord.deleteOne(db, key: accountID)
        }
    }

    public func saveBlob(accountID: String, key: String, record: E2eeEncryptedStateRecord) async throws {
        try await database.dbQueue.write { db in
            let blob = E2eeEncryptedBlobRecord(
                accountID: record.accountID,
                blobKey: key,
                version: record.version,
                nonce: record.nonce,
                ciphertext: record.ciphertext
            )
            try blob.upsert(db)
        }
    }

    public func loadBlob(accountID: String, key: String) async throws -> E2eeEncryptedStateRecord? {
        try await database.dbQueue.read { db in
            guard let blob = try E2eeEncryptedBlobRecord.fetchOne(
                db,
                key: ["accountID": accountID, "blobKey": key]
            ) else {
                return nil
            }
            return E2eeEncryptedStateRecord(
                accountID: blob.accountID,
                version: blob.version,
                nonce: blob.nonce,
                ciphertext: blob.ciphertext
            )
        }
    }

    public func deleteBlob(accountID: String, key: String) async throws {
        try await database.dbQueue.write { db in
            _ = try E2eeEncryptedBlobRecord.deleteOne(
                db,
                key: ["accountID": accountID, "blobKey": key]
            )
        }
    }
}

/// 测试用内存 blob 存储。
public actor InMemoryE2eeStateBlobStore: E2eeStateBlobStore {
    private var records: [String: E2eeEncryptedStateRecord] = [:]
    private var blobs: [String: [String: E2eeEncryptedStateRecord]] = [:]

    public init() {}

    public func save(_ record: E2eeEncryptedStateRecord) async throws {
        records[record.accountID] = record
    }

    public func load(accountID: String) async throws -> E2eeEncryptedStateRecord? {
        records[accountID]
    }

    public func delete(accountID: String) async throws {
        records.removeValue(forKey: accountID)
    }

    public func saveBlob(accountID: String, key: String, record: E2eeEncryptedStateRecord) async throws {
        blobs[accountID, default: [:]][key] = record
    }

    public func loadBlob(accountID: String, key: String) async throws -> E2eeEncryptedStateRecord? {
        blobs[accountID]?[key]
    }

    public func deleteBlob(accountID: String, key: String) async throws {
        blobs[accountID]?.removeValue(forKey: key)
    }
}

/// E2EE 协议状态的安全存储编排：写前由共享核心校验，读后再次校验；
/// 注销/切换账号时同时清除包装密钥与密文。
public actor E2eeSecureStateStore {
    private let cipher: any E2eeStateCipher
    private let blobs: any E2eeStateBlobStore
    private let validateProtocolState: @Sendable (Data) -> Bool

    public init(
        cipher: any E2eeStateCipher,
        blobs: any E2eeStateBlobStore,
        validateProtocolState: @escaping @Sendable (Data) -> Bool = {
            E2eeCommandClient().validateProtocolState($0)
        }
    ) {
        self.cipher = cipher
        self.blobs = blobs
        self.validateProtocolState = validateProtocolState
    }

    public func write(accountID: String, state: Data) async throws {
        guard !accountID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw E2eeSecureStateError.corrupted("E2EE 账号标识不能为空")
        }
        guard validateProtocolState(state) else {
            throw E2eeSecureStateError.corrupted("拒绝保存无效的 E2EE 协议状态")
        }
        let record = try await cipher.encrypt(
            accountID: accountID,
            plaintext: state,
            aad: E2eeSecureStateAAD.state(accountID)
        )
        try await blobs.save(record)
    }

    public func read(accountID: String) async throws -> Data? {
        guard !accountID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw E2eeSecureStateError.corrupted("E2EE 账号标识不能为空")
        }
        guard let record = try await blobs.load(accountID: accountID) else {
            return nil
        }
        let state: Data
        do {
            state = try await cipher.decrypt(
                accountID: accountID,
                record: record,
                aad: E2eeSecureStateAAD.state(accountID)
            )
        } catch let error as E2eeSecureStateError {
            throw error
        } catch {
            throw E2eeSecureStateError.corrupted("E2EE 状态解密失败")
        }
        guard validateProtocolState(state) else {
            throw E2eeSecureStateError.corrupted("E2EE 协议状态已损坏或无法解密")
        }
        return state
    }

    public func delete(accountID: String) async throws {
        try await cipher.deleteKey(accountID: accountID)
        try await blobs.delete(accountID: accountID)
        try await blobs.deleteBlob(accountID: accountID, key: Self.profileBlobKey)
    }

    public func writeProfile(accountID: String, profile: E2eeDeviceProfile) async throws {
        guard !accountID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw E2eeSecureStateError.corrupted("E2EE 账号标识不能为空")
        }
        guard profile.validate() else {
            throw E2eeSecureStateError.corrupted("E2EE 设备档案格式无效")
        }
        let data = try JSONEncoder().encode(profile)
        let record = try await cipher.encrypt(
            accountID: accountID,
            plaintext: data,
            aad: E2eeSecureStateAAD.profile(accountID)
        )
        try await blobs.saveBlob(accountID: accountID, key: Self.profileBlobKey, record: record)
    }

    public func readProfile(accountID: String) async throws -> E2eeDeviceProfile? {
        guard !accountID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw E2eeSecureStateError.corrupted("E2EE 账号标识不能为空")
        }
        guard let record = try await blobs.loadBlob(accountID: accountID, key: Self.profileBlobKey) else {
            return nil
        }
        let data: Data
        do {
            data = try await cipher.decrypt(
                accountID: accountID,
                record: record,
                aad: E2eeSecureStateAAD.profile(accountID)
            )
        } catch let error as E2eeSecureStateError {
            throw error
        } catch {
            throw E2eeSecureStateError.corrupted("E2EE 设备档案解密失败")
        }
        guard let profile = try? JSONDecoder().decode(E2eeDeviceProfile.self, from: data),
              profile.validate()
        else {
            throw E2eeSecureStateError.corrupted("E2EE 设备档案已损坏")
        }
        return profile
    }

    public func deleteProfile(accountID: String) async throws {
        try await blobs.deleteBlob(accountID: accountID, key: Self.profileBlobKey)
    }

    public func writeMetadata(accountID: String, key: String, data: Data) async throws {
        guard !accountID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !key.isEmpty else {
            throw E2eeSecureStateError.corrupted("E2EE 元数据标识不能为空")
        }
        let record = try await cipher.encrypt(accountID: accountID, plaintext: data, aad: E2eeSecureStateAAD.metadata(accountID, key: key))
        try await blobs.saveBlob(accountID: accountID, key: "metadata:\(key)", record: record)
    }

    public func readMetadata(accountID: String, key: String) async throws -> Data? {
        guard let record = try await blobs.loadBlob(accountID: accountID, key: "metadata:\(key)") else { return nil }
        return try await cipher.decrypt(accountID: accountID, record: record, aad: E2eeSecureStateAAD.metadata(accountID, key: key))
    }

    private static let profileBlobKey = "device-profile"
}

extension E2eeSecureStateStore: E2eeDeviceStateStorage {
    public func readState(accountID: String) async throws -> Data? {
        try await read(accountID: accountID)
    }

    public func writeState(accountID: String, state: Data) async throws {
        try await write(accountID: accountID, state: state)
    }
}

extension E2eeSecureStateStore: E2eeDirectMessageStorage {}
