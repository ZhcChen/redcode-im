import SwiftUI
import RedCodeNetworking

public struct GroupSettingsView: View {
    private let authController: AuthController
    private let chat: ChatSummary
    private let chatListController: ChatListController
    private let realtimeController: ChatRealtimeController
    private let contactsController: ContactsController?

    @State private var controller: GroupManagementController
    @State private var groupName: String
    @State private var isPinned: Bool
    @State private var isMuted: Bool
    @State private var selectedContactIDs: Set<String> = []
    @State private var showLeaveConfirmation = false
    @State private var showDissolveConfirmation = false

    @Environment(\.dismiss) private var dismiss

    public init(
        authController: AuthController,
        chat: ChatSummary,
        chatListController: ChatListController,
        realtimeController: ChatRealtimeController,
        contactsController: ContactsController?,
        controller: GroupManagementController
    ) {
        self.authController = authController
        self.chat = chat
        self.chatListController = chatListController
        self.realtimeController = realtimeController
        self.contactsController = contactsController
        _controller = State(initialValue: controller)
        _groupName = State(initialValue: chat.displayName)
        _isPinned = State(initialValue: chat.isPinned)
        _isMuted = State(initialValue: chat.isMuted)
    }

    public var body: some View {
        List {
            Section("群信息") {
                HStack(spacing: 12) {
                    GroupAvatar(title: controller.currentGroup?.name ?? chat.displayName)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(controller.currentGroup?.name ?? chat.displayName)
                            .font(.headline)
                        Text("\(controller.members.count) 位成员")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                TextField("群名称", text: $groupName)
                Button("保存群名称") {
                    Task { await renameGroup() }
                }
                .disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || controller.isSaving)
            }

            Section("会话设置") {
                Toggle(
                    "置顶聊天",
                    isOn: Binding(
                        get: { isPinned },
                        set: { value in Task { await updatePinned(value) } }
                    )
                )
                Toggle(
                    "消息免打扰",
                    isOn: Binding(
                        get: { isMuted },
                        set: { value in Task { await updateMuted(value) } }
                    )
                )
                if let settings = controller.settingsSnapshot?.settings {
                    Toggle(
                        "全员禁言",
                        isOn: Binding(
                            get: { settings.globalMuteEnabled },
                            set: { value in
                                Task { await updateGlobalMute(value) }
                            }
                        )
                    )
                    .disabled(!canManage)
                }
            }

            Section("群成员") {
                if controller.members.isEmpty && controller.isLoading {
                    ProgressView("正在加载成员")
                } else {
                    ForEach(controller.members) { member in
                        GroupMemberRow(
                            member: member,
                            canRemove: canManage && member.userID != authController.session?.user.id && member.role != "owner",
                            onRemove: {
                                await removeMember(member)
                            }
                        )
                    }
                }

                if canManage, let contactsController {
                    NavigationLink {
                        AddGroupMembersView(
                            controller: controller,
                            authController: authController,
                            contactsController: contactsController,
                            roomID: chat.roomID
                        )
                    } label: {
                        Label("从联系人添加成员", systemImage: "person.badge.plus")
                    }
                }
            }

            if canManage {
                Section("群管理") {
                    NavigationLink("管理员管理") {
                        GroupAdminsView(controller: controller, authController: authController, roomID: chat.roomID)
                    }
                    NavigationLink("禁言管理") {
                        GroupMuteManagementView(controller: controller, authController: authController, roomID: chat.roomID)
                    }
                    NavigationLink("入群申请") {
                        GroupJoinRequestsView(controller: controller, authController: authController, roomID: chat.roomID)
                    }
                    NavigationLink("群规则") {
                        GroupRulesView(controller: controller, authController: authController, roomID: chat.roomID)
                    }
                    NavigationLink("操作日志") {
                        GroupOperationLogsView(controller: controller)
                    }
                }
            }

            Section {
                Button("退出群聊", role: .destructive) {
                    showLeaveConfirmation = true
                }
                if controller.isOwner(currentUserID: authController.session?.user.id ?? "") {
                    Button("解散群聊", role: .destructive) {
                        showDissolveConfirmation = true
                    }
                }
            }
        }
        .navigationTitle("群设置")
        .overlay {
            if controller.isLoading && controller.currentGroup == nil {
                ProgressView("正在加载群设置")
            }
        }
        .overlay(alignment: .bottom) {
            if let message = controller.errorMessage {
                ErrorBanner(message: message)
            }
        }
        .confirmationDialog("确认退出群聊？", isPresented: $showLeaveConfirmation, titleVisibility: .visible) {
            Button("退出", role: .destructive) {
                Task { await leaveGroup() }
            }
        }
        .confirmationDialog("确认解散群聊？", isPresented: $showDissolveConfirmation, titleVisibility: .visible) {
            Button("解散", role: .destructive) {
                Task { await dissolveGroup() }
            }
        }
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private var canManage: Bool {
        controller.canManage(currentUserID: authController.session?.user.id ?? "")
    }

    private func load() async {
        guard let session = authController.session else {
            return
        }
        do {
            try await controller.loadGroupBundle(
                roomID: chat.roomID,
                token: session.token,
                currentUserID: session.user.id
            )
            if let name = controller.currentGroup?.name {
                groupName = name
            }
            try? await controller.refreshManagementLists(roomID: chat.roomID, token: session.token)
        } catch {
            // 控制器已记录错误。
        }
    }

    private func renameGroup() async {
        guard let token = authController.session?.token else {
            return
        }
        do {
            let updated = try await controller.renameGroup(
                roomID: chat.roomID,
                name: groupName,
                description: nil,
                token: token
            )
            try chatListController.updateLocalChat(roomID: chat.roomID, displayName: updated.displayName)
        } catch {
            // 控制器已记录错误。
        }
    }

    private func updatePinned(_ pinned: Bool) async {
        guard let token = authController.session?.token else {
            return
        }
        let previous = isPinned
        isPinned = pinned
        do {
            try await controller.setRoomPinned(roomID: chat.roomID, pinned: pinned, token: token)
            try chatListController.updateLocalChat(roomID: chat.roomID, isPinned: pinned)
        } catch {
            isPinned = previous
        }
    }

    private func updateMuted(_ muted: Bool) async {
        guard let token = authController.session?.token else {
            return
        }
        let previous = isMuted
        isMuted = muted
        do {
            try await controller.updateNotificationSettings(roomID: chat.roomID, isMuted: muted, token: token)
            try chatListController.updateLocalChat(roomID: chat.roomID, isMuted: muted)
        } catch {
            isMuted = previous
        }
    }

    private func updateGlobalMute(_ enabled: Bool) async {
        guard let token = authController.session?.token else {
            return
        }
        try? await controller.updateGlobalMute(roomID: chat.roomID, enabled: enabled, reason: nil, token: token)
    }

    private func removeMember(_ member: RoomMember) async {
        guard let session = authController.session else {
            return
        }
        try? await controller.removeMember(
            roomID: chat.roomID,
            userID: member.userID,
            token: session.token,
            currentUserID: session.user.id
        )
    }

    private func leaveGroup() async {
        guard let token = authController.session?.token else {
            return
        }
        do {
            try await controller.leaveGroup(roomID: chat.roomID, token: token)
            try chatListController.removeRoom(chat.roomID)
            await realtimeController.syncRooms(chatListController.chats.map(\.roomID), pruneMissing: true)
            dismiss()
        } catch {
            // 控制器已记录错误。
        }
    }

    private func dissolveGroup() async {
        guard let token = authController.session?.token else {
            return
        }
        do {
            try await controller.dissolveGroup(roomID: chat.roomID, token: token)
            try chatListController.removeRoom(chat.roomID)
            await realtimeController.syncRooms(chatListController.chats.map(\.roomID), pruneMissing: true)
            dismiss()
        } catch {
            // 控制器已记录错误。
        }
    }
}

public struct CreateGroupView: View {
    private let authController: AuthController
    private let contactsController: ContactsController
    private let groupController: GroupManagementController
    private let onCreated: (ChatSummary) async -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var selectedIDs: Set<String> = []
    @Environment(\.dismiss) private var dismiss

