#if DEBUG
import Foundation
import RedCodeCore
import RedCodeFeatures
import RedCodeNetworking
import RedCodeStorage

@MainActor
extension AppDependencies {
    static func uiTestingAuthFixture() -> AppDependencies {
        let autoAgree = ProcessInfo.processInfo.environment["RED_CODE_UI_TESTING_AUTH_AUTO_AGREE"] == "1"
        UserDefaults.standard.set(autoAgree, forKey: "redcode-ios-user-agreed-to-terms")
        let user = AuthUser(
            id: "ui-user",
            username: "uitest",
            nickname: "UI 测试用户"
        )
        let session = AuthSession(token: "ui-test-token", refreshToken: "ui-test-refresh", user: user)
        return makeUITestingDependencies(user: user, session: nil, authAPI: UITestingAuthAPIService(session: session))
    }

    static func uiTestingChatFixture() -> AppDependencies {
        let user = AuthUser(
            id: "ui-user",
            username: "uitest",
            nickname: "UI 测试用户"
        )
        let session = AuthSession(token: "ui-test-token", refreshToken: "ui-test-refresh", user: user)
        return makeUITestingDependencies(user: user, session: session, authAPI: UITestingAuthAPIService(session: session))
    }

    private static func makeUITestingDependencies(
        user: AuthUser,
        session: AuthSession?,
        authAPI: UITestingAuthAPIService
    ) -> AppDependencies {
        let chatAPIService = UITestingChatAPIService(currentUser: user)
        do {
            return AppDependencies(
                database: try RedCodeDatabase.makeDatabase(inMemory: true),
                authController: AuthController(
                    api: authAPI,
                    sessionStore: UITestingAuthSessionStore(session: session)
                ),
                chatAPIService: chatAPIService,
                friendAPIService: UITestingFriendAPIService(currentUser: user),
                webSocketService: UITestingChatWebSocketService()
            )
        } catch {
            fatalError("初始化 iOS UI test fixture 失败: \(error)")
        }
    }
}

private actor UITestingAuthSessionStore: AuthSessionStore {
    private var session: AuthSession?

    init(session: AuthSession?) {
        self.session = session
    }

    func save(_ session: AuthSession) async throws {
        self.session = session
    }

    func read() async throws -> AuthSession? {
        session
    }

    func updateUser(_ user: AuthUser) async throws {
        guard let current = session else {
            return
        }
        session = AuthSession(token: current.token, refreshToken: current.refreshToken, user: user)
    }

    func clear() async throws {
        session = nil
    }
}

private struct UITestingAuthAPIService: AuthAPIService {
    let session: AuthSession

    func register(username: String, password: String, nickname: String?) async throws -> AuthUser {
        AuthUser(id: "ui-user", username: username, nickname: nickname)
    }

    func login(username: String, password: String) async throws -> AuthSession {
        session
    }

    func currentUser(token: String) async throws -> AuthUser {
        session.user
    }

    func refresh(refreshToken: String) async throws -> AuthSession {
        session
    }

    func updateProfile(
        token: String,
        nickname: String?,
        avatarURL: String?,
        avatarObjectKey: String?
    ) async throws -> AuthUser {
        AuthUser(
            id: session.user.id,
            username: session.user.username,
            email: session.user.email,
            nickname: nickname ?? session.user.nickname,
            avatarURL: avatarURL ?? session.user.avatarURL,
            avatarObjectKey: avatarObjectKey ?? session.user.avatarObjectKey,
            localAvatarPath: session.user.localAvatarPath,
            status: session.user.status
        )
    }

    func changePassword(token: String, oldPassword: String, newPassword: String) async throws {}

    func resetPasswordWithSMS(
        token: String,
        phone: String,
        code: String,
        newPassword: String
    ) async throws -> ResetPasswordWithSMSResponse {
        ResetPasswordWithSMSResponse(success: true, message: "密码已重置，请使用新密码登录")
    }
}

