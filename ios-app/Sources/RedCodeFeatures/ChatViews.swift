import SwiftUI
import RedCodeNetworking

private let defaultReactionKeys = ["👍", "❤️", "😂", "🎉", "😮", "😢"]

public struct ChatHomeView: View {
    private let authController: AuthController
    private let realtimeController: ChatRealtimeController
    private let makeDetailController: @MainActor () -> ChatDetailController

    @State private var listController: ChatListController

    public init(
        authController: AuthController,
        listController: ChatListController,
        realtimeController: ChatRealtimeController,
        makeDetailController: @escaping @MainActor () -> ChatDetailController
    ) {
        self.authController = authController
        self.realtimeController = realtimeController
        self.makeDetailController = makeDetailController
        _listController = State(initialValue: listController)
    }

    public var body: some View {
        Group {
            if listController.chats.isEmpty && listController.isLoading {
                ProgressView("正在加载会话")
            } else if listController.chats.isEmpty {
                ContentUnavailableView(
                    "暂无会话",
                    systemImage: "message",
                    description: Text("好友或群聊产生消息后会显示在这里")
                )
            } else {
                List {
                    ForEach(listController.chats) { chat in
                        NavigationLink {
                            ChatDetailView(
                                authController: authController,
                                chat: chat,
                                realtimeController: realtimeController,
                                controller: makeDetailController()
                            )
                        } label: {
                            ChatSummaryRow(chat: chat)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(chat)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await refresh()
                }
            }
        }
        .navigationTitle("聊天")
        .toolbar {
            ToolbarItem {
                Button {
                    Task {
                        await refresh()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(listController.isLoading)
            }
        }
        .overlay(alignment: .bottom) {
            if let message = listController.errorMessage {
                ErrorBanner(message: message)
            }
        }
        .task {
            await loadInitialChats()
        }
    }

    private func loadInitialChats() async {
        do {
            try listController.loadCachedChats()
        } catch {
            // 缓存读取失败不阻塞远端刷新。
        }
        await refresh()
        await startRealtime()
    }

    private func refresh() async {
        guard let token = authController.session?.token else {
            return
        }
        do {
            try await listController.refreshChats(token: token)
            await realtimeController.syncRooms(listController.chats.map(\.roomID), pruneMissing: true)
        } catch {
            // 控制器已记录 errorMessage，UI 在底部展示。
        }
    }

    private func startRealtime() async {
        guard let session = authController.session else {
            return
        }
        await realtimeController.start(token: session.token, currentUserID: session.user.id)
        await realtimeController.syncRooms(listController.chats.map(\.roomID), pruneMissing: true)
    }

    private func delete(_ chat: ChatSummary) {
        guard let token = authController.session?.token else {
            return
        }
        Task {
            do {
                try await listController.deleteChat(roomID: chat.roomID, token: token)
                await realtimeController.syncRooms(listController.chats.map(\.roomID), pruneMissing: true)
            } catch {
                // 控制器已回滚并记录错误。
            }
        }
    }
}

private struct ChatSummaryRow: View {
    let chat: ChatSummary

    var body: some View {
        HStack(spacing: 12) {
            AvatarCircle(title: chat.displayName, systemImage: chat.roomType == .group ? "person.3.fill" : "person.fill")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(chat.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    if chat.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if chat.isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(chat.lastMessagePreview.isEmpty ? "暂无消息" : chat.lastMessagePreview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                if let lastMessageAt = chat.lastMessageAt {
                    Text(lastMessageAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if chat.unreadCount > 0 {
                    Text(chat.unreadCount > 99 ? "99+" : "\(chat.unreadCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red, in: Capsule())
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct ChatDetailView: View {
    private let authController: AuthController
    private let chat: ChatSummary
    private let realtimeController: ChatRealtimeController

    @State private var controller: ChatDetailController
    @State private var draftText = ""

    init(
        authController: AuthController,
        chat: ChatSummary,
        realtimeController: ChatRealtimeController,
        controller: ChatDetailController
    ) {
        self.authController = authController
        self.chat = chat
        self.realtimeController = realtimeController
        _controller = State(initialValue: controller)
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
            composer
        }
        .navigationTitle(chat.displayName)
        .overlay {
            if controller.isLoading && controller.messages.isEmpty {
                ProgressView("正在加载消息")
            }
        }
        .overlay(alignment: .bottom) {
            if let message = controller.errorMessage {
                ErrorBanner(message: message)
                    .padding(.bottom, 64)
            }
        }
        .task {
            await enterRoom()
        }
        .onDisappear {
            realtimeController.detachDetailController(controller)
            controller.leaveRoom()
        }
    }

    private var messageList: some View {
        Group {
            if controller.messages.isEmpty && !controller.isLoading {
                ContentUnavailableView(
                    "暂无消息",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("发送第一条消息开始聊天")
                )
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(controller.messages) { message in
                            MessageBubble(
                                message: message,
                                isSelf: message.senderID == authController.session?.user.id,
                                onReactionTap: { reactionKey in
                                    toggleReaction(message, reactionKey: reactionKey)
                                }
                            )
                            .id(message.id)
                            .listRowSeparator(.hidden)
                            .contextMenu {
                                if message.status == .failed {
                                    Button {
                                        resend(message)
                                    } label: {
                                        Label("重试", systemImage: "arrow.clockwise")
                                    }
                                }

                                Button {
                                    controller.quoteMessage(messageID: message.id)
                                } label: {
                                    Label("引用", systemImage: "quote.bubble")
                                }

                                Button {
                                    pin(message, pinned: !message.isPinned)
                                } label: {
                                    Label(message.isPinned ? "取消置顶" : "置顶", systemImage: "pin")
                                }

                                ForEach(defaultReactionKeys, id: \.self) { reactionKey in
                                    Button {
                                        toggleReaction(message, reactionKey: reactionKey)
                                    } label: {
                                        Label(reactionKey, systemImage: "face.smiling")
                                    }
                                }

                                if message.senderID == authController.session?.user.id && !message.id.hasPrefix("local-") {
                                    Button(role: .destructive) {
                                        delete(message)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: controller.messages.count) { _, _ in
                        scrollToBottom(proxy)
                    }
                    .onAppear {
                        scrollToBottom(proxy)
                    }
                }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if let quoted = controller.quotedMessage {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("引用 \(quoted.senderName)")
                            .font(.caption.weight(.semibold))
                        Text(quoted.content.isEmpty ? "[非文本消息]" : quoted.content)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        controller.clearQuote()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField("输入消息", text: $draftText, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        send()
                    }

                Button {
                    send()
                } label: {
                    if controller.isSending {
                        ProgressView()
                    } else {
                        Text("发送")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || controller.isSending)
            }
        }
        .padding(12)
        .background(.background)
    }

    private func enterRoom() async {
        guard let session = authController.session else {
            return
        }
        do {
            try await controller.enterRoom(
                roomID: chat.roomID,
                token: session.token,
                currentUserID: session.user.id
            )
            await realtimeController.attachDetailController(controller, roomID: chat.roomID)
        } catch {
            // 控制器已记录 errorMessage。
        }
    }

    private func send() {
        guard let session = authController.session else {
            return
        }
        let text = draftText
        draftText = ""
        Task {
            do {
                _ = try await controller.sendText(
                    text,
                    token: session.token,
                    currentUserID: session.user.id,
                    currentUserName: session.user.displayName
                )
            } catch {
                // pending message 会保留为 failed，用户可通过上下文重试（后续 UI 继续细化）。
            }
        }
    }

    private func delete(_ message: ChatMessage) {
        guard let token = authController.session?.token else {
            return
        }
        Task {
            try? await controller.deleteMessage(messageID: message.id, token: token)
        }
    }

    private func pin(_ message: ChatMessage, pinned: Bool) {
        guard let token = authController.session?.token else {
            return
        }
        Task {
            try? await controller.setMessagePinned(messageID: message.id, pinned: pinned, token: token)
        }
    }

    private func resend(_ message: ChatMessage) {
        guard let token = authController.session?.token else {
            return
        }
        Task {
            try? await controller.resendMessage(messageID: message.id, token: token)
        }
    }

    private func toggleReaction(_ message: ChatMessage, reactionKey: String) {
        guard let token = authController.session?.token else {
            return
        }
        Task {
            try? await controller.toggleReaction(messageID: message.id, reactionKey: reactionKey, token: token)
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let lastID = controller.messages.last?.id else {
            return
        }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let isSelf: Bool
    let onReactionTap: ((String) -> Void)?

    var body: some View {
        HStack {
            if isSelf {
                Spacer(minLength: 48)
            }

            VStack(alignment: isSelf ? .trailing : .leading, spacing: 4) {
                if !isSelf {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    if let quoted = message.quotedMessage {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(quoted.senderName.isEmpty ? "引用消息" : quoted.senderName)
                                .font(.caption2.weight(.semibold))
                            Text(quoted.content.isEmpty ? "[消息]" : quoted.content)
                                .font(.caption2)
                                .lineLimit(2)
                        }
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    }

                    Text(messageText)
                        .foregroundStyle(isSelf ? .white : .primary)

                    HStack(spacing: 6) {
                        Text(message.timestamp, style: .time)
                        if let statusText {
                            Text(statusText)
                        }
                        if message.isPinned {
                            Image(systemName: "pin.fill")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(isSelf ? .white.opacity(0.75) : .secondary)
                }
                .padding(10)
                .background(isSelf ? Color.accentColor : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

                if !visibleReactions.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(visibleReactions) { reaction in
                            Button {
                                onReactionTap?(reaction.reactionKey)
                            } label: {
                                Text("\(reaction.reactionKey) \(reaction.count)")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        reaction.hasSelf ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !isSelf {
                Spacer(minLength: 48)
            }
        }
        .padding(.vertical, 2)
    }

    private var messageText: String {
        if message.isDeleted {
            return "[消息已删除]"
        }
        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        switch message.messageType {
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

    private var statusText: String? {
        switch message.status {
        case .sending:
            return "发送中"
        case .failed:
            return "发送失败"
        case .read:
            return "已读"
        case .deleted:
            return "已删除"
        case .sent, .none:
            return nil
        }
    }

    private var visibleReactions: [MessageReactionSummary] {
        message.reactions.filter { !$0.reactionKey.isEmpty && $0.count > 0 }
    }
}

private struct AvatarCircle: View {
    let title: String
    let systemImage: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.16))
            if let first = title.trimmingCharacters(in: .whitespacesAndNewlines).first {
                Text(String(first))
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
            } else {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: 44, height: 44)
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.red.opacity(0.9), in: Capsule())
            .padding()
    }
}
