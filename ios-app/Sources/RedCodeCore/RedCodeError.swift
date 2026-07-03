import Foundation

public enum RedCodeError: Error, Equatable, Sendable {
    case configuration(String)
    case authentication(String)
    case network(String)
    case storage(String)
}

extension RedCodeError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .configuration(let message):
            "Configuration error: \(message)"
        case .authentication(let message):
            "Authentication error: \(message)"
        case .network(let message):
            "Network error: \(message)"
        case .storage(let message):
            "Storage error: \(message)"
        }
    }
}
