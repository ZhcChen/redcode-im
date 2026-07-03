import XCTest
@testable import RedCodeFeatures
@testable import RedCodeNetworking
@testable import RedCodeStorage

@MainActor
final class ChatListControllerTests: XCTestCase {
    func testRefreshChatsUsesRemoteResultsAndPersistsCache() async throws {
        let cache = SwiftDataChatSummaryCacheStore(
            container: try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        )
        try cache.saveChats([
            RedCodeChatSummaryDraft(roomID: "cached", roomType: "private", displayName: "Cached")
        ])
        let api = MockChatAPIService(chats: [
            ChatSummary(
                roomID: "remote",
                displayName: "Remote",
                roomType: .group,
                lastMessageID: "m1",
                lastMessagePreview: "hello",
                lastMessageAt: Date(timeIntervalSince1970: 200)
            ),
        ])
        let controller = ChatListController(api: api, cacheStore: cache)

        try await controller.refreshChats(token: "access-token")

        XCTAssertEqual(controller.chats.map(\.roomID), ["remote"])
        XCTAssertEqual(try cache.loadChats().map(\.roomID), ["remote"])
        XCTAssertFalse(controller.isLoading)
        XCTAssertNil(controller.errorMessage)
        let calls = await api.calls
        XCTAssertEqual(calls, [.fetchChats(token: "access-token")])
    }

    func testIncomingMessageUpdatesChatPreviewAndUnreadWithoutDoubleCountingDuplicateLatest() throws {
        let cache = SwiftDataChatSummaryCacheStore(
            container: try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        )
        let controller = ChatListController(api: MockChatAPIService(), cacheStore: cache)
        try controller.upsertChatSummary(
            ChatSummary(
                roomID: "r1",
                displayName: "Alice",
                roomType: .privateChat,
                unreadCount: 1,
                lastMessageID: "old",
                lastMessagePreview: "old",
                lastMessageAt: Date(timeIntervalSince1970: 100)
            )
        )

        let incoming = ChatMessage(
            id: "m1",
            roomID: "r1",
            senderID: "u2",
            senderName: "Alice",
            content: "new message",
            timestamp: Date(timeIntervalSince1970: 200)
        )
        try controller.applyIncomingMessage(incoming, currentUserID: "u1")
        try controller.applyIncomingMessage(incoming, currentUserID: "u1")

        let chat = try XCTUnwrap(controller.chats.first)
        XCTAssertEqual(chat.lastMessageID, "m1")
        XCTAssertEqual(chat.lastMessagePreview, "new message")
        XCTAssertEqual(chat.unreadCount, 2)
        XCTAssertEqual(try cache.loadChats().first?.lastMessageID, "m1")

        try controller.applyMessageRead(roomID: "r1", readerID: "u1", currentUserID: "u1")
        XCTAssertEqual(controller.chats.first?.unreadCount, 0)
    }

    func testDeleteChatRollsBackLocalStateWhenAPIRequestFails() async throws {
        let cache = SwiftDataChatSummaryCacheStore(
            container: try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        )
        let api = MockChatAPIService(deleteError: TestFailure.deleteFailed)
        let controller = ChatListController(api: api, cacheStore: cache)
        try controller.upsertChatSummary(
            ChatSummary(roomID: "r1", displayName: "Alice", roomType: .privateChat)
        )

        do {
            try await controller.deleteChat(roomID: "r1", token: "access-token")
            XCTFail("Expected delete failure")
        } catch TestFailure.deleteFailed {
            // expected
        }

        XCTAssertEqual(controller.chats.map(\.roomID), ["r1"])
        XCTAssertEqual(try cache.loadChats().map(\.roomID), ["r1"])
        XCTAssertNotNil(controller.errorMessage)
    }
}

private enum ChatAPICall: Equatable, Sendable {
    case fetchChats(token: String)
    case deleteChat(roomID: String, token: String)
}

private enum TestFailure: Error {
    case deleteFailed
}

private actor MockChatAPIService: ChatAPIService {
    private(set) var calls: [ChatAPICall] = []

    private let chats: [ChatSummary]
    private let deleteError: Error?

    init(chats: [ChatSummary] = [], deleteError: Error? = nil) {
        self.chats = chats
        self.deleteError = deleteError
    }

    func fetchChats(token: String) async throws -> [ChatSummary] {
        calls.append(.fetchChats(token: token))
        return chats
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

    func deleteChat(roomID: String, token: String) async throws {
        calls.append(.deleteChat(roomID: roomID, token: token))
        if let deleteError {
            throw deleteError
        }
    }

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
}
