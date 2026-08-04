import Foundation

public enum MediaAPIEndpoint: Sendable {
    public static let userAvatarDirectUpload = APIEndpoint(
        method: .post,
        path: "/users/me/avatar/direct-upload"
    )

    public static let userAvatarCommit = APIEndpoint(
        method: .post,
        path: "/users/me/avatar/commit"
    )

    public static func userAvatarDownloadURL(userID: String?, expiresInSeconds: Int = 3_600) -> APIEndpoint {
        APIEndpoint(
            method: .get,
            path: userID.map { "/users/\($0)/avatar/url" } ?? "/users/me/avatar/url",
            queryItems: [
                URLQueryItem(name: "expires_in_seconds", value: String(expiresInSeconds)),
            ]
        )
    }

    public static func roomAvatarDirectUpload(roomID: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/rooms/\(roomID)/avatar/direct-upload")
    }

    public static func roomAvatarCommit(roomID: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/rooms/\(roomID)/avatar/commit")
    }

    public static func roomAvatarDownloadURL(roomID: String, expiresInSeconds: Int = 3_600) -> APIEndpoint {
        APIEndpoint(
            method: .get,
            path: "/rooms/\(roomID)/avatar/url",
            queryItems: [
                URLQueryItem(name: "expires_in_seconds", value: String(expiresInSeconds)),
            ]
        )
    }

    public static func messageAttachmentSignature(roomID: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/rooms/\(roomID)/messages/attachments/signature")
    }

    public static func messageAttachmentCommit(roomID: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/rooms/\(roomID)/messages/attachments/commit")
    }

    public static func messageAttachmentDownloadURL(
        roomID: String,
        key: String,
        expiresInSeconds: Int = 600
    ) -> APIEndpoint {
        APIEndpoint(
            method: .get,
            path: "/rooms/\(roomID)/messages/attachments/download",
            queryItems: [
                URLQueryItem(name: "key", value: key),
                URLQueryItem(name: "expires_in_seconds", value: String(expiresInSeconds)),
            ]
        )
    }
}
