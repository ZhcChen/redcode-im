import Foundation
import RedCodeNetworking

public enum PushNotificationType: String, Equatable, Sendable {
    case message
    case friendRequest = "friend_request"
    case groupEvent = "group_event"
    case unknown

    public init(rawValue: String) {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "message":
            self = .message
        case "friend_request":
            self = .friendRequest
        case "group_event":
            self = .groupEvent
        default:
            self = .unknown
        }
    }
}

public struct PushNotificationPayload: Equatable, Sendable {
    public let type: PushNotificationType
    public let roomID: String?
    public let messageID: String?
    public let roomType: ChatType?
    public let senderID: String?
    public let senderName: String?
    public let chatName: String?
    public let requestID: String?
    public let requesterID: String?

    public init(
        type: PushNotificationType,
        roomID: String? = nil,
        messageID: String? = nil,
        roomType: ChatType? = nil,
        senderID: String? = nil,
        senderName: String? = nil,
        chatName: String? = nil,
        requestID: String? = nil,
        requesterID: String? = nil
    ) {
        self.type = type
        self.roomID = roomID?.nilIfBlank
        self.messageID = messageID?.nilIfBlank
        self.roomType = roomType
        self.senderID = senderID?.nilIfBlank
        self.senderName = senderName?.nilIfBlank
        self.chatName = chatName?.nilIfBlank
        self.requestID = requestID?.nilIfBlank
        self.requesterID = requesterID?.nilIfBlank
    }

    public init(dictionary: [String: String]) {
        let type = PushNotificationType(rawValue: dictionary["type"] ?? "message")
        let decodedRoomType = dictionary["room_type"].map { ChatType(pushRoomType: $0) }
        self.init(
            type: type,
            roomID: dictionary["room_id"],
            messageID: dictionary["message_id"],
            roomType: decodedRoomType,
            senderID: dictionary["sender_id"],
            senderName: dictionary["sender_name"],
            chatName: dictionary["chat_name"],
            requestID: dictionary["request_id"],
            requesterID: dictionary["requester_id"]
        )
    }

    public init(userInfo: [AnyHashable: Any]) {
        var dictionary: [String: String] = [:]
        for (key, value) in userInfo {
            dictionary[String(describing: key)] = String(describing: value)
        }
        self.init(dictionary: dictionary)
    }

    public var dictionary: [String: String] {
        var result = ["type": type.rawValue]
        if let roomID { result["room_id"] = roomID }
        if let messageID { result["message_id"] = messageID }
        if let roomType { result["room_type"] = roomType.rawValue }
        if let senderID { result["sender_id"] = senderID }
        if let senderName { result["sender_name"] = senderName }
        if let chatName { result["chat_name"] = chatName }
        if let requestID { result["request_id"] = requestID }
        if let requesterID { result["requester_id"] = requesterID }
        return result
    }

    public var jsonPayload: String? {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

public enum PushNavigationDestination: Equatable, Identifiable, Sendable {
    case chat(roomID: String, roomType: ChatType, chatName: String, messageID: String?)
    case friendRequests

    public var id: String {
        switch self {
        case .chat(let roomID, _, _, let messageID):
            "chat:\(roomID):\(messageID ?? "")"
        case .friendRequests:
            "friend_requests"
        }
    }

    public init?(payload: PushNotificationPayload) {
        switch payload.type {
        case .friendRequest:
            self = .friendRequests
        case .message, .groupEvent:
            guard let roomID = payload.roomID, !roomID.isEmpty else {
                return nil
            }
            self = .chat(
                roomID: roomID,
                roomType: payload.roomType ?? .privateChat,
                chatName: payload.chatName ?? "聊天",
                messageID: payload.messageID
            )
        case .unknown:
            return nil
        }
    }
}

private extension ChatType {
    init(pushRoomType: String) {
        switch pushRoomType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "group", "public":
            self = .group
        case "favorite":
            self = .favorite
        default:
            self = .privateChat
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
