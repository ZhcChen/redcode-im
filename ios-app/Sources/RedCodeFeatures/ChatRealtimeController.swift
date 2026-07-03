import Foundation
import RedCodeNetworking
import RedCodeStorage

public protocol ChatWebSocketService: Sendable {
    func connect(accessToken: String?) async throws
    func disconnect() async
    func ensureRoomsSubscribed(_ roomIDs: [String], pruneMissing: Bool) async
    func eventStream() async -> AsyncStream<WebSocketServerEvent>
    func snapshot() async -> WebSocketClientSnapshot
}

extension WebSocketClient: ChatWebSocketService {
    public func eventStream() async -> AsyncStream<WebSocketServerEvent> {
        events()
    }
}

@MainActor
public final class ChatRealtimeController {
    public private(set) var connectionStatus: WebSocketConnectionStatus = .disconnected
    public private(set) var errorMessage: String?

    private let webSocket: any ChatWebSocketService
    private let listController: ChatListController
    private let messageCacheStore: any MessageCacheStore

    private var eventTask: Task<Void, Never>?
    private var token: String?
    private var currentUserID: String?
    private weak var activeDetailController: ChatDetailController?
    private var activeRoomID = ""

    public init(
        webSocket: any ChatWebSocketService,
        listController: ChatListController,
        messageCacheStore: any MessageCacheStore
    ) {
        self.webSocket = webSocket
        self.listController = listController
        self.messageCacheStore = messageCacheStore
    }

    deinit {
        eventTask?.cancel()
    }

    public func start(token: String, currentUserID: String) async {
        self.token = token
        self.currentUserID = currentUserID
        beginEventLoopIfNeeded()
        do {
            try await webSocket.connect(accessToken: token)
            await syncRooms(listController.chats.map(\.roomID), pruneMissing: true)
            await refreshSnapshot()
        } catch {
            errorMessage = error.localizedDescription
            connectionStatus = .error
        }
    }

    public func stop() async {
        eventTask?.cancel()
        eventTask = nil
        token = nil
        currentUserID = nil
        activeDetailController = nil
        activeRoomID = ""
        await webSocket.disconnect()
        connectionStatus = .disconnected
        errorMessage = nil
    }

    public func syncRooms(_ roomIDs: [String], pruneMissing: Bool = true) async {
        await webSocket.ensureRoomsSubscribed(roomIDs, pruneMissing: pruneMissing)
        await refreshSnapshot()
    }

    public func attachDetailController(_ controller: ChatDetailController, roomID: String) async {
        activeDetailController = controller
        activeRoomID = roomID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !activeRoomID.isEmpty {
            await webSocket.ensureRoomsSubscribed([activeRoomID], pruneMissing: false)
        }
        await refreshSnapshot()
    }

    public func detachDetailController(_ controller: ChatDetailController) {
        if activeDetailController === controller {
            activeDetailController = nil
            activeRoomID = ""
        }
    }

    private func beginEventLoopIfNeeded() {
        guard eventTask == nil else {
            return
        }
        eventTask = Task { [weak self] in
            guard let self else {
                return
            }
            let stream = await webSocket.eventStream()
            for await event in stream {
                await self.handle(event)
            }
        }
    }

    private func handle(_ event: WebSocketServerEvent) async {
        await refreshSnapshot()
        switch event.type {
        case "message":
            await handleMessageEvent(event)
        case "message_read":
            handleMessageReadEvent(event)
        case "message_update":
            handleMessageUpdateEvent(event)
        case "pin_update":
            handlePinUpdateEvent(event)
        case "reaction_update":
            await handleReactionUpdateEvent(event)
        case "room_created":
            await refreshChatsFromServer()
        case "room_history_cleared", "group_dissolved":
            handleRoomRemovedEvent(event)
        case "error":
            errorMessage = event.stringValue(for: "message") ?? "WebSocket 服务端错误"
        default:
            break
        }
    }

