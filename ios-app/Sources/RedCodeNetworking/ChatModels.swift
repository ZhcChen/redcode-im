import Foundation

public enum ChatType: String, Codable, Equatable, Sendable {
    case privateChat = "private"
    case group = "group"
    case favorite = "favorite"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = (try? container.decode(String.self))?.lowercased()
        switch rawValue {
        case "group", "public":
            self = .group
        case "favorite":
            self = .favorite
        default:
            self = .privateChat
        }
    }
}

public enum ChatMessageType: String, Codable, Equatable, Sendable {
    case text
    case image
    case audio
    case video
    case file
    case system
    case mixed

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = (try? container.decode(String.self))?.lowercased()
        self = ChatMessageType(rawValue: rawValue ?? "") ?? .text
    }
}

public enum ChatMessageStatus: String, Codable, Equatable, Sendable {
    case sending
    case sent
    case failed
    case deleted
    case read

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = (try? container.decode(String.self))?.lowercased()
        self = ChatMessageStatus(rawValue: rawValue ?? "") ?? .sent
    }
}

public struct ChatMessageAttachment: Codable, Equatable, Sendable {
    public let key: String
    public let name: String?
    public let mimeType: String?
    public let size: Int64?
    public let width: Int?
    public let height: Int?
    public let durationMilliseconds: Int?
    public let thumbnailKey: String?

    public init(
        key: String,
        name: String? = nil,
        mimeType: String? = nil,
        size: Int64? = nil,
        width: Int? = nil,
        height: Int? = nil,
        durationMilliseconds: Int? = nil,
        thumbnailKey: String? = nil
    ) {
        self.key = key
        self.name = name
        self.mimeType = mimeType
        self.size = size
        self.width = width
        self.height = height
        self.durationMilliseconds = durationMilliseconds
        self.thumbnailKey = thumbnailKey
    }

    private enum CodingKeys: String, CodingKey {
        case key
        case name
        case mimeType = "mime"
        case size
        case width
        case height
        case durationMilliseconds = "duration_ms"
        case thumbnailKey = "thumbnail_key"
    }
}

public struct ChatMessagePart: Codable, Equatable, Sendable {
    public let position: Int
    public let partType: ChatMessageType
    public let text: String?
    public let attachment: ChatMessageAttachment?

    public init(
        position: Int,
        partType: ChatMessageType,
        text: String? = nil,
        attachment: ChatMessageAttachment? = nil
    ) {
        self.position = position
        self.partType = partType
        self.text = text
        self.attachment = attachment
    }

    private enum CodingKeys: String, CodingKey {
        case position
        case partType = "part_type"
        case text
        case attachment
    }
}

public struct ChatMessageQuote: Decodable, Equatable, Sendable {
    public let id: String
    public let roomID: String
    public let senderID: String
    public let senderName: String
    public let content: String
    public let messageType: ChatMessageType
    public let timestamp: Date?
    public let isDeleted: Bool
    public let parts: [ChatMessagePart]

    public init(
        id: String,
        roomID: String,
        senderID: String,
        senderName: String,
        content: String,
        messageType: ChatMessageType = .text,
        timestamp: Date? = nil,
        isDeleted: Bool = false,
        parts: [ChatMessagePart] = []
    ) {
        self.id = id
        self.roomID = roomID
        self.senderID = senderID
        self.senderName = senderName
        self.content = content
        self.messageType = messageType
        self.timestamp = timestamp
        self.isDeleted = isDeleted
        self.parts = parts
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeString(forKey: .id, fallbackKey: .messageID)
        roomID = try container.decodeString(forKey: .roomID)
        senderID = try container.decodeString(forKey: .senderID)
        let username = try container.decodeIfPresent(String.self, forKey: .senderUsername)
        let nickname = try container.decodeIfPresent(String.self, forKey: .senderNickname)
        senderName = (nickname ?? username ?? senderID)
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        messageType = try container.decodeIfPresent(ChatMessageType.self, forKey: .messageType) ?? .text
        timestamp = container.decodeFlexibleDate(forKey: .createdAt, fallbackKey: .timestamp)
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        parts = try container.decodeIfPresent([ChatMessagePart].self, forKey: .parts) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case messageID = "message_id"
        case roomID = "room_id"
        case senderID = "sender_id"
        case senderUsername = "sender_username"
        case senderNickname = "sender_nickname"
        case content
        case messageType = "message_type"
        case createdAt = "created_at"
        case timestamp
        case isDeleted = "is_deleted"
        case parts
    }
}