    public init(
        authController: AuthController,
        contactsController: ContactsController,
        groupController: GroupManagementController,
        onCreated: @escaping (ChatSummary) async -> Void
    ) {
        self.authController = authController
        self.contactsController = contactsController
        self.groupController = groupController
        self.onCreated = onCreated
    }

    public var body: some View {
        List {
            Section("群资料") {
                TextField("群名称", text: $name)
                TextField("群描述（可选）", text: $description)
            }

            Section("选择联系人") {
                if contactsController.contacts.isEmpty {
                    Text("暂无联系人可加入群聊")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(contactsController.contacts) { contact in
                        Button {
                            toggle(contact.userID)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contact.displayName)
                                    Text(contact.username)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedIDs.contains(contact.userID) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
        }
        .navigationTitle("发起群聊")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("创建") {
                    Task { await create() }
                }
                .disabled(!canCreate)
            }
        }
        .overlay(alignment: .bottom) {
            if let message = groupController.errorMessage {
                ErrorBanner(message: message)
            }
        }
        .task {
            await loadContacts()
        }
    }

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !selectedIDs.isEmpty
            && !groupController.isSaving
    }

    private func toggle(_ userID: String) {
        if selectedIDs.contains(userID) {
            selectedIDs.remove(userID)
        } else {
            selectedIDs.insert(userID)
        }
    }

