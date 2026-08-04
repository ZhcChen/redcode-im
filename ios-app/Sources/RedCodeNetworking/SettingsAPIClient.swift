import Foundation
import RedCodeCore

public protocol SettingsAPIService: Sendable {
    func fetchGeneralSettings() async throws -> GeneralSettings
    func fetchAppName() async throws -> String
    func fetchDocument(_ kind: SettingsDocumentKind) async throws -> DocumentContent
    func submitFeedback(token: String, content: String, contact: String?) async throws -> SubmitFeedbackResponse
    func checkLatestVersion(currentVersion: String, channel: String) async throws -> VersionCheckResult
    func fetchVersionDownloadURL(id: String, expiresInSeconds: Int) async throws -> String
}

public struct SettingsAPIClient: SettingsAPIService {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public init(environment: RedCodeEnvironment) {
        self.apiClient = APIClient(environment: environment)
    }

    public func fetchGeneralSettings() async throws -> GeneralSettings {
        try await apiClient.get(SettingsAPIEndpoint.general, as: GeneralSettings.self)
    }

    public func fetchAppName() async throws -> String {
        let response = try await apiClient.get(SettingsAPIEndpoint.appName, as: AppNameResponse.self)
        return response.appName
    }

    public func fetchDocument(_ kind: SettingsDocumentKind) async throws -> DocumentContent {
        try await apiClient.get(SettingsAPIEndpoint.document(kind), as: DocumentContent.self)
    }

    public func submitFeedback(
        token: String,
        content: String,
        contact: String? = nil
    ) async throws -> SubmitFeedbackResponse {
        let request = try SubmitFeedbackRequest(content: content, contact: contact)
        return try await apiClient.post(
            SettingsAPIEndpoint.submitFeedback,
            body: request,
            bearerToken: token,
            as: SubmitFeedbackResponse.self
        )
    }

    public func checkLatestVersion(
        currentVersion: String,
        channel: String = "stable"
    ) async throws -> VersionCheckResult {
        try await apiClient.get(
            SettingsAPIEndpoint.latestVersion(
                platform: "ios",
                channel: channel,
                currentVersion: currentVersion
            ),
            as: VersionCheckResult.self
        )
    }

    public func fetchVersionDownloadURL(
        id: String,
        expiresInSeconds: Int = 600
    ) async throws -> String {
        let response = try await apiClient.get(
            SettingsAPIEndpoint.versionDownloadURL(
                id: id,
                expiresInSeconds: expiresInSeconds
            ),
            as: VersionDownloadURLResponse.self
        )
        if let url = response.downloadURL, !url.isEmpty {
            return url
        }
        throw NetworkFailure(kind: .invalidResponse, message: response.message)
    }
}

private struct AppNameResponse: Codable, Sendable {
    let appName: String

    private enum CodingKeys: String, CodingKey {
        case appName = "app_name"
    }
}
