import Foundation
import RedCodeCore

public struct APIEndpoint: Equatable, Sendable {
    public let method: HTTPMethod
    public let path: String
    public let queryItems: [URLQueryItem]

    public init(
        method: HTTPMethod = .get,
        path: String,
        queryItems: [URLQueryItem] = []
    ) {
        self.method = method
        self.path = path
        self.queryItems = queryItems
    }

    public func url(in environment: RedCodeEnvironment) throws -> URL {
        guard !path.isEmpty else {
            throw RedCodeError.configuration("API endpoint path cannot be empty")
        }

        guard var components = URLComponents(
            url: environment.apiBaseURL,
            resolvingAgainstBaseURL: false
        ) else {
            throw RedCodeError.configuration("Invalid API base URL")
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpointPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + [basePath, endpointPath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw RedCodeError.configuration("Unable to build API endpoint URL")
        }

        return url
    }
}
