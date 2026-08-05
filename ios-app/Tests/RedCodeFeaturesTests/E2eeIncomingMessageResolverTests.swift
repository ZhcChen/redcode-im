import Foundation
import RedCodeCore
import RedCodeNetworking
import XCTest
@testable import RedCodeFeatures

@MainActor
final class E2eeIncomingMessageResolverTests: XCTestCase {
    func testPlaintextMessagePassesThroughWithoutDecrypting() async throws {
        let decryptor = IncomingDecryptorStub()
        let resolver = makeResolver(decryptor: decryptor)
        let message = makeMessage(content: "plain")

        let resolved = try await resolver.resolve(
            message,
            source: .history,
            accountID: "u1",
            token: "token"
        )

        XCTAssertEqual(resolved, message)
        let calls = await decryptor.callCount()
        XCTAssertEqual(calls, 0)
    }

    func testEncryptedMessageDecryptsAndValidatesEpoch() async throws {
        let decryptor = IncomingDecryptorStub(
            result: E2eeDecryptedMessage(
                messageID: "m1",
                roomID: "r1",
                text: "secret",
                epoch: 7,
                encrypted: true
            )
        )
        let resolver = makeResolver(decryptor: decryptor)

        let resolved = try await resolver.resolve(
            makeEncryptedMessage(),
            source: .webSocket,
            accountID: "u1",
            token: "token"
        )

        XCTAssertEqual(resolved.content, "secret")
        XCTAssertEqual(resolved.encryptedContent, "Y2lwaGVydGV4dA==")
        XCTAssertEqual(resolved.encryptionMetadata?.protocolName, "mls")
        let calls = await decryptor.callCount()
        XCTAssertEqual(calls, 1)
    }

    func testCachedResolvedMessageAvoidsDuplicateDecrypt() async throws {
        let decryptor = IncomingDecryptorStub()
        let resolver = makeResolver(decryptor: decryptor)
        let cached = makeMessage(content: "cached")

        let resolved = try await resolver.resolve(
            makeEncryptedMessage(),
            source: .history,
            accountID: "u1",
            token: "token",
            cachedMessage: cached
        )

        XCTAssertEqual(resolved.content, "cached")
        let calls = await decryptor.callCount()
        XCTAssertEqual(calls, 0)
    }

    func testEmptyLegacyCacheDoesNotBypassDecrypt() async throws {
        let decryptor = IncomingDecryptorStub(
            result: E2eeDecryptedMessage(
                messageID: "m1",
                roomID: "r1",
                text: "recovered",
                epoch: 7,
                encrypted: true
            )
        )
        let resolver = makeResolver(decryptor: decryptor)

        let resolved = try await resolver.resolve(
            makeEncryptedMessage(),
            source: .history,
            accountID: "u1",
            token: "token",
            cachedMessage: makeMessage(content: "")
        )

        XCTAssertEqual(resolved.content, "recovered")
        let calls = await decryptor.callCount()
        XCTAssertEqual(calls, 1)
    }

    func testAttachmentPayloadMapsDisplayPartsWithoutKeyMaterial() async throws {
        let part = E2eeAttachmentPart(
            partKey: "11111111-1111-1111-1111-111111111111",
            objectKey: "messages/r1/image.enc",
            name: "image.png",
            mimeType: "image/png",
            size: 128,
            partPosition: 0,
            nonce: Data(repeating: 2, count: 12),
            dek: Data(repeating: 3, count: 32)
        )
        let decryptor = IncomingDecryptorStub(
            result: E2eeDecryptedMessage(
                messageID: "m1",
                roomID: "r1",
                text: "[加密附件]",
                epoch: 7,
                encrypted: true,
                attachmentParts: [part]
            )
        )
        let resolver = makeResolver(decryptor: decryptor)

        let resolved = try await resolver.resolve(
            makeEncryptedMessage(),
            source: .history,
            accountID: "u1",
            token: "token"
        )

        XCTAssertEqual(resolved.parts.count, 1)
        XCTAssertEqual(resolved.parts.first?.partType, .image)
        XCTAssertEqual(resolved.parts.first?.attachment?.key, part.objectKey)
        XCTAssertEqual(resolved.parts.first?.attachment?.size, part.size)
    }

    func testIncompleteEnvelopeAndInvalidMetadataFailClosed() async {
        let resolver = makeResolver(decryptor: IncomingDecryptorStub())
        let incomplete = makeMessage(encryptedContent: "YQ==", metadata: nil)
        let invalid = makeEncryptedMessage(protocolName: "unknown")

        await assertResolverError("E2EE 消息密文与 metadata 不完整") {
            _ = try await resolver.resolve(incomplete, source: .history, accountID: "u1", token: "token")
        }
        await assertResolverError("E2EE 消息 metadata 无效") {
            _ = try await resolver.resolve(invalid, source: .history, accountID: "u1", token: "token")
        }
    }

