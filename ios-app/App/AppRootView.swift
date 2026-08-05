import SwiftUI
import RedCodeFeatures
import RedCodeNetworking

struct AppRootView: View {
    let dependencies: AppDependencies
    @ObservedObject private var authController: AuthController
    @Environment(\.scenePhase) private var scenePhase
    @State private var didRestoreSession = false

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _authController = ObservedObject(wrappedValue: dependencies.authController)
    }

    var body: some View {
        Group {
            if !didRestoreSession && authController.isLoading {
                RestoreSessionView()
            } else if authController.state.isAuthenticated {
                MainTabView(dependencies: dependencies)
            } else {
                AuthEntryView(
                    authController: authController,
                    settingsController: dependencies.makeSettingsController()
                )
            }
        }
        .task {
            guard !didRestoreSession else {
                return
            }
            await authController.restoreSession()
            didRestoreSession = true
        }
        .onChange(of: authController.state.isAuthenticated) { isAuthenticated in
            if isAuthenticated, let session = authController.session {
                Task {
                    try? await dependencies.e2eeSessionLifecycle.onAuthenticated(session: session)
                }
            } else {
                Task {
                    await dependencies.chatRealtimeController.stop()
                }
            }
        }
        .onChange(of: scenePhase) { nextPhase in
            dependencies.pushController.updateAppActiveState(nextPhase == .active)
            if nextPhase == .active, authController.state.isAuthenticated {
                Task {
                    try? await dependencies.e2eeSessionLifecycle.onForeground()
                }
            }
        }
    }
}

private struct RestoreSessionView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("正在恢复登录状态")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MainTabView: View {
    let dependencies: AppDependencies
    @ObservedObject private var authController: AuthController
    @ObservedObject private var notificationNavigation: NotificationNavigationController
    @State private var selectedTab: AppTab = .chats

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _authController = ObservedObject(wrappedValue: dependencies.authController)
        _notificationNavigation = ObservedObject(wrappedValue: dependencies.pushController.navigationController)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            AppNavigationContainer {
                ChatHomeView(
                    authController: authController,
                    listController: dependencies.chatListController,
                    realtimeController: dependencies.chatRealtimeController,
                    makeDetailController: dependencies.makeChatDetailController,
                    makeGroupManagementController: dependencies.makeGroupManagementController,
                    contactsController: dependencies.contactsController,
                    mediaAPI: dependencies.mediaAPI,
                    emojiAPI: dependencies.emojiAPI,
                    attachmentCache: dependencies.messageAttachmentCache,
                    avatarCache: dependencies.mediaAvatarCache,
                    emojiCache: dependencies.mediaEmojiCache,
                    chatPreferencesStore: dependencies.chatBackgroundPreferences,
                    makeMessageSearchController: dependencies.makeMessageSearchController,
                    makeEmojiStickerController: dependencies.makeEmojiStickerController,
                    notificationNavigation: notificationNavigation
                )
            }
            .tabItem {
                Label("聊天", systemImage: "message")
            }
            .tag(AppTab.chats)

            AppNavigationContainer {
                ContactsHomeView(
                    authController: authController,
                    contactsController: dependencies.contactsController,
                    addFriendController: dependencies.addFriendController,
                    chatListController: dependencies.chatListController,
                    realtimeController: dependencies.chatRealtimeController,
                    makeDetailController: dependencies.makeChatDetailController,
                    makeGroupManagementController: dependencies.makeGroupManagementController,
                    mediaAPI: dependencies.mediaAPI,
                    attachmentCache: dependencies.messageAttachmentCache
                )
            }
            .tabItem {
                Label("联系人", systemImage: "person.2")
            }
            .tag(AppTab.contacts)

