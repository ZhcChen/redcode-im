import SwiftUI
import PhotosUI
import RedCodeNetworking
import RedCodeStorage
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

private let defaultReactionKeys = ["👍", "❤️", "😂", "🎉", "😮", "😢"]

private struct NotificationChatRoute: Identifiable, Hashable {
    let roomID: String
    let displayName: String
    let roomType: ChatType

    var id: String { roomID }

    init(chat: ChatSummary) {
        roomID = chat.roomID
        displayName = chat.displayName
        roomType = chat.roomType
    }

    var chatSummary: ChatSummary {
        ChatSummary(roomID: roomID, displayName: displayName, roomType: roomType)
    }
}

public struct ChatHomeView: View {
    private let authController: AuthController
    private let realtimeController: ChatRealtimeController
    private let makeDetailController: @MainActor () -> ChatDetailController
    private let makeGroupManagementController: (@MainActor () -> GroupManagementController)?
    private let contactsController: ContactsController?
    private let mediaAPI: (any MediaAPIService)?
    private let emojiAPI: (any EmojiAPIService)?
    private let attachmentCache: AttachmentFileCache?
    private let avatarCache: AvatarFileCache?
    private let emojiCache: EmojiFileCache?
    private let chatPreferencesStore: (any ChatPreferencesStore)?
    private let makeMessageSearchController: (@MainActor () -> MessageSearchController)?
    private let makeEmojiStickerController: (@MainActor () -> EmojiStickerController)?
    private let notificationNavigation: NotificationNavigationController?

    @State private var listController: ChatListController
    @State private var notificationChatRoute: NotificationChatRoute?

