import Foundation
import XCTest

@testable import RedCodeCore

final class E2eeDirectMessageCoordinatorTests: XCTestCase {
    func testWebSocketAndHistoryShareEntryAndRejectDuplicate() async throws {
        let fixture = await Fixture.make()
        let encrypted = try await fixture.coordinator.decryptIncoming(
            accountID: "account-a", deviceLabel: "iOS",
            input: E2eeIncomingMessage(messageID: "m-1", roomID: "room-1", ciphertext: Data([9]), source: .webSocket), token: "token"
        )
        let legacy = try await fixture.coordinator.decryptIncoming(
            accountID: "account-a", deviceLabel: "iOS",
            input: E2eeIncomingMessage(messageID: "m-2", roomID: "room-1", ciphertext: nil, plaintext: "legacy", source: .history), token: "token"
        )
        XCTAssertEqual(encrypted.text, "secret")
        XCTAssertTrue(encrypted.encrypted)
        XCTAssertEqual(legacy.text, "legacy")
        do {
            _ = try await fixture.coordinator.decryptIncoming(
                accountID: "account-a", deviceLabel: "iOS",
                input: E2eeIncomingMessage(messageID: "m-1", roomID: "room-1", ciphertext: Data([9]), source: .history), token: "token"
            )
            XCTFail("重复消息必须拒绝")
        } catch let error as E2eeDirectMessageError {
            XCTAssertFalse(error.message.isEmpty)
        }
        XCTAssertEqual(fixture.core.decryptCalls, 1)
    }

    func testDamagedCiphertextFailsClosed() async throws {
        let fixture = await Fixture.make()
        fixture.core.failDecrypt = true
        do {
            _ = try await fixture.coordinator.decryptIncoming(
                accountID: "account-a", deviceLabel: "iOS",
                input: E2eeIncomingMessage(messageID: "bad", roomID: "room-1", ciphertext: Data([0]), source: .webSocket), token: "token"
            )
            XCTFail("损坏密文必须失败")
        } catch let error as E2eeDirectMessageError {
            XCTAssertEqual(error.message, "E2EE 消息解密失败")
        }
        let unchangedState = await fixture.storage.readState(accountID: "account-a")
        XCTAssertEqual(unchangedState, Data([1]))
        fixture.core.failDecrypt = false
        let retried = try await fixture.coordinator.decryptIncoming(
            accountID: "account-a", deviceLabel: "iOS",
            input: E2eeIncomingMessage(messageID: "bad", roomID: "room-1", ciphertext: Data([9]), source: .history), token: "token"
        )
        XCTAssertEqual(retried.text, "secret")
    }

    func testIdentityChangeBlocksSecondSend() async throws {
        let fixture = await Fixture.make()
        let firstMessage = try await fixture.coordinator.sendText(accountID: "account-a", deviceLabel: "iOS", roomID: "room-1", peerUserID: "account-b", text: "first secret", token: "token")
        XCTAssertEqual(firstMessage, "server-message")
        await fixture.api.setFingerprint(Data(repeating: 7, count: 32))
        do {
            _ = try await fixture.coordinator.sendText(accountID: "account-a", deviceLabel: "iOS", roomID: "room-1", peerUserID: "account-b", text: "second secret", token: "token")
            XCTFail("身份变化必须阻断")
        } catch let error as E2eeDirectMessageError {
            XCTAssertTrue(error.message.contains("身份已变化"))
        }
        let sendCalls = await fixture.api.sendCalls
        XCTAssertEqual(sendCalls, 1)
    }

    func testFailedSendResumesAfterRestartWithSameIdempotencyKey() async throws {
        let fixture = await Fixture.make()
        await fixture.api.setFailSend(true)
        do {
            _ = try await fixture.coordinator.sendText(accountID: "account-a", deviceLabel: "iOS", roomID: "room-1", peerUserID: "account-b", text: "survives restart", token: "token")
            XCTFail("网络失败必须保留 pending")
        } catch {}
        let firstKey = await fixture.api.lastIdempotencyKey
        let pendingState = await fixture.storage.readState(accountID: "account-a")
        XCTAssertEqual(pendingState, Data([1]))
        await fixture.api.setFailSend(false)
        let restarted = E2eeDirectMessageCoordinator(storage: fixture.storage, lifecycle: fixture.lifecycle, api: fixture.api, core: fixture.core)
        let resumed = try await restarted.retryPendingSend(accountID: "account-a", token: "token")
        let resumedKey = await fixture.api.lastIdempotencyKey
        let resumedState = await fixture.storage.readState(accountID: "account-a")
        XCTAssertEqual(resumed, "server-message")
        XCTAssertEqual(resumedKey, firstKey)
        XCTAssertEqual(resumedState, Data([2]))
    }

