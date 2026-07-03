import XCTest
@testable import RedCodeFeatures
@testable import RedCodeNetworking
@testable import RedCodeStorage

@MainActor
final class ChatRealtimeControllerTests: XCTestCase {
    func testMessageEventUpdatesChatListAndMessageCache() async throws {
        let container = try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        let chatCache = SwiftDataChatSummaryCacheStore(container: container)
        let messageCache = SwiftDataMessageCacheStore(container: container)
        let listController = ChatListController(api: RealtimeMockChatAPIService(), cacheStore: chatCache)
        try listController.upsertChatSummary(
            ChatSummary(roomID: "r1", displayName: "Alice", roomType: .privateChat)
        )
        let webSocket = MockChatWebSocketService()
        let realtimeController = ChatRealtimeController(
            webSocket: webSocket,
            listController: listController,
            messageCacheStore: messageCache
        )

        await realtimeController.start(token: "access-token", currentUserID: "u1")
        await webSocket.emit(messageEvent(messageID: "m1", senderID: "u2", content: "hello"))

        try await waitUntil {
            listController.chats.first?.lastMessageID == "m1"
        }

        let chat = try XCTUnwrap(listController.chats.first)
        XCTAssertEqual(chat.lastMessagePreview, "hello")
        XCTAssertEqual(chat.unreadCount, 1)
        XCTAssertEqual(try messageCache.loadMessages(roomID: "r1").map(\.id), ["m1"])
        let calls = await webSocket.recordedCalls()
        XCTAssertTrue(calls.contains(.connect(token: "access-token")))
        XCTAssertTrue(calls.contains(.ensureRooms(roomIDs: ["r1"], pruneMissing: true)))
    }

    func testActiveDetailReceivesMessageAndMarksIncomingRead() async throws {
        let container = try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        let chatCache = SwiftDataChatSummaryCacheStore(container: container)
        let messageCache = SwiftDataMessageCacheStore(container: container)
        let listController = ChatListController(api: RealtimeMockChatAPIService(), cacheStore: chatCache)
        try listController.upsertChatSummary(
            ChatSummary(roomID: "r1", displayName: "Alice", roomType: .privateChat)
        )
        let detailAPI = RealtimeMockChatAPIService()
        let detailController = ChatDetailController(api: detailAPI, messageCacheStore: messageCache)
        try await detailController.enterRoom(roomID: "r1", token: "access-token", currentUserID: "u1")
        let webSocket = MockChatWebSocketService()
        let realtimeController = ChatRealtimeController(
            webSocket: webSocket,
            listController: listController,
            messageCacheStore: messageCache
        )

        await realtimeController.start(token: "access-token", currentUserID: "u1")
        await realtimeController.attachDetailController(detailController, roomID: "r1")
        await webSocket.emit(messageEvent(messageID: "m1", senderID: "u2", content: "hello"))

        try await waitUntil {
            detailController.messages.map(\.id) == ["m1"]
                && listController.chats.first?.unreadCount == 0
        }

        let calls = await detailAPI.recordedCalls()
        XCTAssertTrue(calls.contains(.markRead(roomID: "r1", messageID: "m1", token: "access-token")))
    }

    func testReadAndPinEventsUpdateActiveDetailAndCache() async throws {
        let container = try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        let chatCache = SwiftDataChatSummaryCacheStore(container: container)
        let messageCache = SwiftDataMessageCacheStore(container: container)
        try messageCache.saveMessages(roomID: "r1", messages: [
            RedCodeMessageDraft(
                id: "m1",
                roomID: "r1",
                senderID: "u1",
                senderName: "Me",
                content: "mine",
                timestamp: Date(timeIntervalSince1970: 100)
            ),
            RedCodeMessageDraft(
                id: "m2",
                roomID: "r1",
                senderID: "u2",
                senderName: "Alice",
                content: "theirs",
                timestamp: Date(timeIntervalSince1970: 200)
            ),
        ])
        let listController = ChatListController(api: RealtimeMockChatAPIService(), cacheStore: chatCache)
        try listController.upsertChatSummary(
            ChatSummary(roomID: "r1", displayName: "Alice", roomType: .privateChat)
        )
        let detailController = ChatDetailController(
            api: RealtimeMockChatAPIService(),
            messageCacheStore: messageCache
        )
        try await detailController.enterRoom(roomID: "r1", token: "access-token", currentUserID: "u1")
        let webSocket = MockChatWebSocketService()
        let realtimeController = ChatRealtimeController(
            webSocket: webSocket,
            listController: listController,
            messageCacheStore: messageCache
        )

        await realtimeController.start(token: "access-token", currentUserID: "u1")
        await realtimeController.attachDetailController(detailController, roomID: "r1")
        await webSocket.emit(WebSocketServerEvent(
            type: "message_read",
            fields: [
                "room_id": .string("r1"),
                "message_id": .string("m1"),
                "reader_id": .string("u2"),
            ]
        ))
        await webSocket.emit(WebSocketServerEvent(
            type: "pin_update",
            fields: [
                "room_id": .string("r1"),
                "message_id": .string("m2"),
                "is_pinned": .bool(true),
                "pinned_by": .string("u2"),
                "pinned_at": .string("2026-07-03T12:00:00Z"),
            ]
        ))

        try await waitUntil {
            detailController.messages.first(where: { $0.id == "m1" })?.status == .read
                && detailController.messages.first(where: { $0.id == "m2" })?.isPinned == true
        }

        let cached = try messageCache.loadMessages(roomID: "r1")
        XCTAssertEqual(cached.first(where: { $0.id == "m1" })?.status, "read")
        XCTAssertEqual(cached.first(where: { $0.id == "m2" })?.isPinned, true)
    }

