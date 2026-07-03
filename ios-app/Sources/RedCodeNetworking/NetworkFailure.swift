import Foundation

public enum NetworkFailureKind: String, Equatable, Sendable {
    case offline
    case timeout
    case cancelled
    case unauthorized
    case forbidden
    case notFound
    case server
    case decoding
    case invalidResponse
    case unknown
}

public struct NetworkFailure: Error, Equatable, Sendable {
    public let kind: NetworkFailureKind
    public let message: String
    public let statusCode: Int?

    public init(
        kind: NetworkFailureKind,
        message: String,
        statusCode: Int? = nil
    ) {
        self.kind = kind
        self.message = message
        self.statusCode = statusCode
    }

    public var isUserRecoverable: Bool {
        switch kind {
        case .offline, .timeout, .server, .unknown:
            true
        case .cancelled, .unauthorized, .forbidden, .notFound, .decoding, .invalidResponse:
            false
        }
    }

    public var recoverySuggestion: String? {
        switch kind {
        case .offline:
            "检查网络连接后重试"
        case .timeout:
            "网络超时，请稍后重试"
        case .server:
            "服务暂时不可用，请稍后重试"
        case .unknown:
            "请稍后重试"
        case .cancelled, .unauthorized, .forbidden, .notFound, .decoding, .invalidResponse:
            nil
        }
    }

    public static func http(statusCode: Int, message: String) -> NetworkFailure {
        NetworkFailure(
            kind: kind(forHTTPStatusCode: statusCode),
            message: message,
            statusCode: statusCode
        )
    }

    public static func transport(_ error: Error) -> NetworkFailure {
        if let failure = error as? NetworkFailure {
            return failure
        }
        guard let urlError = error as? URLError else {
            return NetworkFailure(kind: .unknown, message: error.localizedDescription)
        }

        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
            return NetworkFailure(kind: .offline, message: urlError.localizedDescription)
        case .timedOut:
            return NetworkFailure(kind: .timeout, message: urlError.localizedDescription)
        case .cancelled:
            return NetworkFailure(kind: .cancelled, message: urlError.localizedDescription)
        default:
            return NetworkFailure(kind: .unknown, message: urlError.localizedDescription)
        }
    }

    private static func kind(forHTTPStatusCode statusCode: Int) -> NetworkFailureKind {
        switch statusCode {
        case 401:
            .unauthorized
        case 403:
            .forbidden
        case 404:
            .notFound
        case 500...599:
            .server
        default:
            .unknown
        }
    }
}

extension NetworkFailure: LocalizedError {
    public var errorDescription: String? {
        message
    }
}
