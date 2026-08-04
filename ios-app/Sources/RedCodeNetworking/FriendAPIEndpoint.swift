import Foundation

public enum FriendAPIEndpoint: Sendable {
    public static func searchUsers(keyword: String, limit: Int = 20) -> APIEndpoint {
        APIEndpoint(
            method: .get,
            path: "/users/search",
            queryItems: [
                URLQueryItem(name: "keyword", value: keyword),
                URLQueryItem(name: "limit", value: String(limit)),
            ]
        )
    }

    public static let friends = APIEndpoint(method: .get, path: "/friends")
    public static let friendRequests = APIEndpoint(method: .get, path: "/friends/requests")
    public static let createFriendRequest = APIEndpoint(method: .post, path: "/friends/requests")

    public static func friendRequests(direction: String? = nil, status: String? = nil) -> APIEndpoint {
        var queryItems: [URLQueryItem] = []
        if let direction, !direction.isEmpty {
            queryItems.append(URLQueryItem(name: "direction", value: direction))
        }
        if let status, !status.isEmpty {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        return APIEndpoint(method: .get, path: "/friends/requests", queryItems: queryItems)
    }

    public static func respondFriendRequest(requestID: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/friends/requests/\(requestID)/respond")
    }

    public static func ensurePrivateChat(friendUserID: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/friends/\(friendUserID)/chat")
    }

    public static func deleteFriend(friendUserID: String) -> APIEndpoint {
        APIEndpoint(method: .delete, path: "/friends/\(friendUserID)")
    }
}
