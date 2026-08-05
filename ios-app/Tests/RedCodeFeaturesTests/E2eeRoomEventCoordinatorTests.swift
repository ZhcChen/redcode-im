import XCTest
@testable import RedCodeCore
@testable import RedCodeFeatures
@testable import RedCodeNetworking

@MainActor
final class E2eeRoomEventCoordinatorTests: XCTestCase {
    func testPlaintextRuntimeDoesNotMutateMLS() async throws {
        let fixture = Fixture(runtime: .init(serverStorageMode: "persist", contentAuditMode: "plaintext"))
        try await fixture.lifecycle.onAuthenticated(session: fixture.session)

        try await fixture.coordinator.reconcile(roomID: "room-1")

        let calls = await fixture.reconciler.snapshot()
        XCTAssertEqual(calls, [])
    }

    func testReadyRuntimeReconcilesUsingAuthenticatedSession() async throws {
        let fixture = Fixture(runtime: .init(serverStorageMode: "persist", contentAuditMode: "e2ee"))
        try await fixture.lifecycle.onAuthenticated(session: fixture.session)

        try await fixture.coordinator.reconcile(roomID: " room-1 ")

        let calls = await fixture.reconciler.snapshot()
        XCTAssertEqual(calls, ["account-a:room-1:access-token"])
    }

    func testAccountMismatchFailsClosed() async throws {
        let fixture = Fixture(runtime: .init(serverStorageMode: "persist", contentAuditMode: "e2ee"))
        try await fixture.lifecycle.onAuthenticated(session: fixture.session)
        fixture.sessionBox.value = AuthSession(
            token: "other-token",
            user: AuthUser(id: "account-b", username: "bob")
        )

        do {
            try await fixture.coordinator.reconcile(roomID: "room-1")
            XCTFail("Expected account mismatch")
        } catch let error as E2eeSessionLifecycleError {
            XCTAssertEqual(error.message, "E2EE 账号与认证会话不匹配")
        }
        let calls = await fixture.reconciler.snapshot()
        XCTAssertEqual(calls, [])
    }

    func testConcurrentEventsShareOneRoomReconcile() async throws {
        let fixture = Fixture(runtime: .init(serverStorageMode: "persist", contentAuditMode: "e2ee"))
        try await fixture.lifecycle.onAuthenticated(session: fixture.session)
        await fixture.reconciler.pause()

        async let first: Void = fixture.coordinator.reconcile(roomID: "room-1")
        async let second: Void = fixture.coordinator.reconcile(roomID: "room-1")
        await fixture.reconciler.waitUntilStarted()
        await fixture.reconciler.resume()
        _ = try await (first, second)

        let calls = await fixture.reconciler.snapshot()
        XCTAssertEqual(calls, ["account-a:room-1:access-token"])
    }
}

@MainActor
private final class Fixture {
    let sessionBox: SessionBox
    let lifecycle: E2eeSessionLifecycle
    let reconciler = RecordingGroupReconciler()
    let coordinator: E2eeRoomEventCoordinator

    init(runtime: MessageRuntimeSettings) {
        let session = AuthSession(token: "access-token", user: AuthUser(id: "account-a", username: "alice"))
        sessionBox = SessionBox(value: session)
        lifecycle = E2eeSessionLifecycle(
            settings: FixedRuntimeSettings(runtime: runtime),
            devices: ActiveDeviceLifecycle(),
            secureState: NoopSecureStateCleaner(),
            deviceLabel: "iPhone"
        )
        coordinator = E2eeRoomEventCoordinator(
            sessionStatus: lifecycle,
            currentSession: { [weak sessionBox] in sessionBox?.value },
            coordinator: reconciler
        )
    }

    var session: AuthSession { sessionBox.value! }
}

@MainActor
private final class SessionBox {
    var value: AuthSession?
    init(value: AuthSession?) { self.value = value }
}

private actor FixedRuntimeSettings: E2eeRuntimeSettingsProviding {
    let runtime: MessageRuntimeSettings
    init(runtime: MessageRuntimeSettings) { self.runtime = runtime }
    func fetchMessageRuntime() async throws -> MessageRuntimeSettings { runtime }
}

private actor ActiveDeviceLifecycle: E2eeAppDeviceLifecycle {
    func ensureReady(accountID: String, deviceLabel: String, token: String) async throws -> E2eeDeviceProfile {
        E2eeDeviceProfile(
            deviceId: "device-a",
            deviceLabel: deviceLabel,
            registered: true,
            keyPackagePublished: true
        )
    }

    func topUpKeyPackages(accountID: String, token: String) async throws -> Int { 0 }
}

private actor NoopSecureStateCleaner: E2eeAccountSecureStateClearing {
    func delete(accountID: String) async throws {}
}

private actor RecordingGroupReconciler: E2eeGroupReconciling {
    private var calls: [String] = []
    private var isPaused = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func reconcileGroup(accountID: String, roomID: String, token: String) async throws {
        calls.append("\(accountID):\(roomID):\(token)")
        if isPaused {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }

    func snapshot() -> [String] { calls }

    func pause() { isPaused = true }

    func waitUntilStarted() async {
        while calls.isEmpty {
            await Task.yield()
        }
    }

    func resume() {
        isPaused = false
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}