    public init(
        authController: AuthController,
        listController: ChatListController,
        realtimeController: ChatRealtimeController,
        makeDetailController: @escaping @MainActor () -> ChatDetailController,
        makeGroupManagementController: (@MainActor () -> GroupManagementController)? = nil,
        contactsController: ContactsController? = nil,
        mediaAPI: (any MediaAPIService)? = nil,
        emojiAPI: (any EmojiAPIService)? = nil,
        attachmentCache: AttachmentFileCache? = nil,
        avatarCache: AvatarFileCache? = nil,
        emojiCache: EmojiFileCache? = nil,
        chatPreferencesStore: (any ChatPreferencesStore)? = nil,
        makeMessageSearchController: (@MainActor () -> MessageSearchController)? = nil,
        makeEmojiStickerController: (@MainActor () -> EmojiStickerController)? = nil,
        notificationNavigation: NotificationNavigationController? = nil
    ) {
        self.authController = authController
        self.realtimeController = realtimeController
        self.makeDetailController = makeDetailController
        self.makeGroupManagementController = makeGroupManagementController
        self.contactsController = contactsController
        self.mediaAPI = mediaAPI
        self.emojiAPI = emojiAPI
        self.attachmentCache = attachmentCache
        self.avatarCache = avatarCache
        self.emojiCache = emojiCache
        self.chatPreferencesStore = chatPreferencesStore
        self.makeMessageSearchController = makeMessageSearchController
        self.makeEmojiStickerController = makeEmojiStickerController
        self.notificationNavigation = notificationNavigation
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
                                controller: makeDetailController(),
                                chatListController: listController,
                                makeGroupManagementController: makeGroupManagementController,
                                contactsController: contactsController,
                                mediaAPI: mediaAPI,
                                emojiAPI: emojiAPI,
                                attachmentCache: attachmentCache,
                                chatPreferencesStore: chatPreferencesStore,
                                makeMessageSearchController: makeMessageSearchController,
                                makeEmojiStickerController: makeEmojiStickerController
                            )
                        } label: {
                            ChatSummaryRow(
                                chat: chat,
                                token: authController.session?.token,
                                mediaAPI: mediaAPI,
                                avatarCache: avatarCache
                            )
                        }
                        .accessibilityIdentifier("chat.row.\(chat.roomID)")
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
                .accessibilityIdentifier("chat.home.list")
                .refreshable {
                    await refresh()
                }
            }
        }
        .navigationTitle("聊天")
        .toolbar {
            if let makeMessageSearchController {
                ToolbarItem {
                    NavigationLink {
                        MessageSearchView(
                            authController: authController,
                            chats: listController.chats,
                            controller: makeMessageSearchController()
                        )
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
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
        .onChange(of: notificationNavigation?.pendingDestination?.id) { _, _ in
            handlePendingNotificationDestination()
        }
        .navigationDestination(item: $notificationChatRoute) { route in
            ChatDetailView(
                authController: authController,
                chat: route.chatSummary,
                realtimeController: realtimeController,
                controller: makeDetailController(),
                chatListController: listController,
                makeGroupManagementController: makeGroupManagementController,
                contactsController: contactsController,
                mediaAPI: mediaAPI,
                emojiAPI: emojiAPI,
                attachmentCache: attachmentCache,
                chatPreferencesStore: chatPreferencesStore,
                makeMessageSearchController: makeMessageSearchController,
                makeEmojiStickerController: makeEmojiStickerController
            )
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
        handlePendingNotificationDestination()
    }

    private func handlePendingNotificationDestination() {
        guard let destination = notificationNavigation?.pendingDestination else {
            return
        }
        guard case .chat(let roomID, let roomType, let chatName, _) = destination else {
            return
        }
        _ = notificationNavigation?.consumePendingDestination()
        let chat = listController.chats.first { $0.roomID == roomID }
            ?? ChatSummary(roomID: roomID, displayName: chatName, roomType: roomType)
        notificationChatRoute = NotificationChatRoute(chat: chat)
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
    let token: String?
    let mediaAPI: (any MediaAPIService)?
    let avatarCache: AvatarFileCache?

    @State private var cachedAvatarURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            AvatarCircle(
                title: chat.displayName,
                systemImage: chat.roomType == .group ? "person.3.fill" : "person.fill",
                fileURL: cachedAvatarURL,
                remoteURL: chat.avatarURL.flatMap(URL.init(string:))
            )

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
        .task(id: avatarTaskID) {
            await resolveAvatar()
        }
    }

    private var avatarTaskID: String {
        [chat.roomID, chat.friendUserID ?? "", chat.avatarObjectKey ?? "", chat.avatarURL ?? ""].joined(separator: "|")
    }

    private func resolveAvatar() async {
        guard let avatarObjectKey = chat.avatarObjectKey, !avatarObjectKey.isEmpty else {
            cachedAvatarURL = nil
            return
        }
        guard let token, let mediaAPI, let avatarCache else {
            return
        }

        do {
            if chat.roomType == .group {
                if let cached = try await avatarCache.resolveRoomAvatar(roomID: chat.roomID, objectKey: avatarObjectKey) {
                    cachedAvatarURL = cached.fileURL
                    return
                }
                guard let downloadURL = try await mediaAPI.roomAvatarDownloadURL(roomID: chat.roomID, token: token, expiresInSeconds: 3_600) else {
                    return
                }
                let data = try await mediaAPI.download(from: downloadURL)
                let cached = try await avatarCache.saveRoomAvatar(
                    roomID: chat.roomID,
                    objectKey: avatarObjectKey,
                    data: data,
                    suggestedExtension: URL(fileURLWithPath: avatarObjectKey).pathExtension,
                    mimeType: nil
                )
                cachedAvatarURL = cached.fileURL
            } else if let friendUserID = chat.friendUserID, !friendUserID.isEmpty {
                if let cached = try await avatarCache.resolveUserAvatar(userID: friendUserID, objectKey: avatarObjectKey) {
                    cachedAvatarURL = cached.fileURL
                    return
                }
                guard let downloadURL = try await mediaAPI.userAvatarDownloadURL(userID: friendUserID, token: token, expiresInSeconds: 3_600) else {
                    return
                }
                let data = try await mediaAPI.download(from: downloadURL)
                let cached = try await avatarCache.saveUserAvatar(
                    userID: friendUserID,
                    objectKey: avatarObjectKey,
                    data: data,
                    suggestedExtension: URL(fileURLWithPath: avatarObjectKey).pathExtension,
                    mimeType: nil
                )
                cachedAvatarURL = cached.fileURL
            }
        } catch {
            // 头像失败不影响会话列表。
        }
    }
}

struct ChatDetailView: View {
    private let authController: AuthController
    private let chat: ChatSummary
    private let realtimeController: ChatRealtimeController
    private let chatListController: ChatListController?
    private let makeGroupManagementController: (@MainActor () -> GroupManagementController)?
    private let contactsController: ContactsController?
    private let mediaAPI: (any MediaAPIService)?
    private let emojiAPI: (any EmojiAPIService)?
    private let attachmentCache: AttachmentFileCache?
    private let chatPreferencesStore: (any ChatPreferencesStore)?
    private let makeMessageSearchController: (@MainActor () -> MessageSearchController)?
    private let makeEmojiStickerController: (@MainActor () -> EmojiStickerController)?

    @State private var controller: ChatDetailController
    @State private var draftText = ""
    @State private var showEmojiPalette = false
    @State private var backgroundPreference: ChatBackgroundPreference = .default
    @State private var stickerController: EmojiStickerController?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var pendingFiles: [PreparedUploadFile] = []
    @State private var isPreparingMedia = false
    @State private var isFileImporterPresented = false
    @State private var voiceRecorder = VoiceRecorderController()

    init(
        authController: AuthController,
        chat: ChatSummary,
        realtimeController: ChatRealtimeController,
        controller: ChatDetailController,
        chatListController: ChatListController? = nil,
        makeGroupManagementController: (@MainActor () -> GroupManagementController)? = nil,
        contactsController: ContactsController? = nil,
        mediaAPI: (any MediaAPIService)? = nil,
        emojiAPI: (any EmojiAPIService)? = nil,
        attachmentCache: AttachmentFileCache? = nil,
        chatPreferencesStore: (any ChatPreferencesStore)? = nil,
        makeMessageSearchController: (@MainActor () -> MessageSearchController)? = nil,
        makeEmojiStickerController: (@MainActor () -> EmojiStickerController)? = nil
    ) {
        self.authController = authController
        self.chat = chat
        self.realtimeController = realtimeController
        self.chatListController = chatListController
        self.makeGroupManagementController = makeGroupManagementController
        self.contactsController = contactsController
        self.mediaAPI = mediaAPI
        self.emojiAPI = emojiAPI
        self.attachmentCache = attachmentCache
        self.chatPreferencesStore = chatPreferencesStore
        self.makeMessageSearchController = makeMessageSearchController
        self.makeEmojiStickerController = makeEmojiStickerController
        _controller = State(initialValue: controller)
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
            composer
        }
        .accessibilityIdentifier("chat.detail")
        .navigationTitle(chat.displayName)
        .toolbar {
            if let makeMessageSearchController {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        MessageSearchView(
                            authController: authController,
                            chats: chatListController?.chats ?? [chat],
                            initialRoomID: chat.roomID,
                            controller: makeMessageSearchController()
                        )
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            if chat.roomType == .group,
               let chatListController,
               let makeGroupManagementController {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        GroupSettingsView(
                            authController: authController,
                            chat: chat,
                            chatListController: chatListController,
                            realtimeController: realtimeController,
                            contactsController: contactsController,
                            controller: makeGroupManagementController()
                        )
                    } label: {
                        Image(systemName: "person.3.sequence.fill")
                    }
                    .accessibilityIdentifier("chat.group-settings")
                }
            }
        }
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
            await loadBackgroundPreference()
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
                                roomID: chat.roomID,
                                token: authController.session?.token,
                                mediaAPI: mediaAPI,
                                attachmentCache: attachmentCache,
                                onReactionTap: { reactionKey in
                                    toggleReaction(message, reactionKey: reactionKey)
                                }
                            )
                            .accessibilityIdentifier("chat.message.\(message.id)")
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
                    .scrollContentBackground(.hidden)
                    .background(backgroundPreference.swiftUIColor)
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

            if !pendingFiles.isEmpty {
                PendingAttachmentStrip(files: pendingFiles) { file in
                    pendingFiles.removeAll { $0.localURL == file.localURL }
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 6,
                    matching: .any(of: [.images, .videos])
                ) {
                    Image(systemName: "photo.on.rectangle")
                }
                .disabled(mediaAPI == nil || isPreparingMedia)

                Button {
                    isFileImporterPresented = true
                } label: {
                    Image(systemName: "paperclip")
                }
                .disabled(mediaAPI == nil || isPreparingMedia)

                Button {
                    showEmojiPalette.toggle()
                } label: {
                    Image(systemName: "face.smiling")
                }

                Button {
                    toggleVoiceRecording()
                } label: {
                    Image(systemName: voiceRecorder.isRecording ? "stop.circle.fill" : "mic.circle")
                        .foregroundStyle(voiceRecorder.isRecording ? .red : .primary)
                }
                .disabled(mediaAPI == nil || isPreparingMedia)

                TextField("输入消息", text: $draftText, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("chat.composer.input")
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
                .accessibilityIdentifier("chat.composer.send")
                .disabled(
                    (draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingFiles.isEmpty)
                        || controller.isSending
                        || isPreparingMedia
                )
            }
        }
        .padding(12)
        .background(.background)
        .overlay(alignment: .topLeading) {
            if showEmojiPalette {
                ChatComposerEmojiPanel(
                    stickerController: stickerController,
                    token: authController.session?.token,
                    onEmojiSelect: { emoji in
                        draftText.append(emoji)
                    },
                    onStickerSelect: sendSticker
                )
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 12)
                .offset(y: -300)
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .onChange(of: selectedPhotoItems) { _, items in
            Task {
                await preparePhotoItems(items)
            }
        }
        .onChange(of: showEmojiPalette) { _, isShown in
            if isShown {
                loadStickerPacksIfNeeded()
            }
        }
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

    private func loadBackgroundPreference() async {
        guard let chatPreferencesStore else {
            return
        }
        if let preference = try? await chatPreferencesStore.loadBackground() {
            backgroundPreference = preference
        }
    }

    private func loadStickerPacksIfNeeded() {
        guard let token = authController.session?.token,
              let makeEmojiStickerController else {
            return
        }
        let resolvedController: EmojiStickerController
        if let stickerController {
            resolvedController = stickerController
        } else {
            let newController = makeEmojiStickerController()
            stickerController = newController
            resolvedController = newController
        }
        Task {
            await resolvedController.load(token: token)
        }
    }

    private func send() {
        guard let session = authController.session else {
            return
        }
        let text = draftText
        draftText = ""
        showEmojiPalette = false
        let files = pendingFiles
        pendingFiles = []
        Task {
            do {
                if files.isEmpty {
                    _ = try await controller.sendText(
                        text,
                        token: session.token,
                        currentUserID: session.user.id,
                        currentUserName: session.user.displayName
                    )
                } else {
                    _ = try await controller.sendPreparedMedia(
                        files: files,
                        caption: text,
                        token: session.token,
                        currentUserID: session.user.id,
                        currentUserName: session.user.displayName
                    )
                }
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

    private func sendSticker(_ item: EmojiItem) {
        guard let session = authController.session,
              let stickerController else {
            return
        }
        showEmojiPalette = false
        Task {
            do {
                guard let fileURL = await stickerController.resolveEmojiImage(item: item, token: session.token) else {
                    controller.setErrorMessage("表情图片加载失败")
                    return
                }
                let prepared = try MediaUploadPreparer.prepareFile(
                    at: fileURL,
                    kind: .image,
                    fileName: item.preparedUploadFileName,
                    contentType: item.preferredImageContentType
                )
                _ = try await controller.sendPreparedMedia(
                    files: [prepared],
                    token: session.token,
                    currentUserID: session.user.id,
                    currentUserName: session.user.displayName
                )
            } catch {
                controller.setErrorMessage(error.localizedDescription)
            }
        }
    }

    private func preparePhotoItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else {
            return
        }
        isPreparingMedia = true
        defer {
            isPreparingMedia = false
            selectedPhotoItems = []
        }

        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    continue
                }
                let contentType = item.supportedContentTypes.first
                let ext = contentType?.preferredFilenameExtension ?? "bin"
                let fileName = "photo-\(UUID().uuidString).\(ext)"
                let url = try MediaUploadPreparer.writeTemporaryFile(data: data, preferredFileName: fileName)
                let kind: PreparedUploadKind = contentType?.conforms(to: .movie) == true ? .video : .image
                let prepared = try MediaUploadPreparer.prepareFile(
                    at: url,
                    kind: kind,
                    fileName: fileName,
                    contentType: contentType?.preferredMIMEType
                )
                pendingFiles.append(prepared)
            } catch {
                controller.setErrorMessage(error.localizedDescription)
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            for sourceURL in urls {
                let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccessing {
                        sourceURL.stopAccessingSecurityScopedResource()
                    }
                }
                let data = try Data(contentsOf: sourceURL)
                let tempURL = try MediaUploadPreparer.writeTemporaryFile(
                    data: data,
                    preferredFileName: sourceURL.lastPathComponent
                )
                pendingFiles.append(try MediaUploadPreparer.prepareFile(at: tempURL))
            }
        } catch {
            controller.setErrorMessage(error.localizedDescription)
        }
    }

    private func toggleVoiceRecording() {
        if voiceRecorder.isRecording {
            do {
                let file = try voiceRecorder.stop()
                pendingFiles.append(file)
            } catch {
                controller.setErrorMessage(error.localizedDescription)
            }
            return
        }

        Task {
            do {
                try await voiceRecorder.start()
            } catch {
                controller.setErrorMessage(error.localizedDescription)
            }
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
    let roomID: String
    let token: String?
    let mediaAPI: (any MediaAPIService)?
    let attachmentCache: AttachmentFileCache?
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

                    if !message.attachments.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(message.parts.filter { $0.attachment != nil }, id: \.position) { part in
                                AttachmentContentView(
                                    part: part,
                                    roomID: roomID,
                                    token: token,
                                    mediaAPI: mediaAPI,
                                    attachmentCache: attachmentCache,
                                    isSelf: isSelf
                                )
                            }
                        }
                    }

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
    var fileURL: URL?
    var remoteURL: URL?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.16))
            if let fileURL, let image = platformImage(from: fileURL) {
                image
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else if let remoteURL {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        fallback
                    }
                }
                .clipShape(Circle())
            } else {
                fallback
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }

    @ViewBuilder
    private var fallback: some View {
        if let first = title.trimmingCharacters(in: .whitespacesAndNewlines).first {
                Text(String(first))
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
        } else {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
        }
    }
}

