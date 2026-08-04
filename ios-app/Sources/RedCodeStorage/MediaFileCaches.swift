import Foundation

public struct AttachmentFileCache: Sendable {
    private let cache: FileResourceCache

    public init(rootURL: URL? = nil) {
        self.cache = FileResourceCache(namespace: "message_attachments", rootURL: rootURL)
    }

    public func resolve(objectKey: String) async throws -> CachedFileEntry? {
        try await cache.resolve(cacheKey: cacheKey(objectKey), objectKey: objectKey)
    }

    public func save(
        objectKey: String,
        data: Data,
        suggestedExtension: String? = nil,
        mimeType: String? = nil
    ) async throws -> CachedFileEntry {
        try await cache.save(
            cacheKey: cacheKey(objectKey),
            objectKey: objectKey,
            data: data,
            suggestedExtension: suggestedExtension,
            mimeType: mimeType
        )
    }

    public func saveFile(
        objectKey: String,
        sourceURL: URL,
        suggestedExtension: String? = nil,
        mimeType: String? = nil
    ) async throws -> CachedFileEntry {
        try await cache.saveFile(
            cacheKey: cacheKey(objectKey),
            objectKey: objectKey,
            sourceURL: sourceURL,
            suggestedExtension: suggestedExtension,
            mimeType: mimeType
        )
    }

    public func remove(objectKey: String) async throws {
        try await cache.remove(cacheKey: cacheKey(objectKey))
    }

    public func clearAll() async throws {
        try await cache.clearAll()
    }

    private func cacheKey(_ objectKey: String) -> String {
        "message:\(objectKey)"
    }
}

public struct AvatarFileCache: Sendable {
    private let cache: FileResourceCache

    public init(rootURL: URL? = nil, ttl: TimeInterval = 7 * 24 * 60 * 60) {
        self.cache = FileResourceCache(namespace: "avatar_cache", rootURL: rootURL, ttl: ttl)
    }

    public func resolveUserAvatar(userID: String, objectKey: String) async throws -> CachedFileEntry? {
        try await cache.resolve(cacheKey: "user:\(userID)", objectKey: objectKey)
    }

    public func resolveRoomAvatar(roomID: String, objectKey: String) async throws -> CachedFileEntry? {
        try await cache.resolve(cacheKey: "room:\(roomID)", objectKey: objectKey)
    }

    public func saveUserAvatar(
        userID: String,
        objectKey: String,
        data: Data,
        suggestedExtension: String? = nil,
        mimeType: String? = nil
    ) async throws -> CachedFileEntry {
        try await cache.save(
            cacheKey: "user:\(userID)",
            objectKey: objectKey,
            data: data,
            suggestedExtension: suggestedExtension,
            mimeType: mimeType
        )
    }

    public func saveRoomAvatar(
        roomID: String,
        objectKey: String,
        data: Data,
        suggestedExtension: String? = nil,
        mimeType: String? = nil
    ) async throws -> CachedFileEntry {
        try await cache.save(
            cacheKey: "room:\(roomID)",
            objectKey: objectKey,
            data: data,
            suggestedExtension: suggestedExtension,
            mimeType: mimeType
        )
    }

    public func clearUser(userID: String) async throws {
        try await cache.remove(cacheKey: "user:\(userID)")
    }

    public func clearRoom(roomID: String) async throws {
        try await cache.remove(cacheKey: "room:\(roomID)")
    }

    public func clearAll() async throws {
        try await cache.clearAll()
    }
}

public struct EmojiFileCache: Sendable {
    private let cache: FileResourceCache

    public init(rootURL: URL? = nil, ttl: TimeInterval = 7 * 24 * 60 * 60) {
        self.cache = FileResourceCache(namespace: "emoji_cache", rootURL: rootURL, ttl: ttl)
    }

    public func resolve(objectKey: String) async throws -> CachedFileEntry? {
        try await cache.resolve(cacheKey: cacheKey(objectKey), objectKey: objectKey)
    }

    public func save(
        objectKey: String,
        data: Data,
        suggestedExtension: String? = nil,
        mimeType: String? = nil
    ) async throws -> CachedFileEntry {
        try await cache.save(
            cacheKey: cacheKey(objectKey),
            objectKey: objectKey,
            data: data,
            suggestedExtension: suggestedExtension,
            mimeType: mimeType
        )
    }

    public func remove(objectKey: String) async throws {
        try await cache.remove(cacheKey: cacheKey(objectKey))
    }

    public func clearAll() async throws {
        try await cache.clearAll()
    }

    private func cacheKey(_ objectKey: String) -> String {
        "emoji:\(objectKey)"
    }
}
