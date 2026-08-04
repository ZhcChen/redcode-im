import Foundation

public struct AuthSession: Codable, Equatable, Sendable {
    public let token: String
    public let refreshToken: String?
    public let user: AuthUser

    public init(
        token: String,
        refreshToken: String? = nil,
        user: AuthUser
    ) {
        self.token = token
        self.refreshToken = refreshToken
        self.user = user
    }

    public var isValid: Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case token
        case refreshToken = "refresh_token"
        case user
    }
}