            AppNavigationContainer {
                SettingsHomeView(
                    authController: authController,
                    settingsController: dependencies.makeSettingsController(),
                    makeChatSettingsController: dependencies.makeChatSettingsController,
                    makeEmojiStickerController: dependencies.makeEmojiStickerController,
                    onLogout: dependencies.logoutAndClearLocalState
                )
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
            .tag(AppTab.settings)
        }
        .task {
            await dependencies.initializePushForAuthenticatedSession()
        }
        .onChange(of: notificationNavigation.pendingDestination?.id) { destinationID in
            guard destinationID != nil else {
                return
            }
            switch notificationNavigation.pendingDestination {
            case .friendRequests:
                selectedTab = .contacts
                _ = notificationNavigation.consumePendingDestination()
            case .chat:
                selectedTab = .chats
            case nil:
                break
            }
        }
    }
}

private enum AuthMode: String, CaseIterable, Identifiable {
    case login
    case register

    var id: String { rawValue }

    var title: String {
        switch self {
        case .login:
            "登录"
        case .register:
            "注册"
        }
    }

    var submitTitle: String {
        switch self {
        case .login:
            "登录"
        case .register:
            "注册并登录"
        }
    }
}

private struct AuthEntryView: View {
    @ObservedObject var authController: AuthController
    @ObservedObject var settingsController: SettingsController

    @AppStorage("redcode-ios-user-agreed-to-terms") private var agreedToTerms = false
    @State private var mode: AuthMode = .login
    @State private var account = ""
    @State private var password = ""
    @State private var nickname = ""
    @State private var localErrorMessage: String?

    init(authController: AuthController, settingsController: SettingsController) {
        _authController = ObservedObject(wrappedValue: authController)
        _settingsController = ObservedObject(wrappedValue: settingsController)
    }

    private var canSubmit: Bool {
        let normalizedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedAccount.count >= 3
            && password.count >= 6
            && agreedToTerms
            && !authController.isLoading
    }

    var body: some View {
        AppNavigationContainer {
            Form {
                Section {
                    Picker("认证方式", selection: $mode) {
                        ForEach(AuthMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    TextField("账号", text: $account)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .accessibilityIdentifier("auth.account.input")

                    SecureField("密码", text: $password)
                        .textContentType(mode == .register ? .newPassword : .password)
                        .accessibilityIdentifier("auth.password.input")

                    if mode == .register {
                        TextField("昵称（可选）", text: $nickname)
                            .textContentType(.nickname)
                            .accessibilityIdentifier("auth.nickname.input")
                    }
                } header: {
                    Text("账号密码")
                } footer: {
                    Text("当前测试阶段使用普通账号密码，不需要邮箱验证码。账号支持 3-20 位小写字母、数字、点、下划线或连字符；密码至少 6 位。")
                }

                Section {
                    Toggle(isOn: $agreedToTerms) {
                        Text("我已阅读并同意协议")
                    }
                    .accessibilityIdentifier("auth.terms.toggle")

                    NavigationLink("查看用户协议") {
                        SettingsDocumentView(controller: settingsController, kind: .userAgreement)
                    }
                    NavigationLink("查看隐私协议") {
                        SettingsDocumentView(controller: settingsController, kind: .privacyPolicy)
                    }
                } footer: {
                    Text("登录或注册前需勾选协议；协议内容来自后端公开配置。")
                }

                if let message = localErrorMessage ?? authController.errorMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        HStack {
                            Spacer()
                            if authController.isLoading {
                                ProgressView()
                            } else {
                                Text(mode.submitTitle)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSubmit)
                    .accessibilityIdentifier("auth.submit")
                }
            }
            .navigationTitle("RedCode IM")
        }
    }

    private func submit() {
        let currentMode = mode
        let currentAccount = account
        let currentPassword = password
        let currentNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)

        Task { @MainActor in
            localErrorMessage = nil
            do {
                switch currentMode {
                case .login:
                    try await authController.login(
                        username: currentAccount,
                        password: currentPassword
                    )
                case .register:
                    try await authController.registerAndLogin(
                        username: currentAccount,
                        password: currentPassword,
                        nickname: currentNickname.isEmpty ? nil : currentNickname
                    )
                }
            } catch {
                localErrorMessage = error.localizedDescription
            }
        }
    }
}
