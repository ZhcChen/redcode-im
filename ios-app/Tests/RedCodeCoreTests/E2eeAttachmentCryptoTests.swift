import Foundation
import XCTest

@testable import RedCodeCore

final class E2eeAttachmentCryptoTests: XCTestCase {
    private func aad(position: UInt32 = 0) throws -> Data {
        try E2eeAttachmentCrypto.attachmentAAD(roomID: "11111111-2222-4333-8444-555555555555", partKey: "00000000-0000-4000-8000-000000000001", partPosition: position, objectKey: "messages/r1/files/secret.bin")
    }

    func testRoundTripUsesWebCryptoCiphertextTagLayout() throws {
        let plaintext = Data("top secret attachment".utf8); let encrypted = try E2eeAttachmentCrypto.encrypt(plaintext, aad: aad())
        XCTAssertEqual(try E2eeAttachmentCrypto.decrypt(encrypted.ciphertext, aad: aad(), nonce: encrypted.nonce, dek: encrypted.dek), plaintext)
        XCTAssertEqual(encrypted.ciphertext.count, plaintext.count + 16)
        XCTAssertEqual(encrypted.nonce.count, 12); XCTAssertEqual(encrypted.dek.count, 32)
    }

    func testTamperedAADFailsClosed() throws {
        let encrypted = try E2eeAttachmentCrypto.encrypt(Data("secret".utf8), aad: aad())
        XCTAssertThrowsError(try E2eeAttachmentCrypto.decrypt(encrypted.ciphertext, aad: aad(position: 1), nonce: encrypted.nonce, dek: encrypted.dek))
    }

    func testRetryGeneratesFreshNonceAndDEK() throws {
        let first = try E2eeAttachmentCrypto.encrypt(Data([1]), aad: aad()); let second = try E2eeAttachmentCrypto.encrypt(Data([1]), aad: aad())
        XCTAssertNotEqual(first.nonce, second.nonce); XCTAssertNotEqual(first.dek, second.dek)
    }

    func testAADPositionAndPeripheralPolicy() throws {
        let value = try aad(position: 0x01020304); let offset = Data("redcode-im/e2ee/attachment/v1\u{0}".utf8).count + 32
        XCTAssertEqual(value[offset..<offset + 4], Data([1, 2, 3, 4]))
        XCTAssertFalse(E2eePeripheralPolicy.canUseServerSearch); XCTAssertFalse(E2eePeripheralPolicy.canForwardCiphertext)
        XCTAssertTrue(E2eePeripheralPolicy.canIndexLocally(decrypted: true, text: "decrypted"))
    }
}
