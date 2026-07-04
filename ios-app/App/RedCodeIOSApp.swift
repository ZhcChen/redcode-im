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
    private let friendAPIService: any FriendAPIService
    private let roomAPIService: any RoomAPIService
    private let messageCacheStore: SwiftDataMessageCacheStore

    convenience init(
        environment: RedCodeEnvironment = .simulatorDevelopment(),
        modelContainer: ModelContainer
    ) {
        let authController = AuthController(
            api: AuthAPIClient(environment: environment),
            sessionStore: KeyValueAuthSessionStore(keyValueStore: KeychainKeyValueStore())
        )
        let chatAPIService = ChatAPIClient(environment: environment)
        self.init(
            environment: environment,
            modelContainer: modelContainer,
            authController: authController,
            chatAPIService: chatAPIService,
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
        friendAPIService: (any FriendAPIService)? = nil,
        roomAPIService: (any RoomAPIService)? = nil,
        webSocketService: any ChatWebSocketService
    ) {
        self.environment = environment
        self.modelContainer = modelContainer
        self.authController = authController
        self.chatAPIService = chatAPIService
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
            messageCacheStore: messageCacheStore
        )
    }

    func makeGroupManagementController() -> GroupManagementController {
        GroupManagementController(
            api: roomAPIService,
            cacheStore: SwiftDataGroupCacheStore(container: modelContainer)
        )
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
