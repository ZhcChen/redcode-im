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

    private let environment: RedCodeEnvironment
    private let modelContainer: ModelContainer
    private let chatAPIService: any ChatAPIService
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
            webSocketService: WebSocketClient(configuration: WebSocketConfiguration(environment: environment))
        )
    }

    init(
        environment: RedCodeEnvironment = .simulatorDevelopment(),
        modelContainer: ModelContainer,
        authController: AuthController,
        chatAPIService: any ChatAPIService,
        webSocketService: any ChatWebSocketService
    ) {
        self.environment = environment
        self.modelContainer = modelContainer
        self.authController = authController
        self.chatAPIService = chatAPIService
        let chatListController = ChatListController(
            api: chatAPIService,
            cacheStore: SwiftDataChatSummaryCacheStore(container: modelContainer)
        )
        let messageCacheStore = SwiftDataMessageCacheStore(container: modelContainer)
        self.chatListController = chatListController
        self.messageCacheStore = messageCacheStore
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