private actor UITestingChatAPIService: ChatAPIService {
    private let currentUser: AuthUser
    private let roomID = "ui-room"
    private var sentMessageIndex = 0
    private var messages: [ChatMessage]

    init(currentUser: AuthUser) {
        self.currentUser = currentUser
        messages = [
            ChatMessage(
                id: "ui-message-1",
                roomID: roomID,
                senderID: "alice",
                senderName: "Alice 测试",
                content: "你好，iOS UI test",
                timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                reactions: [
                    MessageReactionSummary(reactionKey: "👍", count: 1, hasSelf: false),
                ]
            ),
            ChatMessage(
                id: "ui-message-2",
                roomID: roomID,
                senderID: currentUser.id,
                senderName: currentUser.displayName,
                content: "这是本机 Simulator 聊天夹具",
                timestamp: Date(timeIntervalSince1970: 1_700_000_060)
            ),
        ]
    }

    func fetchChats(token: String) async throws -> [ChatSummary] {
        [
            ChatSummary(
                roomID: roomID,
                displayName: "Alice 测试",
                roomType: .privateChat,
                unreadCount: 1,
                lastMessageID: messages.last?.id,
                lastMessagePreview: messages.last?.content ?? "",
                lastMessageAt: messages.last?.timestamp
            ),
        ]
    }

    func loadMessages(
        roomID: String,
        token: String,
        limit: Int,
        beforeID: String?,
        sinceID: String?
    ) async throws -> [ChatMessage] {
        messages.filter { $0.roomID == roomID }
    }

    func sendTextMessage(
        roomID: String,
        content: String,
        quotedMessageID: String?,
        token: String
    ) async throws -> ChatMessage {
        sentMessageIndex += 1
        let quotedMessage = quotedMessageID.flatMap { id in
            messages.first(where: { $0.id == id })?.asQuoteForUITesting
        }
        let message = ChatMessage(
            id: "ui-sent-\(sentMessageIndex)",
            roomID: roomID,
            senderID: currentUser.id,
            senderName: currentUser.displayName,
            content: content,
            timestamp: Date(),
            quotedMessage: quotedMessage
        )
        messages.append(message)
        return message
    }

    func markMessagesAsRead(roomID: String, messageID: String, token: String) async throws {}

    func deleteChat(roomID: String, token: String) async throws {}

    func deleteMessage(roomID: String, messageID: String, token: String) async throws -> ChatMessage {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else {
            return ChatMessage(
                id: messageID,
                roomID: roomID,
                senderID: currentUser.id,
                senderName: currentUser.displayName,
                content: "",
                status: .deleted,
                timestamp: Date(),
                isDeleted: true
            )
        }
        let deleted = messages[index].deletingForUITesting()
        messages[index] = deleted
        return deleted
    }

    func setMessagePinned(roomID: String, messageID: String, pinned: Bool, token: String) async throws {}

    func addMessageReaction(
        roomID: String,
        messageID: String,
        reactionKey: String,
        token: String
    ) async throws -> [MessageReactionSummary] {
        [MessageReactionSummary(reactionKey: reactionKey, count: 2, hasSelf: true)]
    }

    func removeMessageReaction(
        roomID: String,
        messageID: String,
        reactionKey: String,
        token: String
    ) async throws -> [MessageReactionSummary] {
        [MessageReactionSummary(reactionKey: reactionKey, count: 1, hasSelf: false)]
    }

    func fetchMessageReactions(roomID: String, messageID: String, token: String) async throws -> [MessageReactionSummary] {
        [MessageReactionSummary(reactionKey: "👍", count: 1, hasSelf: false)]
    }
}

private actor UITestingFriendAPIService: FriendAPIService {
    private let currentUser: AuthUser
    private let friend = AuthUser(id: "alice", username: "alice", nickname: "Alice 测试")

    init(currentUser: AuthUser) {
        self.currentUser = currentUser
    }

    func searchUsers(keyword: String, limit: Int, token: String) async throws -> [AuthUser] {
        keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : [friend]
    }

    func fetchFriends(token: String) async throws -> [FriendInfo] {
        [FriendInfo(id: "ui-friendship-1", user: friend, createdAt: Date(timeIntervalSince1970: 1_700_000_000))]
    }

    func sendFriendRequest(targetUserID: String, message: String?, token: String) async throws -> FriendRequestInfo {
        FriendRequestInfo(
            id: "ui-request-outgoing",
            requester: currentUser,
            addressee: friend,
            status: .pending,
            message: message,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    func fetchFriendRequests(direction: String?, status: String?, token: String) async throws -> [FriendRequestInfo] {
        guard direction == "incoming" else {
            return []
        }
        return [
            FriendRequestInfo(
                id: "ui-request-incoming",
                requester: friend,
                addressee: currentUser,
                status: .pending,
                message: "我是 Alice",
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                isIncoming: true
            ),
        ]
    }

    func respondFriendRequest(requestID: String, action: FriendRequestAction, token: String) async throws -> FriendRequestInfo {
        FriendRequestInfo(
            id: requestID,
            requester: friend,
            addressee: currentUser,
            status: action == .accept ? .accepted : .declined,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            respondedAt: Date(),
            isIncoming: true
        )
    }

    func ensurePrivateChat(friendUserID: String, token: String) async throws -> EnsurePrivateChatResult {
        EnsurePrivateChatResult(
            roomID: "ui-room",
            roomName: "Alice 测试",
            friendID: friendUserID,
            friendName: "Alice 测试"
        )
    }

    func deleteFriend(friendUserID: String, token: String) async throws {}
}

private actor UITestingChatWebSocketService: ChatWebSocketService {
    private var desiredRooms: Set<String> = []
    private var subscribedRooms: Set<String> = []
    private var continuation: AsyncStream<WebSocketServerEvent>.Continuation?

    func connect(accessToken: String?) async throws {}

    func disconnect() async {
        desiredRooms.removeAll()
        subscribedRooms.removeAll()
        continuation?.finish()
        continuation = nil
    }

    func ensureRoomsSubscribed(_ roomIDs: [String], pruneMissing: Bool) async {
        let normalized = Set(roomIDs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        if pruneMissing {
            desiredRooms = normalized
        } else {
            desiredRooms.formUnion(normalized)
        }
        subscribedRooms = desiredRooms
    }

    func eventStream() async -> AsyncStream<WebSocketServerEvent> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    func snapshot() async -> WebSocketClientSnapshot {
        WebSocketClientSnapshot(
            status: .authenticated,
            connectionID: "ui-test-ws",
            desiredRooms: desiredRooms,
            subscribedRooms: subscribedRooms
        )
    }
}

private extension ChatMessage {
    var asQuoteForUITesting: ChatMessageQuote {
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

    func deletingForUITesting() -> ChatMessage {
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
}
#endif