    private func loadContacts() async {
        guard let token = authController.session?.token else {
            return
        }
        do {
            try contactsController.loadCachedContacts()
        } catch {
            // 缓存失败不阻塞远端刷新。
        }
        try? await contactsController.refreshContacts(token: token)
    }

    private func create() async {
        guard let token = authController.session?.token else {
            return
        }
        do {
            let chat = try await groupController.createGroup(
                name: name,
                description: description,
                memberIDs: Array(selectedIDs),
                token: token
            )
            await onCreated(chat)
            dismiss()
        } catch {
            // 控制器已记录错误。
        }
    }
}

private struct AddGroupMembersView: View {
    let controller: GroupManagementController
    let authController: AuthController
    let contactsController: ContactsController
    let roomID: String

    @State private var selectedIDs: Set<String> = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(availableContacts) { contact in
                Button {
                    toggle(contact.userID)
                } label: {
                    HStack {
                        Text(contact.displayName)
                        Spacer()
                        if selectedIDs.contains(contact.userID) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("添加成员")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("添加") {
                    Task { await add() }
                }
                .disabled(selectedIDs.isEmpty || controller.isSaving)
            }
        }
    }

    private var availableContacts: [ContactSummary] {
        let existing = Set(controller.members.map(\.userID))
        return contactsController.contacts.filter { !existing.contains($0.userID) }
    }

    private func toggle(_ userID: String) {
        if selectedIDs.contains(userID) {
            selectedIDs.remove(userID)
        } else {
            selectedIDs.insert(userID)
        }
    }

    private func add() async {
        guard let session = authController.session else {
            return
        }
        do {
            _ = try await controller.addMembers(
                roomID: roomID,
                userIDs: Array(selectedIDs),
                token: session.token,
                currentUserID: session.user.id
            )
            dismiss()
        } catch {
            // 控制器已记录错误。
        }
    }
}

private struct GroupAdminsView: View {
    let controller: GroupManagementController
    let authController: AuthController
    let roomID: String

