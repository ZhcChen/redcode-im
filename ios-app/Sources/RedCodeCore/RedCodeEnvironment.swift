import Foundation

public enum RedCodeEnvironmentKind: String, CaseIterable, Equatable, Sendable {
    case development
    case test
    case release
}

public struct RedCodeEnvironment: Equatable, Sendable {
    public let kind: RedCodeEnvironmentKind
    public let apiBaseURL: URL
    public let webSocketURL: URL

    public init(
        kind: RedCodeEnvironmentKind,
        apiBaseURL: URL,
        webSocketURL: URL
    ) throws {
        guard ["http", "https"].contains(apiBaseURL.scheme?.lowercased()) else {
            throw RedCodeError.configuration("API base URL must use http or https")
        }

        guard ["ws", "wss"].contains(webSocketURL.scheme?.lowercased()) else {
            throw RedCodeError.configuration("WebSocket URL must use ws or wss")
        }

        self.kind = kind
        self.apiBaseURL = apiBaseURL
        self.webSocketURL = webSocketURL
    }

    public static func simulatorDevelopment() -> RedCodeEnvironment {
        try! RedCodeEnvironment(
            kind: .development,
            apiBaseURL: URL(string: "http://127.0.0.1:8010")!,
            webSocketURL: URL(string: "ws://127.0.0.1:8010/ws")!
        )
    }
}
