import XCTest
@testable import RedCodeFeatures
@testable import RedCodeNetworking
@testable import RedCodeStorage

@MainActor
final class ChatDetailControllerTests: XCTestCase {
    func testEnterRoomMergesCachedAndRemoteMessagesAndMarksLatestIncomingRead() async throws {
        let cache = SwiftDataMessageCacheStore(
            container: try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        )
        try cache.saveMessages(roomID: "r1", messages: [
            RedCodeMessageDraft(
                id: "cached",
                roomID: "r1",
                senderID: "u1",
                senderName: "Me",
                content: "cached",
                timestamp: Date(timeIntervalSince1970: 100)
            ),
        ])
        let api = MockChatDetailAPIService(messages: [
            ChatMessage(
                id: "remote",
                roomID: "r1",
                senderID: "u2",
                senderName: "Alice",
                content: "remote",
                timestamp: Date(timeIntervalSince1970: 200)
            ),
        ])
        let controller = ChatDetailController(api: api, messageCacheStore: cache)

        try await controller.enterRoom(roomID: "r1", token: "access-token", currentUserID: "u1")

        XCTAssertEqual(controller.messages.map(\.id), ["cached", "remote"])
        XCTAssertEqual(try cache.loadMessages(roomID: "r1").map(\.id), ["cached", "remote"])
        XCTAssertFalse(controller.isLoading)
        XCTAssertNil(controller.errorMessage)
        let calls = await api.calls
        XCTAssertEqual(calls, [
            .loadMessages(roomID: "r1", token: "access-token", limit: 50),
            .markRead(roomID: "r1", messageID: "remote", token: "access-token"),
        ])
    }

    func testSendTextReplacesPendingMessageWithServerMessage() async throws {
        let cache = SwiftDataMessageCacheStore(
            container: try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        )
        let api = MockChatDetailAPIService(sendOutcomes: [
            .success(
                ChatMessage(
                    id: "server",
                    roomID: "r1",
                    senderID: "u1",
                    senderName: "Me",
                    content: "hello",
                    timestamp: Date(timeIntervalSince1970: 200)
                )
            ),
        ])
        let controller = ChatDetailController(api: api, messageCacheStore: cache)
        try await controller.enterRoom(roomID: "r1", token: "access-token", currentUserID: "u1")

        let sent = try await controller.sendText(
            " hello ",
            token: "access-token",
            currentUserID: "u1",
            currentUserName: "Me"
        )

        XCTAssertEqual(sent?.id, "server")
        XCTAssertEqual(controller.messages.map(\.id), ["server"])
        XCTAssertEqual(controller.messages.first?.status, .sent)
        XCTAssertEqual(try cache.loadMessages(roomID: "r1").map(\.id), ["server"])
        let calls = await api.calls
        XCTAssertTrue(calls.contains(.sendText(roomID: "r1", content: "hello", quotedMessageID: nil, token: "access-token")))
    }

    func testSendFailureKeepsFailedPendingMessageAndResendReplacesIt() async throws {
        let cache = SwiftDataMessageCacheStore(
            container: try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        )
        let api = MockChatDetailAPIService(sendOutcomes: [
            .failure,
            .success(
                ChatMessage(
                    id: "server",
                    roomID: "r1",
                    senderID: "u1",
                    senderName: "Me",
                    content: "retry me",
                    timestamp: Date(timeIntervalSince1970: 300)
                )
            ),
        ])
        let controller = ChatDetailController(api: api, messageCacheStore: cache)
        try await controller.enterRoom(roomID: "r1", token: "access-token", currentUserID: "u1")

        do {
            _ = try await controller.sendText(
                "retry me",
                token: "access-token",
                currentUserID: "u1",
                currentUserName: "Me"
            )
            XCTFail("Expected send failure")
        } catch ChatDetailFailure.sendFailed {
            // expected
        }

        let failed = try XCTUnwrap(controller.messages.first)
        XCTAssertTrue(failed.id.hasPrefix("local-"))
        XCTAssertEqual(failed.status, .failed)
        XCTAssertNotNil(controller.errorMessage)

        let resent = try await controller.resendMessage(messageID: failed.id, token: "access-token")

        XCTAssertEqual(resent?.id, "server")
        XCTAssertEqual(controller.messages.map(\.id), ["server"])
        XCTAssertEqual(controller.messages.first?.status, .sent)
    }
}

private enum ChatDetailCall: Equatable, Sendable {
    case loadMessages(roomID: String, token: String, limit: Int)
    case sendText(roomID: String, content: String, quotedMessageID: String?, token: String)
    case markRead(roomID: String, messageID: String, token: String)
}

private enum ChatDetailFailure: Error, Sendable {
    case sendFailed
}

private enum SendOutcome: Sendable {
    case success(ChatMessage)
    case failure
}

private actor MockChatDetailAPIService: ChatAPIService {
    private(set) var calls: [ChatDetailCall] = []

    private let messages: [ChatMessage]
    private var sendOutcomes: [SendOutcome]

    init(messages: [ChatMessage] = [], sendOutcomes: [SendOutcome] = []) {
        self.messages = messages
        self.sendOutcomes = sendOutcomes
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
        calls.append(.loadMessages(roomID: roomID, token: token, limit: limit))
        return messages
    }

    func sendTextMessage(
        roomID: String,
        content: String,
        quotedMessageID: String?,
        token: String
    ) async throws -> ChatMessage {
        calls.append(.sendText(roomID: roomID, content: content, quotedMessageID: quotedMessageID, token: token))
        let outcome = sendOutcomes.isEmpty ? .failure : sendOutcomes.removeFirst()
        switch outcome {
        case .success(let message):
            return message
        case .failure:
            throw ChatDetailFailure.sendFailed
        }
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
}
