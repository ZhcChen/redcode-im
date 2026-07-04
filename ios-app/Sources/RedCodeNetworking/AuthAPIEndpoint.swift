import Foundation
import RedCodeCore

public enum AuthAPIEndpoint: Sendable {
    public static let register = APIEndpoint(method: .post, path: "/auth/register")
    public static let login = APIEndpoint(method: .post, path: "/auth/login")
    public static let me = APIEndpoint(method: .get, path: "/auth/me")
    public static let refresh = APIEndpoint(method: .post, path: "/auth/refresh")
    public static let updateMe = APIEndpoint(method: .patch, path: "/users/me")
    public static let changePassword = APIEndpoint(method: .post, path: "/users/me/password")
    public static let resetPassword = APIEndpoint(method: .post, path: "/auth/password/reset")
}

public struct AccountLoginRequest: Codable, Equatable, Sendable {
    public let username: String
    public let password: String

    public init(username: String, password: String) throws {
        self.username = try AccountName.normalize(username)
        self.password = password
    }
}

public struct AccountRegistrationRequest: Codable, Equatable, Sendable {
    public let username: String
    public let password: String
    public let nickname: String?

    public init(username: String, password: String, nickname: String? = nil) throws {
        let normalizedUsername = try AccountName.normalize(username)
        self.username = normalizedUsername
        self.password = password
        self.nickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? normalizedUsername
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

public struct ResetPasswordWithSMSRequest: Codable, Equatable, Sendable {
    public let phone: String
    public let code: String
    public let newPassword: String

    public init(phone: String, code: String, newPassword: String) throws {
        let phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let newPassword = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phone.isEmpty else {
            throw NetworkFailure(kind: .unknown, message: "手机号不能为空")
        }
        guard !code.isEmpty else {
            throw NetworkFailure(kind: .unknown, message: "验证码不能为空")
        }
        guard newPassword.count >= 6 else {
            throw NetworkFailure(kind: .unknown, message: "新密码长度至少 6 位")
        }
        self.phone = phone
        self.code = code
        self.newPassword = newPassword
    }

    private enum CodingKeys: String, CodingKey {
        case phone
        case code
        case newPassword = "new_password"
    }
}

public struct ResetPasswordWithSMSResponse: Codable, Equatable, Sendable {
    public let success: Bool
    public let message: String

    public init(success: Bool, message: String) {
        self.success = success
        self.message = message
    }
}

public struct UpdateProfileRequest: Codable, Equatable, Sendable {
    public let nickname: String?
    public let avatarURL: String?
    public let avatarObjectKey: String?

    public init(
        nickname: String? = nil,
        avatarURL: String? = nil,
        avatarObjectKey: String? = nil
    ) {
        self.nickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.avatarURL = avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.avatarObjectKey = avatarObjectKey?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case nickname
        case avatarURL = "avatar_url"
        case avatarObjectKey = "avatar_object_key"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
