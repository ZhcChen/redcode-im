import Foundation
import Combine
import RedCodeCore
import RedCodeNetworking
import RedCodeStorage

@MainActor
public final class SettingsController: ObservableObject {
    @Published public private(set) var generalSettings: GeneralSettings?
    @Published public private(set) var privacyPolicy: DocumentContent?
    @Published public private(set) var userAgreement: DocumentContent?
    @Published public private(set) var versionCheck: VersionCheckResult?
    @Published public private(set) var updateURL: URL?
    @Published public private(set) var isLoading = false
    @Published public private(set) var isSubmitting = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var noticeMessage: String?

    private let authController: AuthController
    private let api: any SettingsAPIService
    private let configStore: any AppConfigStore
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        authController: AuthController,
        api: any SettingsAPIService,
        configStore: any AppConfigStore,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.authController = authController
        self.api = api
        self.configStore = configStore
        self.encoder = encoder
        self.decoder = decoder
    }

    public var user: AuthUser? {
        authController.session?.user
    }

    public var displayName: String {
        user?.displayName ?? "RedCode 用户"
    }

    public var appName: String {
        let configured = generalSettings?.appName.trimmingCharacters(in: .whitespacesAndNewlines)
        return configured?.isEmpty == false ? configured! : "RedCode IM"
    }

    public var messageRuntime: MessageRuntimeSettings {
        generalSettings?.messageRuntime ?? .defaults
    }

    public func initialize(currentVersion: String? = nil) async {
        await runLoadingOperation {
            try loadCachedGeneralSettings()
            _ = try? await authController.refreshCurrentUser()
            let fresh = try await loadGeneralSettingsFromRemote()
            generalSettings = fresh
            try saveCached(fresh, key: CacheKey.generalSettings)
            if let currentVersion, !currentVersion.isEmpty {
                try await checkLatestVersion(currentVersion: currentVersion, setLoading: false)
            }
        }
    }

    @discardableResult
    public func refreshGeneralSettings() async throws -> GeneralSettings {
        let settings = try await loadGeneralSettingsFromRemote()
        generalSettings = settings
        try saveCached(settings, key: CacheKey.generalSettings)
        return settings
    }

    @discardableResult
    public func updateNickname(_ nickname: String) async throws -> AuthUser {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RedCodeError.validation("昵称不能为空")
        }
        return try await runSubmittingOperation(successNotice: "昵称已更新") {
            try await authController.updateProfile(nickname: trimmed)
        }
    }

    public func changePassword(oldPassword: String, newPassword: String) async throws {
        guard !oldPassword.isEmpty, !newPassword.isEmpty else {
            throw RedCodeError.validation("密码不能为空")
        }
        guard newPassword.count >= 6 else {
            throw RedCodeError.validation("新密码至少 6 位")
        }
        try await runSubmittingOperation(successNotice: "密码已更新") {
            try await authController.changePassword(
                oldPassword: oldPassword,
                newPassword: newPassword
            )
        }
    }

    public func resetPasswordWithSMS(phone: String, code: String, newPassword: String) async throws {
        guard !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RedCodeError.validation("账号不能为空")
        }
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RedCodeError.validation("验证码不能为空")
        }
        guard newPassword.trimmingCharacters(in: .whitespacesAndNewlines).count >= 6 else {
            throw RedCodeError.validation("新密码至少 6 位")
        }
        let message = try await runSubmittingOperation(successNotice: nil) {
            try await authController.resetPasswordWithSMS(
                phone: phone,
                code: code,
                newPassword: newPassword
            )
        }
        noticeMessage = message.isEmpty ? "密码已重置，请使用新密码登录" : message
    }

    @discardableResult
    public func loadDocument(_ kind: SettingsDocumentKind) async throws -> DocumentContent {
        if let cached = try? cachedDocument(kind) {
            apply(document: cached, kind: kind)
        }

        return try await runLoadingOperation {
            let document = try await api.fetchDocument(kind)
            apply(document: document, kind: kind)
            try saveCached(document, key: cacheKey(for: kind))
            return document
        }
    }

    @discardableResult
    public func submitFeedback(content: String, contact: String? = nil) async throws -> String {
        guard let token = authController.session?.token else {
            throw RedCodeError.authentication("未登录")
        }
        let response: SubmitFeedbackResponse = try await runSubmittingOperation(successNotice: nil) {
            try await api.submitFeedback(token: token, content: content, contact: contact)
        }
        let message = response.message.isEmpty ? "反馈提交成功" : response.message
        noticeMessage = message
        return message
    }

    @discardableResult
    public func checkLatestVersion(
        currentVersion: String,
        channel: String = "stable",
        setLoading: Bool = true
    ) async throws -> VersionCheckResult {
        let operation = {
            let result = try await self.api.checkLatestVersion(
                currentVersion: currentVersion,
                channel: channel
            )
            self.versionCheck = result
            self.updateURL = try await self.resolveUpdateURL(from: result)
            return result
        }

        if setLoading {
            return try await runLoadingOperation(operation)
        }
        return try await operation()
    }

    public func clearNotice() {
        noticeMessage = nil
    }

    private func loadGeneralSettingsFromRemote() async throws -> GeneralSettings {
        var settings = try await api.fetchGeneralSettings()
        if settings.appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let fallbackName = try? await api.fetchAppName()
            if let fallbackName, !fallbackName.isEmpty {
                settings = GeneralSettings(
                    appName: fallbackName,
                    messageRuntime: settings.messageRuntime
                )
            }
        }
        return settings
    }

    private func loadCachedGeneralSettings() throws {
        guard let json = try configStore.loadValue(forKey: CacheKey.generalSettings.rawValue),
              let data = json.data(using: .utf8) else {
            return
        }
        generalSettings = try decoder.decode(GeneralSettings.self, from: data)
    }

    private func cachedDocument(_ kind: SettingsDocumentKind) throws -> DocumentContent? {
        guard let json = try configStore.loadValue(forKey: cacheKey(for: kind).rawValue),
              let data = json.data(using: .utf8) else {
            return nil
        }
        return try decoder.decode(DocumentContent.self, from: data)
    }

    private func apply(document: DocumentContent, kind: SettingsDocumentKind) {
        switch kind {
        case .privacyPolicy:
            privacyPolicy = document
        case .userAgreement:
            userAgreement = document
        }
    }

    private func saveCached<T: Encodable>(_ value: T, key: CacheKey) throws {
        let data = try encoder.encode(value)
        guard let json = String(data: data, encoding: .utf8) else {
            return
        }
        try configStore.saveValue(json, forKey: key.rawValue)
    }

    private func resolveUpdateURL(from result: VersionCheckResult) async throws -> URL? {
        guard result.hasUpdate, let latest = result.latest else {
            return nil
        }

        for rawURL in [latest.appStoreURL, latest.downloadURL] {
            if let rawURL, let url = URL(string: rawURL), !rawURL.isEmpty {
                return url
            }
        }

        let rawURL = try await api.fetchVersionDownloadURL(id: latest.id, expiresInSeconds: 600)
        return URL(string: rawURL)
    }

    private func runLoadingOperation<T: Sendable>(_ operation: () async throws -> T) async throws -> T {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            return try await operation()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    private func runLoadingOperation(_ operation: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await operation()
        } catch {
            if generalSettings == nil {
                generalSettings = GeneralSettings()
            }
            errorMessage = error.localizedDescription
        }
    }

    private func runSubmittingOperation<T: Sendable>(
        successNotice: String?,
        _ operation: () async throws -> T
    ) async throws -> T {
        isSubmitting = true
        errorMessage = nil
        noticeMessage = nil
        defer { isSubmitting = false }
        do {
            let result = try await operation()
            noticeMessage = successNotice
            return result
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    private func cacheKey(for kind: SettingsDocumentKind) -> CacheKey {
        switch kind {
        case .privacyPolicy:
            .privacyPolicy
        case .userAgreement:
            .userAgreement
        }
    }
}

private enum CacheKey: String {
    case generalSettings = "settings.general"
    case privacyPolicy = "settings.privacy_policy"
    case userAgreement = "settings.user_agreement"
}