    private func handleMessageEvent(_ event: WebSocketServerEvent) async {
        do {
            let message = try ChatMessage(webSocketEvent: event, currentUserID: currentUserID)
            try persistMessage(message)
            try listController.applyIncomingMessage(message, currentUserID: currentUserID)

            if activeRoomID == message.roomID, let activeDetailController {
                try activeDetailController.applyIncomingMessage(message)
                try await markActiveRoomReadIfNeeded(message.roomID)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleMessageReadEvent(_ event: WebSocketServerEvent) {
        let roomID = event.stringValue(for: "room_id") ?? ""
        let messageID = event.stringValue(for: "message_id") ?? ""
        let readerID = event.stringValue(for: "reader_id") ?? ""
        do {
            try listController.applyMessageRead(roomID: roomID, readerID: readerID, currentUserID: currentUserID)
            if activeRoomID == roomID, let activeDetailController {
                try activeDetailController.applyMessageRead(
                    messageID: messageID,
                    readerID: readerID,
                    currentUserID: currentUserID
                )
            }
            try updateCachedMessages(roomID: roomID) { messages in
                guard readerID != currentUserID,
                      let currentUserID,
                      let readMessage = messages.first(where: { $0.id == messageID }) else {
                    return messages
                }
                return messages.map { message in
                    if message.senderID == currentUserID,
                       !message.isDeleted,
                       message.timestamp <= readMessage.timestamp {
                        return message.replacingStatus(.read)
                    }
                    return message
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleMessageUpdateEvent(_ event: WebSocketServerEvent) {
        let roomID = event.stringValue(for: "room_id") ?? ""
        let messageID = event.stringValue(for: "message_id") ?? ""
        let isDeleted = event.boolValue(for: "is_deleted") ?? false
        do {
            if activeRoomID == roomID, let activeDetailController {
                try activeDetailController.applyMessageUpdate(messageID: messageID, isDeleted: isDeleted)
            }
            try updateCachedMessages(roomID: roomID) { messages in
                messages.map { message in
                    message.id == messageID && isDeleted ? message.replacingDeleted() : message
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handlePinUpdateEvent(_ event: WebSocketServerEvent) {
        let roomID = event.stringValue(for: "room_id") ?? ""
        let messageID = event.stringValue(for: "message_id") ?? ""
        let isPinned = event.boolValue(for: "is_pinned") ?? false
        let pinnedAt = parseDate(event["pinned_at"])
        let pinnedBy = event.stringValue(for: "pinned_by")
        do {
            if activeRoomID == roomID, let activeDetailController {
                try activeDetailController.applyPinUpdate(
                    messageID: messageID,
                    isPinned: isPinned,
                    pinnedAt: pinnedAt,
                    pinnedBy: pinnedBy
                )
            }
            try updateCachedMessages(roomID: roomID) { messages in
                messages.map { message in
                    message.id == messageID
                        ? message.replacingPinned(isPinned, pinnedAt: pinnedAt, pinnedBy: pinnedBy)
                        : message
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleReactionUpdateEvent(_ event: WebSocketServerEvent) async {
        let roomID = event.stringValue(for: "room_id") ?? ""
        let messageID = event.stringValue(for: "message_id") ?? ""
        guard activeRoomID == roomID, let activeDetailController, let token else {
            return
        }
        do {
            try await activeDetailController.refreshReactions(messageID: messageID, token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleRoomRemovedEvent(_ event: WebSocketServerEvent) {
        let roomID = event.stringValue(for: "room_id") ?? ""
        guard !roomID.isEmpty else {
            return
        }
        do {
            try listController.removeRoom(roomID)
            try messageCacheStore.clear(roomID: roomID)
        } catch {
            errorMessage = error.localizedDescription
        }
        Task {
            await syncRooms(listController.chats.map(\.roomID), pruneMissing: true)
        }
    }

    private func refreshChatsFromServer() async {
        guard let token else {
            return
        }
        do {
            try await listController.refreshChats(token: token)
            await syncRooms(listController.chats.map(\.roomID), pruneMissing: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func markActiveRoomReadIfNeeded(_ roomID: String) async throws {
        guard let token else {
            return
        }
        try await activeDetailController?.markLatestIncomingRead(token: token, currentUserID: currentUserID)
        if let currentUserID {
            try listController.applyMessageRead(roomID: roomID, readerID: currentUserID, currentUserID: currentUserID)
        }
    }

    private func persistMessage(_ message: ChatMessage) throws {
        try updateCachedMessages(roomID: message.roomID) { messages in
            ChatDetailController.mergeMessages(current: messages, incoming: [message])
        }
    }

    private func updateCachedMessages(
        roomID: String,
        transform: ([ChatMessage]) -> [ChatMessage]
    ) throws {
        let roomID = roomID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !roomID.isEmpty else {
            return
        }
        let current = try messageCacheStore.loadMessages(roomID: roomID).map(ChatMessage.init(cacheDraft:))
        let updated = transform(current)
        try messageCacheStore.saveMessages(roomID: roomID, messages: updated.map(\.cacheDraft))
    }

    private func refreshSnapshot() async {
        let snapshot = await webSocket.snapshot()
        connectionStatus = snapshot.status
        errorMessage = snapshot.lastError.isEmpty ? errorMessage : snapshot.lastError
    }
}

private func parseDate(_ value: JSONValue?) -> Date? {
    switch value {
    case .number(let number):
        let seconds = number > 1_000_000_000_000 ? number / 1000 : number
        return Date(timeIntervalSince1970: seconds)
    case .string(let string):
        guard !string.isEmpty else {
            return nil
        }
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: string) {
            return date
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    case .bool, .array, .object, .null, .none:
        return nil
    }
}
