import XCTest
@testable import RedCodeCore
@testable import RedCodeFeatures
@testable import RedCodeNetworking
@testable import RedCodeStorage

@MainActor
final class PushControllerTests: XCTestCase {
    func testRequestLocalNotificationPermissionUpdatesState() async throws {
        let localNotifications = MockLocalNotificationScheduler(permissionResult: true)
        let controller = PushController(
            authController: try await makeAuthController(authenticated: true),
            api: MockPushAPIService(),
            identityStore: MockPushDeviceIdentityStore(),
            localNotifications: localNotifications
        )

        let granted = await controller.requestLocalNotificationPermission()

        XCTAssertTrue(granted)
        XCTAssertTrue(controller.notificationPermissionGranted)
        XCTAssertEqual(localNotifications.authorizationRequests, 1)
    }

    func testRegisterFCMTokenUploadsDeviceAndPersistsIdentity() async throws {
        let api = MockPushAPIService()
        let identityStore = MockPushDeviceIdentityStore(deviceID: "device-1")
        let controller = PushController(
            authController: try await makeAuthController(authenticated: true),
            api: api,
            identityStore: identityStore,
            localNotifications: MockLocalNotificationScheduler()
        )

        try await controller.registerFCMDeviceToken("fcm-token")

        let calls = await api.recordedCalls()
        XCTAssertEqual(calls, [
            .register(
                token: "access-token",
                deviceID: "device-1",
                deviceToken: "fcm-token",
                platform: "ios",
                channel: "fcm"
            ),
        ])
        XCTAssertEqual(controller.registeredIdentity?.deviceID, "device-1")
        XCTAssertEqual(controller.registeredIdentity?.deviceToken, "fcm-token")
        XCTAssertEqual(controller.registeredIdentity?.channel, "fcm")
        XCTAssertNil(controller.lastErrorMessage)
    }

    func testRegisterAPNsTokenConvertsTokenDataToHex() async throws {
        let api = MockPushAPIService()
        let controller = PushController(
            authController: try await makeAuthController(authenticated: true),
            api: api,
            identityStore: MockPushDeviceIdentityStore(deviceID: "device-apns"),
            localNotifications: MockLocalNotificationScheduler()
        )

        try await controller.registerAPNsDeviceToken(Data([0x0a, 0xff, 0x10]))

        let calls = await api.recordedCalls()
        XCTAssertEqual(calls, [
            .register(
                token: "access-token",
                deviceID: "device-apns",
                deviceToken: "0aff10",
                platform: "ios",
                channel: "apns"
            ),
        ])
    }

    func testRegisterDeviceRequiresAuthenticatedSession() async throws {
        let controller = PushController(
            authController: try await makeAuthController(authenticated: false),
            api: MockPushAPIService(),
            identityStore: MockPushDeviceIdentityStore(),
            localNotifications: MockLocalNotificationScheduler()
        )

        do {
            try await controller.registerFCMDeviceToken("fcm-token")
            XCTFail("Expected unauthenticated push registration failure")
        } catch let error as RedCodeError {
            XCTAssertEqual(error, .authentication("未登录"))
        }
    }

    func testUnregisterCurrentDeviceCallsBackendAndClearsRegisteredToken() async throws {
        let api = MockPushAPIService()
        let identityStore = MockPushDeviceIdentityStore(deviceID: "device-1")
        try identityStore.saveRegisteredToken("fcm-token", channel: "fcm")
        let controller = PushController(
            authController: try await makeAuthController(authenticated: true),
            api: api,
            identityStore: identityStore,
            localNotifications: MockLocalNotificationScheduler()
        )

        await controller.unregisterCurrentDevice()

        let calls = await api.recordedCalls()
        XCTAssertEqual(calls, [
            .unregister(token: "access-token", deviceID: "device-1"),
        ])
        let identity = try XCTUnwrap(try identityStore.loadIdentity())
        XCTAssertNil(identity.deviceToken)
        XCTAssertNil(identity.channel)
        XCTAssertEqual(controller.registeredIdentity?.deviceID, "device-1")
        XCTAssertNil(controller.registeredIdentity?.deviceToken)
    }

