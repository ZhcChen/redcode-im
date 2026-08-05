import SwiftUI
import RedCodeCore
import RedCodeFeatures
import RedCodeNetworking
import RedCodeStorage


#if canImport(UIKit)
import UIKit
import UserNotifications
#endif

@MainActor
final class AppDependencies {
    let authController: AuthController
    let chatListController: ChatListController
    let chatRealtimeController: ChatRealtimeController
    let contactsController: ContactsController
    let addFriendController: AddFriendController
    let pushController: PushController
    let e2eeSessionLifecycle: E2eeSessionLifecycle

    private let environment: RedCodeEnvironment
    private let database: RedCodeDatabase
    private let chatAPIService: any ChatAPIService
    private let mediaAPIService: any MediaAPIService
    private let emojiAPIService: any EmojiAPIService
    private let settingsAPIService: any SettingsAPIService
    private let pushAPIService: any PushAPIService
    private let friendAPIService: any FriendAPIService
    private let roomAPIService: any RoomAPIService
    private let messageCacheStore: GRDBMessageCacheStore
    private let messageSearchStore: GRDBMessageSearchStore
    private let chatPreferencesStore: any ChatPreferencesStore
    private let appConfigStore: GRDBAppConfigStore
    private let incomingMessageResolver: any IncomingChatMessageResolving
    private let outgoingTextRouter: any OutgoingTextMessageRouting
    private let attachmentCache = AttachmentFileCache()
    private let avatarCache = AvatarFileCache()
    private let emojiCache = EmojiFileCache()

    convenience init(
        environment: RedCodeEnvironment = .simulatorDevelopment(),
        database: RedCodeDatabase
    ) {
        let authController = AuthController(
            api: AuthAPIClient(environment: environment),
            sessionStore: KeyValueAuthSessionStore(keyValueStore: KeychainKeyValueStore())
        )
        let chatAPIService = ChatAPIClient(environment: environment)
        let mediaAPIService = MediaAPIClient(environment: environment)
        self.init(
            environment: environment,
            database: database,
            authController: authController,
            chatAPIService: chatAPIService,
            mediaAPIService: mediaAPIService,
            emojiAPIService: EmojiAPIClient(environment: environment),
            settingsAPIService: SettingsAPIClient(environment: environment),
            pushAPIService: PushAPIClient(environment: environment),
            friendAPIService: FriendAPIClient(environment: environment),
            roomAPIService: RoomAPIClient(environment: environment),
            webSocketService: WebSocketClient(configuration: WebSocketConfiguration(environment: environment))
        )
    }