public struct ChatMessage: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let roomID: String
    public let senderID: String
    public let senderName: String
    public let content: String
    public let messageType: ChatMessageType
    public let status: ChatMessageStatus?
    public let timestamp: Date
    public let isDeleted: Bool
    public let isPinned: Bool
    public let pinnedAt: Date?
    public let pinnedBy: String?
    public let quotedMessage: ChatMessageQuote?
    public let parts: [ChatMessagePart]
    public let attachments: [ChatMessageAttachment]

    public init(
        id: String,
        roomID: String,
        senderID: String,
        senderName: String,
        content: String,
        messageType: ChatMessageType = .text,
        status: ChatMessageStatus? = .sent,
        timestamp: Date,
        isDeleted: Bool = false,
        isPinned: Bool = false,
        pinnedAt: Date? = nil,
        pinnedBy: String? = nil,
        quotedMessage: ChatMessageQuote? = nil,
        parts: [ChatMessagePart] = [],
        attachments: [ChatMessageAttachment] = []
    ) {
        self.id = id
        self.roomID = roomID
        self.senderID = senderID
        self.senderName = senderName
        self.content = content
        self.messageType = messageType
        self.status = status
        self.timestamp = timestamp
        self.isDeleted = isDeleted
        self.isPinned = isPinned
        self.pinnedAt = pinnedAt
        self.pinnedBy = pinnedBy
        self.quotedMessage = quotedMessage
        self.parts = parts
        self.attachments = attachments
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeString(forKey: .id, fallbackKey: .messageID)
        roomID = try container.decodeString(forKey: .roomID)
        senderID = try container.decodeString(forKey: .senderID)
        let username = try container.decodeIfPresent(String.self, forKey: .senderUsername)
        let nickname = try container.decodeIfPresent(String.self, forKey: .senderNickname)
        senderName = (nickname ?? username ?? senderID)
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        messageType = try container.decodeIfPresent(ChatMessageType.self, forKey: .messageType) ?? .text
        status = try container.decodeIfPresent(ChatMessageStatus.self, forKey: .status)
        timestamp = container.decodeFlexibleDate(forKey: .createdAt, fallbackKey: .timestamp)
            ?? Date(timeIntervalSince1970: 0)
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        pinnedAt = container.decodeFlexibleDate(forKey: .pinnedAt)
        pinnedBy = try container.decodeIfPresent(String.self, forKey: .pinnedBy)
        quotedMessage = try container.decodeIfPresent(ChatMessageQuote.self, forKey: .quotedMessage)
        parts = try container.decodeIfPresent([ChatMessagePart].self, forKey: .parts) ?? []
        attachments = parts.compactMap(\.attachment)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case messageID = "message_id"
        case roomID = "room_id"
        case senderID = "sender_id"
        case senderUsername = "sender_username"
        case senderNickname = "sender_nickname"
        case content
        case messageType = "message_type"
        case status
        case createdAt = "created_at"
        case timestamp
        case isDeleted = "is_deleted"
        case isPinned = "is_pinned"
        case pinnedAt = "pinned_at"
        case pinnedBy = "pinned_by"
        case quotedMessage = "quoted_message"
        case parts
    }
}

public struct ChatMessagePreview: Decodable, Equatable, Sendable {
    public let id: String
    public let content: String
    public let messageType: ChatMessageType
    public let createdAt: Date?
    public let senderID: String
    public let senderUsername: String
    public let senderNickname: String?

