import Foundation

public enum EmojiAPIEndpoint: Sendable {
    public static let myPacks = APIEndpoint(method: .get, path: "/emoji-packs/my")
    public static let availablePacks = APIEndpoint(method: .get, path: "/emoji-packs/available")

    public static func searchPacks(keyword: String) -> APIEndpoint {
        APIEndpoint(
            method: .get,
            path: "/emoji-packs/search",
            queryItems: [
                URLQueryItem(name: "keyword", value: keyword.trimmingCharacters(in: .whitespacesAndNewlines)),
            ]
        )
    }

    public static func downloadURL(objectKey: String, expiresInSeconds: Int = 3_600) -> APIEndpoint {
        APIEndpoint(
            method: .get,
            path: "/emoji-packs/download-url",
            queryItems: [
                URLQueryItem(name: "object_key", value: objectKey),
                URLQueryItem(name: "expires_in_seconds", value: String(expiresInSeconds)),
            ]
        )
    }

    public static func addPack(packID: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/emoji-packs/\(packID)/add")
    }

    public static func removePack(packID: String) -> APIEndpoint {
        APIEndpoint(method: .delete, path: "/emoji-packs/\(packID)/remove")
    }

    public static func addSuite(suiteID: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/emoji-packs/suites/\(suiteID)/add")
    }

    public static func suitePacks(suiteID: String) -> APIEndpoint {
        APIEndpoint(method: .get, path: "/emoji-packs/suites/\(suiteID)/packs")
    }
}
