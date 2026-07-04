import Foundation
import SwiftData

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
public final class SwiftDataContactCacheStore: ContactCacheStore {
    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public func loadContacts() throws -> [RedCodeContactDraft] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<RedCodeContactRecord>())
            .map { $0.toDraft() }
            .sortedForContacts()
    }

    public func saveContacts(_ contacts: [RedCodeContactDraft]) throws {
        let context = ModelContext(container)
        for record in try context.fetch(FetchDescriptor<RedCodeContactRecord>()) {
            context.delete(record)
        }
        for draft in contacts where !draft.userID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            context.insert(RedCodeContactRecord(draft: draft))
        }
        try context.save()
    }

    public func upsert(_ contact: RedCodeContactDraft) throws {
        let userID = contact.userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userID.isEmpty else {
            return
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<RedCodeContactRecord>(
            predicate: #Predicate { $0.userID == userID }
        )
        if let record = try context.fetch(descriptor).first {
            record.apply(contact)
        } else {
            context.insert(RedCodeContactRecord(draft: contact))
        }
        try context.save()
    }

    public func remove(userID: String) throws {
        let userID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userID.isEmpty else {
            return
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<RedCodeContactRecord>(
            predicate: #Predicate { $0.userID == userID }
        )
        for record in try context.fetch(descriptor) {
            context.delete(record)
        }
        try context.save()
    }

    public func clearAll() throws {
        let context = ModelContext(container)
        for record in try context.fetch(FetchDescriptor<RedCodeContactRecord>()) {
            context.delete(record)
        }
        try context.save()
    }
}

private extension RedCodeContactRecord {
    convenience init(draft: RedCodeContactDraft) {
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

    func apply(_ draft: RedCodeContactDraft) {
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
