import Foundation

public struct AuthUser: Codable, Equatable, Sendable {
    public let id: String
    public let username: String
    public let email: String?
    public let nickname: String?
    public let avatarURL: String?
    public let avatarObjectKey: String?
    public let localAvatarPath: String?
    public let status: String?

    public init(
        id: String,
        username: String,
        email: String? = nil,
        nickname: String? = nil,
        avatarURL: String? = nil,
        avatarObjectKey: String? = nil,
        localAvatarPath: String? = nil,
        status: String? = nil
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.nickname = nickname
        self.avatarURL = avatarURL
        self.avatarObjectKey = avatarObjectKey
        self.localAvatarPath = localAvatarPath
        self.status = status
    }

    public var displayName: String {
        if let nickname, !nickname.isEmpty {
            return nickname
        }
        if let email, !email.isEmpty {
            return email
        }
        return username
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case nickname
        case avatarURL = "avatar_url"
        case avatarObjectKey = "avatar_object_key"
        case localAvatarPath = "local_avatar_path"
        case status
    }
}
