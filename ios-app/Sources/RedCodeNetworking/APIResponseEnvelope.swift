import Foundation

public struct BackendErrorResponse: Decodable, Equatable, Sendable {
    public let message: String?
    public let error: String?
    public let detail: String?

    public var preferredMessage: String? {
        [message, error, detail]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

public struct APIResponseEnvelope<Payload: Decodable & Sendable>: Decodable, Sendable {
    public let success: Bool?
    public let message: String?
    public let data: Payload?
    public let item: Payload?

    public var payload: Payload? {
        data ?? item
    }
}
