import XCTest
import RedCodeCore
@testable import RedCodeFeatures
@testable import RedCodeNetworking
@testable import RedCodeStorage

@MainActor
final class ChatDetailControllerTests: XCTestCase {
    func testEncryptedHistoryResolvesBeforePersistingToMessageCache() async throws {
        let cache = GRDBMessageCacheStore(
            database: try RedCodeDatabase.makeDatabase(inMemory: true)
        )
        let envelope = ChatMessage(
            id: "encrypted",
            roomID: "r1",
            senderID: "u2",
            senderName: "Alice",
            content: "",
            encryptedContent: "Y2lwaGVydGV4dA==",
            encryptionMetadata: ChatEncryptionMetadata(
                protocolName: "mls",
                version: 1,
                epoch: 7,
                senderDeviceID: "d2",
                contentType: "application"
            ),
            timestamp: Date(timeIntervalSince1970: 100)
        )
        let resolved = ChatMessage(
            id: "encrypted",
            roomID: "r1",
            senderID: "u2",
            senderName: "Alice",
            content: "decrypted",
            timestamp: Date(timeIntervalSince1970: 100)
        )
        let api = MockChatDetailAPIService(messages: [envelope])
        let resolver = ChatIncomingResolverStub(result: resolved)
        let controller = ChatDetailController(
            api: api,
            messageCacheStore: cache,
            incomingResolver: resolver
        )

        try await controller.enterRoom(
            roomID: "r1",
            token: "access-token",
            currentUserID: "u1",
            peerUserID: "u2"
        )

        XCTAssertEqual(controller.messages.first?.content, "decrypted")
        XCTAssertEqual(try cache.loadMessages(roomID: "r1").first?.content, "decrypted")
        XCTAssertEqual(resolver.sources, [.history])
    }

    func testEncryptedSendBypassesPlaintextAPIAndRemembersResolvedMessage() async throws {
        let cache = GRDBMessageCacheStore(
            database: try RedCodeDatabase.makeDatabase(inMemory: true)
        )
        let api = MockChatDetailAPIService()
        let resolver = ChatIncomingResolverStub()
        let router = ChatOutgoingRouterStub(result: "encrypted-server-id")
        let controller = ChatDetailController(
            api: api,
            messageCacheStore: cache,
            incomingResolver: resolver,
            outgoingTextRouter: router
        )
        try await controller.enterRoom(
            roomID: "r1",
            token: "access-token",
            currentUserID: "u1",
            peerUserID: "u2"
        )

        let sent = try await controller.sendText(
            "secret",
            token: "access-token",
            currentUserID: "u1",
            currentUserName: "Me"
        )

        XCTAssertEqual(sent?.id, "encrypted-server-id")
        XCTAssertEqual(sent?.content, "secret")
        XCTAssertEqual(controller.messages.map(\.id), ["encrypted-server-id"])
        XCTAssertEqual(resolver.rememberedMessages.map(\.id), ["encrypted-server-id"])
        XCTAssertEqual(router.calls.first?.peerUserID, "u2")
        let apiCalls = await api.calls
        XCTAssertFalse(apiCalls.contains { call in
            if case .sendText = call { return true }
            return false
        })
    }

