import Foundation
import RedCodeCore

public protocol AuthAPIService: Sendable {
    func register(username: String, password: String, nickname: String?) async throws -> AuthUser
    func login(username: String, password: String) async throws -> AuthSession
    func currentUser(token: String) async throws -> AuthUser
    func refresh(refreshToken: String) async throws -> AuthSession
    func updateProfile(token: String, nickname: String?, avatarURL: String?, avatarObjectKey: String?) async throws -> AuthUser
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

    public func updateProfile(
        token: String,
        nickname: String? = nil,
        avatarURL: String? = nil,
        avatarObjectKey: String? = nil
    ) async throws -> AuthUser {
        let request = UpdateProfileRequest(
            nickname: nickname,
            avatarURL: avatarURL,
            avatarObjectKey: avatarObjectKey
        )
        return try await apiClient.patch(
            AuthAPIEndpoint.updateMe,
            body: request,
            bearerToken: token,
            as: AuthUser.self
        )
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
