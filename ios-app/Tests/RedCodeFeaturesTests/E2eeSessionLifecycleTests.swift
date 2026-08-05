import XCTest
@testable import RedCodeCore
@testable import RedCodeFeatures
@testable import RedCodeNetworking

@MainActor
final class E2eeSessionLifecycleTests: XCTestCase {
    func testPlaintextRuntimeDoesNotInitializeMLS() async throws {
        let fixture = Fixture(runtime: .init(serverStorageMode: "persist", contentAuditMode: "plaintext"))

        try await fixture.lifecycle.onAuthenticated(session: fixture.session("account-a"))

        let ensureCalls = await fixture.devices.ensureCallSnapshot()
        let topUpCalls = await fixture.devices.topUpCallSnapshot()
        XCTAssertEqual(fixture.lifecycle.status, .plaintext)
        XCTAssertEqual(ensureCalls, [])
        XCTAssertEqual(topUpCalls, [])
    }

    func testE2eeRuntimeInitializesAndTopsUpActiveDevice() async throws {
        let fixture = Fixture(runtime: .init(serverStorageMode: "persist", contentAuditMode: "e2ee"))

        try await fixture.lifecycle.onAuthenticated(session: fixture.session("account-a"))

        let ensureCalls = await fixture.devices.ensureCallSnapshot()
        let topUpCalls = await fixture.devices.topUpCallSnapshot()
        XCTAssertEqual(fixture.lifecycle.status, .ready(accountID: "account-a", deviceID: "device-a"))
        XCTAssertEqual(ensureCalls, ["account-a:iPhone:token-account-a"])
        XCTAssertEqual(topUpCalls, ["account-a:token-account-a"])
    }

    func testConcurrentForegroundRefreshSharesOnePreparation() async throws {
        let fixture = Fixture(runtime: .init(serverStorageMode: "persist", contentAuditMode: "e2ee"))
        try await fixture.lifecycle.onAuthenticated(session: fixture.session("account-a"))
        await fixture.devices.pausePreparation()

        async let first: Void = fixture.lifecycle.onForeground()
        async let second: Void = fixture.lifecycle.onForeground()
        await fixture.devices.resumePreparation()
        _ = try await (first, second)

        let fetchCount = await fixture.settings.fetchCountSnapshot()
        let ensureCalls = await fixture.devices.ensureCallSnapshot()
        let topUpCalls = await fixture.devices.topUpCallSnapshot()
        XCTAssertEqual(fetchCount, 2)
        XCTAssertEqual(ensureCalls.count, 2)
        XCTAssertEqual(topUpCalls.count, 2)
    }

    func testUnknownRuntimeFailsClosedWithoutInitializingMLS() async throws {
        let fixture = Fixture(runtime: .init(serverStorageMode: "future", contentAuditMode: "e2ee"))

        let error = await XCTAssertThrowsErrorAsync {
            try await fixture.lifecycle.onAuthenticated(session: fixture.session("account-a"))
        }

        XCTAssertNotNil(error)
        guard case .blocked(let message) = fixture.lifecycle.status else {
            return XCTFail("Expected blocked status")
        }
        XCTAssertTrue(message.contains("未知的消息存储模式"))
        let ensureCalls = await fixture.devices.ensureCallSnapshot()
        XCTAssertEqual(ensureCalls, [])
    }

    func testPendingApprovalDeviceFailsClosed() async throws {
        let fixture = Fixture(
            runtime: .init(serverStorageMode: "persist", contentAuditMode: "e2ee"),
            profile: E2eeDeviceProfile(
                deviceId: "device-a",
                deviceLabel: "iPhone",
                registered: true,
                deviceStatus: "pending_approval"
            )
        )

        _ = await XCTAssertThrowsErrorAsync {
            try await fixture.lifecycle.onAuthenticated(session: fixture.session("account-a"))
        }

        guard case .blocked(let message) = fixture.lifecycle.status else {
            return XCTFail("Expected blocked status")
        }
        XCTAssertTrue(message.contains("pending_approval"))
        let topUpCalls = await fixture.devices.topUpCallSnapshot()
        XCTAssertEqual(topUpCalls, [])
    }

    func testAccountSwitchClearsPreviousSecureStateBeforePreparingNextAccount() async throws {
        let fixture = Fixture(runtime: .init(serverStorageMode: "persist", contentAuditMode: "e2ee"))
        try await fixture.lifecycle.onAuthenticated(session: fixture.session("account-a"))

        try await fixture.lifecycle.onAuthenticated(session: fixture.session("account-b"))

        let deletedAccountIDs = await fixture.secureState.deletedAccountIDSnapshot()
        XCTAssertEqual(deletedAccountIDs, ["account-a"])
        XCTAssertEqual(fixture.lifecycle.status, .ready(accountID: "account-b", deviceID: "device-a"))
    }

