import Foundation
import RedCodeCore

public struct WebSocketConfiguration: Equatable, Sendable {
    public let url: URL
    public let accessToken: String?
    public let reconnectsAutomatically: Bool

    public init(
        environment: RedCodeEnvironment,
        accessToken: String? = nil,
        reconnectsAutomatically: Bool = true
    ) {
        self.url = environment.webSocketURL
        self.accessToken = accessToken
        self.reconnectsAutomatically = reconnectsAutomatically
    }
}
