import Foundation
import RedCodeCore

public protocol AuthAPIService: Sendable {
    func register(username: String, password: String, nickname: String?) async throws -> AuthUser
    func login(username: String, password: String) async throws -> AuthSession
    func currentUser(token: String) async throws -> AuthUser
    func refresh(refreshToken: String) async throws -> AuthSession
    func changePassword(token: String, oldPassword: String, newPassword: String) async throws
}

public struct AuthAPIClient: AuthAPIService {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public init(environment: RedCodeEnvironment) {
        self.apiClient = APIClient(environment: environment)
    }

    public func register(
        username: String,
        password: String,
        nickname: String? = nil
    ) async throws -> AuthUser {
        let request = try AccountRegistrationRequest(
            username: username,
            password: password,
            nickname: nickname
        )
        return try await apiClient.post(AuthAPIEndpoint.register, body: request, as: AuthUser.self)
    }

    public func login(username: String, password: String) async throws -> AuthSession {
        let request = try AccountLoginRequest(username: username, password: password)
        return try await apiClient.post(AuthAPIEndpoint.login, body: request, as: AuthSession.self)
    }

    public func currentUser(token: String) async throws -> AuthUser {
        try await apiClient.get(AuthAPIEndpoint.me, bearerToken: token, as: AuthUser.self)
    }

    public func refresh(refreshToken: String) async throws -> AuthSession {
        let request = RefreshTokenRequest(refreshToken: refreshToken)
        return try await apiClient.post(AuthAPIEndpoint.refresh, body: request, as: AuthSession.self)
    }

    public func changePassword(
        token: String,
        oldPassword: String,
        newPassword: String
    ) async throws {
        let request = ChangePasswordRequest(oldPassword: oldPassword, newPassword: newPassword)
        try await apiClient.postNoResponse(
            AuthAPIEndpoint.changePassword,
            body: request,
            bearerToken: token
        )
    }
}
