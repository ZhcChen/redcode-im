import XCTest
@testable import RedCodeFeatures
@testable import RedCodeNetworking
@testable import RedCodeStorage

@MainActor
final class ChatExtensionControllerTests: XCTestCase {
    func testEmojiStickerControllerLoadsSearchesAddsAndRemovesPacks() async throws {
        let api = MockEmojiAPIService(
            myPacks: [
                EmojiPack(id: "mine", name: "Mine", items: [
                    EmojiItem(id: "item-1", packID: "mine", imageURL: "", imageObjectKey: "emoji-items/one.gif"),
                ]),
            ],
            availablePacks: [
                EmojiPack(id: "available", name: "Available"),
                EmojiPack(id: "suite", name: "Suite", packType: .suite),
            ],
            searchResults: [
                EmojiPack(id: "search", name: "Search Result"),
            ]
        )
        let controller = EmojiStickerController(api: api, emojiCache: EmojiFileCache())

        await controller.load(token: "access-token")
        await controller.search(keyword: " smile ", token: "access-token")
        await controller.add(pack: EmojiPack(id: "available", name: "Available"), token: "access-token")
        await controller.add(pack: EmojiPack(id: "suite", name: "Suite", packType: .suite), token: "access-token")
        await controller.remove(pack: EmojiPack(id: "mine", name: "Mine"), token: "access-token")

        XCTAssertEqual(controller.availablePacks.map(\.id), ["available", "suite"])
        XCTAssertEqual(controller.searchResults.map(\.id), ["search"])
        XCTAssertFalse(controller.myPacks.contains { $0.id == "mine" })
        XCTAssertNil(controller.errorMessage)
        let calls = await api.recordedCalls()
        XCTAssertTrue(calls.contains(.fetchMy(token: "access-token")))
        XCTAssertTrue(calls.contains(.fetchAvailable(token: "access-token")))
        XCTAssertTrue(calls.contains(.search(keyword: "smile", token: "access-token")))
        XCTAssertTrue(calls.contains(.addPack(packID: "available", token: "access-token")))
        XCTAssertTrue(calls.contains(.addSuite(suiteID: "suite", token: "access-token")))
        XCTAssertTrue(calls.contains(.removePack(packID: "mine", token: "access-token")))
    }

    func testMessageSearchControllerRebuildsLocalIndexAndMergesRemoteResults() async throws {
        let localStore = MockMessageSearchStore(
            searchResponses: [
                LocalMessageSearchResponse(
                    results: [
                        LocalMessageSearchResult(
                            id: "local",
                            roomID: "r1",
                            roomName: "General",
                            senderID: "u1",
                            senderName: "Alice",
                            content: "local redcode",
                            messageType: "text",
                            timestamp: Date(timeIntervalSince1970: 100),
                            relevanceScore: 1,
                            matchedText: "local redcode"
                        ),
                    ],
                    stats: LocalMessageSearchStats(totalResults: 1, searchTimeMilliseconds: 1, query: "redcode"),
                    hasMore: false
                ),
            ]
        )
        let remoteAPI = MockSearchChatAPIService(
            searchResponses: [
                ChatMessageSearchResponse(
                    results: [
                        ChatMessageSearchResult(
                            id: "remote",
                            roomID: "r2",
                            roomName: "Random",
                            senderID: "u2",
                            senderName: "Bob",
                            content: "remote redcode",
                            messageType: .text,
                            timestamp: Date(timeIntervalSince1970: 200),
                            matchedText: "remote redcode",
                            relevanceScore: 1
                        ),
                    ],
                    stats: ChatMessageSearchStats(totalResults: 3, searchTimeMilliseconds: 4, query: "redcode"),
                    hasMore: true
                ),
            ]
        )
        let controller = MessageSearchController(localSearchStore: localStore, remoteAPI: remoteAPI)
        let chats = [
            ChatSummary(roomID: "r1", displayName: "General", roomType: .group),
            ChatSummary(roomID: "r2", displayName: "Random", roomType: .group),
        ]

        controller.rebuildIndex(chats: chats)
        await controller.search(query: " redcode ", roomID: nil, messageType: .text, token: "access-token")

        XCTAssertEqual(localStore.rebuiltRoomNames, ["r1": "General", "r2": "Random"])
        XCTAssertEqual(controller.results.map(\.id), ["remote", "local"])
        XCTAssertEqual(controller.results.map(\.source), ["服务端", "本地"])
        XCTAssertEqual(controller.totalResults, 3)
        XCTAssertTrue(controller.hasMore)
        XCTAssertNil(controller.errorMessage)
        let calls = await remoteAPI.recordedSearchCalls()
        XCTAssertEqual(calls, [
            SearchCall(query: "redcode", roomID: nil, messageType: .text, limit: 50, offset: 0, token: "access-token"),
        ])
    }