    var body: some View {
        List {
            Section("当前管理员") {
                if controller.admins.isEmpty {
                    Text("暂无管理员")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(controller.admins) { admin in
                        HStack {
                            Text(memberName(admin.adminID))
                            Spacer()
                            Button("移除", role: .destructive) {
                                Task { await remove(admin) }
                            }
                        }
                    }
                }
            }

            Section("成员") {
                ForEach(controller.members.filter { $0.role != "owner" }) { member in
                    HStack {
                        GroupMemberTitle(member: member)
                        Spacer()
                        if controller.admins.contains(where: { $0.adminID == member.userID }) {
                            Text("管理员")
                                .foregroundStyle(.secondary)
                        } else {
                            Button("设为管理员") {
                                Task { await appoint(member) }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("管理员管理")
    }

    private func memberName(_ userID: String) -> String {
        controller.members.first { $0.userID == userID }?.displayName ?? userID
    }

    private func appoint(_ member: RoomMember) async {
        guard let token = authController.session?.token else {
            return
        }
        try? await controller.appointAdmin(roomID: roomID, userID: member.userID, token: token)
    }

    private func remove(_ admin: GroupAdmin) async {
        guard let token = authController.session?.token else {
            return
        }
        try? await controller.removeAdmin(roomID: roomID, adminID: admin.adminID, token: token)
    }
}

private struct GroupMuteManagementView: View {
    let controller: GroupManagementController
    let authController: AuthController
    let roomID: String

    @State private var reason = ""

    var body: some View {
        List {
            Section("禁言原因") {
                TextField("可选", text: $reason)
            }
            Section("成员") {
                ForEach(controller.members.filter { $0.role != "owner" }) { member in
                    HStack {
                        GroupMemberTitle(member: member)
                        Spacer()
                        if controller.mutes.contains(where: { $0.userID == member.userID && $0.isActive }) {
                            Button("解除") {
                                Task { await unmute(member) }
                            }
                        } else {
                            Button("禁言") {
                                Task { await mute(member) }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("禁言管理")
    }

    private func mute(_ member: RoomMember) async {
        guard let token = authController.session?.token else {
            return
        }
        try? await controller.muteUser(roomID: roomID, userID: member.userID, reason: reason, hours: 24, token: token)
    }

    private func unmute(_ member: RoomMember) async {
        guard let token = authController.session?.token else {
            return
        }
        try? await controller.unmuteUser(roomID: roomID, userID: member.userID, token: token)
    }
}

private struct GroupJoinRequestsView: View {
    let controller: GroupManagementController
    let authController: AuthController
    let roomID: String

    var body: some View {
        List {
            if controller.joinRequests.isEmpty {
                Text("暂无入群申请")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(controller.joinRequests) { request in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(request.applicantID)
                            .font(.headline)
                        if let message = request.message {
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Button("通过") {
                                Task { await review(request, status: .approved) }
                            }
                            Button("拒绝", role: .destructive) {
                                Task { await review(request, status: .rejected) }
                            }
                        }
                        .disabled(request.status != .pending)
                    }
                }
            }
        }
        .navigationTitle("入群申请")
    }

    private func review(_ request: GroupJoinRequest, status: JoinRequestStatus) async {
        guard let token = authController.session?.token else {
            return
        }
        try? await controller.reviewJoinRequest(
            roomID: roomID,
            requestID: request.id,
            status: status,
            reviewMessage: nil,
            token: token
        )
    }
}

private struct GroupRulesView: View {
    let controller: GroupManagementController
    let authController: AuthController
    let roomID: String

    @State private var title = ""
    @State private var content = ""

    var body: some View {
        List {
            Section("新增群规") {
                TextField("标题", text: $title)
                TextField("内容", text: $content, axis: .vertical)
                Button("新增") {
                    Task { await create() }
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("群规列表") {
                if controller.rules.isEmpty {
                    Text("暂无群规")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(controller.rules) { rule in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(rule.title)
                                    .font(.headline)
                                Spacer()
                                if !rule.isActive {
                                    Text("已停用")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(rule.content)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack {
                                Button(rule.isActive ? "停用" : "启用") {
                                    Task { await toggle(rule) }
                                }
                                Button("删除", role: .destructive) {
                                    Task { await delete(rule) }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("群规则")
    }

    private func create() async {
        guard let token = authController.session?.token else {
            return
        }
        do {
            try await controller.createRule(roomID: roomID, title: title, content: content, token: token)
            title = ""
            content = ""
        } catch {
            // 控制器已记录错误。
        }
    }

    private func toggle(_ rule: GroupRule) async {
        guard let token = authController.session?.token else {
            return
        }
        try? await controller.updateRule(
            roomID: roomID,
            ruleID: rule.id,
            title: nil,
            content: nil,
            isActive: !rule.isActive,
            token: token
        )
    }

    private func delete(_ rule: GroupRule) async {
        guard let token = authController.session?.token else {
            return
        }
        try? await controller.deleteRule(roomID: roomID, ruleID: rule.id, token: token)
    }
}

private struct GroupOperationLogsView: View {
    let controller: GroupManagementController

    var body: some View {
        List {
            if controller.operationLogs.isEmpty {
                Text("暂无操作日志")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(controller.operationLogs) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(log.operationType)
                            .font(.headline)
                        Text("操作人：\(log.operatorID)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let createdAt = log.createdAt {
                            Text(createdAt, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("操作日志")
    }
}

private struct GroupMemberRow: View {
    let member: RoomMember
    let canRemove: Bool
    let onRemove: () async -> Void

    var body: some View {
        HStack {
            GroupMemberTitle(member: member)
            Spacer()
            if canRemove {
                Button("移除", role: .destructive) {
                    Task { await onRemove() }
                }
            }
        }
    }
}

private struct GroupMemberTitle: View {
    let member: RoomMember

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(member.displayName)
            HStack(spacing: 6) {
                Text(member.username)
                if member.role == "owner" {
                    Text("群主")
                } else if member.role == "admin" {
                    Text("管理员")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

private struct GroupAvatar: View {
    let title: String

    var body: some View {
        ZStack {
            Circle()
                .fill(.blue.opacity(0.14))
            Image(systemName: "person.3.fill")
                .foregroundStyle(.blue)
        }
        .frame(width: 44, height: 44)
        .accessibilityLabel(title)
    }
}
