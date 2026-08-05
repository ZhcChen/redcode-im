import Foundation
import RedCodeCore

public struct E2eePreparedAttachment: Equatable, Sendable {
    public let ciphertext: Data
    public let part: E2eeAttachmentPart

    public init(ciphertext: Data, part: E2eeAttachmentPart) {
        self.ciphertext = ciphertext
        self.part = part
    }
}

public protocol E2eeAttachmentCoordinating: Sendable {
    func sendAttachment(
        accountID: String,
        deviceLabel: String,
        roomID: String,
        peerUserID: String?,
        parts: [E2eeAttachmentPart],
        text: String?,
        token: String
    ) async throws -> String

    func retryPendingSend(accountID: String, token: String) async throws -> String
    func hasPendingSend(accountID: String) async throws -> Bool
    func findAttachmentPart(accountID: String, messageID: String, objectKey: String) async throws -> E2eeAttachmentPart?
}

extension E2eeDirectMessageCoordinator: E2eeAttachmentCoordinating {}

@MainActor
public protocol AttachmentMessageRouting: AnyObject {
    func encryptionRequired(accountID: String) throws -> Bool

    func prepareUpload(
        roomID: String,
        objectKey: String,
        name: String,
        mimeType: String,
        size: Int64,
        partPosition: UInt32,
        plaintext: Data,
        accountID: String
    ) throws -> E2eePreparedAttachment?

    func send(
        roomID: String,
        peerUserID: String?,
        parts: [E2eeAttachmentPart],
        text: String?,
        retry: Bool,
        quotedMessageID: String?,
        accountID: String,
        token: String
    ) async throws -> String?

    func decryptDownload(
        roomID: String,
        messageID: String,
        objectKey: String,
        ciphertext: Data,
        accountID: String
    ) async throws -> Data?

    func downloadIsEncrypted(
        messageID: String,
        objectKey: String,
        accountID: String
    ) async throws -> Bool
}

@MainActor
public final class PlaintextAttachmentMessageRouter: AttachmentMessageRouting {
    public init() {}

    public func encryptionRequired(accountID: String) throws -> Bool { false }

    public func prepareUpload(
        roomID: String,
        objectKey: String,
        name: String,
        mimeType: String,
        size: Int64,
        partPosition: UInt32,
        plaintext: Data,
        accountID: String
    ) throws -> E2eePreparedAttachment? { nil }

    public func send(
        roomID: String,
        peerUserID: String?,
        parts: [E2eeAttachmentPart],
        text: String?,
        retry: Bool,
        quotedMessageID: String?,
        accountID: String,
        token: String
    ) async throws -> String? { nil }

    public func decryptDownload(
        roomID: String,
        messageID: String,
        objectKey: String,
        ciphertext: Data,
        accountID: String
    ) async throws -> Data? { nil }

    public func downloadIsEncrypted(
        messageID: String,
        objectKey: String,
        accountID: String
    ) async throws -> Bool { false }
}

@MainActor
public final class E2eeAttachmentMessageRouter: AttachmentMessageRouting {
    private let sessionStatus: any E2eeSessionStatusProviding
    private let coordinator: any E2eeAttachmentCoordinating
    private let deviceLabel: String
    private let newPartKey: () -> String

    public init(
        sessionStatus: any E2eeSessionStatusProviding,
        coordinator: any E2eeAttachmentCoordinating,
        deviceLabel: String,
        newPartKey: @escaping () -> String = { UUID().uuidString }
    ) {
        self.sessionStatus = sessionStatus
        self.coordinator = coordinator
        self.deviceLabel = deviceLabel
        self.newPartKey = newPartKey
    }

    public func encryptionRequired(accountID: String) throws -> Bool {
        try requireE2eeAccount(accountID: accountID)
    }

