import SwiftUI
import RedCodeFeatures

struct AppRootView: View {
    let authController: AuthController
    @State private var didRestoreSession = false

    var body: some View {
        Group {
            if !didRestoreSession && authController.isLoading {
                RestoreSessionView()
            } else if authController.state.isAuthenticated {
                MainTabView(authController: authController)
            } else {
                AuthEntryView(authController: authController)
            }
        }
        .task {
            guard !didRestoreSession else {
                return
            }
            await authController.restoreSession()
            didRestoreSession = true
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
    let authController: AuthController

    var body: some View {
        TabView {
            NavigationStack {
                ContentUnavailableView("聊天", systemImage: "message", description: Text("聊天主链路将在下一阶段接入"))
                    .navigationTitle("聊天")
            }
            .tabItem {
                Label("聊天", systemImage: "message")
            }

            NavigationStack {
                ContentUnavailableView("联系人", systemImage: "person.2", description: Text("好友和联系人流程将在聊天底座后接入"))
                    .navigationTitle("联系人")
            }
            .tabItem {
                Label("联系人", systemImage: "person.2")
            }

            NavigationStack {
                SettingsHomeView(authController: authController)
                    .navigationTitle("设置")
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
        }
    }
}

private struct SettingsHomeView: View {
    let authController: AuthController

    var body: some View {
        List {
            if let user = authController.session?.user {
                Section {
                    LabeledContent("昵称", value: user.displayName)
                    LabeledContent("账号", value: user.username)
                } header: {
                    Text("当前账号")
                }
            }

            Section {
                Button("退出登录", role: .destructive) {
                    Task {
                        try? await authController.logout()
                    }
                }
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
    let authController: AuthController

    @State private var mode: AuthMode = .login
    @State private var account = ""
    @State private var password = ""
    @State private var nickname = ""
    @State private var localErrorMessage: String?

    private var canSubmit: Bool {
        let normalizedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedAccount.count >= 3
            && password.count >= 6
            && !authController.isLoading
    }

    var body: some View {
        NavigationStack {
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

                    SecureField("密码", text: $password)
                        .textContentType(mode == .register ? .newPassword : .password)

                    if mode == .register {
                        TextField("昵称（可选）", text: $nickname)
                            .textContentType(.nickname)
                    }
                } header: {
                    Text("账号密码")
                } footer: {
                    Text("当前测试阶段使用普通账号密码，不需要邮箱验证码。账号支持 3-20 位小写字母、数字、点、下划线或连字符；密码至少 6 位。")
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
