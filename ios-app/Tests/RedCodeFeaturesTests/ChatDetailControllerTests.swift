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
            .commit(roomID: "r1", key: "messages/r1/images_20260704/abc.png", byteCount: 11),
        ])
    }

    func testEncryptedAttachmentUploadsCiphertextAndBypassesRichMessageAPI() async throws {
        let cache = GRDBMessageCacheStore(database: try RedCodeDatabase.makeDatabase(inMemory: true))
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ios-e2ee-media-\(UUID().uuidString).png")
        let plaintext = Data("image-bytes".utf8)
        try plaintext.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        let preparedFile = try MediaUploadPreparer.prepareFile(
            at: tempURL,
            kind: .image,
            fileName: "image.png",
            contentType: "image/png"
        )
        let media = MockMediaAPIService()
        let attachmentRouter = ChatAttachmentRouterStub(
            encryptedData: Data("opaque-ciphertext-and-tag".utf8),
            sendResult: "encrypted-media-id"
        )
        let resolver = ChatIncomingResolverStub()
        let api = MockChatDetailAPIService()
        let controller = ChatDetailController(
            api: api,
            messageCacheStore: cache,
            mediaAPI: media,
            attachmentCache: AttachmentFileCache(rootURL: FileManager.default.temporaryDirectory),
            incomingResolver: resolver,
            attachmentRouter: attachmentRouter
        )
        try await controller.enterRoom(
            roomID: "r1",
            token: "access-token",
            currentUserID: "u1",
            peerUserID: "u2"
        )

        let sent = try await controller.sendPreparedMedia(
            files: [preparedFile],
            token: "access-token",
            currentUserID: "u1",
            currentUserName: "Me"
        )

        XCTAssertEqual(sent?.id, "encrypted-media-id")
        XCTAssertEqual(sent?.attachments.first?.key, "messages/r1/images_20260704/abc.png")
        XCTAssertEqual(resolver.rememberedMessages.map(\.id), ["encrypted-media-id"])
        let uploaded = await media.uploadedData()
        XCTAssertEqual(uploaded, Data("opaque-ciphertext-and-tag".utf8))
        XCTAssertNotEqual(uploaded, plaintext)
        let committed = await media.committedMetadata()
        XCTAssertEqual(committed?.fileSize, Int64(uploaded?.count ?? 0))
        XCTAssertEqual(committed?.hashValue, uploaded.map(MediaUploadPreparer.sha256Hex(data:)))
        let requested = await media.requestedMetadata()
        XCTAssertNil(requested?.hashValue)
        XCTAssertNil(requested?.hashAlgorithm)
        let apiCalls = await api.calls
        XCTAssertFalse(apiCalls.contains { call in
            if case .sendRich = call { return true }
            return false
        })
    }

    func testEncryptedAttachmentDownloadCachesOnlyDecryptedBytes() async throws {
        let cache = GRDBMessageCacheStore(database: try RedCodeDatabase.makeDatabase(inMemory: true))
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ios-e2ee-download-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let ciphertext = Data("ciphertext".utf8)
        let plaintext = Data("decrypted-file".utf8)
        let media = MockMediaAPIService(downloadData: ciphertext)
        let attachmentRouter = ChatAttachmentRouterStub(decryptedData: plaintext)
        let controller = ChatDetailController(
            api: MockChatDetailAPIService(),
            messageCacheStore: cache,
            mediaAPI: media,
            attachmentCache: AttachmentFileCache(rootURL: root),
            attachmentRouter: attachmentRouter
        )
        try await controller.enterRoom(
            roomID: "r1",
            token: "access-token",
            currentUserID: "u1",
            peerUserID: "u2"
        )
        let attachment = ChatMessageAttachment(
            key: "messages/r1/file.enc",
            name: "file.txt",
            mimeType: "text/plain",
            size: Int64(plaintext.count)
        )

        let fileURL = try await controller.resolveAttachmentFile(
            messageID: "m1",
            attachment: attachment,
            token: "access-token"
        )

        let resolvedURL = try XCTUnwrap(fileURL)
        XCTAssertEqual(try Data(contentsOf: resolvedURL), plaintext)
        XCTAssertEqual(attachmentRouter.decryptedCiphertexts, [ciphertext])
    }

    func testEncryptedAttachmentChecksKeyMaterialBeforeReturningCachedFile() async throws {
        let cache = GRDBMessageCacheStore(database: try RedCodeDatabase.makeDatabase(inMemory: true))
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ios-e2ee-cached-download-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let attachmentCache = AttachmentFileCache(rootURL: root)
        let objectKey = "messages/r1/file.enc"
        _ = try await attachmentCache.save(
            objectKey: objectKey,
            data: Data("cached-plaintext".utf8),
            suggestedExtension: "txt",
            mimeType: "text/plain"
        )
        let attachmentRouter = ChatAttachmentRouterStub(missingEncryptedMaterial: true)
        let controller = ChatDetailController(
            api: MockChatDetailAPIService(),
            messageCacheStore: cache,
            mediaAPI: MockMediaAPIService(),
            attachmentCache: attachmentCache,
            attachmentRouter: attachmentRouter
        )
        try await controller.enterRoom(
            roomID: "r1",
            token: "access-token",
            currentUserID: "u1",
            peerUserID: "u2"
        )

        do {
            _ = try await controller.resolveAttachmentFile(
                messageID: "m1",
                attachment: ChatMessageAttachment(
                    key: objectKey,
                    name: "file.txt",
                    mimeType: "text/plain",
                    size: 16
                ),
                token: "access-token"
            )
            XCTFail("Ready 下密钥材料缺失时不得返回缓存文件")
        } catch let error as E2eeDirectMessageError {
            XCTAssertEqual(error.message, "E2EE 附件密钥材料缺失")
        }
    }

    func testEncryptedAttachmentRuntimeChangeAfterSigningDoesNotUpload() async throws {
        let cache = GRDBMessageCacheStore(database: try RedCodeDatabase.makeDatabase(inMemory: true))
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ios-e2ee-runtime-change-\(UUID().uuidString).png")
        try Data("image-bytes".utf8).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        let preparedFile = try MediaUploadPreparer.prepareFile(
            at: tempURL,
            kind: .image,
            fileName: "image.png",
            contentType: "image/png"
        )
        let media = MockMediaAPIService()
        let attachmentRouter = ChatAttachmentRouterStub(encryptionRequiredResults: [true, false])
        let controller = ChatDetailController(
            api: MockChatDetailAPIService(),
            messageCacheStore: cache,
            mediaAPI: media,
            attachmentRouter: attachmentRouter
        )
        try await controller.enterRoom(
            roomID: "r1",
            token: "access-token",
            currentUserID: "u1",
            peerUserID: "u2"
        )

        do {
            _ = try await controller.sendPreparedMedia(
                files: [preparedFile],
                token: "access-token",
                currentUserID: "u1",
                currentUserName: "Me"
            )
            XCTFail("签名等待期间 runtime 变化必须阻断上传")
        } catch let error as E2eeOutgoingMessageError {
            XCTAssertTrue(error.message.contains("runtime 已变化"))
        }
        let mediaCalls = await media.recordedCalls()
        XCTAssertEqual(mediaCalls, [
            .request(roomID: "r1", partType: .image, fileName: "image.png"),
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

@MainActor
private final class ChatAttachmentRouterStub: AttachmentMessageRouting {
    let encryptedData: Data?
    let sendResult: String?
    let decryptedData: Data?
    let missingEncryptedMaterial: Bool
    private var encryptionRequiredResults: [Bool]
    private(set) var decryptedCiphertexts: [Data] = []

    init(
        encryptedData: Data? = nil,
        sendResult: String? = nil,
        decryptedData: Data? = nil,
        missingEncryptedMaterial: Bool = false,
        encryptionRequiredResults: [Bool] = []
    ) {
        self.encryptedData = encryptedData
        self.sendResult = sendResult
        self.decryptedData = decryptedData
        self.missingEncryptedMaterial = missingEncryptedMaterial
        self.encryptionRequiredResults = encryptionRequiredResults
    }

    func encryptionRequired(accountID: String) throws -> Bool {
        if !encryptionRequiredResults.isEmpty {
            return encryptionRequiredResults.removeFirst()
        }
        return encryptedData != nil
    }

    func prepareUpload(
        roomID: String,
        objectKey: String,
        name: String,
        mimeType: String,
        size: Int64,
        partPosition: UInt32,
        plaintext: Data,
        accountID: String
    ) throws -> E2eePreparedAttachment? {
        guard let encryptedData else { return nil }
        return E2eePreparedAttachment(
            ciphertext: encryptedData,
            part: E2eeAttachmentPart(
                partKey: "11111111-1111-1111-1111-111111111111",
                objectKey: objectKey,
                name: name,
                mimeType: mimeType,
                size: size,
                partPosition: partPosition,
                nonce: Data(repeating: 2, count: 12),
                dek: Data(repeating: 3, count: 32)
            )
        )
    }

    func send(
        roomID: String,
        peerUserID: String?,
        parts: [E2eeAttachmentPart],
        text: String?,
        retry: Bool,
        quotedMessageID: String?,
        accountID: String,
        token: String
    ) async throws -> String? { sendResult }

    func decryptDownload(
        roomID: String,
        messageID: String,
        objectKey: String,
        ciphertext: Data,
        accountID: String
    ) async throws -> Data? {
        decryptedCiphertexts.append(ciphertext)
        return decryptedData
    }

    func downloadIsEncrypted(
        messageID: String,
        objectKey: String,
        accountID: String
    ) async throws -> Bool {
        if missingEncryptedMaterial {
            throw E2eeDirectMessageError("E2EE 附件密钥材料缺失")
        }
        return decryptedData != nil
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
    case commit(roomID: String, key: String, byteCount: Int64)
}

private actor MockMediaAPIService: MediaAPIService {
    private(set) var calls: [MediaCall] = []
    private var lastUploadedData: Data?
    private var lastCommittedMetadata: MediaUploadMetadata?
    private var lastRequestedMetadata: MediaUploadMetadata?
    private let downloadData: Data

    init(downloadData: Data = Data()) {
        self.downloadData = downloadData
    }

    func recordedCalls() -> [MediaCall] {
        calls
    }

    func uploadedData() -> Data? { lastUploadedData }
    func committedMetadata() -> MediaUploadMetadata? { lastCommittedMetadata }
    func requestedMetadata() -> MediaUploadMetadata? { lastRequestedMetadata }

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
        lastRequestedMetadata = metadata
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
        lastCommittedMetadata = metadata
        calls.append(.commit(roomID: roomID, key: key, byteCount: metadata.fileSize))
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
        lastUploadedData = data
        calls.append(.upload(contentType: defaultContentType, byteCount: data.count))
    }

    func download(from url: URL) async throws -> Data {
        downloadData
    }
}
