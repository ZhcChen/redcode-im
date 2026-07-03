import Foundation
import RedCodeCore

public protocol AuthSessionStore: Sendable {
    func save(_ session: AuthSession) async throws
    func read() async throws -> AuthSession?
    func updateUser(_ user: AuthUser) async throws
    func clear() async throws
}

public actor KeyValueAuthSessionStore: AuthSessionStore {
    private enum Keys {
        static let token = "auth_token"
        static let user = "auth_user"
        static let refreshToken = "auth_refresh_token"
    }

    private let keyValueStore: KeyValueStore
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        keyValueStore: KeyValueStore,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.keyValueStore = keyValueStore
        self.encoder = encoder
        self.decoder = decoder
    }

    public func save(_ session: AuthSession) async throws {
        try await keyValueStore.setString(session.token, forKey: Keys.token)
        try await keyValueStore.setString(try encode(session.user), forKey: Keys.user)

        if let refreshToken = session.refreshToken, !refreshToken.isEmpty {
            try await keyValueStore.setString(refreshToken, forKey: Keys.refreshToken)
        } else {
            try await keyValueStore.removeValue(forKey: Keys.refreshToken)
        }
    }

    public func read() async throws -> AuthSession? {
        guard
            let token = try await keyValueStore.string(forKey: Keys.token),
            let userJSON = try await keyValueStore.string(forKey: Keys.user)
        else {
            return nil
        }

        do {
            let user = try decoder.decode(AuthUser.self, from: Data(userJSON.utf8))
            let refreshToken = try await keyValueStore.string(forKey: Keys.refreshToken)
            return AuthSession(token: token, refreshToken: refreshToken, user: user)
        } catch {
            try await clear()
            return nil
        }
    }

    public func updateUser(_ user: AuthUser) async throws {
        guard try await keyValueStore.string(forKey: Keys.token) != nil else {
            return
        }

        try await keyValueStore.setString(try encode(user), forKey: Keys.user)
    }

    public func clear() async throws {
        try await keyValueStore.removeValue(forKey: Keys.token)
        try await keyValueStore.removeValue(forKey: Keys.user)
        try await keyValueStore.removeValue(forKey: Keys.refreshToken)
    }

    private func encode(_ user: AuthUser) throws -> String {
        let data = try encoder.encode(user)
        guard let value = String(data: data, encoding: .utf8) else {
            throw RedCodeError.storage("Unable to encode auth user")
        }
        return value
    }
}