    func testEnterRoomMergesCachedAndRemoteMessagesAndMarksLatestIncomingRead() async throws {
        let cache = GRDBMessageCacheStore(
            database: try RedCodeDatabase.makeDatabase(inMemory: true)
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
        let cache = GRDBMessageCacheStore(
            database: try RedCodeDatabase.makeDatabase(inMemory: true)
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
        let cache = GRDBMessageCacheStore(
            database: try RedCodeDatabase.makeDatabase(inMemory: true)
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

    func testToggleReactionUsesAddOrRemoveAndUpdatesMessage() async throws {
        let cache = GRDBMessageCacheStore(
            database: try RedCodeDatabase.makeDatabase(inMemory: true)
        )
        let api = MockChatDetailAPIService(
            messages: [
                ChatMessage(
                    id: "m1",
                    roomID: "r1",
                    senderID: "u2",
                    senderName: "Alice",
                    content: "hello",
                    timestamp: Date(timeIntervalSince1970: 100)
                ),
            ],
            addReactionSummaries: [
                MessageReactionSummary(reactionKey: "👍", count: 1, hasSelf: true),
            ],
            removeReactionSummaries: []
        )
        let controller = ChatDetailController(api: api, messageCacheStore: cache)
        try await controller.enterRoom(roomID: "r1", token: "access-token", currentUserID: "u1")

        try await controller.toggleReaction(messageID: "m1", reactionKey: "👍", token: "access-token")

        XCTAssertEqual(controller.messages.first?.reactions, [
            MessageReactionSummary(reactionKey: "👍", count: 1, hasSelf: true),
        ])

        try await controller.toggleReaction(messageID: "m1", reactionKey: "👍", token: "access-token")

        XCTAssertEqual(controller.messages.first?.reactions, [])
        let calls = await api.calls
        XCTAssertTrue(calls.contains(.addReaction(roomID: "r1", messageID: "m1", reactionKey: "👍", token: "access-token")))
        XCTAssertTrue(calls.contains(.removeReaction(roomID: "r1", messageID: "m1", reactionKey: "👍", token: "access-token")))
    }

    func testSendPreparedMediaUploadsCommitsAndSendsRichMessage() async throws {
        let cache = GRDBMessageCacheStore(
            database: try RedCodeDatabase.makeDatabase(inMemory: true)
        )
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ios-media-test-\(UUID().uuidString).png")
        try Data("image-bytes".utf8).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let prepared = try MediaUploadPreparer.prepareFile(
            at: tempURL,
            kind: .image,
            fileName: "image.png",
            contentType: "image/png"
        )
        let api = MockChatDetailAPIService(sendOutcomes: [
            .success(
                ChatMessage(
                    id: "server-media",
                    roomID: "r1",
                    senderID: "u1",
                    senderName: "Me",
                    content: "[图片]",
                    messageType: .image,
                    timestamp: Date(timeIntervalSince1970: 300),
                    parts: [
                        ChatMessagePart(
                            position: 0,
                            partType: .image,
                            attachment: ChatMessageAttachment(
                                key: "messages/r1/images_20260704/abc.png",
                                name: "image.png",
                                mimeType: "image/png",
                                size: Int64(Data("image-bytes".utf8).count)
                            )
                        ),
                    ]
                )
            ),
        ])
        let media = MockMediaAPIService()
        let controller = ChatDetailController(
            api: api,
            messageCacheStore: cache,
            mediaAPI: media,
            attachmentCache: AttachmentFileCache(rootURL: FileManager.default.temporaryDirectory)
        )
        try await controller.enterRoom(roomID: "r1", token: "access-token", currentUserID: "u1")

        let sent = try await controller.sendPreparedMedia(
            files: [prepared],
            token: "access-token",
            currentUserID: "u1",
            currentUserName: "Me"
        )

        XCTAssertEqual(sent?.id, "server-media")
        XCTAssertEqual(controller.messages.map(\.id), ["server-media"])
        XCTAssertEqual(controller.messages.first?.attachments.first?.key, "messages/r1/images_20260704/abc.png")
        let calls = await api.calls
        XCTAssertTrue(calls.contains(.sendRich(roomID: "r1", partTypes: [.image], token: "access-token")))
        let mediaCalls = await media.recordedCalls()
        XCTAssertEqual(mediaCalls, [
            .request(roomID: "r1", partType: .image, fileName: "image.png"),
            .upload(contentType: "image/png", byteCount: 11),
            .commit(roomID: "r1", key: "messages/r1/images_20260704/abc.png"),
        ])
    }
}

@MainActor
private final class ChatIncomingResolverStub: IncomingChatMessageResolving {
    let result: ChatMessage?
    private(set) var sources: [E2eeMessageSource] = []
    private(set) var rememberedMessages: [ChatMessage] = []

    init(result: ChatMessage? = nil) {
        self.result = result
    }

    func resolve(
        _ message: ChatMessage,
        source: E2eeMessageSource,
        accountID: String,
        token: String,
        cachedMessage: ChatMessage?
    ) async throws -> ChatMessage {
        sources.append(source)
        return result ?? message
    }

    func rememberResolved(_ message: ChatMessage, accountID: String) {
        rememberedMessages.append(message)
    }
}

private struct ChatOutgoingRouterCall: Equatable {
    let roomID: String
    let peerUserID: String?
    let retry: Bool
}

@MainActor
private final class ChatOutgoingRouterStub: OutgoingTextMessageRouting {
    let result: String?
    private(set) var calls: [ChatOutgoingRouterCall] = []

    init(result: String?) {
        self.result = result
    }

    func send(
        roomID: String,
        peerUserID: String?,
        text: String,
        retry: Bool,
        quotedMessageID: String?,
        accountID: String,
        token: String
    ) async throws -> String? {
        calls.append(ChatOutgoingRouterCall(roomID: roomID, peerUserID: peerUserID, retry: retry))
        return result
    }
}

private enum ChatDetailCall: Equatable, Sendable {
    case loadMessages(roomID: String, token: String, limit: Int)
    case sendText(roomID: String, content: String, quotedMessageID: String?, token: String)
    case markRead(roomID: String, messageID: String, token: String)
    case addReaction(roomID: String, messageID: String, reactionKey: String, token: String)
    case removeReaction(roomID: String, messageID: String, reactionKey: String, token: String)
    case fetchReactions(roomID: String, messageID: String, token: String)
    case sendRich(roomID: String, partTypes: [ChatMessageType], token: String)
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
    private let addReactionSummaries: [MessageReactionSummary]
    private let removeReactionSummaries: [MessageReactionSummary]
    private let fetchedReactionSummaries: [MessageReactionSummary]

    init(
        messages: [ChatMessage] = [],
        sendOutcomes: [SendOutcome] = [],
        addReactionSummaries: [MessageReactionSummary] = [],
        removeReactionSummaries: [MessageReactionSummary] = [],
        fetchedReactionSummaries: [MessageReactionSummary] = []
    ) {
        self.messages = messages
        self.sendOutcomes = sendOutcomes
        self.addReactionSummaries = addReactionSummaries
        self.removeReactionSummaries = removeReactionSummaries
        self.fetchedReactionSummaries = fetchedReactionSummaries
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

    func sendRichMessage(
        roomID: String,
        content: String?,
        parts: [OutgoingMessagePart],
        quotedMessageID: String?,
        token: String
    ) async throws -> ChatMessage {
        calls.append(.sendRich(roomID: roomID, partTypes: parts.map(\.type), token: token))
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

    func addMessageReaction(
        roomID: String,
        messageID: String,
        reactionKey: String,
        token: String
    ) async throws -> [MessageReactionSummary] {
        calls.append(.addReaction(roomID: roomID, messageID: messageID, reactionKey: reactionKey, token: token))
        return addReactionSummaries
    }

    func removeMessageReaction(
        roomID: String,
        messageID: String,
        reactionKey: String,
        token: String
    ) async throws -> [MessageReactionSummary] {
        calls.append(.removeReaction(roomID: roomID, messageID: messageID, reactionKey: reactionKey, token: token))
        return removeReactionSummaries
    }

    func fetchMessageReactions(roomID: String, messageID: String, token: String) async throws -> [MessageReactionSummary] {
        calls.append(.fetchReactions(roomID: roomID, messageID: messageID, token: token))
        return fetchedReactionSummaries
    }
}

private enum MediaCall: Equatable, Sendable {
    case request(roomID: String, partType: MediaPartType, fileName: String)
    case upload(contentType: String?, byteCount: Int)
    case commit(roomID: String, key: String)
}

private actor MockMediaAPIService: MediaAPIService {
    private(set) var calls: [MediaCall] = []

    func recordedCalls() -> [MediaCall] {
        calls
    }

    func requestUserAvatarUpload(metadata: MediaUploadMetadata, token: String) async throws -> DirectUploadDescriptor {
        DirectUploadDescriptor(key: "avatars/u1.png", signature: nil)
    }

    func commitUserAvatarUpload(key: String, token: String) async throws -> MediaCommitResult {
        MediaCommitResult(success: true, message: "ok", avatarURL: nil)
    }

    func userAvatarDownloadURL(userID: String?, token: String, expiresInSeconds: Int) async throws -> URL? {
        nil
    }

    func requestRoomAvatarUpload(roomID: String, metadata: MediaUploadMetadata, token: String) async throws -> DirectUploadDescriptor {
        DirectUploadDescriptor(key: "room_avatars/\(roomID)/avatar.png", signature: nil)
    }

    func commitRoomAvatarUpload(roomID: String, key: String, token: String) async throws -> MediaCommitResult {
        MediaCommitResult(success: true, message: "ok", avatarURL: nil)
    }

    func roomAvatarDownloadURL(roomID: String, token: String, expiresInSeconds: Int) async throws -> URL? {
        nil
    }

    func requestMessageAttachmentUpload(
        roomID: String,
        partType: MediaPartType,
        metadata: MediaUploadMetadata,
        token: String
    ) async throws -> DirectUploadDescriptor {
        calls.append(.request(roomID: roomID, partType: partType, fileName: metadata.fileName))
        return DirectUploadDescriptor(
            key: "messages/r1/images_20260704/abc.png",
            signature: DirectUploadSignature(
                url: URL(string: "http://storage.local/mock-bucket/messages/r1/images_20260704/abc.png")!,
                method: .put,
                headers: [:],
                key: "messages/r1/images_20260704/abc.png"
            )
        )
    }

    func commitMessageAttachmentUpload(
        roomID: String,
        key: String,
        metadata: MediaUploadMetadata,
        token: String
    ) async throws {
        calls.append(.commit(roomID: roomID, key: key))
    }

    func messageAttachmentDownloadURL(
        roomID: String,
        key: String,
        token: String,
        expiresInSeconds: Int
    ) async throws -> URL? {
        URL(string: "http://storage.local/mock-bucket/\(key)")
    }

    func upload(data: Data, using signature: DirectUploadSignature, defaultContentType: String?) async throws {
        calls.append(.upload(contentType: defaultContentType, byteCount: data.count))
    }

    func download(from url: URL) async throws -> Data {
        Data()
    }
}
