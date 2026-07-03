import Foundation
import RedCodeCore

#if canImport(Security)
import Security

public actor KeychainKeyValueStore: KeyValueStore {
    private let service: String
    private let accessGroup: String?

    public init(
        service: String = Bundle.main.bundleIdentifier ?? "com.redcode.im.iosapp",
        accessGroup: String? = nil
    ) {
        self.service = service
        self.accessGroup = accessGroup
    }

    public func string(forKey key: String) async throws -> String? {
        var query = baseQuery(forKey: key)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw keychainError("读取 Keychain 失败", status: status)
        }
        guard
            let data = item as? Data,
            let value = String(data: data, encoding: .utf8)
        else {
            throw RedCodeError.storage("Keychain 数据格式无效")
        }
        return value
    }

    public func setString(_ value: String, forKey key: String) async throws {
        let data = Data(value.utf8)
        var query = baseQuery(forKey: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus != errSecItemNotFound {
            throw keychainError("更新 Keychain 失败", status: updateStatus)
        }

        query.merge(attributes) { _, new in new }
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw keychainError("写入 Keychain 失败", status: addStatus)
        }
    }

    public func removeValue(forKey key: String) async throws {
        let status = SecItemDelete(baseQuery(forKey: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw keychainError("删除 Keychain 失败", status: status)
        }
    }

    private func baseQuery(forKey key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        if let accessGroup, !accessGroup.isEmpty {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    private func keychainError(_ message: String, status: OSStatus) -> RedCodeError {
        RedCodeError.storage("\(message): \(status)")
    }
}
#endif
