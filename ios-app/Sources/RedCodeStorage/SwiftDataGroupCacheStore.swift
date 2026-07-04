import Foundation
import SwiftData

public struct RedCodeGroupDraft: Equatable, Sendable {
    public let roomID: String
    public let name: String
    public let ownerID: String?
    public let currentUserRole: String?
    public let memberCount: Int
    public let avatarURL: String?
    public let avatarObjectKey: String?
    public let updatedAt: Date

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

@MainActor
public protocol GroupCacheStore: AnyObject {
    func loadGroups() throws -> [RedCodeGroupDraft]
    func saveGroups(_ groups: [RedCodeGroupDraft]) throws
    func upsert(_ group: RedCodeGroupDraft) throws
    func remove(roomID: String) throws
    func clearAll() throws
}

@MainActor
public final class SwiftDataGroupCacheStore: GroupCacheStore {
    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public func loadGroups() throws -> [RedCodeGroupDraft] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<RedCodeGroupRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toDraft() }
    }

    public func saveGroups(_ groups: [RedCodeGroupDraft]) throws {
        let context = ModelContext(container)
        for record in try context.fetch(FetchDescriptor<RedCodeGroupRecord>()) {
            context.delete(record)
        }
        for draft in groups where !draft.roomID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            context.insert(RedCodeGroupRecord(draft: draft))
        }
        try context.save()
    }

    public func upsert(_ group: RedCodeGroupDraft) throws {
        let roomID = group.roomID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !roomID.isEmpty else {
            return
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<RedCodeGroupRecord>(
            predicate: #Predicate { $0.roomID == roomID }
        )
        if let record = try context.fetch(descriptor).first {
            record.apply(group)
        } else {
            context.insert(RedCodeGroupRecord(draft: group))
        }
        try context.save()
    }

    public func remove(roomID: String) throws {
        let roomID = roomID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !roomID.isEmpty else {
            return
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<RedCodeGroupRecord>(
            predicate: #Predicate { $0.roomID == roomID }
        )
        for record in try context.fetch(descriptor) {
            context.delete(record)
        }
        try context.save()
    }

    public func clearAll() throws {
        let context = ModelContext(container)
        for record in try context.fetch(FetchDescriptor<RedCodeGroupRecord>()) {
            context.delete(record)
        }
        try context.save()
    }
}

private extension RedCodeGroupRecord {
    convenience init(draft: RedCodeGroupDraft) {
        self.init(
            roomID: draft.roomID,
            name: draft.name,
            ownerID: draft.ownerID,
            currentUserRole: draft.currentUserRole,
            memberCount: draft.memberCount,
            avatarURL: draft.avatarURL,
            avatarObjectKey: draft.avatarObjectKey,
            updatedAt: draft.updatedAt
        )
    }

    func apply(_ draft: RedCodeGroupDraft) {
        name = draft.name
        ownerID = draft.ownerID
        currentUserRole = draft.currentUserRole
        memberCount = draft.memberCount
        avatarURL = draft.avatarURL
        avatarObjectKey = draft.avatarObjectKey
        updatedAt = draft.updatedAt
    }

    func toDraft() -> RedCodeGroupDraft {
        RedCodeGroupDraft(
            roomID: roomID,
            name: name,
            ownerID: ownerID,
            currentUserRole: currentUserRole,
            memberCount: memberCount,
            avatarURL: avatarURL,
            avatarObjectKey: avatarObjectKey,
            updatedAt: updatedAt
        )
    }
}
