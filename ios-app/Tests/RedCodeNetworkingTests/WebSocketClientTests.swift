import XCTest
@testable import RedCodeCore
@testable import RedCodeNetworking

final class WebSocketClientTests: XCTestCase {
    func testConnectUsesJSONHandshakeAndSendsAuthCommand() async throws {
        let transport = MockWebSocketTransport()
        let client = WebSocketClient(
            configuration: WebSocketConfiguration(
                environment: .simulatorDevelopment(),
                accessToken: "access-token"
            ),
            transportFactory: { transport }
        )

        try await client.connect()

        let connectedURL = await transport.recordedConnectedURL()
        let sentPayloads = try await decodedPayloads(from: transport)

        XCTAssertEqual(connectedURL?.absoluteString, "ws://127.0.0.1:8010/ws?format=json")
        XCTAssertEqual(sentPayloads.count, 1)
        XCTAssertEqual(sentPayloads[0]["type"] as? String, "auth")
        XCTAssertEqual(sentPayloads[0]["token"] as? String, "access-token")
        let snapshot = await client.snapshot()
        XCTAssertEqual(snapshot.status, .connected)

        await client.disconnect()
    }

    func testAuthenticatedFrameRestoresDesiredRoomSubscriptions() async throws {
        let transport = MockWebSocketTransport()
        let client = WebSocketClient(
            configuration: WebSocketConfiguration(
                environment: .simulatorDevelopment(),
                accessToken: "access-token"
            ),
            transportFactory: { transport }
        )
        let roomID = "11111111-1111-1111-1111-111111111111"

        try await client.connect()
        await client.ensureRoomsSubscribed([roomID])
        try await client.processFrameForTests(#"{"type":"authed","user_id":"u1","conn_id":"conn-1"}"#)

        let sentPayloads = try await decodedPayloads(from: transport)
        XCTAssertEqual(sentPayloads.map { $0["type"] as? String }, ["auth", "join"])
        XCTAssertEqual(sentPayloads[1]["room_id"] as? String, roomID)

        var snapshot = await client.snapshot()
        XCTAssertEqual(snapshot.status, .authenticated)
        XCTAssertEqual(snapshot.connectionID, "conn-1")
        XCTAssertEqual(snapshot.desiredRooms, [roomID])
        XCTAssertEqual(snapshot.pendingRooms, [roomID])
        XCTAssertTrue(snapshot.subscribedRooms.isEmpty)

        try await client.processFrameForTests(#"{"type":"joined","room_id":"\#(roomID)"}"#)
        snapshot = await client.snapshot()
        XCTAssertEqual(snapshot.subscribedRooms, [roomID])
        XCTAssertTrue(snapshot.pendingRooms.isEmpty)

        await client.disconnect()
    }

    func testPruneMissingRoomSendsLeaveAndClearsLocalRoomState() async throws {
        let transport = MockWebSocketTransport()
        let client = WebSocketClient(
            configuration: WebSocketConfiguration(
                environment: .simulatorDevelopment(),
                accessToken: "access-token"
            ),
            transportFactory: { transport }
        )
        let keptRoomID = "11111111-1111-1111-1111-111111111111"
        let removedRoomID = "22222222-2222-2222-2222-222222222222"

        try await client.connect()
        await client.ensureRoomsSubscribed([keptRoomID, removedRoomID])
        try await client.processFrameForTests(#"{"type":"authed","conn_id":"conn-1"}"#)
        try await client.processFrameForTests(#"{"type":"joined","room_id":"\#(keptRoomID)"}"#)
        try await client.processFrameForTests(#"{"type":"joined","room_id":"\#(removedRoomID)"}"#)

        await client.ensureRoomsSubscribed([keptRoomID], pruneMissing: true)

        let sentPayloads = try await decodedPayloads(from: transport)
        XCTAssertEqual(sentPayloads.last?["type"] as? String, "leave")
        XCTAssertEqual(sentPayloads.last?["room_id"] as? String, removedRoomID)

        let snapshot = await client.snapshot()
        XCTAssertEqual(snapshot.desiredRooms, [keptRoomID])
        XCTAssertEqual(snapshot.subscribedRooms, [keptRoomID])
        XCTAssertFalse(snapshot.pendingRooms.contains(removedRoomID))

        await client.disconnect()
    }

    func testTypingCommandOnlySendsForSubscribedRooms() async throws {
        let transport = MockWebSocketTransport()
        let client = WebSocketClient(
            configuration: WebSocketConfiguration(
                environment: .simulatorDevelopment(),
                accessToken: "access-token"
            ),
            transportFactory: { transport }
        )
        let roomID = "11111111-1111-1111-1111-111111111111"

        try await client.connect()
        await client.setTyping(roomID: roomID, isTyping: true)
        let payloadCountBeforeSubscribe = try await decodedPayloads(from: transport).count
        XCTAssertEqual(payloadCountBeforeSubscribe, 1)

        await client.ensureRoomsSubscribed([roomID])
        try await client.processFrameForTests(#"{"type":"authed","conn_id":"conn-1"}"#)
        try await client.processFrameForTests(#"{"type":"joined","room_id":"\#(roomID)"}"#)
        await client.setTyping(roomID: roomID, isTyping: true)

        let sentPayloads = try await decodedPayloads(from: transport)
        let typingPayload = try XCTUnwrap(sentPayloads.last)
        XCTAssertEqual(typingPayload["type"] as? String, "typing")
        XCTAssertEqual(typingPayload["room_id"] as? String, roomID)
        XCTAssertEqual(typingPayload["is_typing"] as? Bool, true)

        await client.disconnect()
    }

    func testReconnectReauthenticatesAndRestoresDesiredSubscriptions() async throws {
        let firstTransport = MockWebSocketTransport()
        let secondTransport = MockWebSocketTransport()
        let factory = MockTransportFactory([firstTransport, secondTransport])
        let client = WebSocketClient(
            configuration: WebSocketConfiguration(
                environment: .simulatorDevelopment(),
                accessToken: "access-token"
            ),
            transportFactory: { factory.next() },
            reconnectDelayProvider: { _ in 0 }
        )
        let roomID = "11111111-1111-1111-1111-111111111111"

        try await client.connect()
        await client.ensureRoomsSubscribed([roomID])
        try await client.processFrameForTests(#"{"type":"authed","conn_id":"conn-1"}"#)
        await firstTransport.failReceive(.network("closed"))

        try await waitUntil {
            await secondTransport.recordedSentTexts().count == 1
        }
        let secondAuthPayloads = try await decodedPayloads(from: secondTransport)
        XCTAssertEqual(secondAuthPayloads.first?["type"] as? String, "auth")

        try await client.processFrameForTests(#"{"type":"authed","conn_id":"conn-2"}"#)

        try await waitUntil {
            try await decodedPayloads(from: secondTransport)
                .contains { $0["type"] as? String == "join" }
        }
        let snapshot = await client.snapshot()
        XCTAssertEqual(snapshot.status, .authenticated)
        XCTAssertEqual(snapshot.connectionID, "conn-2")
        XCTAssertEqual(snapshot.desiredRooms, [roomID])
        XCTAssertEqual(snapshot.pendingRooms, [roomID])

        await client.disconnect()
    }

    func testEventDeduplicatorDropsRepeatedMessageEvents() {
        var deduplicator = WebSocketEventDeduplicator(capacity: 2)
        let firstMessage = WebSocketServerEvent(
            type: "message",
            fields: ["message_id": .string("m1")]
        )
        let duplicateMessage = WebSocketServerEvent(
            type: "message",
            fields: ["message_id": .string("m1")]
        )
        let secondMessage = WebSocketServerEvent(
            type: "message",
            fields: ["message_id": .string("m2")]
        )
        let thirdMessage = WebSocketServerEvent(
            type: "message",
            fields: ["message_id": .string("m3")]
        )

        XCTAssertTrue(deduplicator.shouldAccept(firstMessage))
        XCTAssertFalse(deduplicator.shouldAccept(duplicateMessage))
        XCTAssertTrue(deduplicator.shouldAccept(secondMessage))
        XCTAssertTrue(deduplicator.shouldAccept(thirdMessage))
        XCTAssertTrue(deduplicator.shouldAccept(firstMessage))
    }

    func testChatMessageDecodesFromWebSocketMessageEvent() throws {
        let event = WebSocketServerEvent(
            type: "message",
            fields: [
                "message_id": .string("m1"),
                "room_id": .string("r1"),
                "sender_id": .string("u1"),
                "sender_username": .string("alice"),
                "sender_nickname": .string("Alice"),
                "content": .string("hello"),
                "message_type": .string("text"),
                "timestamp": .string("2026-07-03T12:00:00Z"),
                "quoted_message": .object([
                    "message_id": .string("q1"),
                    "room_id": .string("r1"),
                    "sender_id": .string("u2"),
                    "sender_username": .string("bob"),
                    "content": .string("quoted"),
                ]),
            ]
        )

        let message = try ChatMessage(webSocketEvent: event, currentUserID: "u1")

        XCTAssertEqual(message.id, "m1")
        XCTAssertEqual(message.roomID, "r1")
        XCTAssertEqual(message.senderName, "Alice")
        XCTAssertEqual(message.content, "hello")
        XCTAssertEqual(message.status, .sent)
        XCTAssertEqual(message.quotedMessage?.id, "q1")
        XCTAssertEqual(message.quotedMessage?.content, "quoted")
    }
}

private actor MockWebSocketTransport: WebSocketTransport {
    private var connectedURL: URL?
    private var sentTexts: [String] = []
    private var continuations: [CheckedContinuation<String, Error>] = []
    private var queuedReceiveErrors: [RedCodeError] = []

    func connect(url: URL) async throws {
        connectedURL = url
    }

    func sendText(_ text: String) async throws {
        sentTexts.append(text)
    }

    func receiveText() async throws -> String {
        if !queuedReceiveErrors.isEmpty {
            throw queuedReceiveErrors.removeFirst()
        }
        return try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func failReceive(_ error: RedCodeError) {
        if let continuation = continuations.popLast() {
            continuation.resume(throwing: error)
        } else {
            queuedReceiveErrors.append(error)
        }
    }

    func close() async {
        for continuation in continuations {
            continuation.resume(throwing: CancellationError())
        }
        continuations.removeAll()
    }

    func recordedConnectedURL() -> URL? {
        connectedURL
    }

    func recordedSentTexts() -> [String] {
        sentTexts
    }
}

private final class MockTransportFactory: @unchecked Sendable {
    private let lock = NSLock()
    private var transports: [MockWebSocketTransport]
    private var index = 0

    init(_ transports: [MockWebSocketTransport]) {
        self.transports = transports
    }

    func next() -> any WebSocketTransport {
        lock.lock()
        defer { lock.unlock() }
        let transport = transports[min(index, transports.count - 1)]
        index += 1
        return transport
    }
}

private func decodedPayloads(from transport: MockWebSocketTransport) async throws -> [[String: Any]] {
    let sentTexts = await transport.recordedSentTexts()
    return try sentTexts.map { text in
        let data = Data(text.utf8)
        let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return try XCTUnwrap(payload)
    }
}

private func waitUntil(
    timeout: TimeInterval = 2,
    predicate: () async throws -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if try await predicate() {
            return
        }
        try await Task.sleep(nanoseconds: 50_000_000)
    }
    XCTFail("Condition was not met before timeout")
}
