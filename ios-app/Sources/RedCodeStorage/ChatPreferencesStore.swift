import Foundation

public enum ChatBackgroundKind: String, Codable, Equatable, Sendable {
    case `default`
    case preset
    case customImage
}

public struct ChatBackgroundPreference: Codable, Equatable, Sendable {
    public let kind: ChatBackgroundKind
    public let value: String?

    public init(kind: ChatBackgroundKind = .default, value: String? = nil) {
        self.kind = kind
        self.value = value
    }

    public static let `default` = ChatBackgroundPreference()
}

public protocol ChatPreferencesStore: Sendable {
    func loadBackground() async throws -> ChatBackgroundPreference
    func saveBackground(_ preference: ChatBackgroundPreference) async throws
    func resetBackground() async throws
}

public actor UserDefaultsChatPreferencesStore: ChatPreferencesStore {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard, key: String = "redcode-ios-chat-background") {
        self.defaults = defaults
        self.key = key
    }

    public func loadBackground() async throws -> ChatBackgroundPreference {
        guard let data = defaults.data(forKey: key) else {
            return .default
        }
        return (try? decoder.decode(ChatBackgroundPreference.self, from: data)) ?? .default
    }

    public func saveBackground(_ preference: ChatBackgroundPreference) async throws {
        defaults.set(try encoder.encode(preference), forKey: key)
    }

    public func resetBackground() async throws {
        defaults.removeObject(forKey: key)
    }
}
