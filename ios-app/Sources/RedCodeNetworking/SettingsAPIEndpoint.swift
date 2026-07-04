import Foundation

public enum SettingsDocumentKind: Equatable, Sendable {
    case privacyPolicy
    case userAgreement

    public var title: String {
        switch self {
        case .privacyPolicy:
            "隐私协议"
        case .userAgreement:
            "用户协议"
        }
    }
}

public enum SettingsAPIEndpoint: Sendable {
    public static let general = APIEndpoint(method: .get, path: "/settings/general")
    public static let appName = APIEndpoint(method: .get, path: "/settings/app-name")

    public static func document(_ kind: SettingsDocumentKind) -> APIEndpoint {
        switch kind {
        case .privacyPolicy:
            APIEndpoint(method: .get, path: "/settings/privacy-policy")
        case .userAgreement:
            APIEndpoint(method: .get, path: "/settings/user-agreement")
        }
    }

    public static let submitFeedback = APIEndpoint(method: .post, path: "/feedbacks")

    public static func latestVersion(
        platform: String = "ios",
        channel: String = "stable",
        currentVersion: String? = nil
    ) -> APIEndpoint {
        var queryItems = [
            URLQueryItem(name: "platform", value: platform),
            URLQueryItem(name: "channel", value: channel),
        ]
        if let currentVersion = currentVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
           !currentVersion.isEmpty {
            queryItems.append(URLQueryItem(name: "current_version", value: currentVersion))
        }
        return APIEndpoint(method: .get, path: "/versions/latest", queryItems: queryItems)
    }

    public static func latestVersionDownloadURL(
        platform: String = "ios",
        channel: String = "stable",
        expiresInSeconds: Int = 600
    ) -> APIEndpoint {
        APIEndpoint(
            method: .get,
            path: "/versions/latest/download-url",
            queryItems: [
                URLQueryItem(name: "platform", value: platform),
                URLQueryItem(name: "channel", value: channel),
                URLQueryItem(name: "expires_in_seconds", value: "\(expiresInSeconds)"),
            ]
        )
    }

    public static func versionDownloadURL(
        id: String,
        expiresInSeconds: Int = 600
    ) -> APIEndpoint {
        APIEndpoint(
            method: .get,
            path: "/versions/download",
            queryItems: [
                URLQueryItem(name: "id", value: id),
                URLQueryItem(name: "expires_in_seconds", value: "\(expiresInSeconds)"),
            ]
        )
    }
}
