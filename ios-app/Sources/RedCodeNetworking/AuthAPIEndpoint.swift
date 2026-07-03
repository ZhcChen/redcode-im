import Foundation
import RedCodeCore

public enum AuthAPIEndpoint: Sendable {
    public static let register = APIEndpoint(method: .post, path: "/auth/register")
    public static let login = APIEndpoint(method: .post, path: "/auth/login")
    public static let me = APIEndpoint(method: .get, path: "/auth/me")
    public static let refresh = APIEndpoint(method: .post, path: "/auth/refresh")
    public static let changePassword = APIEndpoint(method: .post, path: "/users/me/password")
}

public struct EmailLoginRequest: Codable, Equatable, Sendable {
    public let email: String
    public let password: String

    public init(email: String, password: String) throws {
        self.email = try EmailAddress.normalize(email)
        self.password = password
    }
}

public struct EmailRegistrationRequest: Codable, Equatable, Sendable {
    public let email: String
    public let password: String
    public let nickname: String?

    public init(email: String, password: String, nickname: String? = nil) throws {
        let normalizedEmail = try EmailAddress.normalize(email)
        self.email = normalizedEmail
        self.password = password
        self.nickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? normalizedEmail
    }
}

public struct RefreshTokenRequest: Codable, Equatable, Sendable {
    public let refreshToken: String

    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }

    private enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

public struct ChangePasswordRequest: Codable, Equatable, Sendable {
    public let oldPassword: String
    public let newPassword: String

    public init(oldPassword: String, newPassword: String) {
        self.oldPassword = oldPassword
        self.newPassword = newPassword
    }

    private enum CodingKeys: String, CodingKey {
        case oldPassword = "old_password"
        case newPassword = "new_password"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
