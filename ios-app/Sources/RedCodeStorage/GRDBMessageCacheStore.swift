import Foundation
import GRDB

@MainActor
public protocol MessageCacheStore: AnyObject {
    func listRoomIDs() throws -> [String]
    func loadMessages(roomID: String) throws -> [RedCodeMessageDraft]
    func saveMessages(roomID: String, messages: [RedCodeMessageDraft]) throws
    func clear(roomID: String) throws
    func clearAll() throws
}

@MainActor
public final class GRDBMessageCacheStore: MessageCacheStore {
    private let database: RedCodeDatabase
    private let policy: MessageCachePolicy

    public init(
        database: RedCodeDatabase,
        policy: MessageCachePolicy = MessageCachePolicy()
    ) {
        self.database = database
        self.policy = policy
    }

    public func listRoomIDs() throws -> [String] {
        try database.dbQueue.read { db in
            let records = try RedCodeMessageRecord.fetchAll(db)
            return Array(Set(records.map(\.roomID))).sorted()
        }
    }

    public func loadMessages(roomID: String) throws -> [RedCodeMessageDraft] {
        let roomID = normalizedRoomID(roomID)
        guard !roomID.isEmpty else {
            return []
        }

        return try database.dbQueue.read { db in
            try RedCodeMessageRecord
                .filter(Column("roomID") == roomID)
                .order(Column("timestamp").asc)
                .fetchAll(db)
                .map { $0.toDraft() }
        }
    }

    public func saveMessages(roomID: String, messages: [RedCodeMessageDraft]) throws {
        let roomID = normalizedRoomID(roomID)
        guard !roomID.isEmpty else {
            return
        }

        let trimmed = messages
            .filter { !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.timestamp < $1.timestamp }
            .suffix(policy.maxMessagesPerRoom)

        try database.dbQueue.write { db in
            _ = try RedCodeMessageRecord.filter(Column("roomID") == roomID).deleteAll(db)
            for draft in trimmed {
                try RedCodeMessageRecord(draft: draft, roomID: roomID).insert(db)
            }
        }
    }

    public func clear(roomID: String) throws {
        let roomID = normalizedRoomID(roomID)
        guard !roomID.isEmpty else {
            return
        }

        try database.dbQueue.write { db in
            _ = try RedCodeMessageRecord.filter(Column("roomID") == roomID).deleteAll(db)
        }
    }

    public func clearAll() throws {
        try database.dbQueue.write { db in
            try RedCodeMessageRecord.deleteAll(db)
        }
    }

    private func normalizedRoomID(_ roomID: String) -> String {
        roomID.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
