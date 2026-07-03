import Foundation
import Observation
import RedCodeNetworking
import RedCodeStorage

@MainActor
@Observable
public final class ChatDetailController {
    public private(set) var roomID: String = ""
    public private(set) var messages: [ChatMessage] = []
    public private(set) var isLoading = false
    public private(set) var isSending = false
    public private(set) var errorMessage: String?
    public private(set) var quotedMessage: ChatMessage?

    public var canSend: Bool {
        !roomID.isEmpty && !isSending
    }

    private let api: any ChatAPIService
    private let messageCacheStore: any MessageCacheStore

    public init(
        api: any ChatAPIService,
        messageCacheStore: any MessageCacheStore
    ) {
        self.api = api
        self.messageCacheStore = messageCacheStore
    }

    public func enterRoom(
        roomID: String,
        token: String,
        currentUserID: String?,
        limit: Int = 50
    ) async throws {
        let roomID = roomID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !roomID.isEmpty else {
            return
        }

        self.roomID = roomID
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let cached = try messageCacheStore.loadMessages(roomID: roomID).map(ChatMessage.init(cacheDraft:))
            if !cached.isEmpty {
                messages = cached.sortedByTimestamp()
            }

            let remote = try await api.loadMessages(
                roomID: roomID,
                token: token,
                limit: limit,
                beforeID: nil,
                sinceID: nil
            )
            messages = ChatDetailController.mergeMessages(current: messages, incoming: remote)
            try persist()
            try await syncReadState(token: token, currentUserID: currentUserID)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func leaveRoom() {
        roomID = ""
        messages = []
        isLoading = false
        isSending = false
        errorMessage = nil
        quotedMessage = nil
    }

    public func quoteMessage(messageID: String) {
        quotedMessage = messages.first { $0.id == messageID && !$0.isDeleted }
    }

    public func clearQuote() {
        quotedMessage = nil
    }

    @discardableResult
    public func sendText(
        _ content: String,
        token: String,
        currentUserID: String,
        currentUserName: String = "我"
    ) async throws -> ChatMessage? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !roomID.isEmpty else {
            return nil
        }

        let quote = quotedMessage?.asQuote
        quotedMessage = nil
        let pending = ChatMessage.pendingText(
            roomID: roomID,
            senderID: currentUserID,
            senderName: currentUserName,
            content: trimmed,
            quotedMessage: quote
        )
        messages = ChatDetailController.mergeMessages(current: messages, incoming: [pending])
        try persist()

        return try await flushPendingMessage(
            localID: pending.id,
            content: trimmed,
            quotedMessageID: quote?.id,
            token: token
        )
    }

    @discardableResult
    public func resendMessage(messageID: String, token: String) async throws -> ChatMessage? {
        guard let failed = messages.first(where: { $0.id == messageID && $0.status == .failed }) else {
            return nil
        }
        return try await flushPendingMessage(
            localID: failed.id,
            content: failed.content,
            quotedMessageID: failed.quotedMessage?.id,
            token: token
        )
    }

    public func applyIncomingMessage(_ message: ChatMessage) throws {
        guard message.roomID == roomID else {
            return
        }
        messages = ChatDetailController.mergeMessages(current: messages, incoming: [message])
        try persist()
    }

    public func applyMessageRead(messageID: String, readerID: String, currentUserID: String?) throws {
        guard !roomID.isEmpty, !messageID.isEmpty, readerID != currentUserID else {
            return
        }
        guard let readMessage = messages.first(where: { $0.id == messageID }) else {
            return
        }

        messages = messages.map { message in
            if message.senderID == currentUserID,
               !message.isDeleted,
               message.timestamp <= readMessage.timestamp {
                return message.replacingStatus(.read)
            }
            return message
        }
        try persist()
    }

    public func applyMessageUpdate(messageID: String, isDeleted: Bool) throws {
        guard !roomID.isEmpty, !messageID.isEmpty else {
            return
        }
        messages = messages.map { message in
            message.id == messageID && isDeleted ? message.replacingDeleted() : message
        }
        try persist()
    }

