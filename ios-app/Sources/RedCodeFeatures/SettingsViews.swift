import SwiftUI
import RedCodeCore
import RedCodeNetworking

public struct SettingsHomeView: View {
    @ObservedObject private var authController: AuthController
    @StateObject private var settingsController: SettingsController
    private let makeChatSettingsController: () -> ChatSettingsController
    private let makeEmojiStickerController: () -> EmojiStickerController
    private let makeE2eeDeviceManagementController: () -> E2eeDeviceManagementController
    private let onLogout: () async -> Void

    @State private var showLogoutConfirmation = false

    public init(
        authController: AuthController,
        settingsController: SettingsController,
        makeChatSettingsController: @escaping () -> ChatSettingsController,
        makeEmojiStickerController: @escaping () -> EmojiStickerController,
        makeE2eeDeviceManagementController: @escaping () -> E2eeDeviceManagementController,
        onLogout: @escaping () async -> Void = {}
    ) {
        _authController = ObservedObject(wrappedValue: authController)
        _settingsController = StateObject(wrappedValue: settingsController)
        self.makeChatSettingsController = makeChatSettingsController
        self.makeEmojiStickerController = makeEmojiStickerController
        self.makeE2eeDeviceManagementController = makeE2eeDeviceManagementController
        self.onLogout = onLogout
    }

