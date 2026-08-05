import XCTest
@testable import RedCodeCore

final class E2eeDeviceManagerTests: XCTestCase {
    func testListDevicesDelegatesToAPI() async throws {
        let target = device(status: "pending_approval")
        let api = DeviceManagerAPI(devices: [target])
        let manager = E2eeDeviceManager(storage: DeviceManagerStorage(), api: api)

        let devices = try await manager.listDevices(token: "access-token")

        XCTAssertEqual(devices, [target])
        let tokens = await api.listTokens()
        XCTAssertEqual(tokens, ["access-token"])
    }

    func testApproveSignsValidatedDeviceAndCallsAPI() async throws {
        let target = device(status: "pending_approval")
        let api = DeviceManagerAPI(devices: [target])
        let signer = DeviceApprovalSigner()
        let manager = E2eeDeviceManager(
            storage: DeviceManagerStorage(),
            api: api,
            signer: signer
        )

        _ = try await manager.approveDevice(accountID: accountID, target: target, token: "access-token")

        XCTAssertEqual(signer.states(), [Data("state".utf8)])
        let approvals = await api.approvals()
        XCTAssertEqual(approvals.count, 1)
        XCTAssertEqual(approvals.first?.targetDeviceID, target.id)
        XCTAssertEqual(approvals.first?.approverDeviceID, currentDeviceID)
        XCTAssertEqual(approvals.first?.signature, Data("signature".utf8))
    }

    func testApproveRejectsUnsupportedProtocolBeforeSigning() async throws {
        let target = E2eeDeviceInfo(
            id: targetDeviceID,
            protocolVersion: 2,
            credentialFingerprint: Data(repeating: 7, count: 32).base64EncodedString(),
            status: "pending_approval"
        )
        let signer = DeviceApprovalSigner()
        let manager = E2eeDeviceManager(
            storage: DeviceManagerStorage(),
            api: DeviceManagerAPI(devices: [target]),
            signer: signer
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await manager.approveDevice(accountID: accountID, target: target, token: "access-token")
        }
        XCTAssertEqual(signer.states(), [])
    }

    func testApproveRejectsWrongFingerprintLengthBeforeSigning() async throws {
        let target = E2eeDeviceInfo(
            id: targetDeviceID,
            protocolVersion: 1,
            credentialFingerprint: Data(repeating: 7, count: 31).base64EncodedString(),
            status: "pending_approval"
        )
        let signer = DeviceApprovalSigner()
        let manager = E2eeDeviceManager(
            storage: DeviceManagerStorage(),
            api: DeviceManagerAPI(devices: [target]),
            signer: signer
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await manager.approveDevice(accountID: accountID, target: target, token: "access-token")
        }
        XCTAssertEqual(signer.states(), [])
    }

    private func device(status: String) -> E2eeDeviceInfo {
        E2eeDeviceInfo(
            id: targetDeviceID,
            deviceLabel: "iPad",
            protocolVersion: 1,
            credentialFingerprint: Data(repeating: 7, count: 32).base64EncodedString(),
            status: status
        )
    }
}

private let accountID = "11111111-1111-1111-1111-111111111111"
private let currentDeviceID = "22222222-2222-2222-2222-222222222222"
private let targetDeviceID = "33333333-3333-3333-3333-333333333333"

private final class DeviceApprovalSigner: E2eeDeviceApprovalSigning, @unchecked Sendable {
    private let lock = NSLock()
    private var signedStates: [Data] = []

    func signDeviceApproval(state: Data, payload: Data) throws -> E2eeCommandResult {
        lock.withLock { signedStates.append(state) }
        return E2eeCommandResult(fields: [Data("signature".utf8)])
    }

    func states() -> [Data] { lock.withLock { signedStates } }
}

private actor DeviceManagerStorage: E2eeDeviceStateStorage {
    func readState(accountID: String) async throws -> Data? { Data("state".utf8) }
    func writeState(accountID: String, state: Data) async throws {}
    func readProfile(accountID: String) async throws -> E2eeDeviceProfile? {
        E2eeDeviceProfile(
            deviceId: currentDeviceID,
            deviceLabel: "iPhone",
            registered: true,
            deviceStatus: "active"
        )
    }
    func writeProfile(accountID: String, profile: E2eeDeviceProfile) async throws {}
    func deleteProfile(accountID: String) async throws {}
    func readMetadata(accountID: String, key: String) async throws -> Data? { nil }
    func writeMetadata(accountID: String, key: String, data: Data) async throws {}
}

private actor DeviceManagerAPI: E2eeMLSApi {
    struct Approval: Equatable {
        let targetDeviceID: String
        let approverDeviceID: String
        let signature: Data
    }

    private let devices: [E2eeDeviceInfo]
    private var tokens: [String] = []
    private var approvalCalls: [Approval] = []

    init(devices: [E2eeDeviceInfo]) { self.devices = devices }

    func fetchRootIdentity(userID: String, token: String) async throws -> Data? { nil }
    func registerDevice(deviceID: String, deviceLabel: String, material: E2eeRegistrationMaterial, token: String) async throws -> String { "active" }
    func publishKeyPackages(deviceID: String, keyPackages: [Data], token: String) async throws -> Int { keyPackages.count }
    func fetchKeyPackageInventory(deviceID: String, token: String) async throws -> E2eeKeyPackageInventory { .init(available: 0, maxAvailable: 100) }
    func listDevices(token: String) async throws -> [E2eeDeviceInfo] {
        tokens.append(token)
        return devices
    }
    func approveDevice(targetDeviceID: String, approverDeviceID: String, signature: Data, token: String) async throws -> E2eeDeviceInfo {
        approvalCalls.append(.init(targetDeviceID: targetDeviceID, approverDeviceID: approverDeviceID, signature: signature))
        return devices.first { $0.id == targetDeviceID } ?? E2eeDeviceInfo(id: targetDeviceID)
    }
    func revokeDevice(deviceID: String, token: String) async throws -> E2eeDeviceInfo { E2eeDeviceInfo(id: deviceID, status: "revoked") }

    func listTokens() -> [String] { tokens }
    func approvals() -> [Approval] { approvalCalls }
}

private func XCTAssertThrowsErrorAsync(_ expression: () async throws -> Void) async {
    do {
        try await expression()
        XCTFail("Expected error")
    } catch {}
}