    public init(
        id: String,
        content: String,
        messageType: ChatMessageType = .text,
        createdAt: Date? = nil,
        senderID: String,
        senderUsername: String,
        senderNickname: String? = nil
    ) {
        self.id = id
        self.content = content
        self.messageType = messageType
        self.createdAt = createdAt
        self.senderID = senderID
        self.senderUsername = senderUsername
        self.senderNickname = senderNickname
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeString(forKey: .id)
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        messageType = try container.decodeIfPresent(ChatMessageType.self, forKey: .messageType) ?? .text
        createdAt = container.decodeFlexibleDate(forKey: .createdAt)
        senderID = try container.decodeIfPresent(String.self, forKey: .senderID) ?? ""
        senderUsername = try container.decodeIfPresent(String.self, forKey: .senderUsername) ?? ""
        senderNickname = try container.decodeIfPresent(String.self, forKey: .senderNickname)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case content
        case messageType = "message_type"
        case createdAt = "created_at"
        case senderID = "sender_id"
        case senderUsername = "sender_username"
        case senderNickname = "sender_nickname"
    }
}

public struct ChatSummary: Decodable, Equatable, Identifiable, Sendable {
    public var id: String { roomID }

    public let roomID: String
    public let displayName: String
    public let roomType: ChatType
    public let avatarURL: String?
    public let avatarObjectKey: String?
    public let unreadCount: Int
    public let lastReadMessageID: String?
    public let lastReadAt: Date?
    public let notificationSettings: Int
    public let isMuted: Bool
    public let isPinned: Bool
    public let lastMessageID: String?
    public let lastMessage: ChatMessagePreview?
    public let lastMessagePreview: String
    public let lastMessageAt: Date?
    public let friendUserID: String?

    public init(
        roomID: String,
        displayName: String,
        roomType: ChatType = .privateChat,
        avatarURL: String? = nil,
        avatarObjectKey: String? = nil,
        unreadCount: Int = 0,
        lastReadMessageID: String? = nil,
        lastReadAt: Date? = nil,
        notificationSettings: Int = 0,
        isMuted: Bool = false,
        isPinned: Bool = false,
        lastMessageID: String? = nil,
        lastMessage: ChatMessagePreview? = nil,
        lastMessagePreview: String = "",
        lastMessageAt: Date? = nil,
        friendUserID: String? = nil
    ) {
        self.roomID = roomID
        self.displayName = displayName
        self.roomType = roomType
        self.avatarURL = avatarURL
        self.avatarObjectKey = avatarObjectKey
        self.unreadCount = unreadCount
        self.lastReadMessageID = lastReadMessageID
        self.lastReadAt = lastReadAt
        self.notificationSettings = notificationSettings
        self.isMuted = isMuted
        self.isPinned = isPinned
        self.lastMessageID = lastMessageID
        self.lastMessage = lastMessage
        self.lastMessagePreview = lastMessagePreview
        self.lastMessageAt = lastMessageAt
        self.friendUserID = friendUserID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let roomID = try container.decodeString(forKey: .roomID, fallbackKey: .id)
        let roomType = try container.decodeIfPresent(ChatType.self, forKey: .roomType) ?? .privateChat
        let decodedName = try container.decodeIfPresent(String.self, forKey: .name)
        let decodedRoomName = try container.decodeIfPresent(String.self, forKey: .roomName)
        let roomName = decodedName ?? decodedRoomName
        let friendRemark = try container.decodeIfPresent(String.self, forKey: .friendRemark)
        let friendNickname = try container.decodeIfPresent(String.self, forKey: .friendNickname)
        let friendUsername = try container.decodeIfPresent(String.self, forKey: .friendUsername)
        let lastMessage = try container.decodeIfPresent(ChatMessagePreview.self, forKey: .lastMessage)

        self.roomID = roomID
        self.roomType = roomType
        displayName = roomType == .privateChat
            ? (friendRemark ?? friendNickname ?? friendUsername ?? roomName ?? "私聊")
            : (roomName ?? (roomType == .favorite ? "收藏" : "群聊"))
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        let decodedAvatarObjectKey = try container.decodeIfPresent(String.self, forKey: .avatarObjectKey)
        let decodedRoomAvatarObjectKey = try container.decodeIfPresent(String.self, forKey: .roomAvatarObjectKey)
        let decodedFriendAvatarObjectKey = try container.decodeIfPresent(String.self, forKey: .friendAvatarObjectKey)
        avatarObjectKey = decodedAvatarObjectKey ?? decodedRoomAvatarObjectKey ?? decodedFriendAvatarObjectKey
        unreadCount = try container.decodeFlexibleInt(forKey: .unreadCount) ?? 0
        lastReadMessageID = try container.decodeIfPresent(String.self, forKey: .lastReadMessageID)
        lastReadAt = container.decodeFlexibleDate(forKey: .lastReadAt)
        notificationSettings = try container.decodeFlexibleInt(forKey: .notificationSettings) ?? 0
        isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        lastMessageID = lastMessage?.id
        self.lastMessage = lastMessage
        lastMessagePreview = ChatSummary.previewText(for: lastMessage)
        lastMessageAt = lastMessage?.createdAt
        friendUserID = try container.decodeIfPresent(String.self, forKey: .friendUserID)
    }

