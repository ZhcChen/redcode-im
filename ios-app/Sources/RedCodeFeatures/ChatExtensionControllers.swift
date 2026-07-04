import Foundation
import Observation
import RedCodeNetworking
import RedCodeStorage

public let redCodeBuiltInEmoji: [String] = [
    "😀", "😄", "😂", "😊", "😍", "😘", "😎", "😭",
    "😡", "👍", "👎", "🙏", "👏", "💪", "🎉", "❤️",
    "🔥", "✨", "✅", "❌", "👀", "🤝", "💯", "🍻",
]

@MainActor
@Observable
public final class EmojiStickerController {
    public private(set) var myPacks: [EmojiPack] = []
    public private(set) var availablePacks: [EmojiPack] = []
    public private(set) var searchResults: [EmojiPack] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    private let api: any EmojiAPIService
    private let emojiCache: EmojiFileCache

    public init(api: any EmojiAPIService, emojiCache: EmojiFileCache = EmojiFileCache()) {
        self.api = api
        self.emojiCache = emojiCache
    }

    public func load(token: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let my = api.fetchMyPacks(token: token)
            async let available = api.fetchAvailablePacks(token: token)
            myPacks = try await my
            availablePacks = try await available
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func search(keyword: String, token: String) async {
        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            searchResults = []
            return
        }
        do {
            searchResults = try await api.searchPacks(keyword: keyword, token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func add(pack: EmojiPack, token: String) async {
        do {
            if pack.packType == .suite {
                _ = try await api.addSuite(suiteID: pack.id, token: token)
            } else {
                try await api.addPack(packID: pack.id, token: token)
            }
            await load(token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func remove(pack: EmojiPack, token: String) async {
        do {
            try await api.removePack(packID: pack.id, token: token)
            myPacks.removeAll { $0.id == pack.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func resolveEmojiImage(item: EmojiItem, token: String) async -> URL? {
        let objectKey = item.imageObjectKey ?? item.imageURL
        guard !objectKey.isEmpty else {
            return nil
        }
        do {
            if let cached = try await emojiCache.resolve(objectKey: objectKey) {
                return cached.fileURL
            }
            let downloadURL: URL?
            if let imageObjectKey = item.imageObjectKey, !imageObjectKey.isEmpty {
                downloadURL = try await api.emojiDownloadURL(objectKey: imageObjectKey, token: token, expiresInSeconds: 3_600)
            } else {
                downloadURL = URL(string: item.imageURL)
            }
            guard let downloadURL else {
                return nil
            }
            let (data, response) = try await URLSession.shared.data(from: downloadURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }
            let cached = try await emojiCache.save(
                objectKey: objectKey,
                data: data,
                suggestedExtension: URL(fileURLWithPath: objectKey).pathExtension,
                mimeType: httpResponse.value(forHTTPHeaderField: "Content-Type")
            )
            return cached.fileURL
        } catch {
            return nil
        }
    }
}

public struct MessageSearchDisplayResult: Equatable, Identifiable, Sendable {
    public let id: String
    public let roomID: String
    public let roomName: String
    public let senderName: String
    public let content: String
    public let messageType: String
    public let timestamp: Date
    public let matchedText: String?
    public let source: String

    public init(
        id: String,
        roomID: String,
        roomName: String,
        senderName: String,
        content: String,
        messageType: String,
        timestamp: Date,
        matchedText: String? = nil,
        source: String
    ) {
        self.id = id
        self.roomID = roomID
        self.roomName = roomName
        self.senderName = senderName
        self.content = content
        self.messageType = messageType
        self.timestamp = timestamp
        self.matchedText = matchedText
        self.source = source
    }
}

@MainActor
@Observable
public final class MessageSearchController {
    public private(set) var results: [MessageSearchDisplayResult] = []
    public private(set) var isSearching = false
    public private(set) var isIndexing = false
    public private(set) var hasMore = false
    public private(set) var totalResults = 0
    public private(set) var errorMessage: String?

    private let localSearchStore: any MessageSearchStore
    private let remoteAPI: (any ChatAPIService)?
    private var localOffset = 0
    private var remoteOffset = 0
    private var hasMoreLocal = false
    private var hasMoreRemote = false

    public init(localSearchStore: any MessageSearchStore, remoteAPI: (any ChatAPIService)? = nil) {
        self.localSearchStore = localSearchStore
        self.remoteAPI = remoteAPI
    }

    public func rebuildIndex(chats: [ChatSummary]) {
        isIndexing = true
        defer { isIndexing = false }
        do {
            let roomNames = Dictionary(uniqueKeysWithValues: chats.map { ($0.roomID, $0.displayName) })
            try localSearchStore.rebuildIndex(roomNamesByID: roomNames)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func search(
        query: String,
        roomID: String? = nil,
        messageType: ChatMessageType? = nil,
        token: String? = nil
    ) async {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            results = []
            totalResults = 0
            hasMore = false
            return
        }

        isSearching = true
        errorMessage = nil
        localOffset = 0
        remoteOffset = 0
        defer { isSearching = false }

        do {
            let local = try localSearchStore.searchMessages(
                query: query,
                roomID: roomID,
                messageType: messageType?.rawValue,
                limit: 50,
                offset: 0
            )
            results = local.results.map(MessageSearchDisplayResult.local)
            totalResults = local.stats.totalResults
            localOffset = local.results.count
            hasMoreLocal = local.hasMore
            hasMoreRemote = false

            if let token, remoteAPI != nil {
                try await appendRemote(query: query, roomID: roomID, messageType: messageType, token: token, offset: 0)
            }
            hasMore = hasMoreLocal || hasMoreRemote
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func loadMore(
        query: String,
        roomID: String? = nil,
        messageType: ChatMessageType? = nil,
        token: String? = nil
    ) async {
        guard hasMore, !isSearching else {
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            if hasMoreLocal {
                let local = try localSearchStore.searchMessages(
                    query: query,
                    roomID: roomID,
                    messageType: messageType?.rawValue,
                    limit: 50,
                    offset: localOffset
                )
                merge(local.results.map(MessageSearchDisplayResult.local))
                localOffset += local.results.count
                hasMoreLocal = local.hasMore
            } else if let token, let remoteAPI, hasMoreRemote {
                _ = remoteAPI
                try await appendRemote(query: query, roomID: roomID, messageType: messageType, token: token, offset: remoteOffset)
            }
            hasMore = hasMoreLocal || hasMoreRemote
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func appendRemote(
        query: String,
        roomID: String?,
        messageType: ChatMessageType?,
        token: String,
        offset: Int
    ) async throws {
        guard let remoteAPI else {
            return
        }
        let response = try await remoteAPI.searchMessages(
            query: query,
            roomID: roomID,
            messageType: messageType,
            limit: 50,
            offset: offset,
            token: token
        )
        merge(response.results.map(MessageSearchDisplayResult.remote))
        remoteOffset = offset + response.results.count
        totalResults = max(totalResults, response.stats.totalResults)
        hasMoreRemote = response.hasMore
    }

    private func merge(_ incoming: [MessageSearchDisplayResult]) {
        var seen = Set(results.map(\.id))
        var merged = results
        for item in incoming where !seen.contains(item.id) {
            seen.insert(item.id)
            merged.append(item)
        }
        results = merged.sorted { $0.timestamp > $1.timestamp }
    }
}

@MainActor
@Observable
public final class ChatSettingsController {
    public private(set) var background: ChatBackgroundPreference = .default
    public private(set) var isWorking = false
    public private(set) var errorMessage: String?

    private let preferencesStore: any ChatPreferencesStore
    private let messageCacheStore: any MessageCacheStore
    private let attachmentCache: AttachmentFileCache
    private let avatarCache: AvatarFileCache
    private let emojiCache: EmojiFileCache

    public init(
        preferencesStore: any ChatPreferencesStore,
        messageCacheStore: any MessageCacheStore,
        attachmentCache: AttachmentFileCache,
        avatarCache: AvatarFileCache,
        emojiCache: EmojiFileCache
    ) {
        self.preferencesStore = preferencesStore
        self.messageCacheStore = messageCacheStore
        self.attachmentCache = attachmentCache
        self.avatarCache = avatarCache
        self.emojiCache = emojiCache
    }

    public func load() async {
        do {
            background = try await preferencesStore.loadBackground()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func saveBackground(_ preference: ChatBackgroundPreference) async {
        do {
            try await preferencesStore.saveBackground(preference)
            background = preference
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func clearAllCaches() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await attachmentCache.clearAll()
            try await avatarCache.clearAll()
            try await emojiCache.clearAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func clearChatHistory() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try messageCacheStore.clearAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension MessageSearchDisplayResult {
    static func local(_ result: LocalMessageSearchResult) -> MessageSearchDisplayResult {
        MessageSearchDisplayResult(
            id: result.id,
            roomID: result.roomID,
            roomName: result.roomName,
            senderName: result.senderName,
            content: result.content,
            messageType: result.messageType,
            timestamp: result.timestamp,
            matchedText: result.matchedText,
            source: "本地"
        )
    }

    static func remote(_ result: ChatMessageSearchResult) -> MessageSearchDisplayResult {
        MessageSearchDisplayResult(
            id: result.id,
            roomID: result.roomID,
            roomName: result.roomName,
            senderName: result.senderName,
            content: result.content,
            messageType: result.messageType.rawValue,
            timestamp: result.timestamp,
            matchedText: result.matchedText,
            source: "服务端"
        )
    }
}
