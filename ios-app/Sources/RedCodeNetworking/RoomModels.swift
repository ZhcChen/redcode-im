import Foundation

public struct RoomInfo: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let roomType: String
    public let description: String?
    public let avatarURL: String?
    public let avatarObjectKey: String?
    public let ownerID: String?

    public init(
        id: String,
        name: String,
        roomType: String,
        description: String? = nil,
        avatarURL: String? = nil,
        avatarObjectKey: String? = nil,
        ownerID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.roomType = roomType
        self.description = description
        self.avatarURL = avatarURL
        self.avatarObjectKey = avatarObjectKey
        self.ownerID = ownerID
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case roomType = "room_type"
        case description
        case avatarURL = "avatar_url"
        case avatarObjectKey = "avatar_object_key"
        case ownerID = "owner_id"
    }
}

public struct CreateGroupRoomRequest: Encodable, Equatable, Sendable {
    public let name: String
    public let description: String?
    public let roomType: String
    public let memberIDs: [String]

    public init(name: String, description: String? = nil, memberIDs: [String]) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.description = description?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.roomType = "group"
        self.memberIDs = memberIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case roomType = "room_type"
        case memberIDs = "member_ids"
    }
}

struct CreateRoomResponse: Decodable, Sendable {
    let room: RoomInfo
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
