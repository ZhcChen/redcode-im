import Foundation

public struct StoredPushDeviceIdentity: Equatable, Sendable {
    public let deviceID: String
    public let deviceToken: String?
    public let channel: String?
    public let updatedAt: Date?

    public init(
        deviceID: String,
        deviceToken: String? = nil,
        channel: String? = nil,
        updatedAt: Date? = nil
    ) {
        self.deviceID = deviceID
        self.deviceToken = deviceToken
        self.channel = channel
        self.updatedAt = updatedAt
    }
}

@MainActor
public protocol PushDeviceIdentityStore: AnyObject {
    func getOrCreateDeviceID() throws -> String
    func loadIdentity() throws -> StoredPushDeviceIdentity?
    func saveRegisteredToken(_ token: String, channel: String) throws
    func clearRegisteredToken() throws
    func clearAll() throws
}

@MainActor
public final class UserDefaultsPushDeviceIdentityStore: PushDeviceIdentityStore {
    private let defaults: UserDefaults
    private let keyPrefix: String

    public init(
        defaults: UserDefaults = .standard,
        keyPrefix: String = "redcode-ios-push"
    ) {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    public func getOrCreateDeviceID() throws -> String {
        if let existing = defaults.string(forKey: key("device_id"))?.trimmingCharacters(in: .whitespacesAndNewlines),
           !existing.isEmpty {
            return existing
        }
        let deviceID = UUID().uuidString
        defaults.set(deviceID, forKey: key("device_id"))
        return deviceID
    }

    public func loadIdentity() throws -> StoredPushDeviceIdentity? {
        guard let deviceID = defaults.string(forKey: key("device_id"))?.trimmingCharacters(in: .whitespacesAndNewlines),
              !deviceID.isEmpty else {
            return nil
        }
        let timestamp = defaults.object(forKey: key("updated_at")) as? TimeInterval
        return StoredPushDeviceIdentity(
            deviceID: deviceID,
            deviceToken: defaults.string(forKey: key("device_token")),
            channel: defaults.string(forKey: key("channel")),
            updatedAt: timestamp.map { Date(timeIntervalSince1970: $0) }
        )
    }

    public func saveRegisteredToken(_ token: String, channel: String) throws {
        _ = try getOrCreateDeviceID()
        defaults.set(token.trimmingCharacters(in: .whitespacesAndNewlines), forKey: key("device_token"))
        defaults.set(channel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), forKey: key("channel"))
        defaults.set(Date().timeIntervalSince1970, forKey: key("updated_at"))
    }

    public func clearRegisteredToken() throws {
        defaults.removeObject(forKey: key("device_token"))
        defaults.removeObject(forKey: key("channel"))
        defaults.removeObject(forKey: key("updated_at"))
    }

    public func clearAll() throws {
        defaults.removeObject(forKey: key("device_id"))
        try clearRegisteredToken()
    }

    private func key(_ name: String) -> String {
        "\(keyPrefix).\(name)"
    }
}