    public var body: some View {
        List {
            accountSection
            chatSection
            contentSection
            appSection
            logoutSection
        }
        .navigationTitle("设置")
        .refreshable {
            _ = try? await settingsController.refreshGeneralSettings()
        }
        .task {
            await settingsController.initialize(currentVersion: currentAppVersion)
        }
        .alert("确认退出登录？", isPresented: $showLogoutConfirmation) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) {
                Task {
                    await onLogout()
                }
            }
        } message: {
            Text("退出后会清理本机登录态、WebSocket 和本地敏感缓存。")
        }
    }

    private var accountSection: some View {
        Section {
            NavigationLink {
                ProfileSettingsView(controller: settingsController)
            } label: {
                HStack(spacing: 12) {
                    UserAvatarBadge(name: settingsController.displayName)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(settingsController.displayName)
                            .font(.headline)
                        Text(settingsController.user?.username ?? "未加载账号")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            NavigationLink("账号与安全") {
                AccountSecuritySettingsView(
                    controller: settingsController,
                    e2eeController: makeE2eeDeviceManagementController()
                )
            }
        } header: {
            Text("当前账号")
        }
    }

    private var chatSection: some View {
        Section("聊天") {
            NavigationLink("聊天设置") {
                ChatSettingsView(
                    authController: authController,
                    settingsController: makeChatSettingsController(),
                    stickerController: makeEmojiStickerController()
                )
            }
        }
    }

    private var contentSection: some View {
        Section("内容与协议") {
            NavigationLink("用户协议") {
                SettingsDocumentView(controller: settingsController, kind: .userAgreement)
            }
            NavigationLink("隐私协议") {
                SettingsDocumentView(controller: settingsController, kind: .privacyPolicy)
            }
        }
    }

    private var appSection: some View {
        Section("应用") {
            NavigationLink("关于 \(settingsController.appName)") {
                AboutSettingsView(
                    controller: settingsController,
                    currentVersion: currentAppVersion
                )
            }
            NavigationLink("意见反馈") {
                FeedbackSettingsView(controller: settingsController)
            }
            if let notice = settingsController.noticeMessage {
                Text(notice)
                    .foregroundStyle(.secondary)
            }
            if let error = settingsController.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
    }

    private var logoutSection: some View {
        Section {
            Button("退出登录", role: .destructive) {
                showLogoutConfirmation = true
            }
        }
    }

    private var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }
}

public struct ProfileSettingsView: View {
    @StateObject private var controller: SettingsController
    @State private var nicknameDraft = ""

    public init(controller: SettingsController) {
        _controller = StateObject(wrappedValue: controller)
    }

    public var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        UserAvatarBadge(name: controller.displayName, size: 92)
                        Text("头像上传沿用媒体模块能力；当前页先展示已缓存头像标识。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                .padding(.vertical, 10)
            }

            Section("账号资料") {
                RedCodeLabeledValueRow(title: "账号", value: controller.user?.username ?? "-")
                RedCodeLabeledValueRow(title: "邮箱", value: controller.user?.email ?? "未绑定")
                TextField("昵称", text: $nicknameDraft)
                    .redcodeTextContentTypeNickname()
                    .onSubmit {
                        submitNickname()
                    }
            }

            messageSection

            Section {
                Button {
                    submitNickname()
                } label: {
                    if controller.isSubmitting {
                        ProgressView()
                    } else {
                        Text("保存资料")
                    }
                }
                .disabled(controller.isSubmitting || nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("个人资料")
        .onAppear {
            nicknameDraft = controller.user?.nickname ?? ""
        }
    }

    @ViewBuilder
    private var messageSection: some View {
        if let notice = controller.noticeMessage {
            Section {
                Text(notice).foregroundStyle(.secondary)
            }
        }
        if let error = controller.errorMessage {
            Section {
                Text(error).foregroundStyle(.red)
            }
        }
    }

    private func submitNickname() {
        let nickname = nicknameDraft
        Task {
            _ = try? await controller.updateNickname(nickname)
            nicknameDraft = controller.user?.nickname ?? nicknameDraft
        }
    }
}

public struct AccountSecuritySettingsView: View {
    @StateObject private var controller: SettingsController
    @StateObject private var e2eeController: E2eeDeviceManagementController
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var resetPhone = ""
    @State private var resetCode = ""
    @State private var resetNewPassword = ""
    @State private var resetConfirmPassword = ""
    @State private var localError: String?
    @State private var pendingRevocation: E2eeDeviceInfo?

    public init(controller: SettingsController, e2eeController: E2eeDeviceManagementController) {
        _controller = StateObject(wrappedValue: controller)
        _e2eeController = StateObject(wrappedValue: e2eeController)
    }

    public var body: some View {
        Form {
            Section {
                SecureField("当前密码", text: $oldPassword)
                    .textContentType(.password)
                SecureField("新密码", text: $newPassword)
                    .redcodeTextContentTypeNewPassword()
                SecureField("确认新密码", text: $confirmPassword)
                    .redcodeTextContentTypeNewPassword()
            } header: {
                Text("修改密码")
            } footer: {
                Text("当前测试阶段使用普通账号密码；不需要邮箱验证码二次验证。")
            }

            Section {
                TextField("当前账号/手机号", text: $resetPhone)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                TextField("验证码", text: $resetCode)
                    .textContentType(.oneTimeCode)
                SecureField("新密码", text: $resetNewPassword)
                    .redcodeTextContentTypeNewPassword()
                SecureField("确认新密码", text: $resetConfirmPassword)
                    .redcodeTextContentTypeNewPassword()
            } header: {
                Text("验证码重置密码")
            } footer: {
                Text("该接口需已登录，且账号需等于当前登录账号；本地测试可使用后台通用验证码。")
            }

            e2eeDeviceSection

            if let localError {
                Section {
                    Text(localError).foregroundStyle(.red)
                }
            }
            if let error = controller.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }
            if let notice = controller.noticeMessage {
                Section {
                    Text(notice).foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    submitPasswordChange()
                } label: {
                    if controller.isSubmitting {
                        ProgressView()
                    } else {
                        Text("修改密码")
                    }
                }
                .disabled(controller.isSubmitting || oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)

                Button {
                    submitPasswordReset()
                } label: {
                    Text("使用验证码重置密码")
                }
                .disabled(
                    controller.isSubmitting
                        || resetPhone.isEmpty
                        || resetCode.isEmpty
                        || resetNewPassword.isEmpty
                        || resetConfirmPassword.isEmpty
                )
            }
        }
        .navigationTitle("账号与安全")
        .onAppear {
            if resetPhone.isEmpty {
                resetPhone = controller.user?.username ?? ""
            }
        }
        .task {
            await e2eeController.refresh()
        }
        .confirmationDialog(
            "撤销此加密设备？",
            isPresented: Binding(
                get: { pendingRevocation != nil },
                set: { if !$0 { pendingRevocation = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("撤销设备", role: .destructive) {
                guard let device = pendingRevocation else { return }
                pendingRevocation = nil
                Task { await e2eeController.revoke(device) }
            }
            Button("取消", role: .cancel) {
                pendingRevocation = nil
            }
        } message: {
            Text("撤销后该设备不能读取新的加密消息。")
        }
    }

    @ViewBuilder
    private var e2eeDeviceSection: some View {
        Section("端到端加密设备") {
            if !e2eeController.isE2eeRuntime {
                Label("当前未启用端到端加密", systemImage: "lock.open")
                    .foregroundStyle(.secondary)
            } else if e2eeController.isLoading && e2eeController.devices.isEmpty {
                HStack {
                    ProgressView()
                    Text("正在加载设备")
                }
            } else if e2eeController.devices.isEmpty {
                Text("暂无加密设备").foregroundStyle(.secondary)
            } else {
                ForEach(e2eeController.devices, id: \.id) { device in
                    E2eeDeviceRow(
                        device: device,
                        isCurrent: device.id == e2eeController.currentDeviceID,
                        isOperating: device.id == e2eeController.operatingDeviceID,
                        isDisabled: e2eeController.operatingDeviceID != nil,
                        onApprove: { Task { await e2eeController.approve(device) } },
                        onRevoke: { pendingRevocation = device }
                    )
                }
            }
            if let error = e2eeController.errorMessage {
                Text(error).foregroundStyle(.red)
            }
        }
    }

    private func submitPasswordChange() {
        guard newPassword == confirmPassword else {
            localError = "两次输入的新密码不一致"
            return
        }

        let oldPassword = oldPassword
        let newPassword = newPassword
        Task {
            localError = nil
            do {
                try await controller.changePassword(oldPassword: oldPassword, newPassword: newPassword)
                self.oldPassword = ""
                self.newPassword = ""
                self.confirmPassword = ""
            } catch {
                localError = error.localizedDescription
            }
        }
    }

    private func submitPasswordReset() {
        guard resetNewPassword == resetConfirmPassword else {
            localError = "两次输入的新密码不一致"
            return
        }

        let phone = resetPhone
        let code = resetCode
        let newPassword = resetNewPassword
        Task {
            localError = nil
            do {
                try await controller.resetPasswordWithSMS(
                    phone: phone,
                    code: code,
                    newPassword: newPassword
                )
                resetCode = ""
                resetNewPassword = ""
                resetConfirmPassword = ""
            } catch {
                localError = error.localizedDescription
            }
        }
    }
}

private struct E2eeDeviceRow: View {
    let device: E2eeDeviceInfo
    let isCurrent: Bool
    let isOperating: Bool
    let isDisabled: Bool
    let onApprove: () -> Void
    let onRevoke: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: deviceIcon)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(device.deviceLabel.isEmpty ? "未命名设备" : device.deviceLabel)
                    if isCurrent {
                        Text("当前设备")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(device.status == "revoked" ? .red : .secondary)
            }
            Spacer()
            if isOperating {
                ProgressView()
            } else if device.status == "pending_approval" {
                Button("批准", action: onApprove)
                    .disabled(isDisabled)
            } else if device.status == "active" && !isCurrent {
                Button("撤销", role: .destructive, action: onRevoke)
                    .disabled(isDisabled)
            }
        }
        .padding(.vertical, 2)
    }

    private var deviceIcon: String {
        let label = device.deviceLabel.lowercased()
        return label.contains("ipad") ? "ipad" : "iphone"
    }

    private var statusText: String {
        switch device.status {
        case "pending_approval": "等待批准"
        case "active": "已批准"
        case "revoked": "已撤销"
        default: device.status.isEmpty ? "状态未知" : device.status
        }
    }
}

public struct SettingsDocumentView: View {
    @StateObject private var controller: SettingsController
    private let kind: SettingsDocumentKind

    public init(controller: SettingsController, kind: SettingsDocumentKind) {
        _controller = StateObject(wrappedValue: controller)
        self.kind = kind
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let error = controller.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }

                if controller.isLoading && document == nil {
                    HStack {
                        ProgressView()
                        Text("正在加载内容...")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(document?.title ?? kind.title)
                        .font(.title2.bold())
                    if let updatedAt = document?.updatedAt {
                        Text("更新于 \(updatedAt)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(plainText(fromHTML: document?.content ?? "暂无内容"))
                        .font(.body)
                        .lineSpacing(6)
                }
            }
            .padding()
        }
        .navigationTitle(kind.title)
        .task {
            _ = try? await controller.loadDocument(kind)
        }
    }

    private var document: DocumentContent? {
        switch kind {
        case .privacyPolicy:
            controller.privacyPolicy
        case .userAgreement:
            controller.userAgreement
        }
    }

    private func plainText(fromHTML value: String) -> String {
        value
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct AboutSettingsView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var controller: SettingsController
    @State private var showUpdateAlert = false
    private let currentVersion: String

    public init(controller: SettingsController, currentVersion: String) {
        _controller = StateObject(wrappedValue: controller)
        self.currentVersion = currentVersion
    }

    public var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    AppLogoBadge()
                    Text(controller.appName)
                        .font(.title3.bold())
                    Text("iOS App · Version \(currentVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }

            Section("消息运行模式") {
                RedCodeLabeledValueRow(title: "服务器存储", value: controller.messageRuntime.serverStorageMode)
                RedCodeLabeledValueRow(title: "内容审计", value: controller.messageRuntime.contentAuditMode)
                Text(controller.messageRuntime.runtimeNoticeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("版本") {
                Button {
                    checkVersion()
                } label: {
                    if controller.isLoading {
                        ProgressView()
                    } else {
                        Text("检查更新")
                    }
                }

                if let latest = controller.versionCheck?.latest, controller.versionCheck?.hasUpdate == true {
                    RedCodeLabeledValueRow(title: "最新版本", value: latest.version)
                    if let releaseNotes = latest.releaseNotes, !releaseNotes.isEmpty {
                        Text(releaseNotes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let updateURL = controller.updateURL {
                        Link("打开更新链接", destination: updateURL)
                    }
                } else if controller.versionCheck != nil {
                    Text("当前已是最新版本")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                NavigationLink("意见反馈") {
                    FeedbackSettingsView(controller: controller)
                }
            }
        }
        .navigationTitle("关于")
        .alert("发现新版本", isPresented: $showUpdateAlert) {
            if let url = controller.updateURL {
                Button("打开更新链接") {
                    openURL(url)
                }
            }
            if controller.versionCheck?.latest?.mandatory == true {
                Button("稍后处理", role: .cancel) {}
            } else {
                Button("取消", role: .cancel) {}
            }
        } message: {
            Text(updateAlertMessage)
        }
    }

    private var updateAlertMessage: String {
        guard let latest = controller.versionCheck?.latest else {
            return "检测到新版本。"
        }
        if latest.mandatory {
            return "检测到强制更新 \(latest.version)。请更新后继续使用。"
        }
        return "检测到新版本 \(latest.version)，可打开链接完成更新。"
    }

    private func checkVersion() {
        Task {
            do {
                let result = try await controller.checkLatestVersion(currentVersion: currentVersion)
                showUpdateAlert = result.hasUpdate
            } catch {
                showUpdateAlert = false
            }
        }
    }
}

public struct FeedbackSettingsView: View {
    @StateObject private var controller: SettingsController
    @State private var content = ""
    @State private var contact = ""

    public init(controller: SettingsController) {
        _controller = StateObject(wrappedValue: controller)
    }

    public var body: some View {
        Form {
            Section {
                TextEditor(text: $content)
                    .frame(minHeight: 140)
                TextField("联系方式（选填）", text: $contact)
            } header: {
                Text("反馈内容")
            } footer: {
                Text("请尽量提供问题、建议或复现步骤。")
            }

            if let error = controller.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }
            if let notice = controller.noticeMessage {
                Section {
                    Text(notice).foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    submitFeedback()
                } label: {
                    if controller.isSubmitting {
                        ProgressView()
                    } else {
                        Text("提交反馈")
                    }
                }
                .disabled(controller.isSubmitting || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("意见反馈")
    }

    private func submitFeedback() {
        let content = content
        let contact = contact
        Task {
            do {
                _ = try await controller.submitFeedback(content: content, contact: contact)
                self.content = ""
                self.contact = ""
            } catch {
                // SettingsController 已保存错误消息，UI 直接展示。
            }
        }
    }
}

private struct UserAvatarBadge: View {
    let name: String
    var size: CGFloat = 48

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.38, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [Color.green, Color.teal],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            )
    }
}

private struct AppLogoBadge: View {
    var body: some View {
        Text("R")
            .font(.system(size: 38, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 82, height: 82)
            .background(
                LinearGradient(
                    colors: [Color.green, Color.teal],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
    }
}
