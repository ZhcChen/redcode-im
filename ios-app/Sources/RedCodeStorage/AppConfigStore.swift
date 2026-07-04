import Foundation
import SwiftData

@MainActor
public protocol AppConfigStore: AnyObject {
    func loadValue(forKey key: String) throws -> String?
    func saveValue(_ valueJSON: String, forKey key: String) throws
    func removeValue(forKey key: String) throws
    func clearAll() throws
}

@MainActor
public final class SwiftDataAppConfigStore: AppConfigStore {
    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public func loadValue(forKey key: String) throws -> String? {
        let key = normalizedKey(key)
        guard !key.isEmpty else {
            return nil
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<RedCodeAppConfigRecord>(
            predicate: #Predicate { $0.key == key }
        )
        return try context.fetch(descriptor).first?.valueJSON
    }

    public func saveValue(_ valueJSON: String, forKey key: String) throws {
        let key = normalizedKey(key)
        guard !key.isEmpty else {
            return
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<RedCodeAppConfigRecord>(
            predicate: #Predicate { $0.key == key }
        )
        if let record = try context.fetch(descriptor).first {
            record.valueJSON = valueJSON
            record.updatedAt = Date()
        } else {
            context.insert(RedCodeAppConfigRecord(key: key, valueJSON: valueJSON))
        }
        try context.save()
    }

    public func removeValue(forKey key: String) throws {
        let key = normalizedKey(key)
        guard !key.isEmpty else {
            return
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<RedCodeAppConfigRecord>(
            predicate: #Predicate { $0.key == key }
        )
        for record in try context.fetch(descriptor) {
            context.delete(record)
        }
        try context.save()
    }

    public func clearAll() throws {
        let context = ModelContext(container)
        for record in try context.fetch(FetchDescriptor<RedCodeAppConfigRecord>()) {
            context.delete(record)
        }
        try context.save()
    }

    private func normalizedKey(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