    func testRekeyRemovesRevokedDeviceAndAddsNewDevice() async throws {
        let fixture = await Fixture.make()
        await fixture.api.configureRekey()
        fixture.core.members = ["account-a/device-a", "account-b/device-revoked"]
        try await fixture.coordinator.reconcileGroup(accountID: "account-a", roomID: "room-1", token: "token")
        XCTAssertEqual(fixture.core.removedMembers, ["account-b/device-revoked"])
        let controls = await fixture.api.submittedControls
        XCTAssertEqual(controls.map(\.contentType), ["commit", "commit", "welcome"])
        XCTAssertEqual(controls.last?.recipientDeviceID, "device-new")
    }
}

private struct Fixture {
    let storage: FakeDirectStorage; let lifecycle: FakeDirectLifecycle; let api: FakeDirectAPI
    let core: FakeDirectCore; let coordinator: E2eeDirectMessageCoordinator
    static func make() async -> Fixture {
        let storage = FakeDirectStorage()
        let profile = E2eeDeviceProfile(deviceId: "device-a", deviceLabel: "iOS", registered: true, keyPackagePublished: true, lastCommitMessageIds: ["room-1": "commit-1"])
        await storage.writeState(accountID: "account-a", state: Data([1]))
        await storage.writeProfile(accountID: "account-a", profile: profile)
        let lifecycle = FakeDirectLifecycle(storage: storage); let api = FakeDirectAPI(); let core = FakeDirectCore()
        let coordinator = E2eeDirectMessageCoordinator(storage: storage, lifecycle: lifecycle, api: api, core: core, newID: { "fixed-id" })
        return Fixture(storage: storage, lifecycle: lifecycle, api: api, core: core, coordinator: coordinator)
    }
}

private actor FakeDirectStorage: E2eeDirectMessageStorage {
    var states: [String: Data] = [:]; var profiles: [String: E2eeDeviceProfile] = [:]; var metadata: [String: Data] = [:]
    func readState(accountID: String) -> Data? { states[accountID] }
    func writeState(accountID: String, state: Data) { states[accountID] = state }
    func readProfile(accountID: String) -> E2eeDeviceProfile? { profiles[accountID] }
    func writeProfile(accountID: String, profile: E2eeDeviceProfile) { profiles[accountID] = profile }
    func deleteProfile(accountID: String) { profiles.removeValue(forKey: accountID) }
    func readMetadata(accountID: String, key: String) -> Data? { metadata["\(accountID):\(key)"] }
    func writeMetadata(accountID: String, key: String, data: Data) { metadata["\(accountID):\(key)"] = data }
}

private actor FakeDirectLifecycle: E2eeDirectDeviceLifecycle {
    let storage: FakeDirectStorage
    init(storage: FakeDirectStorage) { self.storage = storage }
    func ensureReady(accountID: String, deviceLabel: String, token: String) async throws -> E2eeDeviceProfile { await storage.readProfile(accountID: accountID)! }
}

