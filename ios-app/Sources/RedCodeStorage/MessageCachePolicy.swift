import Foundation
import RedCodeCore

public struct CachedMessageIdentity: Equatable, Sendable {
    public let id: String
    public let roomID: String
    public let timestamp: Date

    public init(id: String, roomID: String, timestamp: Date) {
        self.id = id
        self.roomID = roomID
        self.timestamp = timestamp
    }
}

public struct MessageCachePolicy: Equatable, Sendable {
    public let maxMessagesPerRoom: Int

    public init(maxMessagesPerRoom: Int = RedCodePlatformPolicy.maxCachedMessagesPerRoom) {
        self.maxMessagesPerRoom = maxMessagesPerRoom
    }

    public func retainedMessages(
        from messages: [CachedMessageIdentity],
        roomID: String
    ) -> [CachedMessageIdentity] {
        messages
            .filter { $0.roomID == roomID }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(maxMessagesPerRoom)
            .sorted { $0.timestamp < $1.timestamp }
    }
}
