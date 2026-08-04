import Foundation

public enum EmojiPackType: Int, Codable, Equatable, Sendable {
    case single = 0
    case suite = 1

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = (try? container.decode(Int.self)) ?? 0
        self = EmojiPackType(rawValue: value) ?? .single
    }
}

public struct EmojiPack: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let iconURL: String?
    public let iconObjectKey: String?
    public let description: String?
    public let isActive: Bool
    public let packType: EmojiPackType
    public let parentID: String?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let items: [EmojiItem]

    public init(
        id: String,
        name: String,
        iconURL: String? = nil,
        iconObjectKey: String? = nil,
        description: String? = nil,
        isActive: Bool = true,
        packType: EmojiPackType = .single,
        parentID: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        items: [EmojiItem] = []
    ) {
        self.id = id
        self.name = name
        self.iconURL = iconURL
        self.iconObjectKey = iconObjectKey
        self.description = description
        self.isActive = isActive
        self.packType = packType
        self.parentID = parentID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.items = items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        iconURL = try container.decodeIfPresent(String.self, forKey: .iconURL)
        iconObjectKey = try container.decodeIfPresent(String.self, forKey: .iconObjectKey)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        packType = try container.decodeIfPresent(EmojiPackType.self, forKey: .packType) ?? .single
        parentID = try container.decodeIfPresent(String.self, forKey: .parentID)
        createdAt = container.decodeFlexibleDate(forKey: .createdAt)
        updatedAt = container.decodeFlexibleDate(forKey: .updatedAt)
        items = try container.decodeIfPresent([EmojiItem].self, forKey: .items) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case iconURL = "icon_url"
        case iconObjectKey = "icon_object_key"
        case description
        case isActive = "is_active"
        case packType = "pack_type"
        case parentID = "parent_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case items
    }
}

public struct EmojiItem: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let packID: String
    public let imageURL: String
    public let imageObjectKey: String?
    public let name: String?
    public let sortOrder: Int
    public let createdAt: Date?

    public init(
        id: String,
        packID: String,
        imageURL: String,
        imageObjectKey: String? = nil,
        name: String? = nil,
        sortOrder: Int = 0,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.packID = packID
        self.imageURL = imageURL
        self.imageObjectKey = imageObjectKey
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        packID = try container.decode(String.self, forKey: .packID)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL) ?? ""
        imageObjectKey = try container.decodeIfPresent(String.self, forKey: .imageObjectKey)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        createdAt = container.decodeFlexibleDate(forKey: .createdAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case packID = "pack_id"
        case imageURL = "image_url"
        case imageObjectKey = "image_object_key"
        case name
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }
}

public struct EmojiPackWithItems: Decodable, Equatable, Sendable {
    public let pack: EmojiPack
    public let items: [EmojiItem]

    public init(pack: EmojiPack, items: [EmojiItem]) {
        self.pack = pack
        self.items = items
    }

    public var hydratedPack: EmojiPack {
        EmojiPack(
            id: pack.id,
            name: pack.name,
            iconURL: pack.iconURL,
            iconObjectKey: pack.iconObjectKey,
            description: pack.description,
            isActive: pack.isActive,
            packType: pack.packType,
            parentID: pack.parentID,
            createdAt: pack.createdAt,
            updatedAt: pack.updatedAt,
            items: items.sorted { $0.sortOrder < $1.sortOrder }
        )
    }
}

public struct EmojiActionResponse: Decodable, Equatable, Sendable {
    public let success: Bool
    public let message: String
    public let count: Int?
}

public struct EmojiDownloadURLResponse: Decodable, Equatable, Sendable {
    public let success: Bool
    public let message: String
    public let downloadURL: URL?

    private enum CodingKeys: String, CodingKey {
        case success
        case message
        case downloadURL = "download_url"
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleDate(forKey key: Key) -> Date? {
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return FlexibleDateParser.parse(string)
        }
        if let double = try? decodeIfPresent(Double.self, forKey: key) {
            let seconds = double > 1_000_000_000_000 ? double / 1000 : double
            return Date(timeIntervalSince1970: seconds)
        }
        return nil
    }
}

private enum FlexibleDateParser {
    static func parse(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else {
            return nil
        }
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
