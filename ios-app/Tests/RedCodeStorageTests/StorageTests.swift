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

    func testMessageSearchIndexStrategyPrefersSwiftDataUntilThreshold() {
        let strategy = MessageSearchIndexStrategy(sqliteFTS5Threshold: 100)

        XCTAssertEqual(strategy.backendForIndexedMessageCount(99), .swiftData)
        XCTAssertEqual(strategy.backendForIndexedMessageCount(100), .sqliteFTS5)
        XCTAssertEqual(
            MessageSearchIndexStrategy(preferredBackend: .sqliteFTS5)
                .backendForIndexedMessageCount(1),
            .sqliteFTS5
        )
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

    func testAttachmentFileCacheSavesResolvesAndRemovesData() async throws {
        let rootURL = try makeTemporaryCacheRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let cache = AttachmentFileCache(rootURL: rootURL)
        let objectKey = "rooms/room-1/hello.txt"

        let saved = try await cache.save(
            objectKey: objectKey,
            data: Data("hello".utf8),
            mimeType: "text/plain"
        )
        let resolved = try await cache.resolve(objectKey: objectKey)
        let existsAfterSave = FileManager.default.fileExists(atPath: saved.fileURL.path)
        try await cache.remove(objectKey: objectKey)
        let removed = try await cache.resolve(objectKey: objectKey)

        XCTAssertTrue(existsAfterSave)
        XCTAssertEqual(resolved?.objectKey, objectKey)
        XCTAssertEqual(resolved?.mimeType, "text/plain")
        XCTAssertEqual(resolved?.size, 5)
        XCTAssertNil(removed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: saved.fileURL.path))
    }

    func testAvatarFileCacheRejectsObjectKeyMismatchAndExpiresEntries() async throws {
        let rootURL = try makeTemporaryCacheRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let avatarCache = AvatarFileCache(rootURL: rootURL)

        let saved = try await avatarCache.saveUserAvatar(
            userID: "user-1",
            objectKey: "avatars/user-1-a.png",
            data: Data([1, 2, 3]),
            mimeType: "image/png"
        )
        let mismatch = try await avatarCache.resolveUserAvatar(
            userID: "user-1",
            objectKey: "avatars/user-1-b.png"
        )

        XCTAssertNil(mismatch)
        XCTAssertFalse(FileManager.default.fileExists(atPath: saved.fileURL.path))

        let expiringCache = AvatarFileCache(rootURL: rootURL, ttl: -1)
        let expired = try await expiringCache.saveRoomAvatar(
            roomID: "room-1",
            objectKey: "avatars/room-1.png",
            data: Data([4, 5, 6]),
            mimeType: "image/png"
        )
        let resolvedExpired = try await expiringCache.resolveRoomAvatar(
            roomID: "room-1",
            objectKey: "avatars/room-1.png"
        )

        XCTAssertNil(resolvedExpired)
        XCTAssertFalse(FileManager.default.fileExists(atPath: expired.fileURL.path))
    }

    func testEmojiFileCacheUsesObjectKeyExtensionAndClearAll() async throws {
        let rootURL = try makeTemporaryCacheRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let cache = EmojiFileCache(rootURL: rootURL)
        let objectKey = "https://cdn.example.test/emojis/redcode.gif"

        let saved = try await cache.save(
            objectKey: objectKey,
            data: Data([7, 8, 9]),
            mimeType: "image/gif"
        )
        let resolved = try await cache.resolve(objectKey: objectKey)
        try await cache.clearAll()
        let cleared = try await cache.resolve(objectKey: objectKey)

        XCTAssertEqual(saved.fileURL.pathExtension, "gif")
        XCTAssertEqual(resolved?.mimeType, "image/gif")
        XCTAssertNil(cleared)
        XCTAssertFalse(FileManager.default.fileExists(atPath: saved.fileURL.path))
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

    private func makeTemporaryCacheRoot() throws -> URL {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("redcode-ios-cache-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        return rootURL
    }
}