    private static func previewText(for message: ChatMessagePreview?) -> String {
        guard let message else { return "" }
        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        switch message.messageType {
        case .image:
            return "[图片]"
        case .audio:
            return "[语音]"
        case .video:
            return "[视频]"
        case .file:
            return "[文件]"
        case .mixed:
            return "[多媒体消息]"
        case .system:
            return "[系统消息]"
        case .text:
            return ""
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case roomID = "room_id"
        case name
        case roomName = "room_name"
        case roomType = "room_type"
        case avatarURL = "avatar_url"
        case avatarObjectKey = "avatar_object_key"
        case roomAvatarObjectKey = "room_avatar_object_key"
        case friendAvatarObjectKey = "friend_avatar_object_key"
        case unreadCount = "unread_count"
        case lastReadMessageID = "last_read_message_id"
        case lastReadAt = "last_read_at"
        case notificationSettings = "notification_settings"
        case isMuted = "is_muted"
        case isPinned = "is_pinned"
        case lastMessage = "last_message"
        case friendUserID = "friend_user_id"
        case friendNickname = "friend_nickname"
        case friendUsername = "friend_username"
        case friendRemark = "friend_remark"
    }
}

private extension KeyedDecodingContainer {
    func decodeString(forKey key: Key, fallbackKey: Key? = nil) throws -> String {
        if let value = try decodeIfPresent(String.self, forKey: key), !value.isEmpty {
            return value
        }
        if let fallbackKey,
           let value = try decodeIfPresent(String.self, forKey: fallbackKey),
           !value.isEmpty {
            return value
        }
        throw DecodingError.keyNotFound(
            key,
            DecodingError.Context(codingPath: codingPath, debugDescription: "Missing string for \(key.stringValue)")
        )
    }

    func decodeFlexibleDate(forKey key: Key, fallbackKey: Key? = nil) -> Date? {
        if let date = decodeFlexibleDate(forKey: key) {
            return date
        }
        guard let fallbackKey else {
            return nil
        }
        return decodeFlexibleDate(forKey: fallbackKey)
    }

    func decodeFlexibleDate(forKey key: Key) -> Date? {
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return DateParser.parse(string)
        }
        if let double = try? decodeIfPresent(Double.self, forKey: key) {
            let seconds = double > 1_000_000_000_000 ? double / 1000 : double
            return Date(timeIntervalSince1970: seconds)
        }
        return nil
    }

    func decodeFlexibleInt(forKey key: Key) throws -> Int? {
        if let int = try decodeIfPresent(Int.self, forKey: key) {
            return int
        }
        if let double = try decodeIfPresent(Double.self, forKey: key) {
            return Int(double)
        }
        if let string = try decodeIfPresent(String.self, forKey: key) {
            return Int(string)
        }
        return nil
    }
}

private enum DateParser {
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
