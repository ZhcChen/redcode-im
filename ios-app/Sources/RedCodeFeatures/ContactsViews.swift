import SwiftUI
import RedCodeCore
import RedCodeNetworking

public struct ContactsHomeView: View {
    private let authController: AuthController
    private let chatListController: ChatListController
    private let realtimeController: ChatRealtimeController
    private let makeDetailController: @MainActor () -> ChatDetailController

    @State private var contactsController: ContactsController
    @State private var addFriendController: AddFriendController
    @State private var activeChat: ChatSummary?

    public init(
        authController: AuthController,
        contactsController: ContactsController,
        addFriendController: AddFriendController,
        chatListController: ChatListController,
        realtimeController: ChatRealtimeController,
        makeDetailController: @escaping @MainActor () -> ChatDetailController
    ) {
        self.authController = authController
        self.chatListController = chatListController
        self.realtimeController = realtimeController
        self.makeDetailController = makeDetailController
        _contactsController = State(initialValue: contactsController)
        _addFriendController = State(initialValue: addFriendController)
    }

    public var body: some View {
        List {
            Section {
                NavigationLink {
                    AddFriendView(
                        authController: authController,
                        addFriendController: addFriendController,
                        contactsController: contactsController
                    )
                } label: {
                    HStack(spacing: 12) {
                        ContactIcon(systemImage: "person.badge.plus.fill", tint: .blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("新的朋友")
                            Text("搜索用户、处理好友申请")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if contactsController.pendingIncomingCount > 0 {
                            Text("\(contactsController.pendingIncomingCount)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.red, in: Capsule())
                        }
                    }
                }
                .accessibilityIdentifier("contacts.new-friends")
            }

            Section("联系人") {
                if contactsController.contacts.isEmpty && !contactsController.isLoading {
                    ContentUnavailableView(
                        "暂无联系人",
                        systemImage: "person.2",
                        description: Text("添加好友后会显示在这里")
                    )
                } else {
                    ForEach(contactsController.contacts) { contact in
                        NavigationLink {
                            ContactDetailView(
                                contact: contact,
                                isLoading: contactsController.isLoading,
                                errorMessage: contactsController.errorMessage,
                                onOpenChat: {
                                    await openChat(contact)
                                },
                                onDelete: {
                                    await deleteContact(contact)
                                }
                            )
                        } label: {
                            ContactRow(contact: contact)
                        }
                        .accessibilityIdentifier("contacts.row.\(contact.userID)")
                    }
                }
            }
        }
        .navigationTitle("联系人")
        .toolbar {
            ToolbarItem {
                Button {
                    Task {
                        await refresh()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(contactsController.isLoading)
            }
        }
        .overlay {
            if contactsController.isLoading && contactsController.contacts.isEmpty {
                ProgressView("正在加载联系人")
            }
        }
        .overlay(alignment: .bottom) {
            if let message = contactsController.errorMessage {
                ErrorBanner(message: message)
            }
        }
        .refreshable {
            await refresh()
        }
        .navigationDestination(isPresented: activeChatPresented) {
            if let activeChat {
                ChatDetailView(
                    authController: authController,
                    chat: activeChat,
                    realtimeController: realtimeController,
                    controller: makeDetailController()
                )
            }
        }
        .task {
            await loadInitialContacts()
        }
    }

    private var activeChatPresented: Binding<Bool> {
        Binding(
            get: { activeChat != nil },
            set: { isPresented in
                if !isPresented {
                    activeChat = nil
                }
            }
        )
    }

    private func loadInitialContacts() async {
        do {
            try contactsController.loadCachedContacts()
        } catch {
            // 缓存读取失败不阻塞远端刷新。
        }
        await refresh()
    }

    private func refresh() async {
        guard let token = authController.session?.token else {
            return
        }
        do {
            try await contactsController.refreshContacts(token: token)
        } catch {
            // 控制器已记录错误。
        }
    }

    private func openChat(_ contact: ContactSummary) async {
        guard let token = authController.session?.token else {
            return
        }
        do {
            let chat = try await contactsController.ensurePrivateChat(contact: contact, token: token)
            try chatListController.upsertChatSummary(chat)
            await realtimeController.syncRooms(chatListController.chats.map(\.roomID), pruneMissing: false)
            activeChat = chat
        } catch {
            // 控制器或系统弹层会保留当前页面，错误后续统一收口展示。
        }
    }

    private func deleteContact(_ contact: ContactSummary) async -> Bool {
        guard let token = authController.session?.token else {
            return false
        }
        do {
            try await contactsController.deleteContact(userID: contact.userID, token: token)
            return true
        } catch {
            // 控制器已回滚并记录错误。
            return false
        }
    }
}

private struct AddFriendView: View {
    let authController: AuthController
    let addFriendController: AddFriendController
    let contactsController: ContactsController

    @State private var keyword = ""
    @State private var requestMessage = ""
    @State private var sentUserIDs: Set<String> = []

    var body: some View {
        List {
            Section {
                TextField("输入账号或昵称", text: $keyword)
                    .onSubmit {
                        Task {
                            await search()
                        }
                    }

                Button {
                    Task {
                        await search()
                    }
                } label: {
                    HStack {
                        Spacer()
                        if addFriendController.isSearching {
                            ProgressView()
                        } else {
                            Text("搜索")
                        }
                        Spacer()
                    }
                }
                .disabled(keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                TextField("申请备注（可选）", text: $requestMessage)
            } header: {
                Text("添加好友")
            }

            if !addFriendController.searchResults.isEmpty {
                Section("搜索结果") {
                    ForEach(addFriendController.searchResults, id: \.id) { user in
                        UserSearchResultRow(
                            user: user,
                            isSent: sentUserIDs.contains(user.id),
                            onSend: {
                                await sendRequest(to: user)
                            }
                        )
                    }
                }
            }

            Section("待处理申请") {
                if addFriendController.incomingRequests.isEmpty && !addFriendController.isLoadingRequests {
                    Text("暂无新的好友申请")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(addFriendController.incomingRequests) { request in
                        FriendRequestRow(
                            request: request,
                            onAccept: {
                                await respond(request, action: .accept)
                            },
                            onDecline: {
                                await respond(request, action: .decline)
                            }
                        )
                    }
                }
            }

            if !addFriendController.outgoingRequests.isEmpty {
                Section("已发送申请") {
                    ForEach(addFriendController.outgoingRequests) { request in
                        HStack {
                            ContactIcon(title: request.counterparty.displayName, systemImage: "person.fill")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(request.counterparty.displayName)
                                Text("等待对方验证")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("新的朋友")
        .overlay(alignment: .bottom) {
            if let message = addFriendController.errorMessage {
                ErrorBanner(message: message)
            }
        }
        .task {
            await loadRequests()
        }
        .refreshable {
            await loadRequests()
        }
    }

    private func search() async {
        guard let token = authController.session?.token else {
            return
        }
        do {
            try await addFriendController.searchUsers(keyword: keyword, token: token)
        } catch {
            // 控制器已记录错误。
        }
    }

    private func sendRequest(to user: AuthUser) async {
        guard let token = authController.session?.token else {
            return
        }
        do {
            _ = try await addFriendController.sendFriendRequest(
                targetUserID: user.id,
                message: requestMessage,
                token: token
            )
            sentUserIDs.insert(user.id)
        } catch {
            // 控制器已记录错误。
        }
    }

    private func loadRequests() async {
        guard let token = authController.session?.token else {
            return
        }
        do {
            try await addFriendController.loadRequests(token: token)
            try await contactsController.refreshIncomingRequestBadge(token: token)
        } catch {
            // 控制器已记录错误。
        }
    }

    private func respond(_ request: FriendRequestInfo, action: FriendRequestAction) async {
        guard let token = authController.session?.token else {
            return
        }
        do {
            _ = try await addFriendController.respondRequest(
                requestID: request.id,
                action: action,
                token: token
            )
            try await contactsController.refreshContacts(token: token)
        } catch {
            // 控制器已记录错误。
        }
    }
}

private struct ContactDetailView: View {
    let contact: ContactSummary
    let isLoading: Bool
    let errorMessage: String?
    let onOpenChat: () async -> Void
    let onDelete: () async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    ContactIcon(title: contact.displayName, systemImage: "person.fill", size: 72)
                    Text(contact.displayName)
                        .font(.title2.weight(.semibold))
                    Text(contact.username)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section {
                Button {
                    Task {
                        await onOpenChat()
                    }
                } label: {
                    Label("发消息", systemImage: "message.fill")
                }
                .disabled(isLoading)

                Button("删除好友", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .disabled(isLoading)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("联系人详情")
        .confirmationDialog("确定删除这个好友吗？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("删除好友", role: .destructive) {
                Task {
                    if await onDelete() {
                        dismiss()
                    }
                }
            }
            Button("取消", role: .cancel) {}
        }
    }
}

private struct ContactRow: View {
    let contact: ContactSummary

    var body: some View {
        HStack(spacing: 12) {
            ContactIcon(title: contact.displayName, systemImage: "person.fill")
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .lineLimit(1)
                Text(contact.username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct UserSearchResultRow: View {
    let user: AuthUser
    let isSent: Bool
    let onSend: () async -> Void

    var body: some View {
        HStack(spacing: 12) {
            ContactIcon(title: user.displayName, systemImage: "person.fill")
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                Text(user.username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(isSent ? "已发送" : "添加") {
                Task {
                    await onSend()
                }
            }
            .disabled(isSent)
            .buttonStyle(.bordered)
        }
    }
}

private struct FriendRequestRow: View {
    let request: FriendRequestInfo
    let onAccept: () async -> Void
    let onDecline: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ContactIcon(title: request.counterparty.displayName, systemImage: "person.fill")
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.counterparty.displayName)
                    if let message = request.message, !message.isEmpty {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Button("接受") {
                    Task {
                        await onAccept()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("拒绝", role: .destructive) {
                    Task {
                        await onDecline()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ContactIcon: View {
    let title: String?
    let systemImage: String
    let tint: Color
    let size: CGFloat

    init(
        title: String? = nil,
        systemImage: String,
        tint: Color = .blue,
        size: CGFloat = 40
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.16))
            if let initial = title?.trimmingCharacters(in: .whitespacesAndNewlines).first {
                Text(String(initial).uppercased())
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(tint)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
    }
}
