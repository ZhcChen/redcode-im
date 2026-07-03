import Foundation
import RedCodeCore
import RedCodeNetworking
import RedCodeStorage

@MainActor
public final class AuthController {
    public private(set) var session: AuthSession?
    public private(set) var state: AppSessionState = .unauthenticated
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    private let api: any AuthAPIService
    private let sessionStore: any AuthSessionStore

    public init(
        api: any AuthAPIService,
        sessionStore: any AuthSessionStore
    ) {
        self.api = api
        self.sessionStore = sessionStore
    }

    public func restoreSession() async {
        await runLoadingOperation {
            let restored = try await sessionStore.read()
            apply(session: restored)
        }
    }

    @discardableResult
    public func registerAndLogin(
        username: String,
        password: String,
        nickname: String? = nil
    ) async throws -> AuthSession {
        try await runThrowingLoadingOperation {
            _ = try await api.register(username: username, password: password, nickname: nickname)
            let loggedIn = try await api.login(username: username, password: password)
            try await persist(session: loggedIn)
            return loggedIn
        }
    }

    @discardableResult
    public func login(username: String, password: String) async throws -> AuthSession {
        try await runThrowingLoadingOperation {
            let loggedIn = try await api.login(username: username, password: password)
            try await persist(session: loggedIn)
            return loggedIn
        }
    }

    @discardableResult
    public func refreshCurrentUser() async throws -> AuthUser? {
        guard let session else {
            return nil
        }

        let refreshedUser = try await api.currentUser(token: session.token)
        try await sessionStore.updateUser(refreshedUser)
        let nextSession = AuthSession(
            token: session.token,
            refreshToken: session.refreshToken,
            user: refreshedUser
        )
        apply(session: nextSession)
        return refreshedUser
    }

    public func logout() async throws {
        try await sessionStore.clear()
        apply(session: nil)
    }

    public func changePassword(oldPassword: String, newPassword: String) async throws {
        guard let session else {
            throw RedCodeError.authentication("未登录")
        }
        try await api.changePassword(
            token: session.token,
            oldPassword: oldPassword,
            newPassword: newPassword
        )
    }

    private func persist(session: AuthSession) async throws {
        guard session.isValid else {
            throw RedCodeError.authentication("登录响应缺少有效 token")
        }
        try await sessionStore.save(session)
        apply(session: session)
    }

    private func apply(session nextSession: AuthSession?) {
        session = nextSession
        state = AppSessionState.from(session: nextSession)
    }

    private func runLoadingOperation(_ operation: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
            apply(session: nil)
        }
    }

    private func runThrowingLoadingOperation<T: Sendable>(
        _ operation: () async throws -> T
    ) async throws -> T {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            return try await operation()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}
