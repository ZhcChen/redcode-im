import Foundation
import GRDB

public struct RedCodeContactDraft: Equatable, Sendable {
    public let userID: String
    public let username: String
    public let nickname: String?
    public let avatarURL: String?
    public let avatarObjectKey: String?
    public let friendshipStatus: String
    public let updatedAt: Date

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

    public var displayName: String {
        if let nickname, !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nickname
        }
        return username
    }
}

@MainActor
public protocol ContactCacheStore: AnyObject {
    func loadContacts() throws -> [RedCodeContactDraft]
    func saveContacts(_ contacts: [RedCodeContactDraft]) throws
    func upsert(_ contact: RedCodeContactDraft) throws
    func remove(userID: String) throws
    func clearAll() throws
}

@MainActor
public final class GRDBContactCacheStore: ContactCacheStore {
    private let database: RedCodeDatabase

    public init(database: RedCodeDatabase) {
        self.database = database
    }

    public func loadContacts() throws -> [RedCodeContactDraft] {
        try database.dbQueue.read { db in
            try RedCodeContactRecord.fetchAll(db)
                .map { $0.toDraft() }
                .sortedForContacts()
        }
    }

    public func saveContacts(_ contacts: [RedCodeContactDraft]) throws {
        try database.dbQueue.write { db in
            try RedCodeContactRecord.deleteAll(db)
            for draft in contacts where !draft.userID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try RedCodeContactRecord(draft: draft).insert(db)
            }
        }
    }

    public func upsert(_ contact: RedCodeContactDraft) throws {
        let userID = contact.userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userID.isEmpty else {
            return
        }

        try database.dbQueue.write { db in
            if var record = try RedCodeContactRecord.fetchOne(db, key: userID) {
                record.apply(contact)
                try record.update(db)
            } else {
                try RedCodeContactRecord(draft: contact).insert(db)
            }
        }
    }

    public func remove(userID: String) throws {
        let userID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userID.isEmpty else {
            return
        }

        try database.dbQueue.write { db in
            _ = try RedCodeContactRecord.filter(Column("userID") == userID).deleteAll(db)
        }
    }

    public func clearAll() throws {
        try database.dbQueue.write { db in
            try RedCodeContactRecord.deleteAll(db)
        }
    }
}

private extension RedCodeContactRecord {
    init(draft: RedCodeContactDraft) {
        self.init(
            userID: draft.userID,
            username: draft.username,
            nickname: draft.nickname,
            avatarURL: draft.avatarURL,
            avatarObjectKey: draft.avatarObjectKey,
            friendshipStatus: draft.friendshipStatus,
            updatedAt: draft.updatedAt
        )
    }

    mutating func apply(_ draft: RedCodeContactDraft) {
        username = draft.username
        nickname = draft.nickname
        avatarURL = draft.avatarURL
        avatarObjectKey = draft.avatarObjectKey
        friendshipStatus = draft.friendshipStatus
        updatedAt = draft.updatedAt
    }

    func toDraft() -> RedCodeContactDraft {
        RedCodeContactDraft(
            userID: userID,
            username: username,
            nickname: nickname,
            avatarURL: avatarURL,
            avatarObjectKey: avatarObjectKey,
            friendshipStatus: friendshipStatus,
            updatedAt: updatedAt
        )
    }
}

private extension Array where Element == RedCodeContactDraft {
    func sortedForContacts() -> [RedCodeContactDraft] {
        sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }
}
