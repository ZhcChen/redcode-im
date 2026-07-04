import XCTest
@testable import RedCodeCore
@testable import RedCodeFeatures
@testable import RedCodeNetworking
@testable import RedCodeStorage

@MainActor
final class SettingsControllerTests: XCTestCase {
    func testInitializeLoadsCachedSettingsThenRefreshesRemoteAndCaches() async throws {
        let authStore = KeyValueAuthSessionStore(keyValueStore: InMemoryKeyValueStore())
        try await authStore.save(AuthSession(token: "access-token", user: AuthUser(id: "u1", username: "bear")))
        let authController = AuthController(api: MockSettingsAuthAPI(), sessionStore: authStore)
        await authController.restoreSession()
        let configStore = MockAppConfigStore(values: [
            "settings.general": #"{"app_name":"Cached","message_runtime":{"server_storage_mode":"persist","content_audit_mode":"plaintext"}}"#,
        ])
        let api = MockSettingsAPI(
            generalSettings: GeneralSettings(
                appName: "Fresh",
                messageRuntime: MessageRuntimeSettings(serverStorageMode: "relay_only", contentAuditMode: "e2ee")
            )
        )
        let controller = SettingsController(
            authController: authController,
            api: api,
            configStore: configStore
        )

        await controller.initialize()

        XCTAssertEqual(controller.generalSettings?.appName, "Fresh")
        XCTAssertEqual(controller.messageRuntime.serverStorageMode, "relay_only")
        let cached = try XCTUnwrap(configStore.values["settings.general"])
        XCTAssertTrue(cached.contains(#""app_name":"Fresh""#))
    }

    func testUpdateNicknameUpdatesAuthSession() async throws {
        let authStore = KeyValueAuthSessionStore(keyValueStore: InMemoryKeyValueStore())
        try await authStore.save(
            AuthSession(token: "access-token", user: AuthUser(id: "u1", username: "bear", nickname: "Old"))
        )
        let authAPI = MockSettingsAuthAPI(
            updatedUser: AuthUser(id: "u1", username: "bear", nickname: "New Bear")
        )
        let authController = AuthController(api: authAPI, sessionStore: authStore)
        await authController.restoreSession()
        let controller = SettingsController(
            authController: authController,
            api: MockSettingsAPI(),
            configStore: MockAppConfigStore()
        )

        let updated = try await controller.updateNickname(" New Bear ")
        let restored = try await authStore.read()

        XCTAssertEqual(updated.nickname, "New Bear")
        XCTAssertEqual(restored?.user.nickname, "New Bear")
        XCTAssertEqual(controller.noticeMessage, "昵称已更新")
        let profileCalls = await authAPI.recordedProfileCalls()
        XCTAssertEqual(profileCalls, ["New Bear"])
    }

    func testResetPasswordWithSMSDelegatesAndSetsNotice() async throws {
        let authStore = KeyValueAuthSessionStore(keyValueStore: InMemoryKeyValueStore())
        try await authStore.save(AuthSession(token: "access-token", user: AuthUser(id: "u1", username: "bear")))
        let authAPI = MockSettingsAuthAPI()
        let authController = AuthController(api: authAPI, sessionStore: authStore)
        await authController.restoreSession()
        let controller = SettingsController(
            authController: authController,
            api: MockSettingsAPI(),
            configStore: MockAppConfigStore()
        )

        try await controller.resetPasswordWithSMS(phone: " bear ", code: " 123456 ", newPassword: " new-password ")

        XCTAssertEqual(controller.noticeMessage, "密码已重置，请使用新密码登录")
        let resetCalls = await authAPI.recordedResetCalls()
        XCTAssertEqual(resetCalls, [
            ResetPasswordCall(
                token: "access-token",
                phone: " bear ",
                code: " 123456 ",
                newPassword: " new-password "
            ),
        ])
    }

    func testLoadDocumentUsesCacheThenRefreshesRemote() async throws {
        let configStore = MockAppConfigStore(values: [
            "settings.privacy_policy": #"{"title":"缓存隐私","content":"cache","updated_at":null}"#,
        ])
        let api = MockSettingsAPI(
            privacyPolicy: DocumentContent(title: "远端隐私", content: "<p>remote</p>", updatedAt: "2026-07-04T10:00:00Z")
        )
        let controller = SettingsController(
            authController: AuthController(
                api: MockSettingsAuthAPI(),
                sessionStore: KeyValueAuthSessionStore(keyValueStore: InMemoryKeyValueStore())
            ),
            api: api,
            configStore: configStore
        )

        let document = try await controller.loadDocument(.privacyPolicy)

        XCTAssertEqual(document.title, "远端隐私")
        XCTAssertEqual(controller.privacyPolicy?.title, "远端隐私")
        let cached = try XCTUnwrap(configStore.values["settings.privacy_policy"])
        XCTAssertTrue(cached.contains("远端隐私"))
    }

    func testSubmitFeedbackSendsAuthenticatedRequest() async throws {
        let authStore = KeyValueAuthSessionStore(keyValueStore: InMemoryKeyValueStore())
        try await authStore.save(AuthSession(token: "access-token", user: AuthUser(id: "u1", username: "bear")))
        let authController = AuthController(api: MockSettingsAuthAPI(), sessionStore: authStore)
        await authController.restoreSession()
        let api = MockSettingsAPI()
        let controller = SettingsController(
            authController: authController,
            api: api,
            configStore: MockAppConfigStore()
        )

        let message = try await controller.submitFeedback(content: " hello ", contact: " user@example.test ")

        XCTAssertEqual(message, "反馈提交成功")
        XCTAssertEqual(controller.noticeMessage, "反馈提交成功")
        let feedbackCalls = await api.recordedFeedbackCalls()
        XCTAssertEqual(feedbackCalls, [
            FeedbackCall(token: "access-token", content: " hello ", contact: " user@example.test "),
        ])
    }

    func testCheckLatestVersionResolvesUpdateURL() async throws {
        let latest = AppVersionInfo(
            id: "v1",
            platform: "ios",
            version: "0.2.0",
            buildNumber: 2,
            channel: "stable",
            downloadKey: "releases/ios/app.ipa",
            appStoreURL: "https://apps.example.test/redcode",
            mandatory: true,
            isActive: true
        )
        let api = MockSettingsAPI(
            versionCheck: VersionCheckResult(hasUpdate: true, currentVersion: "0.1.0", latest: latest)
        )
        let controller = SettingsController(
            authController: AuthController(
                api: MockSettingsAuthAPI(),
                sessionStore: KeyValueAuthSessionStore(keyValueStore: InMemoryKeyValueStore())
            ),
            api: api,
            configStore: MockAppConfigStore()
        )

        let result = try await controller.checkLatestVersion(currentVersion: "0.1.0")

        XCTAssertTrue(result.hasUpdate)
        XCTAssertEqual(controller.updateURL?.absoluteString, "https://apps.example.test/redcode")
    }
}

private struct FeedbackCall: Equatable, Sendable {
    let token: String
    let content: String
    let contact: String?
}

private struct ResetPasswordCall: Equatable, Sendable {
    let token: String
    let phone: String
    let code: String
    let newPassword: String
}

@MainActor
private final class MockAppConfigStore: AppConfigStore {
    var values: [String: String]

    init(values: [String: String] = [:]) {
        self.values = values
    }

    func loadValue(forKey key: String) throws -> String? {
        values[key.trimmingCharacters(in: .whitespacesAndNewlines)]
    }

    func saveValue(_ valueJSON: String, forKey key: String) throws {
        values[key.trimmingCharacters(in: .whitespacesAndNewlines)] = valueJSON
    }

    func removeValue(forKey key: String) throws {
        values.removeValue(forKey: key.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func clearAll() throws {
        values.removeAll()
    }
}

private actor MockSettingsAPI: SettingsAPIService {
    private let generalSettingsResponse: GeneralSettings
    private let appNameResponse: String
    private let privacyPolicyResponse: DocumentContent
    private let userAgreementResponse: DocumentContent
    private let versionCheckResponse: VersionCheckResult
    private let downloadURLResponse: String
    private(set) var feedbackCalls: [FeedbackCall] = []

    init(
        generalSettings: GeneralSettings = GeneralSettings(appName: "RedCode IM"),
        appName: String = "RedCode IM",
        privacyPolicy: DocumentContent = DocumentContent(title: "隐私协议", content: "privacy"),
        userAgreement: DocumentContent = DocumentContent(title: "用户协议", content: "terms"),
        versionCheck: VersionCheckResult = VersionCheckResult(hasUpdate: false),
        downloadURL: String = "https://cdn.example.test/app.ipa"
    ) {
        self.generalSettingsResponse = generalSettings
        self.appNameResponse = appName
        self.privacyPolicyResponse = privacyPolicy
        self.userAgreementResponse = userAgreement
        self.versionCheckResponse = versionCheck
        self.downloadURLResponse = downloadURL
    }

    func fetchGeneralSettings() async throws -> GeneralSettings {
        generalSettingsResponse
    }

    func fetchAppName() async throws -> String {
        appNameResponse
    }

    func fetchDocument(_ kind: SettingsDocumentKind) async throws -> DocumentContent {
        switch kind {
        case .privacyPolicy:
            privacyPolicyResponse
        case .userAgreement:
            userAgreementResponse
        }
    }

    func submitFeedback(token: String, content: String, contact: String?) async throws -> SubmitFeedbackResponse {
        feedbackCalls.append(FeedbackCall(token: token, content: content, contact: contact))
        return SubmitFeedbackResponse(success: true, message: "反馈提交成功")
    }

    func checkLatestVersion(currentVersion: String, channel: String) async throws -> VersionCheckResult {
        versionCheckResponse
    }

    func fetchVersionDownloadURL(id: String, expiresInSeconds: Int) async throws -> String {
        downloadURLResponse
    }

    func recordedFeedbackCalls() -> [FeedbackCall] {
        feedbackCalls
    }
}

private enum SettingsAuthCall: Equatable, Sendable {
    case updateProfile(nickname: String?)
}

private actor MockSettingsAuthAPI: AuthAPIService {
    private let currentUserResponse: AuthUser
    private let updatedUserResponse: AuthUser
    private(set) var profileCalls: [String?] = []
    private(set) var resetCalls: [ResetPasswordCall] = []

    init(
        currentUser: AuthUser = AuthUser(id: "u1", username: "bear", nickname: "Bear"),
        updatedUser: AuthUser = AuthUser(id: "u1", username: "bear", nickname: "Bear")
    ) {
        self.currentUserResponse = currentUser
        self.updatedUserResponse = updatedUser
    }

    func register(username: String, password: String, nickname: String?) async throws -> AuthUser {
        currentUserResponse
    }

    func login(username: String, password: String) async throws -> AuthSession {
        AuthSession(token: "access-token", user: currentUserResponse)
    }

    func currentUser(token: String) async throws -> AuthUser {
        currentUserResponse
    }

    func refresh(refreshToken: String) async throws -> AuthSession {
        AuthSession(token: "access-token", refreshToken: refreshToken, user: currentUserResponse)
    }

    func updateProfile(
        token: String,
        nickname: String?,
        avatarURL: String?,
        avatarObjectKey: String?
    ) async throws -> AuthUser {
        profileCalls.append(nickname)
        return updatedUserResponse
    }

    func changePassword(
        token: String,
        oldPassword: String,
        newPassword: String
    ) async throws {}

    func resetPasswordWithSMS(
        token: String,
        phone: String,
        code: String,
        newPassword: String
    ) async throws -> ResetPasswordWithSMSResponse {
        resetCalls.append(
            ResetPasswordCall(
                token: token,
                phone: phone,
                code: code,
                newPassword: newPassword
            )
        )
        return ResetPasswordWithSMSResponse(success: true, message: "密码已重置，请使用新密码登录")
    }

    func recordedProfileCalls() -> [String?] {
        profileCalls
    }

    func recordedResetCalls() -> [ResetPasswordCall] {
        resetCalls
    }
}
