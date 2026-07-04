import SwiftUI
import RedCodeCore
import RedCodeFeatures
import RedCodeNetworking
import RedCodeStorage
import SwiftData

@MainActor
final class AppDependencies {
    let authController: AuthController
    let chatListController: ChatListController
    let chatRealtimeController: ChatRealtimeController
    let contactsController: ContactsController
    let addFriendController: AddFriendController

    private let environment: RedCodeEnvironment
    private let modelContainer: ModelContainer
    private let chatAPIService: any ChatAPIService
    private let mediaAPIService: any MediaAPIService
    private let emojiAPIService: any EmojiAPIService
    private let settingsAPIService: any SettingsAPIService
    private let friendAPIService: any FriendAPIService
    private let roomAPIService: any RoomAPIService
    private let messageCacheStore: SwiftDataMessageCacheStore
    private let messageSearchStore: SwiftDataMessageSearchStore
    private let chatPreferencesStore: any ChatPreferencesStore
    private let appConfigStore: SwiftDataAppConfigStore
    private let attachmentCache = AttachmentFileCache()
    private let avatarCache = AvatarFileCache()
    private let emojiCache = EmojiFileCache()

    convenience init(
        environment: RedCodeEnvironment = .simulatorDevelopment(),
        modelContainer: ModelContainer
    ) {
        let authController = AuthController(
            api: AuthAPIClient(environment: environment),
            sessionStore: KeyValueAuthSessionStore(keyValueStore: KeychainKeyValueStore())
        )
        let chatAPIService = ChatAPIClient(environment: environment)
        let mediaAPIService = MediaAPIClient(environment: environment)
        self.init(
            environment: environment,
            modelContainer: modelContainer,
            authController: authController,
            chatAPIService: chatAPIService,
            mediaAPIService: mediaAPIService,
            emojiAPIService: EmojiAPIClient(environment: environment),
            settingsAPIService: SettingsAPIClient(environment: environment),
            friendAPIService: FriendAPIClient(environment: environment),
            roomAPIService: RoomAPIClient(environment: environment),
            webSocketService: WebSocketClient(configuration: WebSocketConfiguration(environment: environment))
        )
    }

    init(
        environment: RedCodeEnvironment = .simulatorDevelopment(),
        modelContainer: ModelContainer,
        authController: AuthController,
        chatAPIService: any ChatAPIService,
        mediaAPIService: (any MediaAPIService)? = nil,
        emojiAPIService: (any EmojiAPIService)? = nil,
        settingsAPIService: (any SettingsAPIService)? = nil,
        friendAPIService: (any FriendAPIService)? = nil,
        roomAPIService: (any RoomAPIService)? = nil,
        chatPreferencesStore: (any ChatPreferencesStore)? = nil,
        webSocketService: any ChatWebSocketService
    ) {
        self.environment = environment
        self.modelContainer = modelContainer
        self.authController = authController
        self.chatAPIService = chatAPIService
        self.mediaAPIService = mediaAPIService ?? MediaAPIClient(environment: environment)
        self.emojiAPIService = emojiAPIService ?? EmojiAPIClient(environment: environment)
        self.settingsAPIService = settingsAPIService ?? SettingsAPIClient(environment: environment)
        self.chatPreferencesStore = chatPreferencesStore ?? UserDefaultsChatPreferencesStore()
        self.appConfigStore = SwiftDataAppConfigStore(container: modelContainer)
        let resolvedFriendAPIService = friendAPIService ?? FriendAPIClient(environment: environment)
        self.friendAPIService = resolvedFriendAPIService
        self.roomAPIService = roomAPIService ?? RoomAPIClient(environment: environment)
        let chatListController = ChatListController(
            api: chatAPIService,
            cacheStore: SwiftDataChatSummaryCacheStore(container: modelContainer)
        )
        let messageCacheStore = SwiftDataMessageCacheStore(container: modelContainer)
        self.chatListController = chatListController
        self.messageCacheStore = messageCacheStore
        self.messageSearchStore = SwiftDataMessageSearchStore(messageCacheStore: messageCacheStore)
        self.contactsController = ContactsController(
            api: resolvedFriendAPIService,
            cacheStore: SwiftDataContactCacheStore(container: modelContainer)
        )
        self.addFriendController = AddFriendController(api: resolvedFriendAPIService)
        self.chatRealtimeController = ChatRealtimeController(
            webSocket: webSocketService,
            listController: chatListController,
            messageCacheStore: messageCacheStore
        )
    }

    static func simulatorDevelopment() -> AppDependencies {
        do {
            return AppDependencies(modelContainer: try RedCodeStorageSchema.makeModelContainer())
        } catch {
            fatalError("初始化 iOS 本地数据容器失败: \(error)")
        }
    }

    static func current() -> AppDependencies {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--redcode-ui-testing-chat-fixture") {
            return uiTestingChatFixture()
        }
        #endif
        return simulatorDevelopment()
    }

    func makeChatDetailController() -> ChatDetailController {
        ChatDetailController(
            api: chatAPIService,
            messageCacheStore: messageCacheStore,
            mediaAPI: mediaAPIService,
            attachmentCache: attachmentCache
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
            cacheStore: SwiftDataGroupCacheStore(container: modelContainer)
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
        try? SwiftDataChatSummaryCacheStore(container: modelContainer).clearAll()
        try? messageCacheStore.clearAll()
        try? SwiftDataContactCacheStore(container: modelContainer).clearAll()
        try? SwiftDataGroupCacheStore(container: modelContainer).clearAll()
        try? appConfigStore.clearAll()
        try? await attachmentCache.clearAll()
        try? await avatarCache.clearAll()
        try? await emojiCache.clearAll()
        try? await chatPreferencesStore.resetBackground()
    }
}

@MainActor
@main
struct RedCodeIOSApp: App {
    @State private var dependencies = AppDependencies.current()

    var body: some Scene {
        WindowGroup {
            AppRootView(dependencies: dependencies)
        }
    }
}
