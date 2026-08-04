import Foundation
import Combine
import RedCodeNetworking
import RedCodeStorage

@MainActor
public final class ChatListController: ObservableObject {
    @Published public private(set) var chats: [ChatSummary] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    public var unreadTotal: Int {
        chats.reduce(0) { $0 + $1.unreadCount }
    }

    private let api: any ChatAPIService
    private let cacheStore: any ChatSummaryCacheStore

    public init(
        api: any ChatAPIService,
        cacheStore: any ChatSummaryCacheStore
    ) {
        self.api = api
        self.cacheStore = cacheStore
    }

    public func loadCachedChats() throws {
        chats = try cacheStore.loadChats().map(ChatSummary.init(cacheDraft:)).sortedForChatList()
    }

    public func refreshChats(token: String) async throws {
        try await runThrowingLoadingOperation {
            let cached = try cacheStore.loadChats().map(ChatSummary.init(cacheDraft:))
            if !cached.isEmpty {
                chats = cached.sortedForChatList()
            }

            let remote = try await api.fetchChats(token: token)
            chats = remote.sortedForChatList()
            try cacheStore.saveChats(chats.map(\.cacheDraft))
        }
    }

    public func upsertChatSummary(_ chat: ChatSummary) throws {
        chats = ([chat] + chats.filter { $0.roomID != chat.roomID }).sortedForChatList()
        try cacheStore.upsert(chat.cacheDraft)
    }

    public func updateLocalChat(
        roomID: String,
        displayName: String? = nil,
        isPinned: Bool? = nil,
        isMuted: Bool? = nil
    ) throws {
        guard let existing = chats.first(where: { $0.roomID == roomID }) else {
            return
        }
        let updated = existing.replacingDisplayAndFlags(
            displayName: displayName,
            isPinned: isPinned,
            isMuted: isMuted
        )
        chats = ([updated] + chats.filter { $0.roomID != roomID }).sortedForChatList()
        try cacheStore.upsert(updated.cacheDraft)
    }

