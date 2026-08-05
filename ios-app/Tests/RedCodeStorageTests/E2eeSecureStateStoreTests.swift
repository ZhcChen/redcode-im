import XCTest

@testable import RedCodeCore
@testable import RedCodeStorage

final class E2eeSecureStateStoreTests: XCTestCase {
    @MainActor
    private func makeStore() throws -> (
        store: E2eeSecureStateStore,
        keyStore: InMemoryKeyValueStore,
        blobs: GRDBE2eeStateBlobStore
    ) {
        let keyStore = InMemoryKeyValueStore()
        let database = try RedCodeDatabase.makeDatabase(inMemory: true)
        let cipher = CryptoKitE2eeStateCipher(keyStore: keyStore)
        let blobs = GRDBE2eeStateBlobStore(database: database)
        let store = E2eeSecureStateStore(cipher: cipher, blobs: blobs)
        return (store, keyStore, blobs)
    }

    @MainActor
    func testEncryptsAndRestoresAccountScopedProtocolState() async throws {
        let (store, _, _) = try makeStore()
        let state = try E2eeCommandClient().newProtocolState()

        try await store.write(accountID: "account-a", state: state)

        let restored = try await store.read(accountID: "account-a")
        XCTAssertEqual(restored, state)
        let otherAccount = try await store.read(accountID: "account-b")
        XCTAssertNil(otherAccount)
    }

    @MainActor
    func testNeverPersistsStateRejectedBySharedCore() async throws {
        let (store, _, blobs) = try makeStore()

        do {
            try await store.write(accountID: "account-a", state: Data([1, 2, 3]))
            XCTFail("无效状态必须被拒绝")
        } catch let error as E2eeSecureStateError {
            guard case .corrupted = error else {
                return XCTFail("预期 corrupted，实际 \(error)")
            }
        }
        let stored = try await store.read(accountID: "account-a")
        XCTAssertNil(stored)
        let storedBlob = try await blobs.load(accountID: "account-a")
        XCTAssertNil(storedBlob)
    }

    @MainActor
    func testFailsClosedWhenCiphertextIsTampered() async throws {
        let (store, _, blobs) = try makeStore()
        try await store.write(accountID: "account-a", state: try E2eeCommandClient().newProtocolState())

        let loaded = try await blobs.load(accountID: "account-a")
        var record = try XCTUnwrap(loaded)
        record.ciphertext[0] ^= 0xFF
        try await blobs.save(record)

        do {
            _ = try await store.read(accountID: "account-a")
            XCTFail("篡改密文必须 fail closed")
        } catch let error as E2eeSecureStateError {
            guard case .corrupted = error else {
                return XCTFail("预期 corrupted，实际 \(error)")
            }
        }
    }

    @MainActor
    func testFailsClosedWhenWrappingKeyIsMissing() async throws {
        let (store, keyStore, _) = try makeStore()
        try await store.write(accountID: "account-a", state: try E2eeCommandClient().newProtocolState())

        try await keyStore.removeValue(forKey: CryptoKitE2eeStateCipher.keyName("account-a"))

        do {
            _ = try await store.read(accountID: "account-a")
            XCTFail("包装密钥缺失必须 fail closed")
        } catch let error as E2eeSecureStateError {
            guard case .corrupted = error else {
                return XCTFail("预期 corrupted，实际 \(error)")
            }
        }
    }

    @MainActor
    func testFailsClosedWhenEnvelopeVersionIsUnsupported() async throws {
        let (store, _, blobs) = try makeStore()
        try await store.write(accountID: "account-a", state: try E2eeCommandClient().newProtocolState())

        let loaded = try await blobs.load(accountID: "account-a")
        var record = try XCTUnwrap(loaded)
        record.version += 1
        try await blobs.save(record)

        do {
            _ = try await store.read(accountID: "account-a")
            XCTFail("版本不匹配必须 fail closed")
        } catch let error as E2eeSecureStateError {
            guard case .corrupted = error else {
                return XCTFail("预期 corrupted，实际 \(error)")
            }
        }
    }

    @MainActor
    func testAccountCleanupRemovesCiphertextAndWrappingKey() async throws {
        let (store, keyStore, blobs) = try makeStore()
        try await store.write(accountID: "account-a", state: try E2eeCommandClient().newProtocolState())
        try await store.writeProfile(
            accountID: "account-a",
            profile: E2eeDeviceProfile(deviceId: "device-a", deviceLabel: "iPhone")
        )
        try await store.writeMetadata(
            accountID: "account-a",
            key: "direct-message",
            data: Data("secret metadata".utf8)
        )

        try await store.delete(accountID: "account-a")

        let stateAfterDelete = try await store.read(accountID: "account-a")
        XCTAssertNil(stateAfterDelete)
        let blobAfterDelete = try await blobs.load(accountID: "account-a")
        XCTAssertNil(blobAfterDelete)
        let profileAfterDelete = try await blobs.loadBlob(accountID: "account-a", key: "device-profile")
        XCTAssertNil(profileAfterDelete)
        let metadataAfterDelete = try await blobs.loadBlob(accountID: "account-a", key: "metadata:direct-message")
        XCTAssertNil(metadataAfterDelete)
        let storedKey = try await keyStore.string(
            forKey: CryptoKitE2eeStateCipher.keyName("account-a")
        )
        XCTAssertNil(storedKey)
    }

    @MainActor
    func testNonceIsRandomPerWrite() async throws {
        let (store, _, blobs) = try makeStore()
        let state = try E2eeCommandClient().newProtocolState()

        try await store.write(accountID: "account-a", state: state)
        let firstLoaded = try await blobs.load(accountID: "account-a")
        let first = try XCTUnwrap(firstLoaded)
        try await store.write(accountID: "account-a", state: state)
        let secondLoaded = try await blobs.load(accountID: "account-a")
        let second = try XCTUnwrap(secondLoaded)

        XCTAssertNotEqual(first.nonce, second.nonce)
        XCTAssertEqual(first.nonce.count, 12)
    }
}
