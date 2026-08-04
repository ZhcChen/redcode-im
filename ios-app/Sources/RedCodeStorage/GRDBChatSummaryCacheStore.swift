import Foundation
import GRDB

public struct RedCodeChatSummaryDraft: Equatable, Sendable {
    public let roomID: String
    public let roomType: String
    public let displayName: String
    public let avatarURL: String?
    public let avatarObjectKey: String?
    public let lastMessageID: String?
    public let lastMessagePreview: String?
    public let lastMessageAt: Date?
    public let unreadCount: Int
    public let isPinned: Bool
    public let isMuted: Bool
    public let updatedAt: Date

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

@MainActor
public protocol ChatSummaryCacheStore: AnyObject {
    func loadChats() throws -> [RedCodeChatSummaryDraft]
    func saveChats(_ chats: [RedCodeChatSummaryDraft]) throws
    func upsert(_ chat: RedCodeChatSummaryDraft) throws
    func remove(roomID: String) throws
    func clearAll() throws
}

@MainActor
public final class GRDBChatSummaryCacheStore: ChatSummaryCacheStore {
    private let database: RedCodeDatabase

    public init(database: RedCodeDatabase) {
        self.database = database
    }

    public func loadChats() throws -> [RedCodeChatSummaryDraft] {
        try database.dbQueue.read { db in
            try RedCodeChatRecord
                .order(Column("updatedAt").desc)
                .fetchAll(db)
                .map { $0.toDraft() }
                .sortedForChatList()
        }
    }

    public func saveChats(_ chats: [RedCodeChatSummaryDraft]) throws {
        try database.dbQueue.write { db in
            try RedCodeChatRecord.deleteAll(db)
            for draft in chats where !draft.roomID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try RedCodeChatRecord(draft: draft).insert(db)
            }
        }
    }

    public func upsert(_ chat: RedCodeChatSummaryDraft) throws {
        let roomID = chat.roomID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !roomID.isEmpty else {
            return
        }

        try database.dbQueue.write { db in
            if var record = try RedCodeChatRecord.fetchOne(db, key: roomID) {
                record.apply(chat)
                try record.update(db)
            } else {
                try RedCodeChatRecord(draft: chat).insert(db)
            }
        }
    }

    public func remove(roomID: String) throws {
        let roomID = roomID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !roomID.isEmpty else {
            return
        }

        try database.dbQueue.write { db in
            _ = try RedCodeChatRecord.filter(Column("roomID") == roomID).deleteAll(db)
        }
    }

    public func clearAll() throws {
        try database.dbQueue.write { db in
            try RedCodeChatRecord.deleteAll(db)
        }
    }
}

private extension RedCodeChatRecord {
    init(draft: RedCodeChatSummaryDraft) {
        self.init(
            roomID: draft.roomID,
            roomType: draft.roomType,
            displayName: draft.displayName,
            avatarURL: draft.avatarURL,
            avatarObjectKey: draft.avatarObjectKey,
            lastMessageID: draft.lastMessageID,
            lastMessagePreview: draft.lastMessagePreview,
            lastMessageAt: draft.lastMessageAt,
            unreadCount: draft.unreadCount,
            isPinned: draft.isPinned,
            isMuted: draft.isMuted,
            updatedAt: draft.updatedAt
        )
    }

    mutating func apply(_ draft: RedCodeChatSummaryDraft) {
        roomType = draft.roomType
        displayName = draft.displayName
        avatarURL = draft.avatarURL
        avatarObjectKey = draft.avatarObjectKey
        lastMessageID = draft.lastMessageID
        lastMessagePreview = draft.lastMessagePreview
        lastMessageAt = draft.lastMessageAt
        unreadCount = draft.unreadCount
        isPinned = draft.isPinned
        isMuted = draft.isMuted
        updatedAt = draft.updatedAt
    }

    func toDraft() -> RedCodeChatSummaryDraft {
        RedCodeChatSummaryDraft(
            roomID: roomID,
            roomType: roomType,
            displayName: displayName,
            avatarURL: avatarURL,
            avatarObjectKey: avatarObjectKey,
            lastMessageID: lastMessageID,
            lastMessagePreview: lastMessagePreview,
            lastMessageAt: lastMessageAt,
            unreadCount: unreadCount,
            isPinned: isPinned,
            isMuted: isMuted,
            updatedAt: updatedAt
        )
    }
}

private extension Array where Element == RedCodeChatSummaryDraft {
    func sortedForChatList() -> [RedCodeChatSummaryDraft] {
        sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return (lhs.lastMessageAt ?? lhs.updatedAt) > (rhs.lastMessageAt ?? rhs.updatedAt)
        }
    }
}
