import Foundation
import RedCodeCore

public enum FriendRequestStatus: String, Codable, Equatable, Sendable {
    case pending
    case accepted
    case declined

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = (try? container.decode(String.self))?.lowercased()
        self = FriendRequestStatus(rawValue: rawValue ?? "") ?? .pending
    }
}

public enum FriendRequestAction: String, Codable, Equatable, Sendable {
    case accept
    case decline
}

public struct FriendInfo: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let user: AuthUser
    public let createdAt: Date?
    public let remark: String?

    public init(id: String, user: AuthUser, createdAt: Date? = nil, remark: String? = nil) {
        self.id = id
        self.user = user
        self.createdAt = createdAt
        self.remark = remark
    }

    public var displayName: String {
        if let remark, !remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return remark
        }
        if let nickname = user.nickname?.trimmingCharacters(in: .whitespacesAndNewlines), !nickname.isEmpty {
            return nickname
        }
        return user.username
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case user
        case createdAt = "created_at"
        case remark
        case friendRemark = "friend_remark"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        user = try container.decode(AuthUser.self, forKey: .user)
        createdAt = container.decodeFlexibleDate(forKey: .createdAt)
        remark = try container.decodeIfPresent(String.self, forKey: .friendRemark)
            ?? container.decodeIfPresent(String.self, forKey: .remark)
    }
}

public struct FriendRequestInfo: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let requester: AuthUser
    public let addressee: AuthUser
    public let status: FriendRequestStatus
    public let message: String?
    public let createdAt: Date?
    public let respondedAt: Date?
    public let isIncoming: Bool

    public init(
        id: String,
        requester: AuthUser,
        addressee: AuthUser,
        status: FriendRequestStatus,
        message: String? = nil,
        createdAt: Date? = nil,
        respondedAt: Date? = nil,
        isIncoming: Bool = false
    ) {
        self.id = id
        self.requester = requester
        self.addressee = addressee
        self.status = status
        self.message = message
        self.createdAt = createdAt
        self.respondedAt = respondedAt
        self.isIncoming = isIncoming
    }

    public var counterparty: AuthUser {
        isIncoming ? requester : addressee
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case requester
        case addressee
        case status
        case message
        case createdAt = "created_at"
        case respondedAt = "responded_at"
        case isIncoming = "is_incoming"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        requester = try container.decode(AuthUser.self, forKey: .requester)
        addressee = try container.decode(AuthUser.self, forKey: .addressee)
        status = try container.decodeIfPresent(FriendRequestStatus.self, forKey: .status) ?? .pending
        message = try container.decodeIfPresent(String.self, forKey: .message)
        createdAt = container.decodeFlexibleDate(forKey: .createdAt)
        respondedAt = container.decodeFlexibleDate(forKey: .respondedAt)
        isIncoming = try container.decodeIfPresent(Bool.self, forKey: .isIncoming) ?? false
    }
}

public struct EnsurePrivateChatResult: Decodable, Equatable, Sendable {
    public let roomID: String
    public let roomName: String
    public let roomType: ChatType
    public let friendID: String
    public let friendName: String
    public let friendAvatarURL: String?
    public let friendAvatarObjectKey: String?

    public init(
        roomID: String,
        roomName: String,
        roomType: ChatType = .privateChat,
        friendID: String,
        friendName: String,
        friendAvatarURL: String? = nil,
        friendAvatarObjectKey: String? = nil
    ) {
        self.roomID = roomID
        self.roomName = roomName
        self.roomType = roomType
        self.friendID = friendID
        self.friendName = friendName
        self.friendAvatarURL = friendAvatarURL
        self.friendAvatarObjectKey = friendAvatarObjectKey
    }

    private enum CodingKeys: String, CodingKey {
        case roomID = "room_id"
        case roomName = "room_name"
        case roomType = "room_type"
        case friendID = "friend_id"
        case friendName = "friend_name"
        case friendAvatarURL = "friend_avatar"
        case friendAvatarObjectKey = "friend_avatar_object_key"
    }
}

public struct CreateFriendRequestPayload: Encodable, Equatable, Sendable {
    public let targetUserID: String
    public let message: String?

    public init(targetUserID: String, message: String? = nil) {
        self.targetUserID = targetUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.message = message?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case targetUserID = "target_user_id"
        case message
    }
}

public struct RespondFriendRequestPayload: Encodable, Equatable, Sendable {
    public let action: FriendRequestAction

    public init(action: FriendRequestAction) {
        self.action = action
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleDate(forKey key: Key) -> Date? {
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return FriendDateParser.parse(string)
        }
        if let double = try? decodeIfPresent(Double.self, forKey: key) {
            let seconds = double > 1_000_000_000_000 ? double / 1000 : double
            return Date(timeIntervalSince1970: seconds)
        }
        return nil
    }
}

private enum FriendDateParser {
    static func parse(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else {
            return nil
        }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
