import Foundation
import GRDB

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

/// SQLite 数据库入口，替代 SwiftData ModelContainer。
///
/// 所有缓存记录通过 GRDB record（Codable + FetchableRecord + PersistableRecord）
/// 读写，主键即业务主键；数据库文件位于 Application Support/RedCodeIM/redcode.sqlite。
public final class RedCodeDatabase: @unchecked Sendable {
    public let dbQueue: DatabaseQueue

    public init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    public static func makeDatabase(inMemory: Bool = false) throws -> RedCodeDatabase {
        let dbQueue = try inMemory ? DatabaseQueue() : DatabaseQueue(path: defaultDatabasePath())
        try Self.migrator.migrate(dbQueue)
        return RedCodeDatabase(dbQueue: dbQueue)
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: RedCodeChatRecord.databaseTableName) { table in
                table.column("roomID", .text).primaryKey()
                table.column("roomType", .text).notNull()
                table.column("displayName", .text).notNull()
                table.column("avatarURL", .text)
                table.column("avatarObjectKey", .text)
                table.column("lastMessageID", .text)
                table.column("lastMessagePreview", .text)
                table.column("lastMessageAt", .datetime)
                table.column("unreadCount", .integer).notNull()
                table.column("isPinned", .boolean).notNull()
                table.column("isMuted", .boolean).notNull()
                table.column("updatedAt", .datetime).notNull()
            }
            try db.create(table: RedCodeMessageRecord.databaseTableName) { table in
                table.column("id", .text).primaryKey()
                table.column("roomID", .text).notNull()
                table.column("senderID", .text).notNull()
                table.column("senderName", .text)
                table.column("content", .text).notNull()
                table.column("messageType", .text).notNull()
                table.column("status", .text).notNull()
                table.column("timestamp", .datetime).notNull()
                table.column("messageIsDeleted", .boolean).notNull()
                table.column("isPinned", .boolean).notNull()
                table.column("quotedMessageID", .text)
                table.column("rawPayloadJSON", .text)
            }
            try db.create(table: RedCodeContactRecord.databaseTableName) { table in
                table.column("userID", .text).primaryKey()
                table.column("username", .text).notNull()
                table.column("nickname", .text)
                table.column("avatarURL", .text)
                table.column("avatarObjectKey", .text)
                table.column("friendshipStatus", .text).notNull()
                table.column("updatedAt", .datetime).notNull()
            }
            try db.create(table: RedCodeGroupRecord.databaseTableName) { table in
                table.column("roomID", .text).primaryKey()
                table.column("name", .text).notNull()
                table.column("ownerID", .text)
                table.column("currentUserRole", .text)
                table.column("memberCount", .integer).notNull()
                table.column("avatarURL", .text)
                table.column("avatarObjectKey", .text)
                table.column("updatedAt", .datetime).notNull()
            }
            try db.create(table: RedCodeAppConfigRecord.databaseTableName) { table in
                table.column("key", .text).primaryKey()
                table.column("valueJSON", .text).notNull()
                table.column("updatedAt", .datetime).notNull()
            }
        }
        return migrator
    }

    private static func defaultDatabasePath() -> String {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = baseURL.appendingPathComponent("RedCodeIM", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("redcode.sqlite").path
    }
}

public struct RedCodeChatRecord: Codable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "redCodeChatRecord"

    public var roomID: String
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

public struct RedCodeMessageRecord: Codable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "redCodeMessageRecord"

    public var id: String
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

    public init(draft: RedCodeMessageDraft, roomID: String) {
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

public struct RedCodeContactRecord: Codable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "redCodeContactRecord"

    public var userID: String
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

public struct RedCodeGroupRecord: Codable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "redCodeGroupRecord"

    public var roomID: String
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

public struct RedCodeAppConfigRecord: Codable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "redCodeAppConfigRecord"

    public var key: String
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