    public func prepareUpload(
        roomID: String,
        objectKey: String,
        name: String,
        mimeType: String,
        size: Int64,
        partPosition: UInt32,
        plaintext: Data,
        accountID: String
    ) throws -> E2eePreparedAttachment? {
        guard try requireE2eeAccount(accountID: accountID) else { return nil }
        let partKey = newPartKey()
        let aad = try E2eeAttachmentCrypto.attachmentAAD(
            roomID: roomID,
            partKey: partKey,
            partPosition: partPosition,
            objectKey: objectKey
        )
        let encrypted = try E2eeAttachmentCrypto.encrypt(plaintext, aad: aad)
        return E2eePreparedAttachment(
            ciphertext: encrypted.ciphertext,
            part: E2eeAttachmentPart(
                partKey: partKey,
                objectKey: objectKey,
                name: name,
                mimeType: mimeType,
                size: size,
                partPosition: partPosition,
                nonce: encrypted.nonce,
                dek: encrypted.dek
            )
        )
    }

    public func send(
        roomID: String,
        peerUserID: String?,
        parts: [E2eeAttachmentPart],
        text: String?,
        retry: Bool,
        quotedMessageID: String?,
        accountID: String,
        token: String
    ) async throws -> String? {
        guard try requireE2eeAccount(accountID: accountID) else { return nil }
        guard quotedMessageID == nil else {
            throw E2eeOutgoingMessageError("E2EE 引用消息将在后续版本支持")
        }
        if retry {
            guard try await coordinator.hasPendingSend(accountID: accountID) else {
                throw E2eeOutgoingMessageError("E2EE 附件重试需要重新选择原文件")
            }
            return try await coordinator.retryPendingSend(accountID: accountID, token: token)
        }
        return try await coordinator.sendAttachment(
            accountID: accountID,
            deviceLabel: deviceLabel,
            roomID: roomID,
            peerUserID: peerUserID,
            parts: parts,
            text: text,
            token: token
        )
    }

    public func decryptDownload(
        roomID: String,
        messageID: String,
        objectKey: String,
        ciphertext: Data,
        accountID: String
    ) async throws -> Data? {
        let status = sessionStatus.status
        try validateReadableAccount(accountID: accountID, status: status)
        guard let part = try await coordinator.findAttachmentPart(
            accountID: accountID,
            messageID: messageID,
            objectKey: objectKey
        ) else {
            if case .ready = status {
                throw E2eeDirectMessageError("E2EE 附件密钥材料缺失")
            }
            return nil
        }
        let aad = try E2eeAttachmentCrypto.attachmentAAD(
            roomID: roomID,
            partKey: part.partKey,
            partPosition: part.partPosition,
            objectKey: part.objectKey
        )
        return try E2eeAttachmentCrypto.decrypt(
            ciphertext,
            aad: aad,
            nonce: part.nonce,
            dek: part.dek
        )
    }

    public func downloadIsEncrypted(
        messageID: String,
        objectKey: String,
        accountID: String
    ) async throws -> Bool {
        let status = sessionStatus.status
        try validateReadableAccount(accountID: accountID, status: status)
        if try await coordinator.findAttachmentPart(
            accountID: accountID,
            messageID: messageID,
            objectKey: objectKey
        ) != nil {
            return true
        }
        if case .ready = status {
            throw E2eeDirectMessageError("E2EE 附件密钥材料缺失")
        }
        return false
    }

    private func requireE2eeAccount(accountID: String) throws -> Bool {
        let status = sessionStatus.status
        try validateReadableAccount(accountID: accountID, status: status)
        if case .plaintext = status { return false }
        return true
    }

    private func validateReadableAccount(accountID: String, status: E2eeSessionStatus) throws {
        switch status {
        case .plaintext:
            return
        case .ready(let activeAccountID, _):
            guard activeAccountID == accountID else {
                throw E2eeOutgoingMessageError("E2EE 会话账号与登录态不一致")
            }
        case .blocked(let message):
            throw E2eeOutgoingMessageError(message)
        case .signedOut:
            throw E2eeOutgoingMessageError("E2EE 会话未登录")
        }
    }
}
