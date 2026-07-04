import SwiftUI
import RedCodeNetworking
import RedCodeStorage

public struct MessageSearchView: View {
    let authController: AuthController
    let chats: [ChatSummary]
    let initialRoomID: String?
    @State private var controller: MessageSearchController
    @State private var query = ""
    @State private var selectedRoomID = ""
    @State private var selectedMessageType = ""

    public init(
        authController: AuthController,
        chats: [ChatSummary],
        initialRoomID: String? = nil,
        controller: MessageSearchController
    ) {
        self.authController = authController
        self.chats = chats
        self.initialRoomID = initialRoomID
        _controller = State(initialValue: controller)
        _selectedRoomID = State(initialValue: initialRoomID ?? "")
    }

    public var body: some View {
        List {
            Section {
                TextField("搜索消息内容", text: $query)
                    .onSubmit { runSearch() }

                Picker("会话", selection: $selectedRoomID) {
                    Text("全部会话").tag("")
                    ForEach(chats) { chat in
                        Text(chat.displayName).tag(chat.roomID)
                    }
                }

                Picker("类型", selection: $selectedMessageType) {
                    Text("全部类型").tag("")
                    Text("文本").tag(ChatMessageType.text.rawValue)
                    Text("图片").tag(ChatMessageType.image.rawValue)
                    Text("语音").tag(ChatMessageType.audio.rawValue)
                    Text("视频").tag(ChatMessageType.video.rawValue)
                    Text("文件").tag(ChatMessageType.file.rawValue)
                    Text("多媒体").tag(ChatMessageType.mixed.rawValue)
                }

                Button {
                    runSearch()
                } label: {
                    if controller.isSearching {
                        ProgressView()
                    } else {
                        Text("搜索")
                    }
                }
                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } footer: {
                if controller.isIndexing {
                    Text("正在从本地聊天缓存构建搜索索引")
                } else {
                    Text("优先搜索本地缓存，随后合并服务端结果。")
                }
            }

            if let error = controller.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }

            Section {
                if controller.results.isEmpty {
                    ContentUnavailableView(
                        "暂无结果",
                        systemImage: "magnifyingglass",
                        description: Text(query.isEmpty ? "输入关键词开始搜索" : "没有匹配的消息")
                    )
                } else {
                    ForEach(controller.results) { result in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(result.roomName)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(result.source)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(result.senderName)：\(result.matchedText ?? result.content)")
                                .font(.body)
                                .lineLimit(3)
                            HStack {
                                Text(result.messageType)
                                Text(result.timestamp, style: .date)
                                Text(result.timestamp, style: .time)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    if controller.hasMore {
                        Button("加载更多") {
                            Task {
                                await controller.loadMore(
                                    query: query,
                                    roomID: selectedRoomID.nilIfEmpty,
                                    messageType: selectedMessageType.chatMessageType,
                                    token: authController.session?.token
                                )
                            }
                        }
                    }
                }
            } header: {
                Text("搜索结果 \(controller.totalResults)")
            }
        }
        .navigationTitle("搜索消息")
        .task {
            controller.rebuildIndex(chats: chats)
        }
    }

    private func runSearch() {
        Task {
            await controller.search(
                query: query,
                roomID: selectedRoomID.nilIfEmpty,
                messageType: selectedMessageType.chatMessageType,
                token: authController.session?.token
            )
        }
    }
}

public struct ChatSettingsView: View {
    let authController: AuthController
    @State private var settingsController: ChatSettingsController
    @State private var stickerController: EmojiStickerController

    public init(
        authController: AuthController,
        settingsController: ChatSettingsController,
        stickerController: EmojiStickerController
    ) {
        self.authController = authController
        _settingsController = State(initialValue: settingsController)
        _stickerController = State(initialValue: stickerController)
    }

    public var body: some View {
        List {
            Section {
                NavigationLink("聊天背景") {
                    ChatBackgroundSettingsView(controller: settingsController)
                }
                NavigationLink("表情管理") {
                    StickerManagementView(authController: authController, controller: stickerController)
                }
            }

            Section {
                Button(role: .destructive) {
                    Task {
                        await settingsController.clearAllCaches()
                    }
                } label: {
                    if settingsController.isWorking {
                        ProgressView()
                    } else {
                        Text("清除媒体/头像/表情缓存")
                    }
                }

                Button(role: .destructive) {
                    Task {
                        await settingsController.clearChatHistory()
                    }
                } label: {
                    Text("清空本地聊天记录")
                }
            }

            if let error = settingsController.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("聊天")
        .task {
            await settingsController.load()
        }
    }
}

public struct ChatBackgroundSettingsView: View {
    @State private var controller: ChatSettingsController

    public init(controller: ChatSettingsController) {
        _controller = State(initialValue: controller)
    }

