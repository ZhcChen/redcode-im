import Foundation
import GRDB

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
public final class GRDBGroupCacheStore: GroupCacheStore {
    private let database: RedCodeDatabase

    public init(database: RedCodeDatabase) {
        self.database = database
    }

    public func loadGroups() throws -> [RedCodeGroupDraft] {
        try database.dbQueue.read { db in
            try RedCodeGroupRecord
                .order(Column("updatedAt").desc)
                .fetchAll(db)
                .map { $0.toDraft() }
        }
    }

    public func saveGroups(_ groups: [RedCodeGroupDraft]) throws {
        try database.dbQueue.write { db in
            try RedCodeGroupRecord.deleteAll(db)
            for draft in groups where !draft.roomID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try RedCodeGroupRecord(draft: draft).insert(db)
            }
        }
    }

    public func upsert(_ group: RedCodeGroupDraft) throws {
        let roomID = group.roomID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !roomID.isEmpty else {
            return
        }

        try database.dbQueue.write { db in
            if var record = try RedCodeGroupRecord.fetchOne(db, key: roomID) {
                record.apply(group)
                try record.update(db)
            } else {
                try RedCodeGroupRecord(draft: group).insert(db)
            }
        }
    }

    public func remove(roomID: String) throws {
        let roomID = roomID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !roomID.isEmpty else {
            return
        }

        try database.dbQueue.write { db in
            _ = try RedCodeGroupRecord.filter(Column("roomID") == roomID).deleteAll(db)
        }
    }

    public func clearAll() throws {
        try database.dbQueue.write { db in
            try RedCodeGroupRecord.deleteAll(db)
        }
    }
}

private extension RedCodeGroupRecord {
    init(draft: RedCodeGroupDraft) {
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

    mutating func apply(_ draft: RedCodeGroupDraft) {
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
