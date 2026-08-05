import RedCodeCore
import XCTest
@testable import RedCodeFeatures

@MainActor
final class E2eeOutgoingTextRouterTests: XCTestCase {
    func testPlaintextRuntimeReturnsNilWithoutCallingSender() async throws {
        let sender = TextSenderStub()
        let router = makeRouter(status: .plaintext, sender: sender)

        let result = try await router.send(
            roomID: "r1",
            peerUserID: "u2",
            text: "hello",
            retry: false,
            quotedMessageID: nil,
            accountID: "u1",
            token: "token"
        )

        XCTAssertNil(result)
        let calls = await sender.recordedCalls()
        XCTAssertEqual(calls, [])
    }

    func testReadyRuntimeSendsEncryptedText() async throws {
        let sender = TextSenderStub(sendResult: "server-id")
        let router = makeRouter(status: .ready(accountID: "u1", deviceID: "d1"), sender: sender)

        let result = try await router.send(
            roomID: "r1",
            peerUserID: "u2",
            text: "hello",
            retry: false,
            quotedMessageID: nil,
            accountID: "u1",
            token: "token"
        )

        XCTAssertEqual(result, "server-id")
        let calls = await sender.recordedCalls()
        XCTAssertEqual(calls, [.send(accountID: "u1", roomID: "r1", peerUserID: "u2", text: "hello")])
    }

    func testRetryRequiresPendingEncryptedSend() async {
        let sender = TextSenderStub(hasPending: false)
        let router = makeRouter(status: .ready(accountID: "u1", deviceID: "d1"), sender: sender)

        await assertRouterError("没有待重试的 E2EE 消息") {
            try await router.send(
                roomID: "r1",
                peerUserID: "u2",
                text: "hello",
                retry: true,
                quotedMessageID: nil,
                accountID: "u1",
                token: "token"
            )
        }
        let calls = await sender.recordedCalls()
        XCTAssertEqual(calls, [.hasPending(accountID: "u1")])
    }

    func testReadyRuntimeRejectsQuoteMissingPeerAndAccountMismatch() async {
        let sender = TextSenderStub()
        let router = makeRouter(status: .ready(accountID: "u1", deviceID: "d1"), sender: sender)

        await assertRouterError("E2EE 引用消息将在后续版本支持") {
            try await router.send(
                roomID: "r1", peerUserID: "u2", text: "hello", retry: false,
                quotedMessageID: "m0", accountID: "u1", token: "token"
            )
        }
        await assertRouterError("E2EE 单聊缺少对端用户标识") {
            try await router.send(
                roomID: "r1", peerUserID: nil, text: "hello", retry: false,
                quotedMessageID: nil, accountID: "u1", token: "token"
            )
        }
        await assertRouterError("E2EE 会话账号与登录态不一致") {
            try await router.send(
                roomID: "r1", peerUserID: "u2", text: "hello", retry: false,
                quotedMessageID: nil, accountID: "other", token: "token"
            )
        }
    }

    private func makeRouter(status: E2eeSessionStatus, sender: TextSenderStub) -> E2eeOutgoingTextRouter {
        E2eeOutgoingTextRouter(
            sessionStatus: SessionStatusRouterStub(status: status),
            sender: sender,
            deviceLabel: "iPhone"
        )
    }

    private func assertRouterError(
        _ expected: String,
        operation: () async throws -> String?
    ) async {
        do {
            _ = try await operation()
            XCTFail("预期 router 阻断发送")
        } catch let error as E2eeOutgoingMessageError {
            XCTAssertEqual(error.message, expected)
        } catch {
            XCTFail("错误类型不匹配：\(error)")
        }
    }
}

@MainActor
private final class SessionStatusRouterStub: E2eeSessionStatusProviding {
    let status: E2eeSessionStatus
    init(status: E2eeSessionStatus) { self.status = status }
}

private enum TextSenderCall: Equatable, Sendable {
    case send(accountID: String, roomID: String, peerUserID: String, text: String)
    case hasPending(accountID: String)
    case retry(accountID: String)
}

private actor TextSenderStub: E2eeTextMessageSending {
    private let sendResult: String
    private let hasPending: Bool
    private var calls: [TextSenderCall] = []

    init(sendResult: String = "server-id", hasPending: Bool = false) {
        self.sendResult = sendResult
        self.hasPending = hasPending
    }

    func sendText(
        accountID: String,
        deviceLabel: String,
        roomID: String,
        peerUserID: String,
        text: String,
        token: String
    ) async throws -> String {
        calls.append(.send(accountID: accountID, roomID: roomID, peerUserID: peerUserID, text: text))
        return sendResult
    }

    func retryPendingSend(accountID: String, token: String) async throws -> String {
        calls.append(.retry(accountID: accountID))
        return sendResult
    }

    func hasPendingSend(accountID: String) async throws -> Bool {
        calls.append(.hasPending(accountID: accountID))
        return hasPending
    }

    func recordedCalls() -> [TextSenderCall] { calls }
}
