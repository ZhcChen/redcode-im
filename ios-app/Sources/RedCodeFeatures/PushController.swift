import Foundation
import Combine
import RedCodeCore
import RedCodeNetworking
import RedCodeStorage

public enum PushDeliveryChannel: String, Equatable, Sendable {
    case fcm
    case apns
}

@MainActor
public protocol ChatLocalNotificationService: AnyObject {
    func maybeShowChatMessage(_ message: ChatMessage, chat: ChatSummary?) async
}

@MainActor
public final class NotificationNavigationController: ObservableObject {
    @Published public private(set) var pendingDestination: PushNavigationDestination?

    public init() {}

    public func receive(payload: PushNotificationPayload) {
        pendingDestination = PushNavigationDestination(payload: payload)
    }

    public func receive(userInfo: [AnyHashable: Any]) {
        receive(payload: PushNotificationPayload(userInfo: userInfo))
    }

    public func consumePendingDestination() -> PushNavigationDestination? {
        let destination = pendingDestination
        pendingDestination = nil
        return destination
    }

    public func clear() {
        pendingDestination = nil
    }
}

@MainActor
public final class PushController: ChatLocalNotificationService, ObservableObject {
    @Published public private(set) var notificationPermissionGranted = false
    @Published public private(set) var registeredIdentity: StoredPushDeviceIdentity?
    @Published public private(set) var isAppActive = true
    @Published public private(set) var lastErrorMessage: String?

    public let navigationController: NotificationNavigationController

    private let authController: AuthController
    private let api: any PushAPIService
    private let identityStore: any PushDeviceIdentityStore
    private let localNotifications: any LocalNotificationScheduling

    public init(
        authController: AuthController,
        api: any PushAPIService,
        identityStore: any PushDeviceIdentityStore,
        localNotifications: any LocalNotificationScheduling = UserNotificationCenterScheduler(),
        navigationController: NotificationNavigationController = NotificationNavigationController()
    ) {
        self.authController = authController
        self.api = api
        self.identityStore = identityStore
        self.localNotifications = localNotifications
        self.navigationController = navigationController
    }

    public func restoreStoredIdentity() {
        registeredIdentity = try? identityStore.loadIdentity()
    }

    @discardableResult
    public func requestLocalNotificationPermission() async -> Bool {
        do {
            let granted = try await localNotifications.requestAuthorization()
            notificationPermissionGranted = granted
            return granted
        } catch {
            lastErrorMessage = error.localizedDescription
            notificationPermissionGranted = false
            return false
        }
    }

    public func updateAppActiveState(_ isActive: Bool) {
        isAppActive = isActive
    }

    public func recordRemoteRegistrationFailure(_ message: String) {
        lastErrorMessage = message
    }

    public func registerFCMDeviceToken(_ token: String) async throws {
        try await registerDeviceToken(token, channel: .fcm)
    }

    public func registerAPNsDeviceToken(_ tokenData: Data) async throws {
        try await registerDeviceToken(tokenData.hexEncodedString, channel: .apns)
    }

    public func registerDeviceToken(
        _ token: String,
        channel: PushDeliveryChannel
    ) async throws {
        guard let accessToken = authController.session?.token else {
            throw RedCodeError.authentication("未登录")
        }
        let deviceID = try identityStore.getOrCreateDeviceID()
        let response = try await api.registerDevice(
            token: accessToken,
            deviceID: deviceID,
            deviceToken: token,
            platform: "ios",
            channel: channel.rawValue
        )
        guard response.success else {
            throw RedCodeError.network(response.message)
        }
        try identityStore.saveRegisteredToken(token, channel: channel.rawValue)
        registeredIdentity = try identityStore.loadIdentity()
        lastErrorMessage = nil
    }

    public func unregisterCurrentDevice() async {
        guard let accessToken = authController.session?.token else {
            try? identityStore.clearRegisteredToken()
            registeredIdentity = try? identityStore.loadIdentity()
            return
        }

        do {
            guard let identity = try identityStore.loadIdentity() else {
                return
            }
            _ = try await api.unregisterDevice(token: accessToken, deviceID: identity.deviceID)
            try identityStore.clearRegisteredToken()
            registeredIdentity = try identityStore.loadIdentity()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func handleNotificationUserInfo(_ userInfo: [AnyHashable: Any]) {
        navigationController.receive(userInfo: userInfo)
    }

    public func handleNotificationPayload(_ payload: PushNotificationPayload) {
        navigationController.receive(payload: payload)
    }

    public func maybeShowChatMessage(_ message: ChatMessage, chat: ChatSummary?) async {
        guard !isAppActive else {
            return
        }
        guard message.senderID != authController.session?.user.id else {
            return
        }
        guard !message.roomID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let payload = PushNotificationPayload(
            type: .message,
            roomID: message.roomID,
            messageID: message.id,
            roomType: chat?.roomType,
            senderID: message.senderID,
            senderName: message.senderName,
            chatName: chat?.displayName
        )

        do {
            try await localNotifications.scheduleChatNotification(
                identifier: message.id,
                title: chat?.displayName ?? message.senderName,
                body: Self.previewText(for: message),
                payload: payload
            )
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func clearNotificationState() async {
        navigationController.clear()
        await localNotifications.clearDeliveredNotifications()
        try? identityStore.clearRegisteredToken()
        registeredIdentity = try? identityStore.loadIdentity()
        lastErrorMessage = nil
    }

    private static func previewText(for message: ChatMessage) -> String {
        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !content.isEmpty {
            return content
        }
        switch message.messageType {
        case .image:
            return "[图片]"
        case .audio:
            return "[语音]"
        case .video:
            return "[视频]"
        case .file:
            return "[文件]"
        case .mixed:
            return "[消息]"
        case .system:
            return "[系统消息]"
        case .text:
            return "收到一条新消息"
        }
    }
}

private extension Data {
    var hexEncodedString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
