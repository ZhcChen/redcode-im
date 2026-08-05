import Foundation
import RedCodeCore

public struct E2eeOutgoingMessageError: Error, Equatable, LocalizedError, Sendable {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? { message }
}

public protocol E2eeTextMessageSending: Sendable {
    func sendText(
        accountID: String,
        deviceLabel: String,
        roomID: String,
        peerUserID: String,
        text: String,
        token: String
    ) async throws -> String

    func retryPendingSend(accountID: String, token: String) async throws -> String
    func hasPendingSend(accountID: String) async throws -> Bool
}

extension E2eeDirectMessageCoordinator: E2eeTextMessageSending {}

@MainActor
public protocol OutgoingTextMessageRouting: AnyObject {
    /// 返回 nil 表示当前 runtime 应继续使用既有 plaintext API。
    func send(
        roomID: String,
        peerUserID: String?,
        text: String,
        retry: Bool,
        quotedMessageID: String?,
        accountID: String,
        token: String
    ) async throws -> String?
}

@MainActor
public final class PlaintextOutgoingTextRouter: OutgoingTextMessageRouting {
    public init() {}

    public func send(
        roomID: String,
        peerUserID: String?,
        text: String,
        retry: Bool,
        quotedMessageID: String?,
        accountID: String,
        token: String
    ) async throws -> String? {
        nil
    }
}

@MainActor
public final class E2eeOutgoingTextRouter: OutgoingTextMessageRouting {
    private let sessionStatus: any E2eeSessionStatusProviding
    private let sender: any E2eeTextMessageSending
    private let deviceLabel: String

    public init(
        sessionStatus: any E2eeSessionStatusProviding,
        sender: any E2eeTextMessageSending,
        deviceLabel: String
    ) {
        self.sessionStatus = sessionStatus
        self.sender = sender
        self.deviceLabel = deviceLabel
    }

    public func send(
        roomID: String,
        peerUserID: String?,
        text: String,
        retry: Bool,
        quotedMessageID: String?,
        accountID: String,
        token: String
    ) async throws -> String? {
        switch sessionStatus.status {
        case .plaintext:
            return nil
        case .signedOut:
            throw E2eeOutgoingMessageError("E2EE 会话未登录")
        case .blocked(let message):
            throw E2eeOutgoingMessageError(message)
        case .ready(let activeAccountID, _):
            guard activeAccountID == accountID else {
                throw E2eeOutgoingMessageError("E2EE 会话账号与登录态不一致")
            }
            guard quotedMessageID == nil else {
                throw E2eeOutgoingMessageError("E2EE 引用消息将在后续版本支持")
            }
            if retry {
                guard try await sender.hasPendingSend(accountID: accountID) else {
                    throw E2eeOutgoingMessageError("没有待重试的 E2EE 消息")
                }
                return try await sender.retryPendingSend(accountID: accountID, token: token)
            }
            guard let peerUserID = peerUserID?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !peerUserID.isEmpty else {
                throw E2eeOutgoingMessageError("E2EE 单聊缺少对端用户标识")
            }
            return try await sender.sendText(
                accountID: accountID,
                deviceLabel: deviceLabel,
                roomID: roomID,
                peerUserID: peerUserID,
                text: text,
                token: token
            )
        }
    }
}
