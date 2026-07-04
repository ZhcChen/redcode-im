import Foundation
import SwiftData

public enum RedCodeStorageSchema {
    public static var schema: Schema {
        Schema([
            RedCodeChatRecord.self,
            RedCodeMessageRecord.self,
            RedCodeContactRecord.self,
            RedCodeGroupRecord.self,
            RedCodeAppConfigRecord.self,
        ])
    }

    public static func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Self.schema
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

@Model
public final class RedCodeChatRecord {
    @Attribute(.unique) public var roomID: String
    public var roomType: String
    public var displayName: String
    public var avatarURL: String?
    public var avatarObjectKey: String?
    public var lastMessageID: String?
    public var lastMessagePreview: String?
    public var lastMessageAt: Date?
    public var unreadCount: Int
    public var isPinned: Bool
    public var isMuted: Bool
    public var updatedAt: Date

    public init(
        roomID: String,
        roomType: String,
        displayName: String,
        avatarURL: String? = nil,
        avatarObjectKey: String? = nil,
        lastMessageID: String? = nil,
        lastMessagePreview: String? = nil,
        lastMessageAt: Date? = nil,
        unreadCount: Int = 0,
        isPinned: Bool = false,
        isMuted: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.roomID = roomID
        self.roomType = roomType
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.avatarObjectKey = avatarObjectKey
        self.lastMessageID = lastMessageID
        self.lastMessagePreview = lastMessagePreview
        self.lastMessageAt = lastMessageAt
        self.unreadCount = unreadCount
        self.isPinned = isPinned
        self.isMuted = isMuted
        self.updatedAt = updatedAt
    }
}

public struct RedCodeMessageDraft: Equatable, Sendable {
    public let id: String
    public let roomID: String
    public let senderID: String
    public let senderName: String?
    public let content: String
    public let messageType: String
    public let status: String
    public let timestamp: Date
    public let isDeleted: Bool
    public let isPinned: Bool
    public let quotedMessageID: String?
    public let rawPayloadJSON: String?

    public init(
        id: String,
        roomID: String,
        senderID: String,
        senderName: String? = nil,
        content: String,
        messageType: String = "text",
        status: String = "sent",
        timestamp: Date,
        isDeleted: Bool = false,
        isPinned: Bool = false,
        quotedMessageID: String? = nil,
        rawPayloadJSON: String? = nil
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
        self.quotedMessageID = quotedMessageID
        self.rawPayloadJSON = rawPayloadJSON
    }
}

@Model
public final class RedCodeMessageRecord {
    @Attribute(.unique) public var id: String
    public var roomID: String
    public var senderID: String
    public var senderName: String?
    public var content: String
    public var messageType: String
    public var status: String
    public var timestamp: Date
    public var messageIsDeleted: Bool
    public var isPinned: Bool
    public var quotedMessageID: String?
    public var rawPayloadJSON: String?

    public init(
        id: String,
        roomID: String,
        senderID: String,
        senderName: String? = nil,
        content: String,
        messageType: String = "text",
        status: String = "sent",
        timestamp: Date,
        isDeleted: Bool = false,
        isPinned: Bool = false,
        quotedMessageID: String? = nil,
        rawPayloadJSON: String? = nil
    ) {
        self.id = id
        self.roomID = roomID
        self.senderID = senderID
        self.senderName = senderName
        self.content = content
        self.messageType = messageType
        self.status = status
        self.timestamp = timestamp
        self.messageIsDeleted = isDeleted
        self.isPinned = isPinned
        self.quotedMessageID = quotedMessageID
        self.rawPayloadJSON = rawPayloadJSON
    }

    public convenience init(draft: RedCodeMessageDraft, roomID: String) {
        self.init(
            id: draft.id,
            roomID: roomID,
            senderID: draft.senderID,
            senderName: draft.senderName,
            content: draft.content,
            messageType: draft.messageType,
            status: draft.status,
            timestamp: draft.timestamp,
            isDeleted: draft.isDeleted,
            isPinned: draft.isPinned,
            quotedMessageID: draft.quotedMessageID,
            rawPayloadJSON: draft.rawPayloadJSON
        )
    }

    public func toDraft() -> RedCodeMessageDraft {
        RedCodeMessageDraft(
            id: id,
            roomID: roomID,
            senderID: senderID,
            senderName: senderName,
            content: content,
            messageType: messageType,
            status: status,
            timestamp: timestamp,
            isDeleted: messageIsDeleted,
            isPinned: isPinned,
            quotedMessageID: quotedMessageID,
            rawPayloadJSON: rawPayloadJSON
        )
    }
}

@Model
public final class RedCodeContactRecord {
    @Attribute(.unique) public var userID: String
    public var username: String
    public var nickname: String?
    public var avatarURL: String?
    public var avatarObjectKey: String?
    public var friendshipStatus: String
    public var updatedAt: Date

    public init(
        userID: String,
        username: String,
        nickname: String? = nil,
        avatarURL: String? = nil,
        avatarObjectKey: String? = nil,
        friendshipStatus: String = "accepted",
        updatedAt: Date = Date()
    ) {
        self.userID = userID
        self.username = username
        self.nickname = nickname
        self.avatarURL = avatarURL
        self.avatarObjectKey = avatarObjectKey
        self.friendshipStatus = friendshipStatus
        self.updatedAt = updatedAt
    }
}

@Model
public final class RedCodeGroupRecord {
    @Attribute(.unique) public var roomID: String
    public var name: String
    public var ownerID: String?
    public var currentUserRole: String?
    public var memberCount: Int
    public var avatarURL: String?
    public var avatarObjectKey: String?
    public var updatedAt: Date

    public init(
        roomID: String,
        name: String,
        ownerID: String? = nil,
        currentUserRole: String? = nil,
        memberCount: Int = 0,
        avatarURL: String? = nil,
        avatarObjectKey: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.roomID = roomID
        self.name = name
        self.ownerID = ownerID
        self.currentUserRole = currentUserRole
        self.memberCount = memberCount
        self.avatarURL = avatarURL
        self.avatarObjectKey = avatarObjectKey
        self.updatedAt = updatedAt
    }
}

@Model
public final class RedCodeAppConfigRecord {
    @Attribute(.unique) public var key: String
    public var valueJSON: String
    public var updatedAt: Date

    public init(
        key: String,
        valueJSON: String,
        updatedAt: Date = Date()
    ) {
        self.key = key
        self.valueJSON = valueJSON
        self.updatedAt = updatedAt
    }
}