    func testLocalNotificationSkipsForegroundAndOwnMessagesThenSchedulesBackgroundIncomingMessage() async throws {
        let localNotifications = MockLocalNotificationScheduler()
        let controller = PushController(
            authController: try await makeAuthController(authenticated: true),
            api: MockPushAPIService(),
            identityStore: MockPushDeviceIdentityStore(),
            localNotifications: localNotifications
        )
        let chat = ChatSummary(roomID: "room-1", displayName: "Alice", roomType: .privateChat)

        await controller.maybeShowChatMessage(
            chatMessage(id: "foreground", senderID: "user-2", content: "hello"),
            chat: chat
        )
        controller.updateAppActiveState(false)
        await controller.maybeShowChatMessage(
            chatMessage(id: "own", senderID: "user-1", content: "mine"),
            chat: chat
        )
        await controller.maybeShowChatMessage(
            chatMessage(id: "incoming", senderID: "user-2", content: "hello"),
            chat: chat
        )

        XCTAssertEqual(localNotifications.scheduled.map(\.identifier), ["incoming"])
        XCTAssertEqual(localNotifications.scheduled.first?.title, "Alice")
        XCTAssertEqual(localNotifications.scheduled.first?.body, "hello")
        XCTAssertEqual(localNotifications.scheduled.first?.payload.roomID, "room-1")
        XCTAssertEqual(localNotifications.scheduled.first?.payload.messageID, "incoming")
    }

    func testEncryptedLocalNotificationUsesFixedPlaceholder() async throws {
        let localNotifications = MockLocalNotificationScheduler()
        let controller = PushController(
            authController: try await makeAuthController(authenticated: true),
            api: MockPushAPIService(),
            identityStore: MockPushDeviceIdentityStore(),
            localNotifications: localNotifications
        )
        controller.updateAppActiveState(false)
        let encrypted = ChatMessage(
            id: "encrypted",
            roomID: "room-1",
            senderID: "user-2",
            senderName: "Alice",
            content: "decrypted secret",
            encryptedContent: "Y2lwaGVydGV4dA==",
            encryptionMetadata: ChatEncryptionMetadata(
                protocolName: "mls",
                version: 1,
                epoch: 7,
                senderDeviceID: "device-2",
                contentType: "application"
            ),
            timestamp: Date(timeIntervalSince1970: 1_000)
        )

        await controller.maybeShowChatMessage(
            encrypted,
            chat: ChatSummary(roomID: "room-1", displayName: "Alice", roomType: .privateChat)
        )

        XCTAssertEqual(localNotifications.scheduled.first?.body, E2eePeripheralPolicy.pushPlaceholder)
        XCTAssertFalse(localNotifications.scheduled.first?.body.contains("secret") == true)
    }

    func testNotificationPayloadCreatesAndConsumesNavigationDestination() async throws {
        let controller = PushController(
            authController: try await makeAuthController(authenticated: true),
            api: MockPushAPIService(),
            identityStore: MockPushDeviceIdentityStore(),
            localNotifications: MockLocalNotificationScheduler()
        )

        controller.handleNotificationUserInfo([
            "type": "message",
            "room_id": "group-1",
            "message_id": "message-1",
            "room_type": "group",
            "chat_name": "Team",
        ])

        XCTAssertEqual(
            controller.navigationController.pendingDestination,
            .chat(roomID: "group-1", roomType: .group, chatName: "Team", messageID: "message-1")
        )
        XCTAssertEqual(
            controller.navigationController.consumePendingDestination(),
            .chat(roomID: "group-1", roomType: .group, chatName: "Team", messageID: "message-1")
        )
        XCTAssertNil(controller.navigationController.pendingDestination)

        controller.handleNotificationPayload(PushNotificationPayload(type: .friendRequest, requestID: "req-1"))
        XCTAssertEqual(controller.navigationController.pendingDestination, .friendRequests)
    }

    func testClearNotificationStateClearsDeliveredNotificationsAndToken() async throws {
        let localNotifications = MockLocalNotificationScheduler()
        let identityStore = MockPushDeviceIdentityStore(deviceID: "device-1")
        try identityStore.saveRegisteredToken("fcm-token", channel: "fcm")
        let controller = PushController(
            authController: try await makeAuthController(authenticated: true),
            api: MockPushAPIService(),
            identityStore: identityStore,
            localNotifications: localNotifications
        )
        controller.handleNotificationPayload(PushNotificationPayload(type: .friendRequest, requestID: "req-1"))

        await controller.clearNotificationState()

        XCTAssertNil(controller.navigationController.pendingDestination)
        XCTAssertEqual(localNotifications.clearDeliveredCount, 1)
        XCTAssertNil(try identityStore.loadIdentity()?.deviceToken)
        XCTAssertNil(controller.lastErrorMessage)
    }

    private func makeAuthController(authenticated: Bool) async throws -> AuthController {
        let store = KeyValueAuthSessionStore(keyValueStore: InMemoryKeyValueStore())
        if authenticated {
            try await store.save(
                AuthSession(token: "access-token", user: AuthUser(id: "user-1", username: "bear"))
            )
        }
        let controller = AuthController(api: MockPushAuthAPIService(), sessionStore: store)
        await controller.restoreSession()
        return controller
    }

