import Foundation

public enum ChatAPIEndpoint: Sendable {
    public static let chats = APIEndpoint(method: .get, path: "/chats")

    public static func deleteChat(roomID: String) -> APIEndpoint {
        APIEndpoint(method: .delete, path: "/chats/\(roomID)")
    }

    public static func messages(
        roomID: String,
        limit: Int = 50,
        beforeID: String? = nil,
        sinceID: String? = nil
    ) -> APIEndpoint {
        var queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let beforeID, !beforeID.isEmpty {
            queryItems.append(URLQueryItem(name: "before_id", value: beforeID))
        }
        if let sinceID, !sinceID.isEmpty {
            queryItems.append(URLQueryItem(name: "since_id", value: sinceID))
        }
        return APIEndpoint(
            method: .get,
            path: "/rooms/\(roomID)/messages",
            queryItems: queryItems
        )
    }

    public static func sendMessage(roomID: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/rooms/\(roomID)/messages")
    }

    public static func markMessagesRead(roomID: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/rooms/\(roomID)/messages/read")
    }

    public static func deleteMessage(roomID: String, messageID: String) -> APIEndpoint {
        APIEndpoint(method: .delete, path: "/rooms/\(roomID)/messages/\(messageID)")
    }

    public static func pinMessage(roomID: String, messageID: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/rooms/\(roomID)/messages/\(messageID)/pin")
    }

    public static func unpinMessage(roomID: String, messageID: String) -> APIEndpoint {
        APIEndpoint(method: .delete, path: "/rooms/\(roomID)/messages/\(messageID)/pin")
    }

    public static func messageReactions(roomID: String, messageID: String) -> APIEndpoint {
        APIEndpoint(method: .get, path: "/rooms/\(roomID)/messages/\(messageID)/reactions")
    }

    public static func addMessageReaction(roomID: String, messageID: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/rooms/\(roomID)/messages/\(messageID)/reactions")
    }

    public static func removeMessageReaction(roomID: String, messageID: String, reactionKey: String) -> APIEndpoint {
        APIEndpoint(
            method: .delete,
            path: "/rooms/\(roomID)/messages/\(messageID)/reactions",
            queryItems: [
                URLQueryItem(name: "reaction_key", value: reactionKey),
            ]
        )
    }
}
