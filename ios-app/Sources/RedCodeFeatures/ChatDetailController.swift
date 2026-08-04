import Foundation
import Combine
import RedCodeCore
import RedCodeNetworking
import RedCodeStorage

@MainActor
public final class ChatDetailController: ObservableObject {
    @Published public private(set) var roomID: String = ""
    @Published public private(set) var messages: [ChatMessage] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isSending = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var quotedMessage: ChatMessage?

    public var canSend: Bool {
        !roomID.isEmpty && !isSending
    }

    private let api: any ChatAPIService
    private let mediaAPI: (any MediaAPIService)?
    private let messageCacheStore: any MessageCacheStore
    private let attachmentCache: AttachmentFileCache?

    public init(
        api: any ChatAPIService,
        messageCacheStore: any MessageCacheStore,
        mediaAPI: (any MediaAPIService)? = nil,
        attachmentCache: AttachmentFileCache? = nil
    ) {
        self.api = api
        self.mediaAPI = mediaAPI
        self.messageCacheStore = messageCacheStore
        self.attachmentCache = attachmentCache
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

    public func setErrorMessage(_ message: String?) {
        errorMessage = message
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
    public func sendPreparedMedia(
        files: [PreparedUploadFile],
        caption: String? = nil,
        token: String,
        currentUserID: String,
        currentUserName: String = "我"
    ) async throws -> ChatMessage? {
        let caption = caption?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        guard !files.isEmpty, !roomID.isEmpty else {
            if let caption {
                return try await sendText(caption, token: token, currentUserID: currentUserID, currentUserName: currentUserName)
            }
            return nil
        }
        guard let mediaAPI else {
            throw RedCodeError.configuration("MediaAPIService is required to send attachments")
        }

        let quote = quotedMessage?.asQuote
        quotedMessage = nil

        let localID = "local-\(Date().timeIntervalSince1970)-\(UUID().uuidString)"
        let pending = ChatMessage.pendingMedia(
            localID: localID,
            roomID: roomID,
            senderID: currentUserID,
            senderName: currentUserName,
            caption: caption,
            files: files,
            quotedMessage: quote
        )
        messages = ChatDetailController.mergeMessages(current: messages, incoming: [pending])
        isSending = true
        defer { isSending = false }
        errorMessage = nil
        try persist()

        do {
            let uploaded = try await upload(files: files, token: token, mediaAPI: mediaAPI)
            let sent = try await api.sendRichMessage(
                roomID: roomID,
                content: caption,
                parts: uploaded.outgoingParts(caption: nil),
                quotedMessageID: quote?.id,
                token: token
            )
            .replacingStatus(.sent)
            messages = ChatDetailController.mergeMessages(current: messages, incoming: [sent])
            try persist()
            return sent
        } catch {
            messages = messages.map {
                $0.id == localID ? $0.replacingStatus(.failed) : $0
            }
            errorMessage = error.localizedDescription
            try persist()
            throw error
        }
    }

    @discardableResult
    public func resendMessage(messageID: String, token: String) async throws -> ChatMessage? {
        guard let failed = messages.first(where: { $0.id == messageID && $0.status == .failed }) else {
            return nil
        }
        if !failed.attachments.isEmpty {
            let sent = try await api.sendRichMessage(
                roomID: roomID,
                content: failed.content.nilIfEmpty,
                parts: failed.outgoingPartsForResend(),
                quotedMessageID: failed.quotedMessage?.id,
                token: token
            )
            .replacingStatus(.sent)
            messages = ChatDetailController.mergeMessages(current: messages, incoming: [sent])
            try persist()
            return sent
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

    private func upload(
        files: [PreparedUploadFile],
        token: String,
        mediaAPI: any MediaAPIService
    ) async throws -> [UploadedMediaFile] {
        var uploaded: [UploadedMediaFile] = []
        for file in files {
            let metadata = file.uploadMetadata
            let descriptor = try await mediaAPI.requestMessageAttachmentUpload(
                roomID: roomID,
                partType: file.mediaPartType,
                metadata: metadata,
                token: token
            )
            if let signature = descriptor.signature {
                let data = try Data(contentsOf: file.localURL)
                try await mediaAPI.upload(data: data, using: signature, defaultContentType: file.contentType)
            }
            try await mediaAPI.commitMessageAttachmentUpload(
                roomID: roomID,
                key: descriptor.key,
                metadata: metadata,
                token: token
            )
            if let attachmentCache {
                _ = try? await attachmentCache.saveFile(
                    objectKey: descriptor.key,
                    sourceURL: file.localURL,
                    suggestedExtension: file.localURL.pathExtension,
                    mimeType: file.contentType
                )
            }
            uploaded.append(UploadedMediaFile(file: file, objectKey: descriptor.key))
        }
        return uploaded
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
            parts: draft.cachedExtras.parts,
            attachments: draft.cachedExtras.parts.compactMap(\.attachment),
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

    static func pendingMedia(
        localID: String,
        roomID: String,
        senderID: String,
        senderName: String,
        caption: String?,
        files: [PreparedUploadFile],
        quotedMessage: ChatMessageQuote?
    ) -> ChatMessage {
        let parts = files.enumerated().map { index, file in
            ChatMessagePart(
                position: index,
                partType: file.chatMessageType,
                attachment: ChatMessageAttachment(
                    key: file.localURL.absoluteString,
                    name: file.fileName,
                    mimeType: file.contentType,
                    size: file.size,
                    width: file.width,
                    height: file.height,
                    durationMilliseconds: file.durationMilliseconds
                )
            )
        }
        let content = caption?.nilIfEmpty ?? files.summaryText
        return ChatMessage(
            id: localID,
            roomID: roomID,
            senderID: senderID,
            senderName: senderName,
            content: content,
            messageType: files.messageType(caption: caption),
            status: .sending,
            timestamp: Date(),
            quotedMessage: quotedMessage,
            parts: parts,
            attachments: parts.compactMap(\.attachment)
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
    let parts: [ChatMessagePart]
    let reactions: [MessageReactionSummary]

    static let empty = CachedMessageExtras(parts: [], reactions: [])

    init(parts: [ChatMessagePart], reactions: [MessageReactionSummary]) {
        self.parts = parts
        self.reactions = reactions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        parts = try container.decodeIfPresent([ChatMessagePart].self, forKey: .parts) ?? []
        reactions = try container.decodeIfPresent([MessageReactionSummary].self, forKey: .reactions) ?? []
    }
}

private struct UploadedMediaFile: Sendable {
    let file: PreparedUploadFile
    let objectKey: String
}

private extension PreparedUploadFile {
    var uploadMetadata: MediaUploadMetadata {
        MediaUploadMetadata(
            fileName: fileName,
            contentType: contentType,
            fileSize: size,
            hashValue: hashValue,
            hashAlgorithm: hashAlgorithm
        )
    }

    var mediaPartType: MediaPartType {
        switch kind {
        case .image:
            .image
        case .video:
            .video
        case .audio:
            .audio
        case .file:
            .file
        }
    }

    var chatMessageType: ChatMessageType {
        switch kind {
        case .image:
            .image
        case .video:
            .video
        case .audio:
            .audio
        case .file:
            .file
        }
    }
}

private extension Array where Element == UploadedMediaFile {
    func outgoingParts(caption: String?) -> [OutgoingMessagePart] {
        var parts: [OutgoingMessagePart] = []
        if let caption = caption?.nilIfEmpty {
            parts.append(.text(caption))
        }
        for item in self {
            parts.append(
                .attachment(
                    type: item.file.chatMessageType,
                    key: item.objectKey,
                    name: item.file.fileName,
                    mime: item.file.contentType,
                    size: item.file.size,
                    width: item.file.width,
                    height: item.file.height,
                    durationMilliseconds: item.file.durationMilliseconds
                )
            )
        }
        return parts
    }
}

private extension Array where Element == PreparedUploadFile {
    var summaryText: String {
        map { file in
            switch file.kind {
            case .image:
                "[图片]"
            case .video:
                "[视频]"
            case .audio:
                "[语音]"
            case .file:
                "[文件]"
            }
        }
        .joined(separator: " ")
    }

    func messageType(caption: String?) -> ChatMessageType {
        if count == 1, caption?.nilIfEmpty == nil {
            return first?.chatMessageType ?? .file
        }
        return .mixed
    }
}

private extension ChatMessage {
    func outgoingPartsForResend() -> [OutgoingMessagePart] {
        var outgoing: [OutgoingMessagePart] = []
        for part in parts {
            if part.partType == .text, let text = part.text?.nilIfEmpty {
                outgoing.append(.text(text))
                continue
            }
            guard let attachment = part.attachment else {
                continue
            }
            outgoing.append(
                .attachment(
                    type: part.partType,
                    key: attachment.key,
                    name: attachment.name,
                    mime: attachment.mimeType,
                    size: attachment.size,
                    width: attachment.width,
                    height: attachment.height,
                    durationMilliseconds: attachment.durationMilliseconds,
                    thumbnailKey: attachment.thumbnailKey
                )
            )
        }
        return outgoing
    }
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
        let extras = CachedMessageExtras(parts: parts, reactions: reactions)
        guard !extras.parts.isEmpty || !extras.reactions.isEmpty,
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

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
