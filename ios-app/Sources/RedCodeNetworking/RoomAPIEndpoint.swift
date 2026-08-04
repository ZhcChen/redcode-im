import Foundation

public enum RoomAPIEndpoint: Sendable {
    public static let rooms = APIEndpoint(method: .post, path: "/rooms")

    public static let listRooms = APIEndpoint(method: .get, path: "/rooms")

    public static func room(_ roomID: String, method: HTTPMethod = .get) -> APIEndpoint {
        APIEndpoint(method: method, path: "/rooms/\(roomID)")
    }

    public static func members(roomID: String) -> APIEndpoint {
        APIEndpoint(method: .get, path: "/rooms/\(roomID)/members")
    }

    public static func addMembers(roomID: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/rooms/\(roomID)/members/add")
    }

    public static func member(roomID: String, userID: String) -> APIEndpoint {
        APIEndpoint(method: .delete, path: "/rooms/\(roomID)/members/\(userID)")
    }

    public static func notificationSettings(roomID: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/rooms/\(roomID)/notification-settings")
    }

    public static func pin(roomID: String, method: HTTPMethod) -> APIEndpoint {
        APIEndpoint(method: method, path: "/rooms/\(roomID)/pin")
    }

    public static func leave(roomID: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/rooms/\(roomID)/leave")
    }

    public static func settings(roomID: String, method: HTTPMethod = .get) -> APIEndpoint {
        APIEndpoint(method: method, path: "/rooms/\(roomID)/settings")
    }

    public static func globalMute(roomID: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/rooms/\(roomID)/mutes/global")
    }

    public static func admins(roomID: String, method: HTTPMethod = .get) -> APIEndpoint {
        APIEndpoint(method: method, path: "/rooms/\(roomID)/admins")
    }

    public static func admin(roomID: String, adminID: String) -> APIEndpoint {
        APIEndpoint(method: .delete, path: "/rooms/\(roomID)/admins/\(adminID)")
    }

    public static func mutes(roomID: String, method: HTTPMethod = .get) -> APIEndpoint {
        APIEndpoint(method: method, path: "/rooms/\(roomID)/mutes")
    }

    public static func mute(roomID: String, mutedUserID: String) -> APIEndpoint {
        APIEndpoint(method: .delete, path: "/rooms/\(roomID)/mutes/\(mutedUserID)")
    }

    public static func rules(roomID: String, method: HTTPMethod = .get) -> APIEndpoint {
        APIEndpoint(method: method, path: "/rooms/\(roomID)/rules")
    }

    public static func rule(roomID: String, ruleID: String, method: HTTPMethod) -> APIEndpoint {
        APIEndpoint(method: method, path: "/rooms/\(roomID)/rules/\(ruleID)")
    }

    public static func joinRequests(roomID: String, method: HTTPMethod = .get) -> APIEndpoint {
        APIEndpoint(method: method, path: "/rooms/\(roomID)/join-requests")
    }

    public static func reviewJoinRequest(roomID: String, requestID: String) -> APIEndpoint {
        APIEndpoint(method: .patch, path: "/rooms/\(roomID)/join-requests/\(requestID)/review")
    }

    public static func invitations(roomID: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/rooms/\(roomID)/invitations")
    }

    public static func operationLogs(roomID: String, limit: Int, offset: Int) -> APIEndpoint {
        APIEndpoint(
            method: .get,
            path: "/rooms/\(roomID)/operation-logs",
            queryItems: [
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)"),
            ]
        )
    }

    public static func detail(roomID: String) -> APIEndpoint {
        APIEndpoint(method: .get, path: "/rooms/\(roomID)/detail")
    }
}