private struct PendingAttachmentStrip: View {
    let files: [PreparedUploadFile]
    let onRemove: (PreparedUploadFile) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(files, id: \.localURL) { file in
                    HStack(spacing: 6) {
                        Image(systemName: file.kind.systemImageName)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.fileName)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Text(file.size.formattedByteCount)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            onRemove(file)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.secondary.opacity(0.12), in: Capsule())
                }
            }
        }
    }
}

private struct ChatComposerEmojiPanel: View {
    let stickerController: EmojiStickerController?
    let token: String?
    let onEmojiSelect: (String) -> Void
    let onStickerSelect: (EmojiItem) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Emoji")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                BuiltInEmojiPalette(onSelect: onEmojiSelect)

                if let stickerController {
                    Divider()
                    HStack {
                        Text("我的表情")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if stickerController.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    let packs = stickerController.myPacks.filter { !$0.items.isEmpty }
                    if packs.isEmpty {
                        Text("暂无自定义表情，可到设置 > 聊天设置 > 表情管理添加。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(packs) { pack in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(pack.name)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 46), spacing: 10)], spacing: 10) {
                                    ForEach(pack.items) { item in
                                        StickerItemButton(
                                            item: item,
                                            token: token,
                                            stickerController: stickerController,
                                            onSelect: onStickerSelect
                                        )
                                    }
                                }
                            }
                        }
                    }

