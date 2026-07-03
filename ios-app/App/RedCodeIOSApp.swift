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
    private let messageCacheStore: SwiftDataMessageCacheStore

    init(
        environment: RedCodeEnvironment = .simulatorDevelopment(),
        modelContainer: ModelContainer
    ) {
        self.environment = environment
        self.modelContainer = modelContainer
        self.authController = AuthController(
            api: AuthAPIClient(environment: environment),
            sessionStore: KeyValueAuthSessionStore(keyValueStore: KeychainKeyValueStore())
        )
        self.chatListController = ChatListController(
            api: ChatAPIClient(environment: environment),
            cacheStore: SwiftDataChatSummaryCacheStore(container: modelContainer)
        )
        self.messageCacheStore = SwiftDataMessageCacheStore(container: modelContainer)
        self.chatRealtimeController = ChatRealtimeController(
            webSocket: WebSocketClient(configuration: WebSocketConfiguration(environment: environment)),
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

    func makeChatDetailController() -> ChatDetailController {
        ChatDetailController(
            api: ChatAPIClient(environment: environment),
            messageCacheStore: messageCacheStore
        )
    }
}

@MainActor
@main
struct RedCodeIOSApp: App {
    @State private var dependencies = AppDependencies.simulatorDevelopment()

    var body: some Scene {
        WindowGroup {
            AppRootView(dependencies: dependencies)
        }
    }
}
