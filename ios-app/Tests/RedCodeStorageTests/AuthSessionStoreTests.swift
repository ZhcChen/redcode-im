import XCTest
@testable import RedCodeCore
@testable import RedCodeStorage

final class AuthSessionStoreTests: XCTestCase {
    func testAuthSessionStorePersistsSessionLikeFlutterTokenStorage() async throws {
        let keyValueStore = InMemoryKeyValueStore()
        let sessionStore = KeyValueAuthSessionStore(keyValueStore: keyValueStore)
        let user = AuthUser(
            id: "u1",
            username: "user1",
            email: "user@example.com",
            nickname: "小红",
            avatarURL: "https://example.test/avatar.png",
            avatarObjectKey: "avatars/u1.png",
            status: "active"
        )

        try await sessionStore.save(
            AuthSession(token: "access-token", refreshToken: "refresh-token", user: user)
        )

        let restored = try await sessionStore.read()
        XCTAssertEqual(restored?.token, "access-token")
        XCTAssertEqual(restored?.refreshToken, "refresh-token")
        XCTAssertEqual(restored?.user, user)
    }

    func testAuthSessionStoreClearsCorruptUserPayload() async throws {
        let keyValueStore = InMemoryKeyValueStore()
        let sessionStore = KeyValueAuthSessionStore(keyValueStore: keyValueStore)

        try await keyValueStore.setString("token", forKey: "auth_token")
        try await keyValueStore.setString("{", forKey: "auth_user")

        let restored = try await sessionStore.read()
        let storedToken = try await keyValueStore.string(forKey: "auth_token")
        let storedUser = try await keyValueStore.string(forKey: "auth_user")

        XCTAssertNil(restored)
        XCTAssertNil(storedToken)
        XCTAssertNil(storedUser)
    }

    func testAuthSessionStoreUpdatesUserOnlyWhenSessionExists() async throws {
        let keyValueStore = InMemoryKeyValueStore()
        let sessionStore = KeyValueAuthSessionStore(keyValueStore: keyValueStore)
        let user = AuthUser(id: "u1", username: "user1")

        try await sessionStore.updateUser(user)
        let restored = try await sessionStore.read()

        XCTAssertNil(restored)
    }
}
