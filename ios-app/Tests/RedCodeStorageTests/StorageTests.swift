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
    func testSwiftDataChatSummaryCacheStoresSortsAndRemovesChats() throws {
        let container = try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        let store = SwiftDataChatSummaryCacheStore(container: container)
        let oldDate = Date(timeIntervalSince1970: 100)
        let newDate = Date(timeIntervalSince1970: 200)

        try store.saveChats([
            RedCodeChatSummaryDraft(
                roomID: "r1",
                roomType: "private",
                displayName: "Alice",
                lastMessageID: "m1",
                lastMessagePreview: "old",
                lastMessageAt: oldDate
            ),
            RedCodeChatSummaryDraft(
                roomID: "r2",
                roomType: "group",
                displayName: "Team",
                lastMessageID: "m2",
                lastMessagePreview: "new",
                lastMessageAt: newDate,
                isPinned: true
            ),
        ])

        XCTAssertEqual(try store.loadChats().map(\.roomID), ["r2", "r1"])

        try store.upsert(
            RedCodeChatSummaryDraft(
                roomID: "r1",
                roomType: "private",
                displayName: "Alice Updated",
                lastMessageID: "m3",
                lastMessagePreview: "updated",
                lastMessageAt: Date(timeIntervalSince1970: 300),
                unreadCount: 2
            )
        )
        let updated = try XCTUnwrap(try store.loadChats().first { $0.roomID == "r1" })
        XCTAssertEqual(updated.displayName, "Alice Updated")
        XCTAssertEqual(updated.lastMessageID, "m3")
        XCTAssertEqual(updated.unreadCount, 2)

        try store.remove(roomID: "r2")
        XCTAssertEqual(try store.loadChats().map(\.roomID), ["r1"])
    }

    @MainActor
    func testSwiftDataContactCacheStoreStoresSortsUpsertsRemovesAndClearsContacts() throws {
        let container = try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        let store = SwiftDataContactCacheStore(container: container)
        let baseDate = Date(timeIntervalSince1970: 1_000)

        try store.saveContacts([
            RedCodeContactDraft(
                userID: "user-2",
                username: "bob",
                avatarObjectKey: "users/user-2/avatar.png",
                updatedAt: baseDate
            ),
            RedCodeContactDraft(
                userID: "user-1",
                username: "alice",
                nickname: "Alice",
                friendshipStatus: "accepted",
                updatedAt: baseDate.addingTimeInterval(10)
            ),
            RedCodeContactDraft(userID: "  ", username: "ignored"),
        ])

        var contacts = try store.loadContacts()
        XCTAssertEqual(contacts.map(\.userID), ["user-1", "user-2"])
        XCTAssertEqual(contacts.map(\.displayName), ["Alice", "bob"])
        XCTAssertEqual(contacts[1].avatarObjectKey, "users/user-2/avatar.png")

        try store.upsert(
            RedCodeContactDraft(
                userID: "user-2",
                username: "bob",
                nickname: "Bobby",
                avatarURL: "https://cdn.example.test/bob.png",
                friendshipStatus: "blocked",
                updatedAt: baseDate.addingTimeInterval(20)
            )
        )

        contacts = try store.loadContacts()
        let updated = try XCTUnwrap(contacts.first { $0.userID == "user-2" })
        XCTAssertEqual(updated.displayName, "Bobby")
        XCTAssertEqual(updated.avatarURL, "https://cdn.example.test/bob.png")
        XCTAssertEqual(updated.friendshipStatus, "blocked")

        try store.remove(userID: " user-1 ")
        XCTAssertEqual(try store.loadContacts().map(\.userID), ["user-2"])

        try store.clearAll()
        XCTAssertTrue(try store.loadContacts().isEmpty)
    }

    @MainActor
    func testSwiftDataGroupCacheStoreStoresUpsertsRemovesAndClearsGroups() throws {
        let container = try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        let store = SwiftDataGroupCacheStore(container: container)
        let baseDate = Date(timeIntervalSince1970: 1_000)

        try store.saveGroups([
            RedCodeGroupDraft(
                roomID: "group-1",
                name: "Old Group",
                ownerID: "owner-1",
                currentUserRole: "owner",
                memberCount: 2,
                updatedAt: baseDate
            ),
            RedCodeGroupDraft(roomID: "  ", name: "ignored"),
        ])

        var groups = try store.loadGroups()
        XCTAssertEqual(groups.map(\.roomID), ["group-1"])
        XCTAssertEqual(groups.first?.memberCount, 2)

        try store.upsert(
            RedCodeGroupDraft(
                roomID: "group-1",
                name: "New Group",
                ownerID: "owner-1",
                currentUserRole: "admin",
                memberCount: 4,
                avatarObjectKey: "rooms/group-1/avatar.png",
                updatedAt: baseDate.addingTimeInterval(10)
            )
        )

        groups = try store.loadGroups()
        XCTAssertEqual(groups.first?.name, "New Group")
        XCTAssertEqual(groups.first?.currentUserRole, "admin")
        XCTAssertEqual(groups.first?.memberCount, 4)
        XCTAssertEqual(groups.first?.avatarObjectKey, "rooms/group-1/avatar.png")

        try store.remove(roomID: " group-1 ")
        XCTAssertTrue(try store.loadGroups().isEmpty)

        try store.upsert(RedCodeGroupDraft(roomID: "group-2", name: "Group 2"))
        try store.clearAll()
        XCTAssertTrue(try store.loadGroups().isEmpty)
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
    func testSwiftDataAppConfigStoreSavesUpdatesRemovesAndClearsValues() throws {
        let container = try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        let store = SwiftDataAppConfigStore(container: container)

        try store.saveValue(#"{"app_name":"RedCode IM"}"#, forKey: " settings.general ")
        XCTAssertEqual(
            try store.loadValue(forKey: "settings.general"),
            #"{"app_name":"RedCode IM"}"#
        )

        try store.saveValue(#"{"app_name":"RedCode Next"}"#, forKey: "settings.general")
        XCTAssertEqual(
            try store.loadValue(forKey: "settings.general"),
            #"{"app_name":"RedCode Next"}"#
        )

        try store.removeValue(forKey: "settings.general")
        XCTAssertNil(try store.loadValue(forKey: "settings.general"))

        try store.saveValue(#"{"title":"隐私协议"}"#, forKey: "settings.privacy_policy")
        try store.clearAll()
        XCTAssertNil(try store.loadValue(forKey: "settings.privacy_policy"))
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

    @MainActor
    func testSwiftDataMessageSearchStoreRebuildsFiltersAndPaginatesLocalIndex() throws {
        let container = try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        let cache = SwiftDataMessageCacheStore(container: container)
        let searchStore = SwiftDataMessageSearchStore(messageCacheStore: cache)
        let base = Date(timeIntervalSince1970: 1_000)

        try cache.saveMessages(roomID: "room-1", messages: [
            RedCodeMessageDraft(
                id: "m1",
                roomID: "room-1",
                senderID: "u1",
                senderName: "Alice",
                content: "hello redcode",
                messageType: "text",
                timestamp: base
            ),
            RedCodeMessageDraft(
                id: "m2",
                roomID: "room-1",
                senderID: "u2",
                senderName: "Bob",
                content: "",
                messageType: "image",
                timestamp: base.addingTimeInterval(10)
            ),
            RedCodeMessageDraft(
                id: "deleted",
                roomID: "room-1",
                senderID: "u2",
                senderName: "Bob",
                content: "redcode deleted",
                status: "deleted",
                timestamp: base.addingTimeInterval(20),
                isDeleted: true
            ),
        ])
        try cache.saveMessages(roomID: "room-2", messages: [
            RedCodeMessageDraft(
                id: "m3",
                roomID: "room-2",
                senderID: "u3",
                senderName: "Carol",
                content: "redcode in second room",
                messageType: "text",
                timestamp: base.addingTimeInterval(30)
            ),
        ])
        let deletedDraft = try XCTUnwrap(try cache.loadMessages(roomID: "room-1").first { $0.id == "deleted" })
        XCTAssertTrue(deletedDraft.isDeleted)

        try searchStore.rebuildIndex(roomNamesByID: ["room-1": "General", "room-2": "Random"])

        let all = try searchStore.searchMessages(query: "redcode", roomID: nil, messageType: nil, limit: 1, offset: 0)
        XCTAssertEqual(all.stats.totalResults, 2)
        XCTAssertEqual(all.results.map(\.id), ["m3"])
        XCTAssertTrue(all.hasMore)
        XCTAssertEqual(all.results.first?.roomName, "Random")

        let pageTwo = try searchStore.searchMessages(query: "redcode", roomID: nil, messageType: nil, limit: 1, offset: 1)
        XCTAssertEqual(pageTwo.results.map(\.id), ["m1"])
        XCTAssertFalse(pageTwo.hasMore)
        XCTAssertEqual(pageTwo.results.first?.matchedText, "hello redcode")

        let imageResults = try searchStore.searchMessages(query: "图片", roomID: "room-1", messageType: "image", limit: 10, offset: 0)
        XCTAssertEqual(imageResults.results.map(\.id), ["m2"])

        let blank = try searchStore.searchMessages(query: "  ", roomID: nil, messageType: nil, limit: 10, offset: 0)
        XCTAssertTrue(blank.results.isEmpty)
        XCTAssertEqual(blank.stats.query, "")
    }

    func testUserDefaultsChatPreferencesStoreSavesLoadsAndResetsBackground() async throws {
        let key = "redcode-ios-chat-background-tests-\(UUID().uuidString)"
        defer {
            UserDefaults.standard.removeObject(forKey: key)
        }
        let store = UserDefaultsChatPreferencesStore(key: key)

        let initial = try await store.loadBackground()
        try await store.saveBackground(ChatBackgroundPreference(kind: .preset, value: "blue"))
        let saved = try await store.loadBackground()
        try await store.resetBackground()
        let reset = try await store.loadBackground()

        XCTAssertEqual(initial, .default)
        XCTAssertEqual(saved, ChatBackgroundPreference(kind: .preset, value: "blue"))
        XCTAssertEqual(reset, .default)
    }

    @MainActor
    func testUserDefaultsPushDeviceIdentityStoreKeepsDeviceIDAndClearsRegisteredToken() throws {
        let suiteName = "redcode-ios-push-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = UserDefaultsPushDeviceIdentityStore(defaults: defaults, keyPrefix: "push-tests")

        let firstID = try store.getOrCreateDeviceID()
        let secondID = try store.getOrCreateDeviceID()
        try store.saveRegisteredToken(" fcm-token ", channel: " FCM ")

        let saved = try XCTUnwrap(try store.loadIdentity())
        XCTAssertFalse(firstID.isEmpty)
        XCTAssertEqual(secondID, firstID)
        XCTAssertEqual(saved.deviceID, firstID)
        XCTAssertEqual(saved.deviceToken, "fcm-token")
        XCTAssertEqual(saved.channel, "fcm")
        XCTAssertNotNil(saved.updatedAt)

        try store.clearRegisteredToken()

        let clearedToken = try XCTUnwrap(try store.loadIdentity())
        XCTAssertEqual(clearedToken.deviceID, firstID)
        XCTAssertNil(clearedToken.deviceToken)
        XCTAssertNil(clearedToken.channel)
        XCTAssertNil(clearedToken.updatedAt)

        try store.clearAll()

        XCTAssertNil(try store.loadIdentity())
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

    func testMediaUploadPreparerInfersMimeKindAndSHA256() throws {
        let rootURL = try makeTemporaryCacheRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let fileURL = rootURL.appendingPathComponent("sample.png")
        try Data("abc".utf8).write(to: fileURL)

        let prepared = try MediaUploadPreparer.prepareFile(at: fileURL)

        XCTAssertEqual(prepared.fileName, "sample.png")
        XCTAssertEqual(prepared.contentType, "image/png")
        XCTAssertEqual(prepared.kind, .image)
        XCTAssertEqual(prepared.size, 3)
        XCTAssertEqual(prepared.hashAlgorithm, MediaUploadPreparer.sha256HashAlgorithm)
        XCTAssertEqual(
            prepared.hashValue,
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
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
