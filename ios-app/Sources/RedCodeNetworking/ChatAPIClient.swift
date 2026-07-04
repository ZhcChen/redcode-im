import Foundation
import RedCodeCore

public protocol ChatAPIService: Sendable {
    func fetchChats(token: String) async throws -> [ChatSummary]
    func loadMessages(
        roomID: String,
        token: String,
        limit: Int,
        beforeID: String?,
        sinceID: String?
    ) async throws -> [ChatMessage]
    func sendTextMessage(
        roomID: String,
        content: String,
        quotedMessageID: String?,
        token: String
    ) async throws -> ChatMessage
    func sendRichMessage(
        roomID: String,
        content: String?,
        parts: [OutgoingMessagePart],
        quotedMessageID: String?,
        token: String
    ) async throws -> ChatMessage
    func markMessagesAsRead(roomID: String, messageID: String, token: String) async throws
    func deleteChat(roomID: String, token: String) async throws
    func deleteMessage(roomID: String, messageID: String, token: String) async throws -> ChatMessage
    func setMessagePinned(roomID: String, messageID: String, pinned: Bool, token: String) async throws
    func addMessageReaction(
        roomID: String,
        messageID: String,
        reactionKey: String,
        token: String
    ) async throws -> [MessageReactionSummary]
    func removeMessageReaction(
        roomID: String,
        messageID: String,
        reactionKey: String,
        token: String
    ) async throws -> [MessageReactionSummary]
    func fetchMessageReactions(roomID: String, messageID: String, token: String) async throws -> [MessageReactionSummary]
}

public extension ChatAPIService {
    func sendRichMessage(
        roomID: String,
        content: String?,
        parts: [OutgoingMessagePart],
        quotedMessageID: String?,
        token: String
    ) async throws -> ChatMessage {
        if parts.isEmpty, let content {
            return try await sendTextMessage(
                roomID: roomID,
                content: content,
                quotedMessageID: quotedMessageID,
                token: token
            )
        }
        throw NetworkFailure(kind: .invalidResponse, message: "当前 ChatAPIService 未实现富媒体消息发送")
    }
}

public struct ChatAPIClient: ChatAPIService {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public init(environment: RedCodeEnvironment) {
        self.apiClient = APIClient(environment: environment)
    }

    public func fetchChats(token: String) async throws -> [ChatSummary] {
        try await apiClient.get(ChatAPIEndpoint.chats, bearerToken: token, as: [ChatSummary].self)
            .sortedForChatList()
    }

    public func loadMessages(
        roomID: String,
        token: String,
        limit: Int = 50,
        beforeID: String? = nil,
        sinceID: String? = nil
    ) async throws -> [ChatMessage] {
        try await apiClient.get(
            ChatAPIEndpoint.messages(
                roomID: roomID,
                limit: limit,
                beforeID: beforeID,
                sinceID: sinceID
            ),
            bearerToken: token,
            as: [ChatMessage].self
        )
        .sorted { $0.timestamp < $1.timestamp }
    }

    public func sendTextMessage(
        roomID: String,
        content: String,
        quotedMessageID: String? = nil,
        token: String
    ) async throws -> ChatMessage {
        let request = SendTextMessageRequest(content: content, quotedMessageID: quotedMessageID)
        let response = try await apiClient.post(
            ChatAPIEndpoint.sendMessage(roomID: roomID),
            body: request,
            bearerToken: token,
            as: SendMessageResponse.self
        )
        return response.message
    }

    public func sendRichMessage(
        roomID: String,
        content: String? = nil,
        parts: [OutgoingMessagePart],
        quotedMessageID: String? = nil,
        token: String
    ) async throws -> ChatMessage {
        let request = SendRichMessageRequest(
            content: content,
            parts: parts,
            quotedMessageID: quotedMessageID
        )
        let response = try await apiClient.post(
            ChatAPIEndpoint.sendMessage(roomID: roomID),
            body: request,
            bearerToken: token,
            as: SendMessageResponse.self
        )
        return response.message
    }

