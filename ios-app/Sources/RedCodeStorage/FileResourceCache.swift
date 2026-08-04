import Foundation
import RedCodeCore

public struct CachedFileEntry: Equatable, Sendable {
    public let cacheKey: String
    public let objectKey: String
    public let fileURL: URL
    public let mimeType: String
    public let size: Int
    public let cachedAt: Date
}

public actor FileResourceCache {
    private struct Metadata: Codable, Sendable {
        let cacheKey: String
        let objectKey: String
        let fileName: String
        let mimeType: String
        let size: Int
        let cachedAt: Date
    }

    private let namespace: String
    private let rootURL: URL
    private let ttl: TimeInterval
    private let fileManager: FileManager
    private let now: @Sendable () -> Date
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        namespace: String,
        rootURL: URL? = nil,
        ttl: TimeInterval = 7 * 24 * 60 * 60,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.namespace = namespace
        self.rootURL = rootURL ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.ttl = ttl
        self.fileManager = fileManager
        self.now = now
    }

    public func resolve(cacheKey: String, objectKey: String? = nil) throws -> CachedFileEntry? {
        let cacheKey = normalizedKey(cacheKey)
        guard !cacheKey.isEmpty else {
            return nil
        }
        guard let metadata = try readMetadata(cacheKey: cacheKey) else {
            return nil
        }
        if let objectKey, !objectKey.isEmpty, metadata.objectKey != objectKey {
            try remove(cacheKey: cacheKey)
            return nil
        }
        if now().timeIntervalSince(metadata.cachedAt) > ttl {
            try remove(cacheKey: cacheKey)
            return nil
        }

        let fileURL = filesDirectory.appendingPathComponent(metadata.fileName)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            try removeMetadata(cacheKey: cacheKey)
            return nil
        }
        return CachedFileEntry(
            cacheKey: metadata.cacheKey,
            objectKey: metadata.objectKey,
            fileURL: fileURL,
            mimeType: metadata.mimeType,
            size: metadata.size,
            cachedAt: metadata.cachedAt
        )
    }

    public func save(
        cacheKey: String,
        objectKey: String,
        data: Data,
        suggestedExtension: String? = nil,
        mimeType: String? = nil
    ) throws -> CachedFileEntry {
        let cacheKey = normalizedKey(cacheKey)
        let objectKey = normalizedKey(objectKey)
        guard !cacheKey.isEmpty, !objectKey.isEmpty else {
            throw RedCodeError.storage("Cache key and object key cannot be empty")
        }

        try ensureDirectories()
        let fileName = fileNameFor(cacheKey: cacheKey, objectKey: objectKey, suggestedExtension: suggestedExtension)
        let fileURL = filesDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        try data.write(to: fileURL, options: [.atomic])

        let metadata = Metadata(
            cacheKey: cacheKey,
            objectKey: objectKey,
            fileName: fileName,
            mimeType: mimeType ?? "application/octet-stream",
            size: data.count,
            cachedAt: now()
        )
        try writeMetadata(metadata, cacheKey: cacheKey)
        return CachedFileEntry(
            cacheKey: cacheKey,
            objectKey: objectKey,
            fileURL: fileURL,
            mimeType: metadata.mimeType,
            size: metadata.size,
            cachedAt: metadata.cachedAt
        )
    }

    public func saveFile(
        cacheKey: String,
        objectKey: String,
        sourceURL: URL,
        suggestedExtension: String? = nil,
        mimeType: String? = nil
    ) throws -> CachedFileEntry {
        let cacheKey = normalizedKey(cacheKey)
        let objectKey = normalizedKey(objectKey)
        guard !cacheKey.isEmpty, !objectKey.isEmpty else {
            throw RedCodeError.storage("Cache key and object key cannot be empty")
        }

        try ensureDirectories()
        let fallbackExtension = suggestedExtension ?? sourceURL.pathExtension
        let fileName = fileNameFor(cacheKey: cacheKey, objectKey: objectKey, suggestedExtension: fallbackExtension)
        let fileURL = filesDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        try fileManager.copyItem(at: sourceURL, to: fileURL)
        let size = try fileSize(at: fileURL)
        let metadata = Metadata(
            cacheKey: cacheKey,
            objectKey: objectKey,
            fileName: fileName,
            mimeType: mimeType ?? "application/octet-stream",
            size: size,
            cachedAt: now()
        )
        try writeMetadata(metadata, cacheKey: cacheKey)
        return CachedFileEntry(
            cacheKey: cacheKey,
            objectKey: objectKey,
            fileURL: fileURL,
            mimeType: metadata.mimeType,
            size: metadata.size,
            cachedAt: metadata.cachedAt
        )
    }

    public func remove(cacheKey: String) throws {
        let cacheKey = normalizedKey(cacheKey)
        guard !cacheKey.isEmpty else {
            return
        }
        if let metadata = try readMetadata(cacheKey: cacheKey) {
            let fileURL = filesDirectory.appendingPathComponent(metadata.fileName)
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        }
        try removeMetadata(cacheKey: cacheKey)
    }

    public func clearAll() throws {
        let namespaceURL = namespaceDirectory
        if fileManager.fileExists(atPath: namespaceURL.path) {
            try fileManager.removeItem(at: namespaceURL)
        }
    }

    private var namespaceDirectory: URL {
        rootURL.appendingPathComponent(namespace, isDirectory: true)
    }

    private var filesDirectory: URL {
        namespaceDirectory.appendingPathComponent("files", isDirectory: true)
    }

    private var metadataDirectory: URL {
        namespaceDirectory.appendingPathComponent("metadata", isDirectory: true)
    }

    private func ensureDirectories() throws {
        try fileManager.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: metadataDirectory, withIntermediateDirectories: true)
    }

    private func readMetadata(cacheKey: String) throws -> Metadata? {
        let metadataURL = metadataURL(cacheKey: cacheKey)
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: metadataURL)
        return try decoder.decode(Metadata.self, from: data)
    }

    private func writeMetadata(_ metadata: Metadata, cacheKey: String) throws {
        try ensureDirectories()
        let data = try encoder.encode(metadata)
        try data.write(to: metadataURL(cacheKey: cacheKey), options: [.atomic])
    }

    private func removeMetadata(cacheKey: String) throws {
        let metadataURL = metadataURL(cacheKey: cacheKey)
        if fileManager.fileExists(atPath: metadataURL.path) {
            try fileManager.removeItem(at: metadataURL)
        }
    }

    private func metadataURL(cacheKey: String) -> URL {
        metadataDirectory.appendingPathComponent(safeName(cacheKey)).appendingPathExtension("json")
    }

    private func fileNameFor(
        cacheKey: String,
        objectKey: String,
        suggestedExtension: String?
    ) -> String {
        let ext = resolvedExtension(objectKey: objectKey, suggestedExtension: suggestedExtension)
        return "\(safeName(cacheKey)).\(ext)"
    }

    private func resolvedExtension(objectKey: String, suggestedExtension: String?) -> String {
        let candidates = [
            URL(string: objectKey)?.pathExtension,
            URL(fileURLWithPath: objectKey).pathExtension,
            suggestedExtension,
        ]

        for candidate in candidates {
            let normalized = candidate?
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let normalized, !normalized.isEmpty {
                return normalized
            }
        }
        return "bin"
    }

    private func safeName(_ value: String) -> String {
        Data(value.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func normalizedKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fileSize(at url: URL) throws -> Int {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int ?? 0
    }
}
