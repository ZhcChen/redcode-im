import Foundation

public enum RedCodeEnvironmentKind: String, CaseIterable, Equatable, Sendable {
    case development
    case test
    case release
}

public struct RedCodeEnvironment: Equatable, Sendable {
    public static let apiBaseURLConfigKey = "REDCODE_API_BASE_URL"
    public static let webSocketURLConfigKey = "REDCODE_WS_URL"

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

    public static func configuredDevelopment(
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:]
    ) throws -> RedCodeEnvironment {
        let fallback = simulatorDevelopment()
        let apiValue = firstConfigValue(
            keys: [apiBaseURLConfigKey, "API_BASE_URL"],
            processEnvironment: processEnvironment,
            infoDictionary: infoDictionary
        )
        let wsValue = firstConfigValue(
            keys: [webSocketURLConfigKey, "WS_URL"],
            processEnvironment: processEnvironment,
            infoDictionary: infoDictionary
        )

        guard apiValue != nil || wsValue != nil else {
            return fallback
        }
        guard apiValue != nil, wsValue != nil else {
            throw RedCodeError.configuration("API and WebSocket base URLs must be configured together")
        }

        guard let apiURL = URL(string: apiValue!) else {
            throw RedCodeError.configuration("API base URL is invalid")
        }
        guard let wsURL = URL(string: wsValue!) else {
            throw RedCodeError.configuration("WebSocket URL is invalid")
        }

        return try RedCodeEnvironment(
            kind: .development,
            apiBaseURL: apiURL,
            webSocketURL: wsURL
        )
    }

    private static func firstConfigValue(
        keys: [String],
        processEnvironment: [String: String],
        infoDictionary: [String: Any]
    ) -> String? {
        for key in keys {
            if let value = processEnvironment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }
        for key in keys {
            if let value = infoDictionary[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }
}
