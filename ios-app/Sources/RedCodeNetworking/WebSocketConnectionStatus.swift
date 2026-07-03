import Foundation

public enum WebSocketConnectionStatus: String, Equatable, Sendable {
    case connecting
    case connected
    case authenticated
    case disconnected
    case error
}
