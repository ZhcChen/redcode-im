import Foundation

public struct WebSocketServerEvent: Equatable, Sendable, Decodable {
    public let type: String
    public let fields: [String: JSONValue]

    public init(type: String, fields: [String: JSONValue] = [:]) {
        self.type = type
        var normalizedFields = fields
        normalizedFields["type"] = .string(type)
        self.fields = normalizedFields
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let fields = try container.decode([String: JSONValue].self)
        guard let type = fields["type"]?.stringValue, !type.isEmpty else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "WebSocket event is missing type"
            )
        }
        self.type = type
        self.fields = fields
    }

    public func stringValue(for key: String) -> String? {
        fields[key]?.stringValue
    }

    public func boolValue(for key: String) -> Bool? {
        fields[key]?.boolValue
    }

    public subscript(key: String) -> JSONValue? {
        fields[key]
    }
}

extension WebSocketServerEvent {
    public var deduplicationKey: String? {
        switch type {
        case "message":
            guard let messageID = stringValue(for: "message_id") ?? stringValue(for: "id") else {
                return nil
            }
            return "message:\(messageID)"
        case "message_read":
            return joinedKey(
                "message_read",
                stringValue(for: "room_id"),
                stringValue(for: "message_id"),
                stringValue(for: "reader_id")
            )
        case "message_update":
            return joinedKey(
                "message_update",
                stringValue(for: "room_id"),
                stringValue(for: "message_id")
            )
        case "pin_update":
            return joinedKey(
                "pin_update",
                stringValue(for: "room_id"),
                stringValue(for: "message_id"),
                stringValue(for: "is_pinned")
            )
        case "reaction_update":
            return joinedKey(
                "reaction_update",
                stringValue(for: "room_id"),
                stringValue(for: "message_id"),
                stringValue(for: "reaction_key"),
                stringValue(for: "user_id"),
                stringValue(for: "action")
            )
        default:
            return nil
        }
    }

    private func joinedKey(_ parts: String?...) -> String? {
        var values: [String] = []
        for part in parts {
            guard let value = part, !value.isEmpty else {
                return nil
            }
            values.append(value)
        }
        return values.joined(separator: ":")
    }
}
