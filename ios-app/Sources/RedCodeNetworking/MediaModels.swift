import Foundation

public enum MediaPartType: String, Codable, Equatable, Sendable {
    case image
    case video
    case audio
    case file
}

public struct DirectUploadSignature: Decodable, Equatable, Sendable {
    public let url: URL
    public let method: HTTPMethod
    public let headers: [String: String]
    public let key: String?

    public init(url: URL, method: HTTPMethod = .put, headers: [String: String] = [:], key: String? = nil) {
        self.url = url
        self.method = method
        self.headers = headers
        self.key = key
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawURL = try container.decode(String.self, forKey: .url)
        guard let url = URL(string: rawURL), !rawURL.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .url,
                in: container,
                debugDescription: "Direct upload signature URL is invalid"
            )
        }
        self.url = url
        let rawMethod = try container.decodeIfPresent(String.self, forKey: .method) ?? HTTPMethod.put.rawValue
        self.method = HTTPMethod(rawValue: rawMethod.uppercased()) ?? .put
        self.headers = try container.decodeIfPresent([String: String].self, forKey: .headers) ?? [:]
        self.key = try container.decodeIfPresent(String.self, forKey: .key)
    }

    private enum CodingKeys: String, CodingKey {
        case url
        case method
        case headers
        case key
    }
}

public struct DirectUploadDescriptor: Equatable, Sendable {
    public let key: String
    public let signature: DirectUploadSignature?

    public init(key: String, signature: DirectUploadSignature?) {
        self.key = key
        self.signature = signature
    }
}

public struct MediaUploadMetadata: Equatable, Sendable {
    public let fileName: String
    public let contentType: String
    public let fileSize: Int64
    public let hashValue: String?
    public let hashAlgorithm: Int?

    public init(
        fileName: String,
        contentType: String,
        fileSize: Int64,
        hashValue: String? = nil,
        hashAlgorithm: Int? = nil
    ) {
        self.fileName = fileName
        self.contentType = contentType
        self.fileSize = fileSize
        self.hashValue = hashValue
        self.hashAlgorithm = hashAlgorithm
    }
}

public struct MediaCommitResult: Equatable, Sendable {
    public let success: Bool
    public let message: String
    public let avatarURL: String?

    public init(success: Bool, message: String, avatarURL: String? = nil) {
        self.success = success
        self.message = message
        self.avatarURL = avatarURL
    }
}

struct AvatarDirectUploadRequest: Encodable, Equatable, Sendable {
    let filename: String
    let contentType: String
    let fileSize: Int64?
    let hashValue: String?
    let hashAlgorithm: Int?

    init(metadata: MediaUploadMetadata) {
        self.filename = metadata.fileName
        self.contentType = metadata.contentType
        self.fileSize = metadata.fileSize
        self.hashValue = metadata.hashValue
        self.hashAlgorithm = metadata.hashAlgorithm
    }

    private enum CodingKeys: String, CodingKey {
        case filename
        case contentType = "content_type"
        case fileSize = "file_size"
        case hashValue = "hash_value"
        case hashAlgorithm = "hash_alg"
    }
}

struct AvatarCommitRequest: Encodable, Equatable, Sendable {
    let key: String
}

struct MessageAttachmentSignatureRequest: Encodable, Equatable, Sendable {
    let partType: MediaPartType
    let filename: String?
    let contentType: String?
    let fileSize: Int64?
    let hashValue: String?
    let hashAlgorithm: Int?

    init(partType: MediaPartType, metadata: MediaUploadMetadata) {
        self.partType = partType
        self.filename = metadata.fileName
        self.contentType = metadata.contentType
        self.fileSize = metadata.fileSize
        self.hashValue = metadata.hashValue
        self.hashAlgorithm = metadata.hashAlgorithm
    }

    private enum CodingKeys: String, CodingKey {
        case partType = "part_type"
        case filename
        case contentType = "content_type"
        case fileSize = "file_size"
        case hashValue = "hash_value"
        case hashAlgorithm = "hash_alg"
    }
}

struct MessageAttachmentCommitRequest: Encodable, Equatable, Sendable {
    let key: String
    let hashValue: String?
    let hashAlgorithm: Int?
    let fileSize: Int64?

    init(key: String, metadata: MediaUploadMetadata) {
        self.key = key
        self.hashValue = metadata.hashValue
        self.hashAlgorithm = metadata.hashAlgorithm
        self.fileSize = metadata.fileSize
    }

    private enum CodingKeys: String, CodingKey {
        case key
        case hashValue = "hash_value"
        case hashAlgorithm = "hash_alg"
        case fileSize = "file_size"
    }
}

struct DirectUploadResponse: Decodable, Sendable {
    let success: Bool
    let message: String
    let key: String?
    let signature: DirectUploadSignature?
}

struct MediaCommitResponse: Decodable, Sendable {
    let success: Bool
    let message: String
    let avatarURL: String?

    private enum CodingKeys: String, CodingKey {
        case success
        case message
        case avatarURL = "avatar_url"
    }
}

struct DownloadURLResponse: Decodable, Sendable {
    let success: Bool
    let message: String
    let downloadURL: URL?

    private enum CodingKeys: String, CodingKey {
        case success
        case message
        case downloadURL = "download_url"
    }
}