    public func deleteChat(roomID: String, token: String) async throws {
        let previous = chats
        chats = chats.filter { $0.roomID != roomID }
        try cacheStore.remove(roomID: roomID)

        do {
            try await api.deleteChat(roomID: roomID, token: token)
        } catch {
            chats = previous
            try cacheStore.saveChats(previous.map(\.cacheDraft))
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func applyIncomingMessage(_ message: ChatMessage, currentUserID: String?) throws {
        guard !message.roomID.isEmpty, !message.id.isEmpty else {
            return
        }

        let isSelf = message.senderID == currentUserID
        let nextChats: [ChatSummary]
        if let existing = chats.first(where: { $0.roomID == message.roomID }) {
            let isDuplicateLatest = existing.lastMessageID == message.id
            let updated = existing.replacingLatestMessage(
                message,
                unreadCount: isSelf || isDuplicateLatest ? existing.unreadCount : existing.unreadCount + 1
            )
            nextChats = [updated] + chats.filter { $0.roomID != message.roomID }
        } else {
            let created = ChatSummary(
                roomID: message.roomID,
                displayName: message.senderName.isEmpty ? "新会话" : message.senderName,
                roomType: .privateChat,
                unreadCount: isSelf ? 0 : 1,
                lastMessageID: message.id,
                lastMessagePreview: message.previewText,
                lastMessageAt: message.timestamp
            )
            nextChats = chats + [created]
        }

        chats = nextChats.sortedForChatList()
        try cacheStore.saveChats(chats.map(\.cacheDraft))
    }

    public func applyMessageRead(roomID: String, readerID: String, currentUserID: String?) throws {
        guard readerID == currentUserID else {
            return
        }
        chats = chats.map { chat in
            chat.roomID == roomID ? chat.replacingUnreadCount(0) : chat
        }
        try cacheStore.saveChats(chats.map(\.cacheDraft))
    }

    public func removeRoom(_ roomID: String) throws {
        chats = chats.filter { $0.roomID != roomID }
        try cacheStore.remove(roomID: roomID)
    }

    private func runThrowingLoadingOperation(_ operation: () async throws -> Void) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

private extension ChatSummary {
    init(cacheDraft draft: RedCodeChatSummaryDraft) {
        self.init(
            roomID: draft.roomID,
            displayName: draft.displayName,
            roomType: ChatType(rawValue: draft.roomType) ?? .privateChat,
            avatarURL: draft.avatarURL,
            avatarObjectKey: draft.avatarObjectKey,
            unreadCount: draft.unreadCount,
            isMuted: draft.isMuted,
            isPinned: draft.isPinned,
            lastMessageID: draft.lastMessageID,
            lastMessagePreview: draft.lastMessagePreview ?? "",
            lastMessageAt: draft.lastMessageAt
        )
    }

    var cacheDraft: RedCodeChatSummaryDraft {
        RedCodeChatSummaryDraft(
            roomID: roomID,
            roomType: roomType.rawValue,
            displayName: displayName,
            avatarURL: avatarURL,
            avatarObjectKey: avatarObjectKey,
            lastMessageID: lastMessageID,
            lastMessagePreview: lastMessagePreview,
            lastMessageAt: lastMessageAt,
            unreadCount: unreadCount,
            isPinned: isPinned,
            isMuted: isMuted,
            updatedAt: Date()
        )
    }

    func replacingLatestMessage(_ message: ChatMessage, unreadCount: Int) -> ChatSummary {
        ChatSummary(
            roomID: roomID,
            displayName: displayName,
            roomType: roomType,
            avatarURL: avatarURL,
            avatarObjectKey: avatarObjectKey,
            unreadCount: unreadCount,
            lastReadMessageID: lastReadMessageID,
            lastReadAt: lastReadAt,
            notificationSettings: notificationSettings,
            isMuted: isMuted,
            isPinned: isPinned,
            lastMessageID: message.id,
            lastMessage: lastMessage,
            lastMessagePreview: message.previewText,
            lastMessageAt: message.timestamp,
            friendUserID: friendUserID
        )
    }

    func replacingUnreadCount(_ unreadCount: Int) -> ChatSummary {
        ChatSummary(
            roomID: roomID,
            displayName: displayName,
            roomType: roomType,
            avatarURL: avatarURL,
            avatarObjectKey: avatarObjectKey,
            unreadCount: unreadCount,
            lastReadMessageID: lastReadMessageID,
            lastReadAt: lastReadAt,
            notificationSettings: notificationSettings,
            isMuted: isMuted,
            isPinned: isPinned,
            lastMessageID: lastMessageID,
            lastMessage: lastMessage,
            lastMessagePreview: lastMessagePreview,
            lastMessageAt: lastMessageAt,
            friendUserID: friendUserID
        )
    }

    func replacingDisplayAndFlags(
        displayName: String?,
        isPinned: Bool?,
        isMuted: Bool?
    ) -> ChatSummary {
        ChatSummary(
            roomID: roomID,
            displayName: displayName ?? self.displayName,
            roomType: roomType,
            avatarURL: avatarURL,
            avatarObjectKey: avatarObjectKey,
            unreadCount: unreadCount,
            lastReadMessageID: lastReadMessageID,
            lastReadAt: lastReadAt,
            notificationSettings: isMuted.map { $0 ? 2 : 0 } ?? notificationSettings,
            isMuted: isMuted ?? self.isMuted,
            isPinned: isPinned ?? self.isPinned,
            lastMessageID: lastMessageID,
            lastMessage: lastMessage,
            lastMessagePreview: lastMessagePreview,
            lastMessageAt: lastMessageAt,
            friendUserID: friendUserID
        )
    }
}

private extension ChatMessage {
    var previewText: String {
        if isDeleted {
            return "[消息已删除]"
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        switch messageType {
        case .image:
            return "[图片]"
        case .audio:
            return "[语音]"
        case .video:
            return "[视频]"
        case .file:
            return "[文件]"
        case .mixed:
            return "[多媒体消息]"
        case .system:
            return "[系统消息]"
        case .text:
            return ""
        }
    }
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
