import XCTest
@testable import RedCodeCore
@testable import RedCodeFeatures
@testable import RedCodeNetworking
@testable import RedCodeStorage

@MainActor
final class AuthControllerTests: XCTestCase {
    func testRestoreSessionLoadsPersistedSession() async throws {
        let user = AuthUser(id: "u1", username: "bear")
        let session = AuthSession(token: "access-token", refreshToken: "refresh-token", user: user)
        let store = KeyValueAuthSessionStore(keyValueStore: InMemoryKeyValueStore())
        try await store.save(session)
        let controller = AuthController(api: MockAuthAPIService(), sessionStore: store)

        await controller.restoreSession()

        XCTAssertEqual(controller.session, session)
        XCTAssertEqual(controller.state, .authenticated(userID: "u1"))
        XCTAssertFalse(controller.isLoading)
        XCTAssertNil(controller.errorMessage)
    }

    func testRegisterAndLoginPersistsLoggedInSession() async throws {
        let api = MockAuthAPIService()
        let store = KeyValueAuthSessionStore(keyValueStore: InMemoryKeyValueStore())
        let controller = AuthController(api: api, sessionStore: store)

        let session = try await controller.registerAndLogin(
            username: " Bear ",
            password: "secret123",
            nickname: "Bear"
        )

        let calls = await api.calls
        let restored = try await store.read()

        XCTAssertEqual(calls, [
            .register(username: " Bear ", password: "secret123", nickname: "Bear"),
            .login(username: " Bear ", password: "secret123"),
        ])
        XCTAssertEqual(session.token, "access-token")
        XCTAssertEqual(restored, session)
        XCTAssertEqual(controller.state, .authenticated(userID: "u1"))
        XCTAssertFalse(controller.isLoading)
    }

    func testLoginFailureDoesNotPersistSessionAndSetsError() async throws {
        let api = MockAuthAPIService(loginError: RedCodeError.authentication("账号或密码错误"))
        let store = KeyValueAuthSessionStore(keyValueStore: InMemoryKeyValueStore())
        let controller = AuthController(api: api, sessionStore: store)

        do {
            _ = try await controller.login(username: "bear", password: "wrong-password")
            XCTFail("Expected login failure")
        } catch let error as RedCodeError {
            XCTAssertEqual(error, .authentication("账号或密码错误"))
        }

        let restored = try await store.read()
        XCTAssertNil(restored)
        XCTAssertNil(controller.session)
        XCTAssertEqual(controller.state, .unauthenticated)
        XCTAssertNotNil(controller.errorMessage)
        XCTAssertFalse(controller.isLoading)
    }

    func testRefreshCurrentUserUpdatesStoredUser() async throws {
        let api = MockAuthAPIService(
            currentUser: AuthUser(id: "u1", username: "bear", nickname: "New Bear")
        )
        let store = KeyValueAuthSessionStore(keyValueStore: InMemoryKeyValueStore())
        try await store.save(
            AuthSession(
                token: "access-token",
                refreshToken: "refresh-token",
                user: AuthUser(id: "u1", username: "bear", nickname: "Old Bear")
            )
        )
        let controller = AuthController(api: api, sessionStore: store)
        await controller.restoreSession()

        let refreshedUser = try await controller.refreshCurrentUser()
        let restored = try await store.read()

        XCTAssertEqual(refreshedUser?.nickname, "New Bear")
        XCTAssertEqual(controller.session?.user.nickname, "New Bear")
        XCTAssertEqual(restored?.user.nickname, "New Bear")
    }

    func testLogoutClearsSessionStoreAndState() async throws {
        let store = KeyValueAuthSessionStore(keyValueStore: InMemoryKeyValueStore())
        try await store.save(
            AuthSession(token: "access-token", user: AuthUser(id: "u1", username: "bear"))
        )
        let controller = AuthController(api: MockAuthAPIService(), sessionStore: store)
        await controller.restoreSession()

        try await controller.logout()

        let restored = try await store.read()
        XCTAssertNil(restored)
        XCTAssertNil(controller.session)
        XCTAssertEqual(controller.state, .unauthenticated)
    }

    func testChangePasswordRequiresSession() async throws {
        let controller = AuthController(
            api: MockAuthAPIService(),
            sessionStore: KeyValueAuthSessionStore(keyValueStore: InMemoryKeyValueStore())
        )

        do {
            try await controller.changePassword(oldPassword: "old", newPassword: "new")
            XCTFail("Expected unauthenticated change-password failure")
        } catch let error as RedCodeError {
            XCTAssertEqual(error, .authentication("未登录"))
        }
    }

    func testChangePasswordDelegatesWhenSessionExists() async throws {
        let api = MockAuthAPIService()
        let store = KeyValueAuthSessionStore(keyValueStore: InMemoryKeyValueStore())
        try await store.save(
            AuthSession(token: "access-token", user: AuthUser(id: "u1", username: "bear"))
        )
        let controller = AuthController(api: api, sessionStore: store)
        await controller.restoreSession()

        try await controller.changePassword(oldPassword: "old-password", newPassword: "new-password")

        let calls = await api.calls
        XCTAssertEqual(calls, [
            .changePassword(
                token: "access-token",
                oldPassword: "old-password",
                newPassword: "new-password"
            ),
        ])
    }
}

private enum AuthCall: Equatable, Sendable {
    case register(username: String, password: String, nickname: String?)
    case login(username: String, password: String)
    case currentUser(token: String)
    case changePassword(token: String, oldPassword: String, newPassword: String)
}

private actor MockAuthAPIService: AuthAPIService {
    private(set) var calls: [AuthCall] = []

    private let loginError: Error?
    private let currentUserResponse: AuthUser
    private let sessionResponse: AuthSession

    init(
        loginError: Error? = nil,
        currentUser: AuthUser = AuthUser(id: "u1", username: "bear", nickname: "Bear"),
        session: AuthSession = AuthSession(
            token: "access-token",
            refreshToken: "refresh-token",
            user: AuthUser(id: "u1", username: "bear", nickname: "Bear")
        )
    ) {
        self.loginError = loginError
        self.currentUserResponse = currentUser
        self.sessionResponse = session
    }

    func register(username: String, password: String, nickname: String?) async throws -> AuthUser {
        calls.append(.register(username: username, password: password, nickname: nickname))
        return currentUserResponse
    }

    func login(username: String, password: String) async throws -> AuthSession {
        calls.append(.login(username: username, password: password))
        if let loginError {
            throw loginError
        }
        return sessionResponse
    }

    func currentUser(token: String) async throws -> AuthUser {
        calls.append(.currentUser(token: token))
        return currentUserResponse
    }

    func refresh(refreshToken: String) async throws -> AuthSession {
        sessionResponse
    }

    func changePassword(
        token: String,
        oldPassword: String,
        newPassword: String
    ) async throws {
        calls.append(
            .changePassword(
                token: token,
                oldPassword: oldPassword,
                newPassword: newPassword
            )
        )
    }
}