    init(
        environment: RedCodeEnvironment = .simulatorDevelopment(),
        database: RedCodeDatabase,
        authController: AuthController,
        chatAPIService: any ChatAPIService,
        mediaAPIService: (any MediaAPIService)? = nil,
        emojiAPIService: (any EmojiAPIService)? = nil,
        settingsAPIService: (any SettingsAPIService)? = nil,
        pushAPIService: (any PushAPIService)? = nil,
        friendAPIService: (any FriendAPIService)? = nil,
        roomAPIService: (any RoomAPIService)? = nil,
        chatPreferencesStore: (any ChatPreferencesStore)? = nil,
        webSocketService: any ChatWebSocketService
    ) {
        self.environment = environment
        self.database = database
        self.authController = authController
        self.chatAPIService = chatAPIService
        self.mediaAPIService = mediaAPIService ?? MediaAPIClient(environment: environment)
        self.emojiAPIService = emojiAPIService ?? EmojiAPIClient(environment: environment)
        self.settingsAPIService = settingsAPIService ?? SettingsAPIClient(environment: environment)
        self.pushAPIService = pushAPIService ?? PushAPIClient(environment: environment)
        self.chatPreferencesStore = chatPreferencesStore ?? UserDefaultsChatPreferencesStore()
        self.appConfigStore = GRDBAppConfigStore(database: database)
        let resolvedFriendAPIService = friendAPIService ?? FriendAPIClient(environment: environment)
        self.friendAPIService = resolvedFriendAPIService
        self.roomAPIService = roomAPIService ?? RoomAPIClient(environment: environment)
        let e2eeSecureState = E2eeSecureStateStore(
            cipher: CryptoKitE2eeStateCipher(keyStore: KeychainKeyValueStore()),
            blobs: GRDBE2eeStateBlobStore(database: database)
        )
        let e2eeMLSAPI = E2eeMLSAPIClient(apiClient: APIClient(environment: environment))
        let e2eeDevices = E2eeDeviceLifecycle(
            storage: e2eeSecureState,
            mlsApi: e2eeMLSAPI
        )
        self.e2eeSessionLifecycle = E2eeSessionLifecycle(
            settings: SettingsE2eeRuntimeProvider(settings: self.settingsAPIService),
            devices: e2eeDevices,
            secureState: E2eeAccountSecureStateCleaner { accountID in
                try await e2eeSecureState.delete(accountID: accountID)
            },
            deviceLabel: "iPhone"
        )
        let directMessageCoordinator = E2eeDirectMessageCoordinator(
            storage: e2eeSecureState,
            lifecycle: e2eeDevices,
            api: e2eeMLSAPI
        )
        let incomingMessageResolver = E2eeIncomingMessageResolver(
            sessionStatus: self.e2eeSessionLifecycle,
            decryptor: directMessageCoordinator,
            deviceLabel: "iPhone"
        )
        self.incomingMessageResolver = incomingMessageResolver
        self.outgoingTextRouter = E2eeOutgoingTextRouter(
            sessionStatus: self.e2eeSessionLifecycle,
            sender: directMessageCoordinator,
            deviceLabel: "iPhone"
        )
        let chatListController = ChatListController(
            api: chatAPIService,
            cacheStore: GRDBChatSummaryCacheStore(database: database)
        )
        let messageCacheStore = GRDBMessageCacheStore(database: database)
        self.chatListController = chatListController
        self.messageCacheStore = messageCacheStore
        self.messageSearchStore = GRDBMessageSearchStore(messageCacheStore: messageCacheStore)
        self.contactsController = ContactsController(
            api: resolvedFriendAPIService,
            cacheStore: GRDBContactCacheStore(database: database)
        )
        self.addFriendController = AddFriendController(api: resolvedFriendAPIService)
        let pushController = PushController(
            authController: authController,
            api: self.pushAPIService,
            identityStore: UserDefaultsPushDeviceIdentityStore()
        )
        self.pushController = pushController
        self.chatRealtimeController = ChatRealtimeController(
            webSocket: webSocketService,
            listController: chatListController,
            messageCacheStore: messageCacheStore,
            localNotificationService: pushController,
            incomingResolver: incomingMessageResolver
        )
    }

    static func simulatorDevelopment(environment: RedCodeEnvironment = .simulatorDevelopment()) -> AppDependencies {
        do {
            return AppDependencies(
                environment: environment,
                database: try RedCodeDatabase.makeDatabase()
            )
        } catch {
            fatalError("初始化 iOS 本地数据容器失败: \(error)")
        }
    }