    public func markMessagesAsRead(roomID: String, messageID: String, token: String) async throws {
        try await apiClient.postNoResponse(
            ChatAPIEndpoint.markMessagesRead(roomID: roomID),
            body: MarkMessageReadRequest(messageID: messageID),
            bearerToken: token
        )
    }

    public func deleteChat(roomID: String, token: String) async throws {
        try await apiClient.deleteNoResponse(
            ChatAPIEndpoint.deleteChat(roomID: roomID),
            bearerToken: token
        )
    }

    public func deleteMessage(roomID: String, messageID: String, token: String) async throws -> ChatMessage {
        try await apiClient.delete(
            ChatAPIEndpoint.deleteMessage(roomID: roomID, messageID: messageID),
            bearerToken: token,
            as: ChatMessage.self
        )
    }

    public func setMessagePinned(
        roomID: String,
        messageID: String,
        pinned: Bool,
        token: String
    ) async throws {
        if pinned {
            try await apiClient.postNoResponse(
                ChatAPIEndpoint.pinMessage(roomID: roomID, messageID: messageID),
                bearerToken: token
            )
        } else {
            try await apiClient.deleteNoResponse(
                ChatAPIEndpoint.unpinMessage(roomID: roomID, messageID: messageID),
                bearerToken: token
            )
        }
    }

    public func addMessageReaction(
        roomID: String,
        messageID: String,
        reactionKey: String,
        token: String
    ) async throws -> [MessageReactionSummary] {
        let response = try await apiClient.post(
            ChatAPIEndpoint.addMessageReaction(roomID: roomID, messageID: messageID),
            body: MessageReactionRequest(reactionKey: reactionKey),
            bearerToken: token,
            as: MessageReactionResponse.self
        )
        return response.summaries
    }

    public func removeMessageReaction(
        roomID: String,
        messageID: String,
        reactionKey: String,
        token: String
    ) async throws -> [MessageReactionSummary] {
        let response = try await apiClient.delete(
            ChatAPIEndpoint.removeMessageReaction(
                roomID: roomID,
                messageID: messageID,
                reactionKey: reactionKey
            ),
            bearerToken: token,
            as: MessageReactionResponse.self
        )
        return response.summaries
    }

    public func fetchMessageReactions(
        roomID: String,
        messageID: String,
        token: String
    ) async throws -> [MessageReactionSummary] {
        let response = try await apiClient.get(
            ChatAPIEndpoint.messageReactions(roomID: roomID, messageID: messageID),
            bearerToken: token,
            as: MessageReactionResponse.self
        )
        return response.summaries
    }
}

public struct SendTextMessageRequest: Encodable, Equatable, Sendable {
    public let content: String
    public let quotedMessageID: String?

    public init(content: String, quotedMessageID: String? = nil) {
        self.content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        self.quotedMessageID = quotedMessageID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case content
        case quotedMessageID = "quoted_message_id"
    }
}

public struct SendRichMessageRequest: Encodable, Equatable, Sendable {
    public let content: String?
    public let parts: [OutgoingMessagePart]
    public let quotedMessageID: String?

    public init(
        content: String? = nil,
        parts: [OutgoingMessagePart],
        quotedMessageID: String? = nil
    ) {
        self.content = content?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.parts = parts
        self.quotedMessageID = quotedMessageID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case content
        case parts
        case quotedMessageID = "quoted_message_id"
    }
}

public struct MarkMessageReadRequest: Encodable, Equatable, Sendable {
    public let messageID: String

    public init(messageID: String) {
        self.messageID = messageID
    }

    private enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
    }
}

public struct MessageReactionRequest: Encodable, Equatable, Sendable {
    public let reactionKey: String

    public init(reactionKey: String) {
        self.reactionKey = reactionKey
    }

    private enum CodingKeys: String, CodingKey {
        case reactionKey = "reaction_key"
    }
}

private struct SendMessageResponse: Decodable, Sendable {
    let message: ChatMessage
}

private struct MessageReactionResponse: Decodable, Sendable {
    let summaries: [MessageReactionSummary]
}

private extension Array where Element == ChatSummary {
    func sortedForChatList() -> [ChatSummary] {
        sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return (lhs.lastMessageAt ?? .distantPast) > (rhs.lastMessageAt ?? .distantPast)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
