import Foundation

public struct WebSocketEventDeduplicator: Sendable {
    private let capacity: Int
    private var seenKeys: Set<String> = []
    private var orderedKeys: [String] = []

    public init(capacity: Int = 512) {
        self.capacity = max(1, capacity)
    }

    public mutating func shouldAccept(_ event: WebSocketServerEvent) -> Bool {
        guard let key = event.deduplicationKey else {
            return true
        }
        guard !seenKeys.contains(key) else {
            return false
        }

        seenKeys.insert(key)
        orderedKeys.append(key)

        while orderedKeys.count > capacity {
            let removed = orderedKeys.removeFirst()
            seenKeys.remove(removed)
        }

        return true
    }

    public mutating func reset() {
        seenKeys.removeAll()
        orderedKeys.removeAll()
    }
}