    static func current() -> AppDependencies {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--redcode-ui-testing-auth-fixture") {
            return uiTestingAuthFixture()
        }
        if ProcessInfo.processInfo.arguments.contains("--redcode-ui-testing-chat-fixture") {
            return uiTestingChatFixture()
        }
        #endif
        do {
            return simulatorDevelopment(environment: try RedCodeEnvironment.configuredDevelopment())
        } catch {
            fatalError("读取 iOS 运行环境配置失败: \(error)")
        }
    }

    func makeChatDetailController() -> ChatDetailController {
        ChatDetailController(
            api: chatAPIService,
            messageCacheStore: messageCacheStore,
            mediaAPI: mediaAPIService,
            attachmentCache: attachmentCache,
            incomingResolver: incomingMessageResolver,
            outgoingTextRouter: outgoingTextRouter
        )
    }

    var mediaAPI: any MediaAPIService {
        mediaAPIService
    }

    var emojiAPI: any EmojiAPIService {
        emojiAPIService
    }

    var messageAttachmentCache: AttachmentFileCache {
        attachmentCache
    }

    var mediaAvatarCache: AvatarFileCache {
        avatarCache
    }

    var mediaEmojiCache: EmojiFileCache {
        emojiCache
    }

    func makeGroupManagementController() -> GroupManagementController {
        GroupManagementController(
            api: roomAPIService,
            cacheStore: GRDBGroupCacheStore(database: database)
        )
    }

    func makeMessageSearchController() -> MessageSearchController {
        MessageSearchController(localSearchStore: messageSearchStore, remoteAPI: chatAPIService)
    }

    func makeEmojiStickerController() -> EmojiStickerController {
        EmojiStickerController(api: emojiAPIService, emojiCache: emojiCache)
    }

    func makeChatSettingsController() -> ChatSettingsController {
        ChatSettingsController(
            preferencesStore: chatPreferencesStore,
            messageCacheStore: messageCacheStore,
            attachmentCache: attachmentCache,
            avatarCache: avatarCache,
            emojiCache: emojiCache
        )
    }

    func makeSettingsController() -> SettingsController {
        SettingsController(
            authController: authController,
            api: settingsAPIService,
            configStore: appConfigStore
        )
    }

    var chatBackgroundPreferences: any ChatPreferencesStore {
        chatPreferencesStore
    }

    func clearLocalStateAfterLogout() async {
        await chatRealtimeController.stop()
        await pushController.clearNotificationState()
        try? GRDBChatSummaryCacheStore(database: database).clearAll()
        try? messageCacheStore.clearAll()
        try? GRDBContactCacheStore(database: database).clearAll()
        try? GRDBGroupCacheStore(database: database).clearAll()
        try? appConfigStore.clearAll()
        try? await attachmentCache.clearAll()
        try? await avatarCache.clearAll()
        try? await emojiCache.clearAll()
        try? await chatPreferencesStore.resetBackground()
    }

    func logoutAndClearLocalState() async {
        await pushController.unregisterCurrentDevice()
        try? await e2eeSessionLifecycle.onLogout()
        try? await authController.logout()
        await clearLocalStateAfterLogout()
    }

    func initializePushForAuthenticatedSession() async {
        pushController.restoreStoredIdentity()
        guard authController.state.isAuthenticated else {
            return
        }
        RedCodePushAppDelegate.install(pushController: pushController)
        let granted = await pushController.requestLocalNotificationPermission()
        guard granted else {
            return
        }
        #if canImport(UIKit)
        UIApplication.shared.registerForRemoteNotifications()
        #endif
    }
}

@MainActor
@main
struct RedCodeIOSApp: App {
    @State private var dependencies = AppDependencies.current()
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(RedCodePushAppDelegate.self) private var pushAppDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            AppRootView(dependencies: dependencies)
                .onAppear {
                    RedCodePushAppDelegate.install(pushController: dependencies.pushController)
                }
        }
    }
}

#if canImport(UIKit)
@MainActor
final class RedCodePushAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private static weak var installedPushController: PushController?
    private static var pendingPayloads: [PushNotificationPayload] = []

    static func install(pushController: PushController) {
        installedPushController = pushController
        pendingPayloads.forEach { pushController.handleNotificationPayload($0) }
        pendingPayloads.removeAll()
    }

    private static func deliver(_ payload: PushNotificationPayload) {
        if let installedPushController {
            installedPushController.handleNotificationPayload(payload)
        } else {
            pendingPayloads.append(payload)
        }
    }

    nonisolated func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenData = Data(deviceToken)
        Task { @MainActor [tokenData] in
            try? await Self.installedPushController?.registerAPNsDeviceToken(tokenData)
        }
    }

    nonisolated func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        let message = error.localizedDescription
        Task { @MainActor [message] in
            Self.installedPushController?.recordRemoteRegistrationFailure(message)
        }
    }

    nonisolated func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let payload = PushNotificationPayload(userInfo: userInfo)
        Task { @MainActor [payload] in
            Self.deliver(payload)
        }
        completionHandler(.newData)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let payload = PushNotificationPayload(userInfo: response.notification.request.content.userInfo)
        await MainActor.run {
            Self.deliver(payload)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []
    }
}
#else
@MainActor
enum RedCodePushAppDelegate {
    static func install(pushController: PushController) {}
}
#endif