private actor FakeDirectAPI: E2eeMLSApi {
    var fingerprint = Data(repeating: 1, count: 32); var failSend = false; var sendCalls = 0; var lastIdempotencyKey: String?
    var epoch = E2eeRoomEpoch(membershipRevision: 1, activeEpoch: 1, status: "active")
    var members: [E2eeRoomMemberDevices] = []; var submittedControls: [E2eeOutgoingControlMessage] = []
    func setFingerprint(_ value: Data) { fingerprint = value }; func setFailSend(_ value: Bool) { failSend = value }
    func configureRekey() {
        epoch = E2eeRoomEpoch(membershipRevision: 2, activeEpoch: 1, status: "rekey_required")
        members = [E2eeRoomMemberDevices(userID: "account-a", devices: [E2eePeerDevice(id: "device-a", protocolVersion: 1, credentialFingerprint: Data(repeating: 1, count: 32))]), E2eeRoomMemberDevices(userID: "account-b", devices: [E2eePeerDevice(id: "device-new", protocolVersion: 1, credentialFingerprint: Data(repeating: 1, count: 32))])]
    }
    func fetchRootIdentity(userID: String, token: String) -> Data? { nil }
    func registerDevice(deviceID: String, deviceLabel: String, material: E2eeRegistrationMaterial, token: String) -> String { "active" }
    func publishKeyPackages(deviceID: String, keyPackages: [Data], token: String) -> Int { keyPackages.count }
    func fetchKeyPackageInventory(deviceID: String, token: String) -> E2eeKeyPackageInventory { E2eeKeyPackageInventory(available: 20, maxAvailable: 100) }
    func listDevices(token: String) -> [E2eeDeviceInfo] { [E2eeDeviceInfo(id: "device-a", status: "active")] }
    func fetchIdentity(userID: String, token: String) -> E2eeRootIdentity { E2eeRootIdentity(userID: userID, publicKey: Data(repeating: 2, count: 32), fingerprint: fingerprint, protocolVersion: 1) }
    func getRoomEpoch(roomID: String, token: String) -> E2eeRoomEpoch { epoch }
    func listRoomMemberDevices(roomID: String, token: String) -> [E2eeRoomMemberDevices] { members }
    func claimKeyPackage(roomID: String, consumerDeviceID: String, targetDeviceID: String, token: String) -> E2eeClaimedKeyPackage { E2eeClaimedKeyPackage(id: "kp", deviceID: targetDeviceID, keyPackage: Data([7])) }
    func submitControlMessage(_ message: E2eeOutgoingControlMessage, token: String) { submittedControls.append(message) }
    func listControlMessages(roomID: String, deviceID: String, afterSequence: UInt64, token: String) -> [E2eeControlMessage] { [] }
    func sendEncryptedMessage(_ message: E2eeEncryptedMessageRequest, token: String) throws -> String {
        sendCalls += 1; lastIdempotencyKey = message.idempotencyKey
        if failSend { throw E2eeDirectMessageError("network") }
        return "server-message"
    }
}

private final class FakeDirectCore: E2eeDirectSessionCore, @unchecked Sendable {
    var decryptCalls = 0; var failDecrypt = false; var members = Set<String>(); var removedMembers: [String] = []
    func createGroup(state: Data, roomID: String) -> E2eeCommandResult { result(Data([2])) }
    func addMember(state: Data, roomID: String, keyPackage: Data) -> E2eeCommandResult { result(Data([3]), Data([4]), Data([5]), epoch(1)) }
    func joinGroup(state: Data, welcome: Data) -> E2eeCommandResult { result(Data([3]), epoch(1)) }
    func encrypt(state: Data, roomID: String, plaintext: Data) -> E2eeCommandResult { result(Data([2]), Data([99, 100]), epoch(1)) }
    func decrypt(state: Data, roomID: String, ciphertext: Data) throws -> E2eeCommandResult {
        decryptCalls += 1; if failDecrypt { throw E2eeDirectMessageError("bad") }
        return result(Data([2]), Data("{\"version\":1,\"type\":\"text\",\"text\":\"secret\"}".utf8), epoch(1))
    }
    func processCommit(state: Data, roomID: String, commit: Data) -> E2eeCommandResult { result(Data([2]), epoch(1)) }
    func removeMember(state: Data, roomID: String, identity: String) -> E2eeCommandResult { removedMembers.append(identity); return result(Data([2]), Data([6]), epoch(2)) }
    func listMembers(state: Data, roomID: String) -> E2eeCommandResult {
        var output = Data(); var count = UInt32(members.count).bigEndian; withUnsafeBytes(of: &count) { output.append(contentsOf: $0) }
        for member in members { let bytes = Data(member.utf8); var length = UInt32(bytes.count).bigEndian; withUnsafeBytes(of: &length) { output.append(contentsOf: $0) }; output.append(bytes) }
        return result(output)
    }
    private func result(_ fields: Data...) -> E2eeCommandResult { E2eeCommandResult(fields: fields) }
    private func epoch(_ value: UInt64) -> Data { withUnsafeBytes(of: value.bigEndian) { Data($0) } }
}