    func testChatSettingsControllerPersistsBackgroundAndClearsCachesAndHistory() async throws {
        let key = "redcode-ios-chat-settings-tests-\(UUID().uuidString)"
        defer {
            UserDefaults.standard.removeObject(forKey: key)
        }
        let preferences = UserDefaultsChatPreferencesStore(key: key)
        let messageCache = GRDBMessageCacheStore(
            database: try RedCodeDatabase.makeDatabase(inMemory: true)
        )
        try messageCache.saveMessages(roomID: "r1", messages: [
            RedCodeMessageDraft(
                id: "m1",
                roomID: "r1",
                senderID: "u1",
                content: "hello",
                timestamp: Date(timeIntervalSince1970: 100)
            ),
        ])

        let rootURL = try makeTemporaryCacheRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let attachmentCache = AttachmentFileCache(rootURL: rootURL)
        let avatarCache = AvatarFileCache(rootURL: rootURL)
        let emojiCache = EmojiFileCache(rootURL: rootURL)
        _ = try await attachmentCache.save(objectKey: "messages/r1/file.txt", data: Data("a".utf8), mimeType: "text/plain")
        _ = try await avatarCache.saveUserAvatar(userID: "u1", objectKey: "users/u1/avatar.png", data: Data("b".utf8))
        _ = try await emojiCache.save(objectKey: "emoji-items/smile.gif", data: Data("c".utf8))

        let controller = ChatSettingsController(
            preferencesStore: preferences,
            messageCacheStore: messageCache,
            attachmentCache: attachmentCache,
            avatarCache: avatarCache,
            emojiCache: emojiCache
        )

        await controller.load()
        XCTAssertEqual(controller.background, .default)

        await controller.saveBackground(ChatBackgroundPreference(kind: .preset, value: "green"))
        await controller.clearAllCaches()
        await controller.clearChatHistory()

        XCTAssertEqual(controller.background, ChatBackgroundPreference(kind: .preset, value: "green"))
        let clearedAttachment = try await attachmentCache.resolve(objectKey: "messages/r1/file.txt")
        let clearedAvatar = try await avatarCache.resolveUserAvatar(userID: "u1", objectKey: "users/u1/avatar.png")
        let clearedEmoji = try await emojiCache.resolve(objectKey: "emoji-items/smile.gif")
        XCTAssertNil(clearedAttachment)
        XCTAssertNil(clearedAvatar)
        XCTAssertNil(clearedEmoji)
        XCTAssertTrue(try messageCache.loadMessages(roomID: "r1").isEmpty)
        XCTAssertFalse(controller.isWorking)
        XCTAssertNil(controller.errorMessage)
    }

    private func makeTemporaryCacheRoot() throws -> URL {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("redcode-ios-feature-cache-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        return rootURL
    }
}

private enum EmojiCall: Equatable, Sendable {
    case fetchMy(token: String)
    case fetchAvailable(token: String)
    case search(keyword: String, token: String)
    case addPack(packID: String, token: String)
    case removePack(packID: String, token: String)
    case addSuite(suiteID: String, token: String)
    case fetchSuite(suiteID: String, token: String)
    case downloadURL(objectKey: String, token: String, expiresInSeconds: Int)
}

private actor MockEmojiAPIService: EmojiAPIService {
    private var calls: [EmojiCall] = []
    private var myPacks: [EmojiPack]
    private let availablePacks: [EmojiPack]
    private let searchResults: [EmojiPack]

    init(myPacks: [EmojiPack], availablePacks: [EmojiPack], searchResults: [EmojiPack]) {
        self.myPacks = myPacks
        self.availablePacks = availablePacks
        self.searchResults = searchResults
    }

    func recordedCalls() -> [EmojiCall] {
        calls
    }

    func fetchMyPacks(token: String) async throws -> [EmojiPack] {
        calls.append(.fetchMy(token: token))
        return myPacks
    }

    func fetchAvailablePacks(token: String) async throws -> [EmojiPack] {
        calls.append(.fetchAvailable(token: token))
        return availablePacks
    }

    func searchPacks(keyword: String, token: String) async throws -> [EmojiPack] {
        calls.append(.search(keyword: keyword, token: token))
        return searchResults
    }

    func addPack(packID: String, token: String) async throws {
        calls.append(.addPack(packID: packID, token: token))
        if let pack = availablePacks.first(where: { $0.id == packID }) {
            myPacks.append(pack)
        }
    }

    func removePack(packID: String, token: String) async throws {
        calls.append(.removePack(packID: packID, token: token))
        myPacks.removeAll { $0.id == packID }
    }

    func addSuite(suiteID: String, token: String) async throws -> Int {
        calls.append(.addSuite(suiteID: suiteID, token: token))
        return 2
    }

    func fetchSuitePacks(suiteID: String, token: String) async throws -> [EmojiPack] {
        calls.append(.fetchSuite(suiteID: suiteID, token: token))
        return []
    }

    func emojiDownloadURL(objectKey: String, token: String, expiresInSeconds: Int) async throws -> URL? {
        calls.append(.downloadURL(objectKey: objectKey, token: token, expiresInSeconds: expiresInSeconds))
        return URL(string: "http://127.0.0.1:19080/\(objectKey)")
    }
}

@MainActor
private final class MockMessageSearchStore: MessageSearchStore {
    private var searchResponses: [LocalMessageSearchResponse]
    private(set) var rebuiltRoomNames: [String: String] = [:]

