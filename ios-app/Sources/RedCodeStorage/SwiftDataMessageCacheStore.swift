import Foundation
import SwiftData

@MainActor
public protocol MessageCacheStore: AnyObject {
    func listRoomIDs() throws -> [String]
    func loadMessages(roomID: String) throws -> [RedCodeMessageDraft]
    func saveMessages(roomID: String, messages: [RedCodeMessageDraft]) throws
    func clear(roomID: String) throws
    func clearAll() throws
}

@MainActor
public final class SwiftDataMessageCacheStore: MessageCacheStore {
    private let container: ModelContainer
    private let policy: MessageCachePolicy

    public init(
        container: ModelContainer,
        policy: MessageCachePolicy = MessageCachePolicy()
    ) {
        self.container = container
        self.policy = policy
    }

    public func listRoomIDs() throws -> [String] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<RedCodeMessageRecord>()
        let records = try context.fetch(descriptor)
        return Array(Set(records.map(\.roomID))).sorted()
    }

    public func loadMessages(roomID: String) throws -> [RedCodeMessageDraft] {
        let roomID = normalizedRoomID(roomID)
        guard !roomID.isEmpty else {
            return []
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<RedCodeMessageRecord>(
            predicate: #Predicate { $0.roomID == roomID },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return try context.fetch(descriptor).map { $0.toDraft() }
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

        let context = ModelContext(container)
        let existingDescriptor = FetchDescriptor<RedCodeMessageRecord>(
            predicate: #Predicate { $0.roomID == roomID }
        )
        for record in try context.fetch(existingDescriptor) {
            context.delete(record)
        }
        for draft in trimmed {
            context.insert(RedCodeMessageRecord(draft: draft, roomID: roomID))
        }
        try context.save()
    }

    public func clear(roomID: String) throws {
        let roomID = normalizedRoomID(roomID)
        guard !roomID.isEmpty else {
            return
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<RedCodeMessageRecord>(
            predicate: #Predicate { $0.roomID == roomID }
        )
        for record in try context.fetch(descriptor) {
            context.delete(record)
        }
        try context.save()
    }

    public func clearAll() throws {
        let context = ModelContext(container)
        for record in try context.fetch(FetchDescriptor<RedCodeMessageRecord>()) {
            context.delete(record)
        }
        try context.save()
    }

    private func normalizedRoomID(_ roomID: String) -> String {
        roomID.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
