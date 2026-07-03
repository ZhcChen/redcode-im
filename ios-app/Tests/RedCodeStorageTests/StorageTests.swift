import XCTest
@testable import RedCodeStorage

final class StorageTests: XCTestCase {
    func testInMemoryKeyValueStoreStoresAndRemovesValues() async throws {
        let store = InMemoryKeyValueStore()

        try await store.setString("token", forKey: "accessToken")
        let storedToken = try await store.string(forKey: "accessToken")
        XCTAssertEqual(storedToken, "token")

        try await store.removeValue(forKey: "accessToken")
        let removedToken = try await store.string(forKey: "accessToken")
        XCTAssertNil(removedToken)
    }

    func testMessageCachePolicyKeepsNewestMessagesForRoom() {
        let base = Date(timeIntervalSince1970: 1_000)
        let messages = (0..<5).map { index in
            CachedMessageIdentity(
                id: "m\(index)",
                roomID: index == 0 ? "other-room" : "room-1",
                timestamp: base.addingTimeInterval(TimeInterval(index))
            )
        }
        let policy = MessageCachePolicy(maxMessagesPerRoom: 2)

        let retained = policy.retainedMessages(from: messages, roomID: "room-1")

        XCTAssertEqual(retained.map(\.id), ["m3", "m4"])
    }
}
