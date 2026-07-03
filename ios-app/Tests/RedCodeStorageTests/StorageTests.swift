import XCTest
import SwiftData
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

    @MainActor
    func testSwiftDataSchemaStoresCoreCacheRecords() throws {
        let container = try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        let now = Date(timeIntervalSince1970: 1_000)

        context.insert(RedCodeChatRecord(
            roomID: "room-1",
            roomType: "direct",
            displayName: "Alice",
            lastMessagePreview: "hello",
            unreadCount: 2,
            updatedAt: now
        ))
        context.insert(RedCodeContactRecord(
            userID: "user-1",
            username: "alice",
            nickname: "Alice"
        ))
        context.insert(RedCodeGroupRecord(
            roomID: "group-1",
            name: "Group",
            ownerID: "user-1",
            currentUserRole: "owner",
            memberCount: 3
        ))
        context.insert(RedCodeAppConfigRecord(
            key: "message_runtime",
            valueJSON: #"{"server_storage_mode":"persist"}"#
        ))
        try context.save()

        let chats = try context.fetch(FetchDescriptor<RedCodeChatRecord>())
        let contacts = try context.fetch(FetchDescriptor<RedCodeContactRecord>())
        let groups = try context.fetch(FetchDescriptor<RedCodeGroupRecord>())
        let configs = try context.fetch(FetchDescriptor<RedCodeAppConfigRecord>())

        XCTAssertEqual(chats.map(\.roomID), ["room-1"])
        XCTAssertEqual(chats.first?.lastMessagePreview, "hello")
        XCTAssertEqual(contacts.map(\.username), ["alice"])
        XCTAssertEqual(groups.map(\.memberCount), [3])
        XCTAssertEqual(configs.map(\.key), ["message_runtime"])
    }

    @MainActor
    func testSwiftDataMessageCacheStoreKeepsNewestMessagesPerRoom() throws {
        let container = try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        let store = SwiftDataMessageCacheStore(
            container: container,
            policy: MessageCachePolicy(maxMessagesPerRoom: 2)
        )
        let base = Date(timeIntervalSince1970: 1_000)
        let messages = (0..<4).map { index in
            RedCodeMessageDraft(
                id: "m\(index)",
                roomID: "room-1",
                senderID: "user-1",
                content: "message \(index)",
                timestamp: base.addingTimeInterval(TimeInterval(index))
            )
        }

        try store.saveMessages(roomID: "room-1", messages: messages)
        try store.saveMessages(roomID: "room-2", messages: [
            RedCodeMessageDraft(
                id: "m-room-2",
                roomID: "room-2",
                senderID: "user-2",
                content: "other",
                timestamp: base
            ),
        ])

        let roomOneMessages = try store.loadMessages(roomID: "room-1")
        let roomIDs = try store.listRoomIDs()

        XCTAssertEqual(roomOneMessages.map(\.id), ["m2", "m3"])
        XCTAssertEqual(roomOneMessages.map(\.content), ["message 2", "message 3"])
        XCTAssertEqual(roomIDs, ["room-1", "room-2"])
    }

    @MainActor
    func testSwiftDataMessageCacheStoreClearsRoomMessages() throws {
        let container = try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        let store = SwiftDataMessageCacheStore(container: container)
        let message = RedCodeMessageDraft(
            id: "m1",
            roomID: "room-1",
            senderID: "user-1",
            content: "hello",
            timestamp: Date(timeIntervalSince1970: 1_000)
        )

        try store.saveMessages(roomID: "room-1", messages: [message])
        try store.clear(roomID: "room-1")

        XCTAssertTrue(try store.loadMessages(roomID: "room-1").isEmpty)
        XCTAssertTrue(try store.listRoomIDs().isEmpty)
    }

    #if canImport(Security)
    func testKeychainKeyValueStoreStoresAndRemovesValues() async throws {
        let store = KeychainKeyValueStore(
            service: "com.redcode.im.iosapp.tests.\(UUID().uuidString)"
        )

        try await store.setString("access-token", forKey: "auth_token")
        let stored = try await store.string(forKey: "auth_token")
        try await store.removeValue(forKey: "auth_token")
        let removed = try await store.string(forKey: "auth_token")

        XCTAssertEqual(stored, "access-token")
        XCTAssertNil(removed)
    }
    #endif
}
