import Foundation
import RedCodeCore
import XCTest
@testable import RedCodeFeatures

@MainActor
final class E2eeAttachmentMessageRouterTests: XCTestCase {
    func testReadyRuntimeEncryptsUploadWithBoundAAD() throws {
        let status = AttachmentStatusStub(status: .ready(accountID: "u1", deviceID: "d1"))
        let coordinator = AttachmentCoordinatorStub()
        let router = makeRouter(status: status, coordinator: coordinator)
        let plaintext = Data("secret attachment".utf8)

        let prepared = try XCTUnwrap(router.prepareUpload(
            roomID: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            objectKey: "messages/r1/file.enc",
            name: "file.txt",
            mimeType: "text/plain",
            size: Int64(plaintext.count),
            partPosition: 0,
            plaintext: plaintext,
            accountID: "u1"
        ))

        XCTAssertNotEqual(prepared.ciphertext, plaintext)
        XCTAssertEqual(prepared.ciphertext.count, plaintext.count + 16)
        XCTAssertEqual(prepared.part.partKey, "11111111-1111-1111-1111-111111111111")
        let aad = try E2eeAttachmentCrypto.attachmentAAD(
            roomID: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            partKey: prepared.part.partKey,
            partPosition: 0,
            objectKey: prepared.part.objectKey
        )
        XCTAssertEqual(
            try E2eeAttachmentCrypto.decrypt(
                prepared.ciphertext,
                aad: aad,
                nonce: prepared.part.nonce,
                dek: prepared.part.dek
            ),
            plaintext
        )
    }

    func testPlaintextRuntimeKeepsExistingUploadPath() throws {
        let router = makeRouter(
            status: AttachmentStatusStub(status: .plaintext),
            coordinator: AttachmentCoordinatorStub()
        )

        let prepared = try router.prepareUpload(
            roomID: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            objectKey: "messages/r1/file.txt",
            name: "file.txt",
            mimeType: "text/plain",
            size: 1,
            partPosition: 0,
            plaintext: Data([1]),
            accountID: "u1"
        )

        XCTAssertNil(prepared)
    }

    func testRuntimeChangeAfterEncryptedPrepareReturnsNilForControllerConflictCheck() async throws {
        let status = AttachmentStatusStub(status: .ready(accountID: "u1", deviceID: "d1"))
        let router = makeRouter(status: status, coordinator: AttachmentCoordinatorStub())
        _ = try router.prepareUpload(
            roomID: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            objectKey: "messages/r1/file.enc",
            name: "file.txt",
            mimeType: "text/plain",
            size: 1,
            partPosition: 0,
            plaintext: Data([1]),
            accountID: "u1"
        )
        status.status = .plaintext

        let result = try await router.send(
            roomID: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            peerUserID: "u2",
            parts: [attachmentPart()],
            text: nil,
            retry: false,
            quotedMessageID: nil,
            accountID: "u1",
            token: "token"
        )

        XCTAssertNil(result)
    }

    func testDownloadDecryptsWithStoredPartAndRejectsMissingMaterialInReady() async throws {
        let part = attachmentPart()
        let status = AttachmentStatusStub(status: .ready(accountID: "u1", deviceID: "d1"))
        let coordinator = AttachmentCoordinatorStub(part: part)
        let router = makeRouter(status: status, coordinator: coordinator)
        let plaintext = Data("download secret".utf8)
        let aad = try E2eeAttachmentCrypto.attachmentAAD(
            roomID: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            partKey: part.partKey,
            partPosition: part.partPosition,
            objectKey: part.objectKey
        )
        let encrypted = try E2eeAttachmentCrypto.encrypt(plaintext, aad: aad)
        coordinator.part = E2eeAttachmentPart(
            partKey: part.partKey,
            objectKey: part.objectKey,
            name: part.name,
            mimeType: part.mimeType,
            size: part.size,
            partPosition: part.partPosition,
            nonce: encrypted.nonce,
            dek: encrypted.dek
        )

        let decrypted = try await router.decryptDownload(
            roomID: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            messageID: "m1",
            objectKey: part.objectKey,
            ciphertext: encrypted.ciphertext,
            accountID: "u1"
        )
        XCTAssertEqual(decrypted, plaintext)

        coordinator.part = nil
        do {
            _ = try await router.decryptDownload(
                roomID: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
                messageID: "m2",
                objectKey: part.objectKey,
                ciphertext: encrypted.ciphertext,
                accountID: "u1"
            )
            XCTFail("Ready 下缺少附件 key material 必须失败")
        } catch let error as E2eeDirectMessageError {
            XCTAssertEqual(error.message, "E2EE 附件密钥材料缺失")
        }
    }

