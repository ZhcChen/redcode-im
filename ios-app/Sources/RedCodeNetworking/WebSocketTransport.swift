import Foundation
import RedCodeCore

public protocol WebSocketTransport: Sendable {
    func connect(url: URL) async throws
    func sendText(_ text: String) async throws
    func receiveText() async throws -> String
    func close() async
}

public actor URLSessionWebSocketTransport: WebSocketTransport {
    private let session: URLSession
    private var task: URLSessionWebSocketTask?

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func connect(url: URL) async throws {
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
    }

    public func sendText(_ text: String) async throws {
        guard let task else {
            throw RedCodeError.network("WebSocket 尚未连接")
        }
        try await task.send(.string(text))
    }

    public func receiveText() async throws -> String {
        guard let task else {
            throw RedCodeError.network("WebSocket 尚未连接")
        }
        let message = try await task.receive()
        switch message {
        case .string(let text):
            return text
        case .data:
            throw RedCodeError.network("暂不支持 WebSocket binary frame")
        @unknown default:
            throw RedCodeError.network("未知 WebSocket frame")
        }
    }

    public func close() async {
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
    }
}
