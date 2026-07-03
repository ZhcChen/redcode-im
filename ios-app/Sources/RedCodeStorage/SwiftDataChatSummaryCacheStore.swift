import Foundation
import SwiftData

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
public final class SwiftDataChatSummaryCacheStore: ChatSummaryCacheStore {
    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public func loadChats() throws -> [RedCodeChatSummaryDraft] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<RedCodeChatRecord>(
            sortBy: [
                SortDescriptor(\.updatedAt, order: .reverse),
            ]
        )
        return try context.fetch(descriptor)
            .map { $0.toDraft() }
            .sortedForChatList()
    }

    public func saveChats(_ chats: [RedCodeChatSummaryDraft]) throws {
        let context = ModelContext(container)
        for record in try context.fetch(FetchDescriptor<RedCodeChatRecord>()) {
            context.delete(record)
        }
        for draft in chats where !draft.roomID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            context.insert(RedCodeChatRecord(draft: draft))
        }
        try context.save()
    }

    public func upsert(_ chat: RedCodeChatSummaryDraft) throws {
        let roomID = chat.roomID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !roomID.isEmpty else {
            return
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<RedCodeChatRecord>(
            predicate: #Predicate { $0.roomID == roomID }
        )
        if let record = try context.fetch(descriptor).first {
            record.apply(chat)
        } else {
            context.insert(RedCodeChatRecord(draft: chat))
        }
        try context.save()
    }

    public func remove(roomID: String) throws {
        let roomID = roomID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !roomID.isEmpty else {
            return
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<RedCodeChatRecord>(
            predicate: #Predicate { $0.roomID == roomID }
        )
        for record in try context.fetch(descriptor) {
            context.delete(record)
        }
        try context.save()
    }

    public func clearAll() throws {
        let context = ModelContext(container)
        for record in try context.fetch(FetchDescriptor<RedCodeChatRecord>()) {
            context.delete(record)
        }
        try context.save()
    }
}

private extension RedCodeChatRecord {
    convenience init(draft: RedCodeChatSummaryDraft) {
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

    func apply(_ draft: RedCodeChatSummaryDraft) {
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