    func testRetryUsesPendingCiphertextWithoutReupload() async throws {
        let coordinator = AttachmentCoordinatorStub()
        coordinator.pending = true
        let router = makeRouter(
            status: AttachmentStatusStub(status: .ready(accountID: "u1", deviceID: "d1")),
            coordinator: coordinator
        )

        let messageID = try await router.send(
            roomID: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            peerUserID: "u2",
            parts: [],
            text: nil,
            retry: true,
            quotedMessageID: nil,
            accountID: "u1",
            token: "token"
        )

        XCTAssertEqual(messageID, "server-id")
        XCTAssertEqual(coordinator.retryCalls, 1)
        XCTAssertEqual(coordinator.sendCalls, 0)
    }

    func testRetryWithoutPendingRequiresOriginalFile() async throws {
        let coordinator = AttachmentCoordinatorStub()
        let router = makeRouter(
            status: AttachmentStatusStub(status: .ready(accountID: "u1", deviceID: "d1")),
            coordinator: coordinator
        )

        do {
            _ = try await router.send(
                roomID: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
                peerUserID: "u2",
                parts: [],
                text: nil,
                retry: true,
                quotedMessageID: nil,
                accountID: "u1",
                token: "token"
            )
            XCTFail("没有 pending 时必须要求重新选择原文件")
        } catch let error as E2eeOutgoingMessageError {
            XCTAssertTrue(error.message.contains("重新选择原文件"))
        }
        XCTAssertEqual(coordinator.retryCalls, 0)
        XCTAssertEqual(coordinator.sendCalls, 0)
    }

    private func makeRouter(
        status: AttachmentStatusStub,
        coordinator: AttachmentCoordinatorStub
    ) -> E2eeAttachmentMessageRouter {
        E2eeAttachmentMessageRouter(
            sessionStatus: status,
            coordinator: coordinator,
            deviceLabel: "iPhone",
            newPartKey: { "11111111-1111-1111-1111-111111111111" }
        )
    }

    private func attachmentPart() -> E2eeAttachmentPart {
        E2eeAttachmentPart(
            partKey: "11111111-1111-1111-1111-111111111111",
            objectKey: "messages/r1/file.enc",
            name: "file.txt",
            mimeType: "text/plain",
            size: 8,
            partPosition: 0,
            nonce: Data(repeating: 2, count: 12),
            dek: Data(repeating: 3, count: 32)
        )
    }
}

@MainActor
private final class AttachmentStatusStub: E2eeSessionStatusProviding {
    var status: E2eeSessionStatus
    init(status: E2eeSessionStatus) { self.status = status }
}

private final class AttachmentCoordinatorStub: E2eeAttachmentCoordinating, @unchecked Sendable {
    var part: E2eeAttachmentPart?
    var pending = false
    var sendCalls = 0
    var retryCalls = 0

    init(part: E2eeAttachmentPart? = nil) {
        self.part = part
    }

    func sendAttachment(
        accountID: String,
        deviceLabel: String,
        roomID: String,
        peerUserID: String?,
        parts: [E2eeAttachmentPart],
        text: String?,
        token: String
    ) async throws -> String {
        sendCalls += 1
        return "server-id"
    }

    func retryPendingSend(accountID: String, token: String) async throws -> String {
        retryCalls += 1
        return "server-id"
    }
    func hasPendingSend(accountID: String) async throws -> Bool { pending }
    func findAttachmentPart(accountID: String, messageID: String, objectKey: String) async throws -> E2eeAttachmentPart? { part }
}
