import Foundation

public enum MessageSearchIndexBackend: String, Equatable, Sendable {
    case swiftData
    case sqliteFTS5
}

public struct MessageSearchIndexStrategy: Equatable, Sendable {
    public let preferredBackend: MessageSearchIndexBackend
    public let sqliteFTS5Threshold: Int

    public init(
        preferredBackend: MessageSearchIndexBackend = .swiftData,
        sqliteFTS5Threshold: Int = 20_000
    ) {
        self.preferredBackend = preferredBackend
        self.sqliteFTS5Threshold = max(1, sqliteFTS5Threshold)
    }

    public func backendForIndexedMessageCount(_ messageCount: Int) -> MessageSearchIndexBackend {
        guard preferredBackend == .swiftData else {
            return preferredBackend
        }
        return messageCount >= sqliteFTS5Threshold ? .sqliteFTS5 : .swiftData
    }
}
