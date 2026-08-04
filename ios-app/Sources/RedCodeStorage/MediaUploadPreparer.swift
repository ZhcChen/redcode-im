import CryptoKit
import Foundation
import RedCodeCore
import UniformTypeIdentifiers

public enum PreparedUploadKind: String, Codable, Equatable, Sendable {
    case image
    case video
    case audio
    case file
}

public struct PreparedUploadFile: Equatable, Sendable {
    public let localURL: URL
    public let fileName: String
    public let contentType: String
    public let size: Int64
    public let hashValue: String?
    public let hashAlgorithm: Int?
    public let kind: PreparedUploadKind
    public let width: Int?
    public let height: Int?
    public let durationMilliseconds: Int?

    public init(
        localURL: URL,
        fileName: String,
        contentType: String,
        size: Int64,
        hashValue: String? = nil,
        hashAlgorithm: Int? = nil,
        kind: PreparedUploadKind,
        width: Int? = nil,
        height: Int? = nil,
        durationMilliseconds: Int? = nil
    ) {
        self.localURL = localURL
        self.fileName = fileName
        self.contentType = contentType
        self.size = size
        self.hashValue = hashValue
        self.hashAlgorithm = hashAlgorithm
        self.kind = kind
        self.width = width
        self.height = height
        self.durationMilliseconds = durationMilliseconds
    }
}

public enum MediaUploadPreparer {
    public static let sha256HashAlgorithm = 2

    public static func prepareFile(
        at url: URL,
        kind explicitKind: PreparedUploadKind? = nil,
        fileName explicitFileName: String? = nil,
        contentType explicitContentType: String? = nil,
        width: Int? = nil,
        height: Int? = nil,
        durationMilliseconds: Int? = nil
    ) throws -> PreparedUploadFile {
        let fileManager = FileManager.default
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile != false else {
            throw RedCodeError.storage("Selected media is not a regular file")
        }
        let size = Int64(values.fileSize ?? 0)
        let contentType = normalizedContentType(
            explicitContentType,
            fallbackURL: url
        )
        let fileName = normalizedFileName(explicitFileName, fallbackURL: url, contentType: contentType)
        let kind = explicitKind ?? inferKind(contentType: contentType, fileURL: url)
        let hash = try sha256Hex(fileURL: url, fileManager: fileManager)

        return PreparedUploadFile(
            localURL: url,
            fileName: fileName,
            contentType: contentType,
            size: size,
            hashValue: hash,
            hashAlgorithm: sha256HashAlgorithm,
            kind: kind,
            width: width,
            height: height,
            durationMilliseconds: durationMilliseconds
        )
    }

    public static func writeTemporaryFile(
        data: Data,
        preferredFileName: String,
        directory: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        let safeName = preferredFileName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let fileName = safeName.isEmpty ? "upload-\(UUID().uuidString).bin" : safeName
        let url = directory.appendingPathComponent("\(UUID().uuidString)-\(fileName)")
        try data.write(to: url, options: [.atomic])
        return url
    }

    public static func sha256Hex(data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    public static func sha256Hex(fileURL: URL, fileManager: FileManager = .default) throws -> String {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw RedCodeError.storage("File does not exist: \(fileURL.path)")
        }
        return sha256Hex(data: try Data(contentsOf: fileURL))
    }

    public static func inferKind(contentType: String, fileURL: URL? = nil) -> PreparedUploadKind {
        let normalized = contentType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.hasPrefix("image/") {
            return .image
        }
        if normalized.hasPrefix("video/") {
            return .video
        }
        if normalized.hasPrefix("audio/") {
            return .audio
        }

        if let fileURL,
           let type = UTType(filenameExtension: fileURL.pathExtension) {
            if type.conforms(to: .image) {
                return .image
            }
            if type.conforms(to: .movie) {
                return .video
            }
            if type.conforms(to: .audio) {
                return .audio
            }
        }
        return .file
    }

    public static func normalizedContentType(_ contentType: String?, fallbackURL: URL) -> String {
        if let contentType = contentType?.trimmingCharacters(in: .whitespacesAndNewlines),
           !contentType.isEmpty {
            return contentType
        }
        if let type = UTType(filenameExtension: fallbackURL.pathExtension),
           let mime = type.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }

    private static func normalizedFileName(
        _ fileName: String?,
        fallbackURL: URL,
        contentType: String
    ) -> String {
        let trimmed = fileName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        let lastPathComponent = fallbackURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !lastPathComponent.isEmpty {
            return lastPathComponent
        }
        let ext = UTType(mimeType: contentType)?.preferredFilenameExtension ?? "bin"
        return "upload-\(UUID().uuidString).\(ext)"
    }
}
