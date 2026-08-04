import Foundation

public protocol KeyValueStore: Sendable {
    func string(forKey key: String) async throws -> String?
    func setString(_ value: String, forKey key: String) async throws
    func removeValue(forKey key: String) async throws
}

public actor InMemoryKeyValueStore: KeyValueStore {
    private var values: [String: String]

    public init(values: [String: String] = [:]) {
        self.values = values
    }

    public func string(forKey key: String) async throws -> String? {
        values[key]
    }

    public func setString(_ value: String, forKey key: String) async throws {
        values[key] = value
    }

    public func removeValue(forKey key: String) async throws {
        values.removeValue(forKey: key)
    }
}
