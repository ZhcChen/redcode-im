import Foundation
import GRDB

@MainActor
public protocol AppConfigStore: AnyObject {
    func loadValue(forKey key: String) throws -> String?
    func saveValue(_ valueJSON: String, forKey key: String) throws
    func removeValue(forKey key: String) throws
    func clearAll() throws
}

@MainActor
public final class GRDBAppConfigStore: AppConfigStore {
    private let database: RedCodeDatabase

    public init(database: RedCodeDatabase) {
        self.database = database
    }

    public func loadValue(forKey key: String) throws -> String? {
        let key = normalizedKey(key)
        guard !key.isEmpty else {
            return nil
        }

        return try database.dbQueue.read { db in
            try RedCodeAppConfigRecord.fetchOne(db, key: key)?.valueJSON
        }
    }

    public func saveValue(_ valueJSON: String, forKey key: String) throws {
        let key = normalizedKey(key)
        guard !key.isEmpty else {
            return
        }

        try database.dbQueue.write { db in
            if var record = try RedCodeAppConfigRecord.fetchOne(db, key: key) {
                record.valueJSON = valueJSON
                record.updatedAt = Date()
                try record.update(db)
            } else {
                try RedCodeAppConfigRecord(key: key, valueJSON: valueJSON).insert(db)
            }
        }
    }

    public func removeValue(forKey key: String) throws {
        let key = normalizedKey(key)
        guard !key.isEmpty else {
            return
        }

        try database.dbQueue.write { db in
            _ = try RedCodeAppConfigRecord.filter(Column("key") == key).deleteAll(db)
        }
    }

    public func clearAll() throws {
        try database.dbQueue.write { db in
            try RedCodeAppConfigRecord.deleteAll(db)
        }
    }

    private func normalizedKey(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
