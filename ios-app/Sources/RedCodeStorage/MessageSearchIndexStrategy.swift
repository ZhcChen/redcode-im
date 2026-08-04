import Foundation

public enum MessageSearchIndexBackend: String, Equatable, Sendable {
    case inMemory
    case sqliteFTS5
}

public struct MessageSearchIndexStrategy: Equatable, Sendable {
    public let preferredBackend: MessageSearchIndexBackend
    public let sqliteFTS5Threshold: Int

    public init(
        preferredBackend: MessageSearchIndexBackend = .inMemory,
        sqliteFTS5Threshold: Int = 20_000
    ) {
        self.preferredBackend = preferredBackend
        self.sqliteFTS5Threshold = max(1, sqliteFTS5Threshold)
    }

    public func backendForIndexedMessageCount(_ messageCount: Int) -> MessageSearchIndexBackend {
        guard preferredBackend == .inMemory else {
            return preferredBackend
        }
        return messageCount >= sqliteFTS5Threshold ? .sqliteFTS5 : .inMemory
    }
}