    public func applyPinUpdate(
        messageID: String,
        isPinned: Bool,
        pinnedAt: Date?,
        pinnedBy: String?
    ) throws {
        guard !roomID.isEmpty, !messageID.isEmpty else {
            return
        }
        messages = messages.map { message in
            message.id == messageID
                ? message.replacingPinned(isPinned, pinnedAt: pinnedAt, pinnedBy: pinnedBy)
                : message
        }
        try persist()
    }

    public func applyReactionSummaries(messageID: String, reactions: [MessageReactionSummary]) throws {
        guard !roomID.isEmpty, !messageID.isEmpty else {
            return
        }
        messages = messages.map { message in
            message.id == messageID ? message.replacingReactions(reactions.visibleReactions()) : message
        }
        try persist()
    }

    public func deleteMessage(messageID: String, token: String) async throws {
        guard !roomID.isEmpty, !messageID.isEmpty else {
            return
        }

        let previous = messages
        messages = messages.map {
            $0.id == messageID ? $0.replacingDeleted() : $0
        }
        try persist()

        do {
            let updated = try await api.deleteMessage(roomID: roomID, messageID: messageID, token: token)
            messages = ChatDetailController.mergeMessages(current: messages, incoming: [updated])
            try persist()
        } catch {
            messages = previous
            try persist()
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func setMessagePinned(messageID: String, pinned: Bool, token: String) async throws {
        guard !roomID.isEmpty, !messageID.isEmpty else {
            return
        }

        let previous = messages
        messages = messages.map {
            $0.id == messageID ? $0.replacingPinned(pinned) : $0
        }
        try persist()

        do {
            try await api.setMessagePinned(roomID: roomID, messageID: messageID, pinned: pinned, token: token)
        } catch {
            messages = previous
            try persist()
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func markLatestIncomingRead(token: String, currentUserID: String?) async throws {
        try await syncReadState(token: token, currentUserID: currentUserID)
    }

    public func toggleReaction(messageID: String, reactionKey: String, token: String) async throws {
        let reactionKey = reactionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !roomID.isEmpty, !messageID.isEmpty, !reactionKey.isEmpty else {
            return
        }
        let hasSelf = messages.first(where: { $0.id == messageID })?
            .reactions
            .first(where: { $0.reactionKey == reactionKey })?
            .hasSelf == true
        let summaries: [MessageReactionSummary]
        if hasSelf {
            summaries = try await api.removeMessageReaction(
                roomID: roomID,
                messageID: messageID,
                reactionKey: reactionKey,
                token: token
            )
        } else {
            summaries = try await api.addMessageReaction(
                roomID: roomID,
                messageID: messageID,
                reactionKey: reactionKey,
                token: token
            )
        }
        try applyReactionSummaries(messageID: messageID, reactions: summaries)
    }

    public func refreshReactions(messageID: String, token: String) async throws {
        guard !roomID.isEmpty, !messageID.isEmpty else {
            return
        }
        let summaries = try await api.fetchMessageReactions(roomID: roomID, messageID: messageID, token: token)
        try applyReactionSummaries(messageID: messageID, reactions: summaries)
    }

    private func flushPendingMessage(
        localID: String,
        content: String,
        quotedMessageID: String?,
        token: String
    ) async throws -> ChatMessage {
        messages = messages.map {
            $0.id == localID ? $0.replacingStatus(.sending) : $0
        }
        isSending = true
        errorMessage = nil
        try persist()

        do {
            let sent = try await api.sendTextMessage(
                roomID: roomID,
                content: content,
                quotedMessageID: quotedMessageID,
                token: token
            )
            .replacingStatus(.sent)
            messages = ChatDetailController.mergeMessages(current: messages, incoming: [sent])
            try persist()
            isSending = false
            return sent
        } catch {
            messages = messages.map {
                $0.id == localID ? $0.replacingStatus(.failed) : $0
            }
            errorMessage = error.localizedDescription
            try persist()
            isSending = false
            throw error
        }
    }

    private func syncReadState(token: String, currentUserID: String?) async throws {
        guard let currentUserID else {
            return
        }
        guard let latestIncoming = messages.last(where: { $0.senderID != currentUserID && !$0.isDeleted }) else {
            return
        }
        do {
            try await api.markMessagesAsRead(roomID: roomID, messageID: latestIncoming.id, token: token)
        } catch {
            // 已读同步不能阻塞消息浏览。
        }
    }

    private func persist() throws {
        guard !roomID.isEmpty else {
            return
        }
        try messageCacheStore.saveMessages(roomID: roomID, messages: messages.map(\.cacheDraft))
    }

    public static func mergeMessages(current: [ChatMessage], incoming: [ChatMessage]) -> [ChatMessage] {
        var byID = Dictionary(uniqueKeysWithValues: current.filter { !$0.id.isEmpty }.map { ($0.id, $0) })
        for message in incoming where !message.id.isEmpty {
            for (id, pending) in byID where pending.matchesPending(serverMessage: message) {
                byID.removeValue(forKey: id)
            }
            if let previous = byID[message.id] {
                byID[message.id] = previous.merged(with: message)
            } else {
                byID[message.id] = message
            }
        }
        return Array(byID.values).sortedByTimestamp()
    }
}

extension ChatMessage {
    init(cacheDraft draft: RedCodeMessageDraft) {
        self.init(
            id: draft.id,
            roomID: draft.roomID,
            senderID: draft.senderID,
            senderName: draft.senderName ?? draft.senderID,
            content: draft.content,
            messageType: ChatMessageType(rawValue: draft.messageType) ?? .text,
            status: ChatMessageStatus(rawValue: draft.status) ?? .sent,
            timestamp: draft.timestamp,
            isDeleted: draft.isDeleted,
            isPinned: draft.isPinned,
            quotedMessage: draft.quotedMessageID.map {
                ChatMessageQuote(
                    id: $0,
                    roomID: draft.roomID,
                    senderID: "",
                    senderName: "",
                    content: ""
                )
            },
            reactions: draft.cachedExtras.reactions
        )
    }

    static func pendingText(
        roomID: String,
        senderID: String,
        senderName: String,
        content: String,
        quotedMessage: ChatMessageQuote?
    ) -> ChatMessage {
        ChatMessage(
            id: "local-\(Date().timeIntervalSince1970)-\(UUID().uuidString)",
            roomID: roomID,
            senderID: senderID,
            senderName: senderName,
            content: content,
            messageType: .text,
            status: .sending,
            timestamp: Date(),
            quotedMessage: quotedMessage
        )
    }

    var cacheDraft: RedCodeMessageDraft {
        RedCodeMessageDraft(
            id: id,
            roomID: roomID,
            senderID: senderID,
            senderName: senderName,
            content: content,
            messageType: messageType.rawValue,
            status: (status ?? .sent).rawValue,
            timestamp: timestamp,
            isDeleted: isDeleted,
            isPinned: isPinned,
            quotedMessageID: quotedMessage?.id,
            rawPayloadJSON: cacheExtrasJSON
        )
    }

    var asQuote: ChatMessageQuote {
        ChatMessageQuote(
            id: id,
            roomID: roomID,
            senderID: senderID,
            senderName: senderName,
            content: content,
            messageType: messageType,
            timestamp: timestamp,
            isDeleted: isDeleted,
            parts: parts
        )
    }

    func replacingStatus(_ status: ChatMessageStatus) -> ChatMessage {
        ChatMessage(
            id: id,
            roomID: roomID,
            senderID: senderID,
            senderName: senderName,
            content: content,
            messageType: messageType,
            status: status,
            timestamp: timestamp,
            isDeleted: isDeleted,
            isPinned: isPinned,
            pinnedAt: pinnedAt,
            pinnedBy: pinnedBy,
            quotedMessage: quotedMessage,
            parts: parts,
            attachments: attachments,
            reactions: reactions
        )
    }

    func replacingReactions(_ reactions: [MessageReactionSummary]) -> ChatMessage {
        ChatMessage(
            id: id,
            roomID: roomID,
            senderID: senderID,
            senderName: senderName,
            content: content,
            messageType: messageType,
            status: status,
            timestamp: timestamp,
            isDeleted: isDeleted,
            isPinned: isPinned,
            pinnedAt: pinnedAt,
            pinnedBy: pinnedBy,
            quotedMessage: quotedMessage,
            parts: parts,
            attachments: attachments,
            reactions: reactions
        )
    }

    func replacingDeleted() -> ChatMessage {
        ChatMessage(
            id: id,
            roomID: roomID,
            senderID: senderID,
            senderName: senderName,
            content: "",
            messageType: messageType,
            status: .deleted,
            timestamp: timestamp,
            isDeleted: true,
            isPinned: false,
            quotedMessage: quotedMessage,
            parts: parts,
            attachments: attachments,
            reactions: reactions
        )
    }

    func replacingPinned(_ pinned: Bool) -> ChatMessage {
        replacingPinned(
            pinned,
            pinnedAt: pinned ? Date() : nil,
            pinnedBy: pinned ? senderID : nil
        )
    }

    func replacingPinned(_ pinned: Bool, pinnedAt: Date?, pinnedBy: String?) -> ChatMessage {
        ChatMessage(
            id: id,
            roomID: roomID,
            senderID: senderID,
            senderName: senderName,
            content: content,
            messageType: messageType,
            status: status,
            timestamp: timestamp,
            isDeleted: isDeleted,
            isPinned: pinned,
            pinnedAt: pinned ? pinnedAt : nil,
            pinnedBy: pinned ? pinnedBy : nil,
            quotedMessage: quotedMessage,
            parts: parts,
            attachments: attachments,
            reactions: reactions
        )
    }

    func merged(with incoming: ChatMessage) -> ChatMessage {
        ChatMessage(
            id: id,
            roomID: incoming.roomID,
            senderID: incoming.senderID,
            senderName: incoming.senderName,
            content: incoming.content,
            messageType: incoming.messageType,
            status: incoming.status ?? status,
            timestamp: incoming.timestamp,
            isDeleted: incoming.isDeleted,
            isPinned: incoming.isPinned,
            pinnedAt: incoming.pinnedAt ?? pinnedAt,
            pinnedBy: incoming.pinnedBy ?? pinnedBy,
            quotedMessage: incoming.quotedMessage ?? quotedMessage,
            parts: incoming.parts.isEmpty ? parts : incoming.parts,
            attachments: incoming.attachments.isEmpty ? attachments : incoming.attachments,
            reactions: incoming.reactions.isEmpty ? reactions : incoming.reactions
        )
    }

    func matchesPending(serverMessage: ChatMessage) -> Bool {
        id.hasPrefix("local-")
            && roomID == serverMessage.roomID
            && senderID == serverMessage.senderID
            && content == serverMessage.content
            && (quotedMessage?.id ?? "") == (serverMessage.quotedMessage?.id ?? "")
    }
}

private struct CachedMessageExtras: Codable {
    let reactions: [MessageReactionSummary]

    static let empty = CachedMessageExtras(reactions: [])
}

private extension RedCodeMessageDraft {
    var cachedExtras: CachedMessageExtras {
        guard let rawPayloadJSON,
              let data = rawPayloadJSON.data(using: .utf8),
              let extras = try? JSONDecoder().decode(CachedMessageExtras.self, from: data) else {
            return .empty
        }
        return extras
    }
}

private extension ChatMessage {
    var cacheExtrasJSON: String? {
        let extras = CachedMessageExtras(reactions: reactions)
        guard !extras.reactions.isEmpty,
              let data = try? JSONEncoder().encode(extras) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

private extension Array where Element == ChatMessage {
    func sortedByTimestamp() -> [ChatMessage] {
        sorted { $0.timestamp < $1.timestamp }
    }
}

private extension Array where Element == MessageReactionSummary {
    func visibleReactions() -> [MessageReactionSummary] {
        filter { !$0.reactionKey.isEmpty && $0.count > 0 }
            .sorted { lhs, rhs in
                if lhs.hasSelf != rhs.hasSelf {
                    return lhs.hasSelf && !rhs.hasSelf
                }
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }
                return lhs.reactionKey < rhs.reactionKey
            }
    }
}
