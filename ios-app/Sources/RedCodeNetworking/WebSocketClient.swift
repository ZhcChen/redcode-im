import Foundation
import RedCodeCore

public struct WebSocketClientSnapshot: Equatable, Sendable {
    public let status: WebSocketConnectionStatus
    public let connectionID: String?
    public let lastError: String
    public let desiredRooms: Set<String>
    public let subscribedRooms: Set<String>
    public let pendingRooms: Set<String>
    public let reconnectAttempts: Int

    public init(
        status: WebSocketConnectionStatus,
        connectionID: String? = nil,
        lastError: String = "",
        desiredRooms: Set<String> = [],
        subscribedRooms: Set<String> = [],
        pendingRooms: Set<String> = [],
        reconnectAttempts: Int = 0
    ) {
        self.status = status
        self.connectionID = connectionID
        self.lastError = lastError
        self.desiredRooms = desiredRooms
        self.subscribedRooms = subscribedRooms
        self.pendingRooms = pendingRooms
        self.reconnectAttempts = reconnectAttempts
    }
}

public actor WebSocketClient {
    public typealias TransportFactory = @Sendable () -> any WebSocketTransport
    public typealias ReconnectDelayProvider = @Sendable (_ attempt: Int) -> UInt64

    private let configuration: WebSocketConfiguration
    private let transportFactory: TransportFactory
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let maxReconnectAttempts: Int
    private let reconnectDelayProvider: ReconnectDelayProvider

    private var transport: (any WebSocketTransport)?
    private var listenTask: Task<Void, Never>?
    private var eventContinuations: [UUID: AsyncStream<WebSocketServerEvent>.Continuation] = [:]
    private var deduplicator = WebSocketEventDeduplicator()

    private var desiredRooms: Set<String> = []
    private var subscribedRooms: Set<String> = []
    private var pendingRooms: Set<String> = []
    private var authToken: String?
    private var manualClose = false
    private var reconnectAttempts = 0

    public private(set) var status: WebSocketConnectionStatus = .disconnected
    public private(set) var connectionID: String?
    public private(set) var lastError = ""

    public init(
        configuration: WebSocketConfiguration,
        transportFactory: @escaping TransportFactory = { URLSessionWebSocketTransport() },
        maxReconnectAttempts: Int = 5,
        reconnectDelayProvider: @escaping ReconnectDelayProvider = { attempt in
            min(UInt64(attempt) * 1_000_000_000, 5_000_000_000)
        }
    ) {
        self.configuration = configuration
        self.transportFactory = transportFactory
        self.maxReconnectAttempts = max(0, maxReconnectAttempts)
        self.reconnectDelayProvider = reconnectDelayProvider
    }

    deinit {
        listenTask?.cancel()
    }

    public func connect(accessToken explicitToken: String? = nil) async throws {
        if status == .connecting || status == .connected || status == .authenticated {
            return
        }

        let token = explicitToken ?? configuration.accessToken
        guard let token, !token.isEmpty else {
            lastError = "用户未登录"
            status = .error
            throw RedCodeError.authentication(lastError)
        }

        authToken = token
        manualClose = false
        lastError = ""
        status = .connecting

        let transport = transportFactory()
        self.transport = transport
        try await transport.connect(url: configuration.jsonHandshakeURL)
        status = .connected
        try await send(AuthCommand(token: token))

        listenTask?.cancel()
        listenTask = Task { [weak self] in
            guard let self else {
                return
            }
            await self.receiveLoop()
        }
    }

    public func disconnect() async {
        manualClose = true
        listenTask?.cancel()
        listenTask = nil
        desiredRooms.removeAll()
        subscribedRooms.removeAll()
        pendingRooms.removeAll()
        connectionID = nil
        reconnectAttempts = 0
        deduplicator.reset()
        await transport?.close()
        transport = nil
        status = .disconnected
    }

    public func ensureRoomsSubscribed(
        _ roomIDs: some Sequence<String>,
        pruneMissing: Bool = false
    ) async {
        let targets = Set(roomIDs.map(normalizedRoomID).filter { !$0.isEmpty })

        if pruneMissing {
            for roomID in desiredRooms where !targets.contains(roomID) {
                desiredRooms.remove(roomID)
                subscribedRooms.remove(roomID)
                pendingRooms.remove(roomID)
                try? await send(LeaveCommand(roomID: roomID))
            }
        }

        for roomID in targets {
            desiredRooms.insert(roomID)
            guard status == .authenticated else {
                continue
            }
            guard !subscribedRooms.contains(roomID), !pendingRooms.contains(roomID) else {
                continue
            }
            pendingRooms.insert(roomID)
            try? await send(JoinCommand(roomID: roomID))
        }
    }

    public func setTyping(roomID: String, isTyping: Bool) async {
        let roomID = normalizedRoomID(roomID)
        guard !roomID.isEmpty else {
            return
        }
        guard status == .authenticated, subscribedRooms.contains(roomID) else {
            return
        }
        try? await send(TypingCommand(roomID: roomID, isTyping: isTyping))
    }

    public func events() -> AsyncStream<WebSocketServerEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            eventContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeEventContinuation(id)
                }
            }
        }
    }

    public func snapshot() -> WebSocketClientSnapshot {
        WebSocketClientSnapshot(
            status: status,
            connectionID: connectionID,
            lastError: lastError,
            desiredRooms: desiredRooms,
            subscribedRooms: subscribedRooms,
            pendingRooms: pendingRooms,
            reconnectAttempts: reconnectAttempts
        )
    }

    func processFrameForTests(_ text: String) async throws {
        try await processFrame(text)
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            guard let transport else {
                return
            }
            do {
                let text = try await transport.receiveText()
                try await processFrame(text)
            } catch is CancellationError {
                return
            } catch {
                await handleTransportClosed(error)
                return
            }
        }
    }

    private func processFrame(_ text: String) async throws {
        guard let data = text.data(using: .utf8) else {
            throw RedCodeError.network("WebSocket frame 不是 UTF-8 文本")
        }

        let event: WebSocketServerEvent
        do {
            event = try decoder.decode(WebSocketServerEvent.self, from: data)
        } catch {
            lastError = "WebSocket 消息解析失败"
            status = .error
            throw RedCodeError.network(lastError)
        }

        switch event.type {
        case "authed":
            connectionID = event.stringValue(for: "conn_id")
            reconnectAttempts = 0
            status = .authenticated
            await ensureRoomsSubscribed(desiredRooms)
        case "joined":
            if let roomID = event.stringValue(for: "room_id") {
                pendingRooms.remove(roomID)
                subscribedRooms.insert(roomID)
            }
        case "left":
            if let roomID = event.stringValue(for: "room_id") {
                pendingRooms.remove(roomID)
                subscribedRooms.remove(roomID)
            }
        case "error":
            lastError = event.stringValue(for: "message") ?? "WebSocket 服务端错误"
            status = .error
        default:
            break
        }

        guard deduplicator.shouldAccept(event) else {
            return
        }
        dispatch(event)
    }

    private func handleTransportClosed(_ error: Error) async {
        await transport?.close()
        transport = nil
        subscribedRooms.removeAll()
        pendingRooms.removeAll()
        connectionID = nil

        if manualClose {
            status = .disconnected
            return
        }

        lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        status = .disconnected
        await reconnectIfNeeded()
    }

    private func reconnectIfNeeded() async {
        guard configuration.reconnectsAutomatically else {
            return
        }
        guard let authToken, !authToken.isEmpty else {
            return
        }
        guard reconnectAttempts < maxReconnectAttempts else {
            status = .error
            lastError = "WebSocket 重连次数已达上限"
            return
        }

        reconnectAttempts += 1
        let delay = reconnectDelayProvider(reconnectAttempts)
        try? await Task.sleep(nanoseconds: delay)
        guard !Task.isCancelled, !manualClose else {
            return
        }
        do {
            try await connect(accessToken: authToken)
        } catch {
            await reconnectIfNeeded()
        }
    }

    private func send<Payload: Encodable & Sendable>(_ payload: Payload) async throws {
        guard let transport else {
            throw RedCodeError.network("WebSocket 尚未连接")
        }
        let data = try encoder.encode(payload)
        guard let text = String(data: data, encoding: .utf8) else {
            throw RedCodeError.network("WebSocket payload 编码失败")
        }
        try await transport.sendText(text)
    }

    private func dispatch(_ event: WebSocketServerEvent) {
        for continuation in eventContinuations.values {
            continuation.yield(event)
        }
    }

    private func removeEventContinuation(_ id: UUID) {
        eventContinuations[id] = nil
    }

    private func normalizedRoomID(_ roomID: String) -> String {
        roomID.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct AuthCommand: Encodable, Sendable {
    let type = "auth"
    let token: String
}

private struct JoinCommand: Encodable, Sendable {
    let type = "join"
    let roomID: String

    enum CodingKeys: String, CodingKey {
        case type
        case roomID = "room_id"
    }
}

private struct LeaveCommand: Encodable, Sendable {
    let type = "leave"
    let roomID: String

    enum CodingKeys: String, CodingKey {
        case type
        case roomID = "room_id"
    }
}

private struct TypingCommand: Encodable, Sendable {
    let type = "typing"
    let roomID: String
    let isTyping: Bool

    enum CodingKeys: String, CodingKey {
        case type
        case roomID = "room_id"
        case isTyping = "is_typing"
    }
}
