import Foundation
import RedCodeCore

public protocol EmojiAPIService: Sendable {
    func fetchMyPacks(token: String) async throws -> [EmojiPack]
    func fetchAvailablePacks(token: String) async throws -> [EmojiPack]
    func searchPacks(keyword: String, token: String) async throws -> [EmojiPack]
    func addPack(packID: String, token: String) async throws
    func removePack(packID: String, token: String) async throws
    func addSuite(suiteID: String, token: String) async throws -> Int
    func fetchSuitePacks(suiteID: String, token: String) async throws -> [EmojiPack]
    func emojiDownloadURL(objectKey: String, token: String, expiresInSeconds: Int) async throws -> URL?
}

public struct EmojiAPIClient: EmojiAPIService {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public init(environment: RedCodeEnvironment) {
        self.apiClient = APIClient(environment: environment)
    }

    public func fetchMyPacks(token: String) async throws -> [EmojiPack] {
        let response = try await apiClient.get(
            EmojiAPIEndpoint.myPacks,
            bearerToken: token,
            as: [EmojiPackWithItems].self
        )
        return response.map(\.hydratedPack)
    }

    public func fetchAvailablePacks(token: String) async throws -> [EmojiPack] {
        try await apiClient.get(EmojiAPIEndpoint.availablePacks, bearerToken: token, as: [EmojiPack].self)
    }

    public func searchPacks(keyword: String, token: String) async throws -> [EmojiPack] {
        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            return []
        }
        return try await apiClient.get(
            EmojiAPIEndpoint.searchPacks(keyword: keyword),
            bearerToken: token,
            as: [EmojiPack].self
        )
    }

    public func addPack(packID: String, token: String) async throws {
        try await apiClient.postNoResponse(EmojiAPIEndpoint.addPack(packID: packID), bearerToken: token)
    }

    public func removePack(packID: String, token: String) async throws {
        try await apiClient.deleteNoResponse(EmojiAPIEndpoint.removePack(packID: packID), bearerToken: token)
    }

    public func addSuite(suiteID: String, token: String) async throws -> Int {
        let response = try await apiClient.post(
            EmojiAPIEndpoint.addSuite(suiteID: suiteID),
            bearerToken: token,
            as: EmojiActionResponse.self
        )
        return response.count ?? 0
    }

    public func fetchSuitePacks(suiteID: String, token: String) async throws -> [EmojiPack] {
        let response = try await apiClient.get(
            EmojiAPIEndpoint.suitePacks(suiteID: suiteID),
            bearerToken: token,
            as: [EmojiPackWithItems].self
        )
        return response.map(\.hydratedPack)
    }

    public func emojiDownloadURL(
        objectKey: String,
        token: String,
        expiresInSeconds: Int = 3_600
    ) async throws -> URL? {
        let response = try await apiClient.get(
            EmojiAPIEndpoint.downloadURL(objectKey: objectKey, expiresInSeconds: expiresInSeconds),
            bearerToken: token,
            as: EmojiDownloadURLResponse.self
        )
        return response.success ? response.downloadURL : nil
    }
}