    func testReactionUpdateRefreshesActiveDetailReactions() async throws {
        let container = try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        let chatCache = SwiftDataChatSummaryCacheStore(container: container)
        let messageCache = SwiftDataMessageCacheStore(container: container)
        let listController = ChatListController(api: RealtimeMockChatAPIService(), cacheStore: chatCache)
        let detailAPI = RealtimeMockChatAPIService(
            fetchedReactionSummaries: [
                MessageReactionSummary(reactionKey: "👍", count: 2, hasSelf: true),
            ]
        )
        let detailController = ChatDetailController(api: detailAPI, messageCacheStore: messageCache)
        try await detailController.enterRoom(roomID: "r1", token: "access-token", currentUserID: "u1")
        try detailController.applyIncomingMessage(
            ChatMessage(
                id: "m1",
                roomID: "r1",
                senderID: "u2",
                senderName: "Alice",
                content: "hello",
                timestamp: Date(timeIntervalSince1970: 100)
            )
        )
        let webSocket = MockChatWebSocketService()
        let realtimeController = ChatRealtimeController(
            webSocket: webSocket,
            listController: listController,
            messageCacheStore: messageCache
        )

        await realtimeController.start(token: "access-token", currentUserID: "u1")
        await realtimeController.attachDetailController(detailController, roomID: "r1")
        await webSocket.emit(WebSocketServerEvent(
            type: "reaction_update",
            fields: [
                "room_id": .string("r1"),
                "message_id": .string("m1"),
                "reaction_key": .string("👍"),
                "user_id": .string("u2"),
                "action": .string("add"),
            ]
        ))

        try await waitUntil {
            detailController.messages.first?.reactions.first?.count == 2
        }

        let calls = await detailAPI.recordedCalls()
        XCTAssertTrue(calls.contains(.fetchReactions(roomID: "r1", messageID: "m1", token: "access-token")))
    }
}

private enum RealtimeWebSocketCall: Equatable, Sendable {
    case connect(token: String?)
    case disconnect
    case ensureRooms(roomIDs: [String], pruneMissing: Bool)
}

private actor MockChatWebSocketService: ChatWebSocketService {
    private var calls: [RealtimeWebSocketCall] = []
    private var status: WebSocketConnectionStatus = .disconnected
    private let stream: AsyncStream<WebSocketServerEvent>
    private let continuation: AsyncStream<WebSocketServerEvent>.Continuation

    init() {
        var continuation: AsyncStream<WebSocketServerEvent>.Continuation!
        self.stream = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    func connect(accessToken: String?) async throws {
        calls.append(.connect(token: accessToken))
        status = .authenticated
    }

    func disconnect() async {
        calls.append(.disconnect)
        status = .disconnected
    }

    func ensureRoomsSubscribed(_ roomIDs: [String], pruneMissing: Bool) async {
        calls.append(.ensureRooms(roomIDs: roomIDs, pruneMissing: pruneMissing))
    }

    func eventStream() async -> AsyncStream<WebSocketServerEvent> {
        stream
    }

    func snapshot() async -> WebSocketClientSnapshot {
        WebSocketClientSnapshot(
            status: status,
            connectionID: nil,
            lastError: "",
            desiredRooms: [],
            subscribedRooms: [],
            pendingRooms: [],
            reconnectAttempts: 0
        )
    }

    func emit(_ event: WebSocketServerEvent) {
        continuation.yield(event)
    }

    func recordedCalls() -> [RealtimeWebSocketCall] {
        calls
    }
}

private enum RealtimeChatCall: Equatable, Sendable {
    case fetchChats(token: String)
    case markRead(roomID: String, messageID: String, token: String)
    case fetchReactions(roomID: String, messageID: String, token: String)
}

private actor RealtimeMockChatAPIService: ChatAPIService {
    private var calls: [RealtimeChatCall] = []
    private let fetchedReactionSummaries: [MessageReactionSummary]

    init(fetchedReactionSummaries: [MessageReactionSummary] = []) {
        self.fetchedReactionSummaries = fetchedReactionSummaries
    }

    func fetchChats(token: String) async throws -> [ChatSummary] {
        calls.append(.fetchChats(token: token))
        return []
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

    func markMessagesAsRead(roomID: String, messageID: String, token: String) async throws {
        calls.append(.markRead(roomID: roomID, messageID: messageID, token: token))
    }

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
        calls.append(.fetchReactions(roomID: roomID, messageID: messageID, token: token))
        return fetchedReactionSummaries
    }

    func recordedCalls() -> [RealtimeChatCall] {
        calls
    }
}

private func messageEvent(messageID: String, senderID: String, content: String) -> WebSocketServerEvent {
    WebSocketServerEvent(
        type: "message",
        fields: [
            "message_id": .string(messageID),
            "room_id": .string("r1"),
            "sender_id": .string(senderID),
            "sender_username": .string(senderID),
            "content": .string(content),
            "message_type": .string("text"),
            "timestamp": .string("2026-07-03T12:00:00Z"),
        ]
    )
}

private func waitUntil(
    timeout: TimeInterval = 2,
    predicate: @MainActor () async throws -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if try await predicate() {
            return
        }
        try await Task.sleep(nanoseconds: 50_000_000)
    }
    XCTFail("Condition was not met before timeout")
}