                    if let error = stickerController.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(12)
        }
        .frame(maxHeight: 280)
    }
}

private struct StickerItemButton: View {
    let item: EmojiItem
    let token: String?
    let stickerController: EmojiStickerController
    let onSelect: (EmojiItem) -> Void

    @State private var fileURL: URL?

    var body: some View {
        Button {
            onSelect(item)
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 46, height: 46)

                    if let fileURL, let image = platformImage(from: fileURL) {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                    } else {
                        Image(systemName: "face.smiling")
                            .foregroundStyle(Color.accentColor)
                    }
                }

                if let name = item.name?.nilIfEmpty {
                    Text(name)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
        .task(id: item.id) {
            guard let token else {
                return
            }
            fileURL = await stickerController.resolveEmojiImage(item: item, token: token)
        }
    }
}

private struct AttachmentContentView: View {
    let part: ChatMessagePart
    let roomID: String
    let token: String?
    let mediaAPI: (any MediaAPIService)?
    let attachmentCache: AttachmentFileCache?
    let isSelf: Bool

    @State private var cachedFileURL: URL?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var playback = VoicePlaybackController()

    private var attachment: ChatMessageAttachment? {
        part.attachment
    }

    var body: some View {
        Button {
            Task {
                await loadIfNeeded(playAudioWhenReady: part.partType == .audio)
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                if part.partType == .image,
                   let cachedFileURL,
                   let image = platformImage(from: cachedFileURL) {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220, maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: part.partType.attachmentSystemImageName)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(detailText)
                                .font(.caption2)
                                .foregroundStyle(isSelf ? .white.opacity(0.75) : .secondary)
                        }
                        if isLoading {
                            ProgressView()
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
        .buttonStyle(.plain)
        .task(id: attachment?.key) {
            if part.partType == .image {
                await loadIfNeeded(playAudioWhenReady: false)
            }
        }
    }

    private var displayName: String {
        attachment?.name?.nilIfEmpty ?? part.partType.attachmentFallbackName
    }

    private var detailText: String {
        let size = attachment?.size.map(\.formattedByteCount)
        let duration = attachment?.durationMilliseconds.map { "\($0 / 1_000)s" }
        return [attachment?.mimeType, size, duration]
            .compactMap { $0?.nilIfEmpty }
            .joined(separator: " · ")
    }

    private func loadIfNeeded(playAudioWhenReady: Bool) async {
        guard let attachment else {
            return
        }
        if let localURL = URL(string: attachment.key), localURL.isFileURL {
            cachedFileURL = localURL
            playIfNeeded(url: localURL, playAudioWhenReady: playAudioWhenReady)
            return
        }
        guard cachedFileURL == nil else {
            if let cachedFileURL {
                playIfNeeded(url: cachedFileURL, playAudioWhenReady: playAudioWhenReady)
            }
            return
        }
        guard let token, let mediaAPI, let attachmentCache else {
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if let cached = try await attachmentCache.resolve(objectKey: attachment.key) {
                cachedFileURL = cached.fileURL
                playIfNeeded(url: cached.fileURL, playAudioWhenReady: playAudioWhenReady)
                return
            }
            guard let downloadURL = try await mediaAPI.messageAttachmentDownloadURL(
                roomID: roomID,
                key: attachment.key,
                token: token,
                expiresInSeconds: 600
            ) else {
                return
            }
            let data = try await mediaAPI.download(from: downloadURL)
            let cached = try await attachmentCache.save(
                objectKey: attachment.key,
                data: data,
                suggestedExtension: URL(fileURLWithPath: attachment.key).pathExtension,
                mimeType: attachment.mimeType
            )
            cachedFileURL = cached.fileURL
            playIfNeeded(url: cached.fileURL, playAudioWhenReady: playAudioWhenReady)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func playIfNeeded(url: URL, playAudioWhenReady: Bool) {
        guard playAudioWhenReady else {
            return
        }
        do {
            try playback.play(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#if canImport(UIKit)
private func platformImage(from url: URL) -> Image? {
    guard let image = UIImage(contentsOfFile: url.path) else {
        return nil
    }
    return Image(uiImage: image)
}
#elseif canImport(AppKit)
private func platformImage(from url: URL) -> Image? {
    guard let image = NSImage(contentsOf: url) else {
        return nil
    }
    return Image(nsImage: image)
}
#else
private func platformImage(from url: URL) -> Image? {
    nil
}
#endif

private extension PreparedUploadKind {
    var systemImageName: String {
        switch self {
        case .image:
            "photo"
        case .video:
            "video"
        case .audio:
            "waveform"
        case .file:
            "doc"
        }
    }
}

private extension ChatMessageType {
    var attachmentSystemImageName: String {
        switch self {
        case .image:
            "photo"
        case .video:
            "play.rectangle"
        case .audio:
            "waveform.circle"
        case .file:
            "doc"
        case .mixed:
            "paperclip"
        case .system:
            "info.circle"
        case .text:
            "text.bubble"
        }
    }

    var attachmentFallbackName: String {
        switch self {
        case .image:
            "图片"
        case .video:
            "视频"
        case .audio:
            "语音"
        case .file:
            "文件"
        case .mixed:
            "附件"
        case .system:
            "系统消息"
        case .text:
            "文本"
        }
    }
}

private extension EmojiItem {
    var preparedUploadFileName: String {
        let fallbackName = name?.nilIfEmpty ?? id
        let sanitizedBase = String(fallbackName
            .map { character in
                character.isLetter || character.isNumber || character == "-" || character == "_" ? character : "-"
            })
        let ext = preferredImageExtension
        return sanitizedBase.hasSuffix(".\(ext)") ? sanitizedBase : "\(sanitizedBase).\(ext)"
    }

    var preferredImageContentType: String {
        UTType(filenameExtension: preferredImageExtension)?.preferredMIMEType ?? "image/png"
    }

    private var preferredImageExtension: String {
        let objectKeyExtension = imageObjectKey
            .flatMap { URL(fileURLWithPath: $0).pathExtension.nilIfEmpty }
        let imageURLExtension = URL(string: imageURL)?.pathExtension.nilIfEmpty
            ?? URL(fileURLWithPath: imageURL).pathExtension.nilIfEmpty
        return objectKeyExtension ?? imageURLExtension ?? "png"
    }
}

private extension Int64 {
    var formattedByteCount: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct ErrorBanner: View {
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
