import XCTest
@testable import RedCodeCore
@testable import RedCodeFeatures

@MainActor
final class E2eeDeviceManagementControllerTests: XCTestCase {
    func testPlaintextRuntimeDoesNotLoadDevices() async {
        let fixture = Fixture(status: .plaintext)

        await fixture.controller.refresh()

        XCTAssertFalse(fixture.controller.isE2eeRuntime)
        let calls = await fixture.devices.calls()
        XCTAssertEqual(calls, [])
    }

    func testReadyRuntimeLoadsPendingDevicesFirstAndMarksCurrentDevice() async {
        let fixture = Fixture(
            status: .ready(accountID: accountID, deviceID: currentDeviceID),
            devices: [
                device(id: currentDeviceID, label: "iPhone", status: "active"),
                device(id: pendingDeviceID, label: "iPad", status: "pending_approval"),
            ]
        )

        await fixture.controller.refresh()

        XCTAssertTrue(fixture.controller.isE2eeRuntime)
        XCTAssertEqual(fixture.controller.currentDeviceID, currentDeviceID)
        XCTAssertEqual(fixture.controller.devices.map(\.id), [pendingDeviceID, currentDeviceID])
    }

    func testApproveDoesNotReconcileRooms() async {
        let target = device(id: pendingDeviceID, label: "iPad", status: "pending_approval")
        let fixture = Fixture(
            status: .ready(accountID: accountID, deviceID: currentDeviceID),
            devices: [target]
        )

        await fixture.controller.approve(target)

        let approvedIDs = await fixture.devices.approvedIDs()
        XCTAssertEqual(approvedIDs, [pendingDeviceID])
        XCTAssertEqual(fixture.roomEvents.roomIDs, [])
    }

    func testRevokeOtherDeviceReconcilesAllRefreshedRooms() async {
        let target = device(id: otherDeviceID, label: "iPad", status: "active")
        let fixture = Fixture(
            status: .ready(accountID: accountID, deviceID: currentDeviceID),
            devices: [target],
            roomIDs: ["room-1", "room-2"]
        )

        await fixture.controller.revoke(target)

        let revokedIDs = await fixture.devices.revokedIDs()
        XCTAssertEqual(revokedIDs, [otherDeviceID])
        XCTAssertEqual(fixture.roomEvents.roomIDs, ["room-1", "room-2"])
        XCTAssertEqual(fixture.lifecycle.foregroundCalls, 0)
    }

    func testRevokeCurrentDeviceRefreshesLifecycleAndLeavesReady() async {
        let target = device(id: currentDeviceID, label: "iPhone", status: "active")
        let fixture = Fixture(
            status: .ready(accountID: accountID, deviceID: currentDeviceID),
            devices: [target]
        )
        fixture.lifecycle.nextStatus = .blocked(message: "设备已撤销")

        await fixture.controller.revoke(target)

        XCTAssertEqual(fixture.lifecycle.foregroundCalls, 1)
        XCTAssertEqual(fixture.lifecycle.status, .blocked(message: "设备已撤销"))
        XCTAssertEqual(fixture.roomEvents.roomIDs, [])
    }

    func testRevokeOtherDeviceContinuesReconcilingAfterOneRoomFails() async {
        let target = device(id: otherDeviceID, label: "iPad", status: "active")
        let fixture = Fixture(
            status: .ready(accountID: accountID, deviceID: currentDeviceID),
            devices: [target],
            roomIDs: ["room-1", "room-2"],
            failingRoomIDs: ["room-1"]
        )

        await fixture.controller.revoke(target)

        XCTAssertEqual(fixture.roomEvents.roomIDs, ["room-1", "room-2"])
        XCTAssertEqual(fixture.controller.errorMessage, "reconcile failed")
    }
}

@MainActor
private final class Fixture {
    let devices: RecordingDeviceManager
    let lifecycle: RecordingSessionLifecycle
    let roomEvents = RecordingDeviceRoomEvents()
    let controller: E2eeDeviceManagementController

    init(
        status: E2eeSessionStatus,
        devices: [E2eeDeviceInfo] = [],
        roomIDs: [String] = [],
        failingRoomIDs: Set<String> = []
    ) {
        let manager = RecordingDeviceManager(devices: devices)
        let lifecycle = RecordingSessionLifecycle(status: status)
        self.devices = manager
        self.lifecycle = lifecycle
        roomEvents.failingRoomIDs = failingRoomIDs
        controller = E2eeDeviceManagementController(
            currentSession: {
                AuthSession(token: "access-token", user: AuthUser(id: accountID, username: "alice"))
            },
            deviceManager: manager,
            lifecycle: lifecycle,
            roomIDs: { _ in roomIDs },
            roomEventHandler: roomEvents
        )
    }
}

private let accountID = "11111111-1111-1111-1111-111111111111"
private let currentDeviceID = "22222222-2222-2222-2222-222222222222"
private let pendingDeviceID = "33333333-3333-3333-3333-333333333333"
private let otherDeviceID = "44444444-4444-4444-4444-444444444444"

private func device(id: String, label: String, status: String) -> E2eeDeviceInfo {
    E2eeDeviceInfo(
        id: id,
        deviceLabel: label,
        protocolVersion: 1,
        credentialFingerprint: Data(repeating: 7, count: 32).base64EncodedString(),
        status: status
    )
}

private actor RecordingDeviceManager: E2eeDeviceManaging {
    private var listedDevices: [E2eeDeviceInfo]
    private var recordedCalls: [String] = []
    private var approvals: [String] = []
    private var revocations: [String] = []

    init(devices: [E2eeDeviceInfo]) { listedDevices = devices }

    func listDevices(token: String) async throws -> [E2eeDeviceInfo] {
        recordedCalls.append("list:\(token)")
        return listedDevices
    }

    func approveDevice(accountID: String, target: E2eeDeviceInfo, token: String) async throws -> E2eeDeviceInfo {
        approvals.append(target.id)
        return target
    }

    func revokeDevice(deviceID: String, token: String) async throws -> E2eeDeviceInfo {
        revocations.append(deviceID)
        return E2eeDeviceInfo(id: deviceID, status: "revoked")
    }

    func calls() -> [String] { recordedCalls }
    func approvedIDs() -> [String] { approvals }
    func revokedIDs() -> [String] { revocations }
}

@MainActor
private final class RecordingSessionLifecycle: E2eeSessionStateRefreshing {
    var status: E2eeSessionStatus
    var nextStatus: E2eeSessionStatus?
    private(set) var foregroundCalls = 0

    init(status: E2eeSessionStatus) { self.status = status }

    func onForeground() async throws {
        foregroundCalls += 1
        if let nextStatus { status = nextStatus }
    }
}

@MainActor
private final class RecordingDeviceRoomEvents: E2eeRoomEventHandling {
    private(set) var roomIDs: [String] = []
    var failingRoomIDs: Set<String> = []

    func reconcile(roomID: String) async throws {
        roomIDs.append(roomID)
        if failingRoomIDs.contains(roomID) {
            throw DeviceRoomEventError.failed
        }
    }
}

private enum DeviceRoomEventError: LocalizedError {
    case failed
    var errorDescription: String? { "reconcile failed" }
}