    private func chatMessage(id: String, senderID: String, content: String) -> ChatMessage {
        ChatMessage(
            id: id,
            roomID: "room-1",
            senderID: senderID,
            senderName: senderID == "user-1" ? "Me" : "Alice",
            content: content,
            timestamp: Date(timeIntervalSince1970: 1_000)
        )
    }
}

private enum PushAPICall: Equatable, Sendable {
    case register(token: String, deviceID: String, deviceToken: String, platform: String, channel: String)
    case unregister(token: String, deviceID: String)
}

private actor MockPushAPIService: PushAPIService {
    private var calls: [PushAPICall] = []

    func registerDevice(
        token: String,
        deviceID: String,
        deviceToken: String,
        platform: String,
        channel: String
    ) async throws -> RegisterPushDeviceResponse {
        calls.append(
            .register(
                token: token,
                deviceID: deviceID,
                deviceToken: deviceToken,
                platform: platform,
                channel: channel
            )
        )
        return RegisterPushDeviceResponse(success: true, message: "ok", deviceID: deviceID)
    }

    func unregisterDevice(token: String, deviceID: String) async throws -> UnregisterPushDeviceResponse {
        calls.append(.unregister(token: token, deviceID: deviceID))
        return UnregisterPushDeviceResponse(success: true, message: "deleted")
    }

    func recordedCalls() -> [PushAPICall] {
        calls
    }
}

@MainActor
private final class MockPushDeviceIdentityStore: PushDeviceIdentityStore {
    private var deviceID: String?
    private var deviceToken: String?
    private var channel: String?
    private var updatedAt: Date?

    init(deviceID: String = "device-1") {
        self.deviceID = deviceID
    }

    func getOrCreateDeviceID() throws -> String {
        if let deviceID {
            return deviceID
        }
        let next = "generated-device"
        deviceID = next
        return next
    }

    func loadIdentity() throws -> StoredPushDeviceIdentity? {
        guard let deviceID else {
            return nil
        }
        return StoredPushDeviceIdentity(
            deviceID: deviceID,
            deviceToken: deviceToken,
            channel: channel,
            updatedAt: updatedAt
        )
    }

    func saveRegisteredToken(_ token: String, channel: String) throws {
        _ = try getOrCreateDeviceID()
        self.deviceToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        self.channel = channel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.updatedAt = Date(timeIntervalSince1970: 1_000)
    }

    func clearRegisteredToken() throws {
        deviceToken = nil
        channel = nil
        updatedAt = nil
    }

    func clearAll() throws {
        deviceID = nil
        try clearRegisteredToken()
    }
}

private struct ScheduledNotification: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
    let payload: PushNotificationPayload
}

@MainActor
private final class MockLocalNotificationScheduler: LocalNotificationScheduling {
    var authorizationRequests = 0
    var scheduled: [ScheduledNotification] = []
    var clearDeliveredCount = 0

    private let permissionResult: Bool

    init(permissionResult: Bool = true) {
        self.permissionResult = permissionResult
    }

    func requestAuthorization() async throws -> Bool {
        authorizationRequests += 1
        return permissionResult
    }

    func scheduleChatNotification(
        identifier: String,
        title: String,
        body: String,
        payload: PushNotificationPayload
    ) async throws {
        scheduled.append(
            ScheduledNotification(identifier: identifier, title: title, body: body, payload: payload)
        )
    }

    func clearDeliveredNotifications() async {
        clearDeliveredCount += 1
    }
}

private actor MockPushAuthAPIService: AuthAPIService {
    func register(username: String, password: String, nickname: String?) async throws -> AuthUser {
        AuthUser(id: "user-1", username: username, nickname: nickname)
    }

    func login(username: String, password: String) async throws -> AuthSession {
        AuthSession(token: "access-token", user: AuthUser(id: "user-1", username: username))
    }

    func currentUser(token: String) async throws -> AuthUser {
        AuthUser(id: "user-1", username: "bear")
    }

    func refresh(refreshToken: String) async throws -> AuthSession {
        AuthSession(token: "access-token", refreshToken: refreshToken, user: AuthUser(id: "user-1", username: "bear"))
    }

    func updateProfile(
        token: String,
        nickname: String?,
        avatarURL: String?,
        avatarObjectKey: String?
    ) async throws -> AuthUser {
        AuthUser(id: "user-1", username: "bear", nickname: nickname)
    }

    func changePassword(token: String, oldPassword: String, newPassword: String) async throws {}

    func resetPasswordWithSMS(
        token: String,
        phone: String,
        code: String,
        newPassword: String
    ) async throws -> ResetPasswordWithSMSResponse {
        ResetPasswordWithSMSResponse(success: true, message: "密码已重置，请使用新密码登录")
    }
}
