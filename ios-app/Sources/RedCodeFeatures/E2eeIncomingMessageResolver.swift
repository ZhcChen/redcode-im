import Foundation
import RedCodeCore
import RedCodeNetworking

public struct E2eeIncomingMessageResolverError: Error, Equatable, LocalizedError, Sendable {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? { message }
}

public protocol E2eeIncomingMessageDecrypting: Sendable {
    func decryptIncoming(
        accountID: String,
        deviceLabel: String,
        input: E2eeIncomingMessage,
        token: String
    ) async throws -> E2eeDecryptedMessage
}

extension E2eeDirectMessageCoordinator: E2eeIncomingMessageDecrypting {}

@MainActor
public protocol E2eeSessionStatusProviding: AnyObject {
    var status: E2eeSessionStatus { get }
}

extension E2eeSessionLifecycle: E2eeSessionStatusProviding {}

@MainActor
public protocol IncomingChatMessageResolving: AnyObject {
    func resolve(
        _ message: ChatMessage,
        source: E2eeMessageSource,
        accountID: String,
        token: String,
        cachedMessage: ChatMessage?
    ) async throws -> ChatMessage

    func rememberResolved(_ message: ChatMessage, accountID: String)
}

@MainActor
public final class PlaintextIncomingMessageResolver: IncomingChatMessageResolving {
    public init() {}

    public func resolve(
        _ message: ChatMessage,
        source: E2eeMessageSource,
        accountID: String,
        token: String,
        cachedMessage: ChatMessage?
    ) async throws -> ChatMessage {
        message
    }

    public func rememberResolved(_ message: ChatMessage, accountID: String) {}
}

@MainActor
public final class E2eeIncomingMessageResolver: IncomingChatMessageResolving {
    private let sessionStatus: any E2eeSessionStatusProviding
    private let decryptor: any E2eeIncomingMessageDecrypting
    private let deviceLabel: String
    private var resolvedMessages: [String: ChatMessage] = [:]
    private var resolvedMessageOrder: [String] = []

    public init(
        sessionStatus: any E2eeSessionStatusProviding,
        decryptor: any E2eeIncomingMessageDecrypting,
        deviceLabel: String
    ) {
        self.sessionStatus = sessionStatus
        self.decryptor = decryptor
        self.deviceLabel = deviceLabel
    }

    public func resolve(
        _ message: ChatMessage,
        source: E2eeMessageSource,
        accountID: String,
        token: String,
        cachedMessage: ChatMessage? = nil
    ) async throws -> ChatMessage {
        if message.isDeleted { return message }

        let encryptedContent = message.encryptedContent
        let metadata = message.encryptionMetadata
        if encryptedContent == nil, metadata == nil { return message }
        guard let encryptedContent, !encryptedContent.isEmpty, let metadata else {
            throw E2eeIncomingMessageResolverError("E2EE 消息密文与 metadata 不完整")
        }
        guard metadata.protocolName == "mls",
              metadata.version == 1,
              metadata.epoch > 0,
              !metadata.senderDeviceID.isEmpty,
              metadata.contentType == "application" else {
            throw E2eeIncomingMessageResolverError("E2EE 消息 metadata 无效")
        }

        try validateSession(accountID: accountID)

        if let cachedMessage,
           cachedMessage.id == message.id,
           isReusableResolvedMessage(cachedMessage) {
            let resolved = message.replacingDecryptedContent(
                cachedMessage.content,
                parts: cachedMessage.parts
            )
            rememberResolved(resolved, accountID: accountID)
            return resolved
        }

        let key = cacheKey(accountID: accountID, messageID: message.id)
        if let cached = resolvedMessages[key], isReusableResolvedMessage(cached) {
            return message.replacingDecryptedContent(cached.content, parts: cached.parts)
        }

        guard let ciphertext = Data(base64Encoded: encryptedContent), !ciphertext.isEmpty else {
            throw E2eeIncomingMessageResolverError("E2EE 消息密文 Base64 无效")
        }

        let decrypted: E2eeDecryptedMessage
        do {
            decrypted = try await decryptor.decryptIncoming(
                accountID: accountID,
                deviceLabel: deviceLabel,
                input: E2eeIncomingMessage(
                    messageID: message.id,
                    roomID: message.roomID,
                    ciphertext: ciphertext,
                    source: source
                ),
                token: token
            )
        } catch {
            throw E2eeIncomingMessageResolverError("E2EE 消息解密失败")
        }

        guard decrypted.messageID == message.id,
              decrypted.roomID == message.roomID,
              decrypted.epoch == metadata.epoch,
              decrypted.encrypted else {
            throw E2eeIncomingMessageResolverError("E2EE 解密结果与消息不匹配")
        }

        let parts = decrypted.attachmentParts.map { part in
            ChatMessagePart(
                position: Int(part.partPosition),
                partType: messageType(for: part.mimeType),
                attachment: ChatMessageAttachment(
                    key: part.objectKey,
                    name: part.name,
                    mimeType: part.mimeType,
                    size: part.size
                )
            )
        }
        let resolved = message.replacingDecryptedContent(decrypted.text, parts: parts)
        rememberResolved(resolved, accountID: accountID)
        return resolved
    }

    public func rememberResolved(_ message: ChatMessage, accountID: String) {
        let key = cacheKey(accountID: accountID, messageID: message.id)
        if resolvedMessages[key] == nil {
            resolvedMessageOrder.append(key)
        }
        resolvedMessages[key] = message
        while resolvedMessageOrder.count > 2_000 {
            let oldest = resolvedMessageOrder.removeFirst()
            resolvedMessages.removeValue(forKey: oldest)
        }
    }

    private func validateSession(accountID: String) throws {
        switch sessionStatus.status {
        case .plaintext:
            return
        case .ready(let activeAccountID, _):
            guard activeAccountID == accountID else {
                throw E2eeIncomingMessageResolverError("E2EE 消息账号与当前会话不匹配")
            }
        case .blocked(let message):
            throw E2eeIncomingMessageResolverError(message)
        case .signedOut:
            throw E2eeIncomingMessageResolverError("E2EE 会话未登录")
        }
    }

    private func cacheKey(accountID: String, messageID: String) -> String {
        "\(accountID):\(messageID)"
    }

    private func isReusableResolvedMessage(_ message: ChatMessage) -> Bool {
        !message.content.isEmpty || !message.parts.isEmpty
    }

    private func messageType(for mimeType: String) -> ChatMessageType {
        if mimeType.hasPrefix("image/") { return .image }
        if mimeType.hasPrefix("video/") { return .video }
        if mimeType.hasPrefix("audio/") { return .audio }
        return .file
    }
}

private extension ChatMessage {
    func replacingDecryptedContent(_ content: String, parts: [ChatMessagePart]) -> ChatMessage {
        ChatMessage(
            id: id,
            roomID: roomID,
            senderID: senderID,
            senderName: senderName,
            content: content,
            encryptedContent: encryptedContent,
            encryptionMetadata: encryptionMetadata,
            messageType: messageType,
            status: status,
            timestamp: timestamp,
            isDeleted: isDeleted,
            isPinned: isPinned,
            pinnedAt: pinnedAt,
            pinnedBy: pinnedBy,
            quotedMessage: quotedMessage,
            parts: parts,
            attachments: parts.compactMap(\.attachment),
            reactions: reactions
        )
    }
}