    func testLogoutClearsCurrentAccountAndMovesToSignedOut() async throws {
        let fixture = Fixture(runtime: .init(serverStorageMode: "persist", contentAuditMode: "e2ee"))
        try await fixture.lifecycle.onAuthenticated(session: fixture.session("account-a"))

        try await fixture.lifecycle.onLogout()

        let deletedAccountIDs = await fixture.secureState.deletedAccountIDSnapshot()
        XCTAssertEqual(deletedAccountIDs, ["account-a"])
        XCTAssertEqual(fixture.lifecycle.status, .signedOut)
    }

    func testPreparationFailureRemainsBlocked() async throws {
        let fixture = Fixture(
            runtime: .init(serverStorageMode: "persist", contentAuditMode: "e2ee"),
            deviceError: E2eeDeviceNotReadyError(message: "包装密钥缺失")
        )

        _ = await XCTAssertThrowsErrorAsync {
            try await fixture.lifecycle.onAuthenticated(session: fixture.session("account-a"))
        }

        XCTAssertEqual(fixture.lifecycle.status, .blocked(message: "包装密钥缺失"))
    }
}

@MainActor
private struct Fixture {
    let settings: RecordingRuntimeSettings
    let devices: RecordingAppDeviceLifecycle
    let secureState = RecordingSecureState()
    let lifecycle: E2eeSessionLifecycle

    init(
        runtime: MessageRuntimeSettings,
        profile: E2eeDeviceProfile = E2eeDeviceProfile(
            deviceId: "device-a",
            deviceLabel: "iPhone",
            registered: true,
            keyPackagePublished: true
        ),
        deviceError: Error? = nil
    ) {
        let settings = RecordingRuntimeSettings(runtime: runtime)
        let devices = RecordingAppDeviceLifecycle(profile: profile, error: deviceError)
        self.settings = settings
        self.devices = devices
        self.lifecycle = E2eeSessionLifecycle(
            settings: settings,
            devices: devices,
            secureState: secureState,
            deviceLabel: "iPhone"
        )
    }

    func session(_ accountID: String) -> AuthSession {
        AuthSession(
            token: "token-\(accountID)",
            user: AuthUser(id: accountID, username: accountID)
        )
    }
}

private actor RecordingRuntimeSettings: E2eeRuntimeSettingsProviding {
    private let runtime: MessageRuntimeSettings
    private(set) var fetchCount = 0

    init(runtime: MessageRuntimeSettings) {
        self.runtime = runtime
    }

    func fetchMessageRuntime() async throws -> MessageRuntimeSettings {
        fetchCount += 1
        return runtime
    }

    func fetchCountSnapshot() -> Int { fetchCount }
}

private actor RecordingAppDeviceLifecycle: E2eeAppDeviceLifecycle {
    private let profile: E2eeDeviceProfile
    private let error: Error?
    private var isPaused = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private(set) var ensureCalls: [String] = []
    private(set) var topUpCalls: [String] = []

    init(profile: E2eeDeviceProfile, error: Error?) {
        self.profile = profile
        self.error = error
    }

    func ensureReady(accountID: String, deviceLabel: String, token: String) async throws -> E2eeDeviceProfile {
        ensureCalls.append("\(accountID):\(deviceLabel):\(token)")
        if isPaused {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
        if let error { throw error }
        return profile
    }

    func topUpKeyPackages(accountID: String, token: String) async throws -> Int {
        topUpCalls.append("\(accountID):\(token)")
        return 1
    }

    func pausePreparation() {
        isPaused = true
    }

    func resumePreparation() {
        isPaused = false
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }

    func ensureCallSnapshot() -> [String] { ensureCalls }
    func topUpCallSnapshot() -> [String] { topUpCalls }
}

private actor RecordingSecureState: E2eeAccountSecureStateClearing {
    private(set) var deletedAccountIDs: [String] = []

    func delete(accountID: String) async throws {
        deletedAccountIDs.append(accountID)
    }

    func deletedAccountIDSnapshot() -> [String] { deletedAccountIDs }
}

@MainActor
private func XCTAssertThrowsErrorAsync(
    _ expression: () async throws -> Void
) async -> Error? {
    do {
        try await expression()
        XCTFail("Expected error")
        return nil
    } catch {
        return error
    }
}