    public var body: some View {
        List {
            Section("预览") {
                RoundedRectangle(cornerRadius: 18)
                    .fill(controller.background.swiftUIColor)
                    .frame(height: 180)
                    .overlay {
                        VStack(spacing: 10) {
                            Text("预览效果")
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.regularMaterial, in: Capsule())
                            Text("聊天气泡会显示在此背景上")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
            }

            Section("纯色背景") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 12)], spacing: 12) {
                    ForEach(chatBackgroundPresets) { preset in
                        Button {
                            Task {
                                await controller.saveBackground(
                                    preset.id == "default"
                                        ? .default
                                        : ChatBackgroundPreference(kind: .preset, value: preset.id)
                                )
                            }
                        } label: {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(preset.color)
                                .frame(height: 48)
                                .overlay {
                                    if isSelected(preset) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(.secondary.opacity(0.25), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("聊天背景")
        .task {
            await controller.load()
        }
    }

    private func isSelected(_ preset: ChatBackgroundPreset) -> Bool {
        controller.background == preset.preference
    }
}

public struct StickerManagementView: View {
    let authController: AuthController
    @State private var controller: EmojiStickerController
    @State private var searchKeyword = ""

    public init(authController: AuthController, controller: EmojiStickerController) {
        self.authController = authController
        _controller = State(initialValue: controller)
    }

    public var body: some View {
        List {
            if let error = controller.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }

            Section("搜索") {
                TextField("搜索表情包", text: $searchKeyword)
                    .onSubmit { search() }
                Button("搜索") { search() }
                    .disabled(searchKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                ForEach(controller.searchResults) { pack in
                    StickerPackRow(pack: pack) {
                        add(pack)
                    }
                }
            }

            Section("我的表情") {
                if controller.myPacks.isEmpty {
                    Text("暂无表情包").foregroundStyle(.secondary)
                }
                ForEach(controller.myPacks) { pack in
                    StickerPackRow(pack: pack) {
                        remove(pack)
                    } trailingTitle: {
                        pack.packType == .suite ? "移除套装" : "移除"
                    }
                }
            }

            Section("表情商店") {
                if controller.availablePacks.isEmpty && controller.isLoading {
                    ProgressView()
                } else if controller.availablePacks.isEmpty {
                    Text("暂无可用表情").foregroundStyle(.secondary)
                }
                ForEach(controller.availablePacks) { pack in
                    StickerPackRow(pack: pack) {
                        add(pack)
                    }
                }
            }
        }
        .navigationTitle("表情管理")
        .task {
            guard let token = authController.session?.token else {
                return
            }
            await controller.load(token: token)
        }
        .refreshable {
            guard let token = authController.session?.token else {
                return
            }
            await controller.load(token: token)
        }
    }

    private func search() {
        guard let token = authController.session?.token else {
            return
        }
        Task {
            await controller.search(keyword: searchKeyword, token: token)
        }
    }

    private func add(_ pack: EmojiPack) {
        guard let token = authController.session?.token else {
            return
        }
        Task {
            await controller.add(pack: pack, token: token)
        }
    }

    private func remove(_ pack: EmojiPack) {
        guard let token = authController.session?.token else {
            return
        }
        Task {
            await controller.remove(pack: pack, token: token)
        }
    }
}

public struct BuiltInEmojiPalette: View {
    let onSelect: (String) -> Void

    public init(onSelect: @escaping (String) -> Void) {
        self.onSelect = onSelect
    }

    public var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 38), spacing: 10)], spacing: 10) {
            ForEach(redCodeBuiltInEmoji, id: \.self) { emoji in
                Button {
                    onSelect(emoji)
                } label: {
                    Text(emoji)
                        .font(.title3)
                        .frame(width: 38, height: 38)
                        .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
    }
}

private struct StickerPackRow: View {
    let pack: EmojiPack
    let action: () -> Void
    var trailingTitle: () -> String = { "添加" }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 46, height: 46)
                .overlay {
                    Image(systemName: pack.packType == .suite ? "square.grid.2x2" : "face.smiling")
                        .foregroundStyle(Color.accentColor)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(pack.name)
                    .font(.headline)
                Text("\(pack.items.count) 个表情")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(trailingTitle()) {
                action()
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}

private struct ChatBackgroundPreset: Identifiable {
    let id: String
    let color: Color

    var preference: ChatBackgroundPreference {
        id == "default" ? .default : ChatBackgroundPreference(kind: .preset, value: id)
    }
}

private let chatBackgroundPresets: [ChatBackgroundPreset] = [
    ChatBackgroundPreset(id: "default", color: .white),
    ChatBackgroundPreset(id: "gray", color: Color(red: 0.96, green: 0.96, blue: 0.96)),
    ChatBackgroundPreset(id: "blue", color: Color(red: 0.91, green: 0.96, blue: 0.99)),
    ChatBackgroundPreset(id: "yellow", color: Color(red: 1.0, green: 0.97, blue: 0.88)),
    ChatBackgroundPreset(id: "green", color: Color(red: 0.91, green: 0.97, blue: 0.91)),
    ChatBackgroundPreset(id: "pink", color: Color(red: 0.99, green: 0.91, blue: 0.94)),
    ChatBackgroundPreset(id: "purple", color: Color(red: 0.96, green: 0.92, blue: 0.98)),
    ChatBackgroundPreset(id: "cyan", color: Color(red: 0.9, green: 0.98, blue: 0.99)),
]

public extension ChatBackgroundPreference {
    var swiftUIColor: Color {
        guard kind == .preset, let value else {
            return .white
        }
        return chatBackgroundPresets.first { $0.id == value }?.color ?? .white
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var chatMessageType: ChatMessageType? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        return ChatMessageType(rawValue: trimmed)
    }
}
