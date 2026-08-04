import Foundation
import RedCodeCore

public struct WebSocketConfiguration: Equatable, Sendable {
    public let url: URL
    public let accessToken: String?
    public let reconnectsAutomatically: Bool
    public let format: String

    public init(
        environment: RedCodeEnvironment,
        accessToken: String? = nil,
        reconnectsAutomatically: Bool = true,
        format: String = "json"
    ) {
        self.url = environment.webSocketURL
        self.accessToken = accessToken
        self.reconnectsAutomatically = reconnectsAutomatically
        self.format = format
    }

    public var jsonHandshakeURL: URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "format" }
        queryItems.append(URLQueryItem(name: "format", value: format))
        components.queryItems = queryItems
        return components.url ?? url
    }
}
