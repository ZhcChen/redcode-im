import XCTest
@testable import RedCodeCore

final class E2eeCommandClientTests: XCTestCase {
    private var client = E2eeCommandClient()

    func testProtocolVersionMatchesSharedCore() {
        XCTAssertEqual(E2eeCommandClient.protocolVersion, 1)
    }

    func testNewProtocolStateIsValid() throws {
        let state = try client.newProtocolState()
        XCTAssertTrue(client.validateProtocolState(state))
    }

    func testTamperedProtocolStateIsInvalid() throws {
        var state = try client.newProtocolState()
        state[state.count - 1] ^= 0xFF
        XCTAssertFalse(client.validateProtocolState(state))
    }

    func testTwoDeviceRoundTripMatchesCommandContract() throws {
        // Alice/Bob 双设备流程与 e2ee-core/tests/command_api.rs 对齐：
        // initialize -> create_group -> add_member -> join_group -> encrypt/decrypt。
        let alice = try client.initialize(deviceIdentity: "alice-device-ios")
        let bob = try client.initialize(deviceIdentity: "bob-device-ios")
        let aliceState = try alice.field(0)
        let bobState = try bob.field(0)
        let bobKeyPackage = try bob.field(1)
        XCTAssertTrue(client.validateProtocolState(aliceState))
        XCTAssertTrue(client.validateProtocolState(bobState))

        let created = try client.createGroup(state: aliceState, roomID: "room-ios-unit")
        let added = try client.execute(
            operation: .addMember,
            fields: [try created.field(0), Data("room-ios-unit".utf8), bobKeyPackage]
        )
        let joined = try client.execute(
            operation: .joinGroup,
            fields: [bobState, try added.field(2)]
        )
        let plaintext = Data("native e2ee round trip".utf8)
        let encrypted = try client.encrypt(
            state: try added.field(0),
            roomID: "room-ios-unit",
            plaintext: plaintext
        )
        let ciphertext = try encrypted.field(1)
        XCTAssertNotEqual(ciphertext, plaintext)

        let decrypted = try client.decrypt(
            state: try joined.field(0),
            roomID: "room-ios-unit",
            ciphertext: ciphertext
        )
        XCTAssertEqual(try decrypted.field(1), plaintext)
    }

    func testUnknownOperationFailsClosed() {
        let badRequest = Data("RCCQ".utf8) + Data([0, 1, 99, 0])
        let response = try? client.executeRaw(badRequest)
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.prefix(4), Data("RCCR".utf8))
        XCTAssertEqual(response?[6], 1, "未知命令必须返回失败状态")
    }
}