    init(searchResponses: [LocalMessageSearchResponse]) {
        self.searchResponses = searchResponses
    }

    func rebuildIndex(roomNamesByID: [String: String]) throws {
        rebuiltRoomNames = roomNamesByID
    }

    func searchMessages(
        query: String,
        roomID: String?,
        messageType: String?,
        limit: Int,
        offset: Int
    ) throws -> LocalMessageSearchResponse {
        searchResponses.isEmpty
            ? LocalMessageSearchResponse(
                results: [],
                stats: LocalMessageSearchStats(totalResults: 0, searchTimeMilliseconds: 0, query: query),
                hasMore: false
            )
            : searchResponses.removeFirst()
    }
}

private struct SearchCall: Equatable, Sendable {
    let query: String
    let roomID: String?
    let messageType: ChatMessageType?
    let limit: Int
    let offset: Int
    let token: String
}

private actor MockSearchChatAPIService: ChatAPIService {
    private var searchCalls: [SearchCall] = []
    private var searchResponses: [ChatMessageSearchResponse]

    init(searchResponses: [ChatMessageSearchResponse]) {
        self.searchResponses = searchResponses
    }

    func recordedSearchCalls() -> [SearchCall] {
        searchCalls
    }

    func fetchChats(token: String) async throws -> [ChatSummary] {
        []
    }

    func loadMessages(
        roomID: String,
        token: String,
        limit: Int,
        beforeID: String?,
        sinceID: String?
    ) async throws -> [ChatMessage] {
        []
    }

    func sendTextMessage(
        roomID: String,
        content: String,
        quotedMessageID: String?,
        token: String
    ) async throws -> ChatMessage {
        ChatMessage(
            id: "sent",
            roomID: roomID,
            senderID: "u1",
            senderName: "Me",
            content: content,
            timestamp: Date(timeIntervalSince1970: 1)
        )
    }

    func markMessagesAsRead(roomID: String, messageID: String, token: String) async throws {}

    func deleteChat(roomID: String, token: String) async throws {}

    func deleteMessage(roomID: String, messageID: String, token: String) async throws -> ChatMessage {
        ChatMessage(
            id: messageID,
            roomID: roomID,
            senderID: "u1",
            senderName: "Me",
            content: "",
            timestamp: Date(timeIntervalSince1970: 1),
            isDeleted: true
        )
    }

    func setMessagePinned(roomID: String, messageID: String, pinned: Bool, token: String) async throws {}

    func addMessageReaction(
        roomID: String,
        messageID: String,
        reactionKey: String,
        token: String
    ) async throws -> [MessageReactionSummary] {
        []
    }

    func removeMessageReaction(
        roomID: String,
        messageID: String,
        reactionKey: String,
        token: String
    ) async throws -> [MessageReactionSummary] {
        []
    }

    func fetchMessageReactions(roomID: String, messageID: String, token: String) async throws -> [MessageReactionSummary] {
        []
    }

    func searchMessages(
        query: String,
        roomID: String?,
        messageType: ChatMessageType?,
        limit: Int,
        offset: Int,
        token: String
    ) async throws -> ChatMessageSearchResponse {
        searchCalls.append(SearchCall(
            query: query,
            roomID: roomID,
            messageType: messageType,
            limit: limit,
            offset: offset,
            token: token
        ))
        return searchResponses.isEmpty
            ? ChatMessageSearchResponse(
                results: [],
                stats: ChatMessageSearchStats(totalResults: 0, searchTimeMilliseconds: 0, query: query),
                hasMore: false
            )
            : searchResponses.removeFirst()
    }
}