    func testInvalidBase64AndMismatchedEpochFailClosed() async {
        let invalidBase64Resolver = makeResolver(decryptor: IncomingDecryptorStub())
        await assertResolverError("E2EE 消息密文 Base64 无效") {
            _ = try await invalidBase64Resolver.resolve(
                makeEncryptedMessage(ciphertext: "%%%"),
                source: .history,
                accountID: "u1",
                token: "token"
            )
        }

        let mismatch = IncomingDecryptorStub(
            result: E2eeDecryptedMessage(
                messageID: "m1",
                roomID: "r1",
                text: "secret",
                epoch: 8,
                encrypted: true
            )
        )
        let mismatchResolver = makeResolver(decryptor: mismatch)
        await assertResolverError("E2EE 解密结果与消息不匹配") {
            _ = try await mismatchResolver.resolve(
                makeEncryptedMessage(),
                source: .webSocket,
                accountID: "u1",
                token: "token"
            )
        }
    }

    func testSignedOutAndAccountMismatchFailClosed() async {
        let signedOut = SessionStatusStub(status: .signedOut)
        let signedOutResolver = E2eeIncomingMessageResolver(
            sessionStatus: signedOut,
            decryptor: IncomingDecryptorStub(),
            deviceLabel: "iPhone"
        )
        await assertResolverError("E2EE 会话未登录") {
            _ = try await signedOutResolver.resolve(
                makeEncryptedMessage(),
                source: .history,
                accountID: "u1",
                token: "token"
            )
        }

        let mismatch = SessionStatusStub(status: .ready(accountID: "u2", deviceID: "d2"))
        let mismatchResolver = E2eeIncomingMessageResolver(
            sessionStatus: mismatch,
            decryptor: IncomingDecryptorStub(),
            deviceLabel: "iPhone"
        )
        await assertResolverError("E2EE 消息账号与当前会话不匹配") {
            _ = try await mismatchResolver.resolve(
                makeEncryptedMessage(),
                source: .history,
                accountID: "u1",
                token: "token"
            )
        }
    }

    private func makeResolver(decryptor: IncomingDecryptorStub) -> E2eeIncomingMessageResolver {
        E2eeIncomingMessageResolver(
            sessionStatus: SessionStatusStub(status: .ready(accountID: "u1", deviceID: "d1")),
            decryptor: decryptor,
            deviceLabel: "iPhone"
        )
    }

    private func makeEncryptedMessage(
        ciphertext: String = "Y2lwaGVydGV4dA==",
        protocolName: String = "mls"
    ) -> ChatMessage {
        makeMessage(
            encryptedContent: ciphertext,
            metadata: ChatEncryptionMetadata(
                protocolName: protocolName,
                version: 1,
                epoch: 7,
                senderDeviceID: "d2",
                contentType: "application",
                controlMessageID: "c7"
            )
        )
    }

    private func makeMessage(
        content: String = "",
        encryptedContent: String? = nil,
        metadata: ChatEncryptionMetadata? = nil
    ) -> ChatMessage {
        ChatMessage(
            id: "m1",
            roomID: "r1",
            senderID: "u2",
            senderName: "Alice",
            content: content,
            encryptedContent: encryptedContent,
            encryptionMetadata: metadata,
            timestamp: Date(timeIntervalSince1970: 1)
        )
    }

    private func assertResolverError(
        _ expected: String,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("预期 resolver 拒绝消息")
        } catch let error as E2eeIncomingMessageResolverError {
            XCTAssertEqual(error.message, expected)
        } catch {
            XCTFail("错误类型不匹配：\(error)")
        }
    }
}

@MainActor
private final class SessionStatusStub: E2eeSessionStatusProviding {
    let status: E2eeSessionStatus

    init(status: E2eeSessionStatus) {
        self.status = status
    }
}

private actor IncomingDecryptorStub: E2eeIncomingMessageDecrypting {
    private let result: E2eeDecryptedMessage?
    private var calls = 0

    init(result: E2eeDecryptedMessage? = nil) {
        self.result = result
    }

    func decryptIncoming(
        accountID: String,
        deviceLabel: String,
        input: E2eeIncomingMessage,
        token: String
    ) async throws -> E2eeDecryptedMessage {
        calls += 1
        guard let result else {
            throw E2eeDirectMessageError("unexpected decrypt")
        }
        return result
    }

    func callCount() -> Int { calls }
}
