import Foundation

#if canImport(UserNotifications)
import UserNotifications
#endif

@MainActor
public protocol LocalNotificationScheduling: AnyObject {
    func requestAuthorization() async throws -> Bool
    func scheduleChatNotification(
        identifier: String,
        title: String,
        body: String,
        payload: PushNotificationPayload
    ) async throws
    func clearDeliveredNotifications() async
}

#if canImport(UserNotifications)
public final class UserNotificationCenterScheduler: LocalNotificationScheduling {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    public func scheduleChatNotification(
        identifier: String,
        title: String,
        body: String,
        payload: PushNotificationPayload
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "聊天" : title
        content.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        content.sound = .default
        content.userInfo = payload.dictionary

        let request = UNNotificationRequest(
            identifier: identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? UUID().uuidString
                : identifier,
            content: content,
            trigger: nil
        )
        try await center.add(request)
    }

    public func clearDeliveredNotifications() async {
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
    }
}
#else
public final class UserNotificationCenterScheduler: LocalNotificationScheduling {
    public init() {}

    public func requestAuthorization() async throws -> Bool {
        false
    }

    public func scheduleChatNotification(
        identifier: String,
        title: String,
        body: String,
        payload: PushNotificationPayload
    ) async throws {}

    public func clearDeliveredNotifications() async {}
}
#endif
