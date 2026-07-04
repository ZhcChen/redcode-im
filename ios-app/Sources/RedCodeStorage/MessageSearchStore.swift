import Foundation

public struct LocalMessageSearchResult: Equatable, Identifiable, Sendable {
    public let id: String
    public let roomID: String
    public let roomName: String
    public let senderID: String
    public let senderName: String
    public let content: String
    public let messageType: String
    public let timestamp: Date
    public let relevanceScore: Double
    public let matchedText: String?

    public init(
        id: String,
        roomID: String,
        roomName: String,
        senderID: String,
        senderName: String,
        content: String,
        messageType: String,
        timestamp: Date,
        relevanceScore: Double,
        matchedText: String? = nil
    ) {
        self.id = id
        self.roomID = roomID
        self.roomName = roomName
        self.senderID = senderID
        self.senderName = senderName
        self.content = content
        self.messageType = messageType
        self.timestamp = timestamp
        self.relevanceScore = relevanceScore
        self.matchedText = matchedText
    }
}

public struct LocalMessageSearchStats: Equatable, Sendable {
    public let totalResults: Int
    public let searchTimeMilliseconds: Int
    public let query: String

    public init(totalResults: Int, searchTimeMilliseconds: Int, query: String) {
        self.totalResults = totalResults
        self.searchTimeMilliseconds = searchTimeMilliseconds
        self.query = query
    }
}

public struct LocalMessageSearchResponse: Equatable, Sendable {
    public let results: [LocalMessageSearchResult]
    public let stats: LocalMessageSearchStats
    public let hasMore: Bool

    public init(results: [LocalMessageSearchResult], stats: LocalMessageSearchStats, hasMore: Bool) {
        self.results = results
        self.stats = stats
        self.hasMore = hasMore
    }
}

@MainActor
public protocol MessageSearchStore: AnyObject {
    func rebuildIndex(roomNamesByID: [String: String]) throws
    func searchMessages(
        query: String,
        roomID: String?,
        messageType: String?,
        limit: Int,
        offset: Int
    ) throws -> LocalMessageSearchResponse
}

@MainActor
public final class SwiftDataMessageSearchStore: MessageSearchStore {
    private let messageCacheStore: any MessageCacheStore
    private var index: [LocalMessageSearchResult] = []

    public init(messageCacheStore: any MessageCacheStore) {
        self.messageCacheStore = messageCacheStore
    }

    public func rebuildIndex(roomNamesByID: [String: String] = [:]) throws {
        var nextIndex: [LocalMessageSearchResult] = []
        for roomID in try messageCacheStore.listRoomIDs() {
            let roomName = roomNamesByID[roomID] ?? roomID
            for draft in try messageCacheStore.loadMessages(roomID: roomID)
                where !draft.isDeleted && draft.status.lowercased() != "deleted" {
                nextIndex.append(
                    LocalMessageSearchResult(
                        id: draft.id,
                        roomID: roomID,
                        roomName: roomName,
                        senderID: draft.senderID,
                        senderName: draft.senderName ?? draft.senderID,
                        content: searchableContent(for: draft),
                        messageType: draft.messageType,
                        timestamp: draft.timestamp,
                        relevanceScore: 0,
                        matchedText: nil
                    )
                )
            }
        }
        index = nextIndex
    }

    public func searchMessages(
        query: String,
        roomID: String? = nil,
        messageType: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) throws -> LocalMessageSearchResponse {
        let stopwatch = Stopwatch()
        stopwatch.start()
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return LocalMessageSearchResponse(
                results: [],
                stats: LocalMessageSearchStats(totalResults: 0, searchTimeMilliseconds: 0, query: ""),
                hasMore: false
            )
        }

        let normalizedRoomID = roomID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedType = messageType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let terms = normalizedQuery
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }

        let matches = index.compactMap { item -> LocalMessageSearchResult? in
            if let normalizedRoomID, !normalizedRoomID.isEmpty, item.roomID != normalizedRoomID {
                return nil
            }
            if let normalizedType, !normalizedType.isEmpty, item.messageType.lowercased() != normalizedType {
                return nil
            }
            let haystacks = [item.content, item.senderName, item.roomName]
            guard terms.allSatisfy({ term in haystacks.contains { $0.localizedCaseInsensitiveContains(term) } }) else {
                return nil
            }
            let score: Double
            if item.content.localizedCaseInsensitiveContains(normalizedQuery) {
                score = 1.0
            } else if item.senderName.localizedCaseInsensitiveContains(normalizedQuery) {
                score = 0.8
            } else {
                score = 0.6
            }
            return LocalMessageSearchResult(
                id: item.id,
                roomID: item.roomID,
                roomName: item.roomName,
                senderID: item.senderID,
                senderName: item.senderName,
                content: item.content,
                messageType: item.messageType,
                timestamp: item.timestamp,
                relevanceScore: score,
                matchedText: makeSnippet(content: item.content, query: normalizedQuery)
            )
        }
        .sorted {
            if $0.relevanceScore != $1.relevanceScore {
                return $0.relevanceScore > $1.relevanceScore
            }
            return $0.timestamp > $1.timestamp
        }

        let safeOffset = max(0, offset)
        let safeLimit = max(1, min(100, limit))
        let page = Array(matches.dropFirst(safeOffset).prefix(safeLimit))
        stopwatch.stop()
        return LocalMessageSearchResponse(
            results: page,
            stats: LocalMessageSearchStats(
                totalResults: matches.count,
                searchTimeMilliseconds: Int(stopwatch.elapsedMilliseconds),
                query: normalizedQuery
            ),
            hasMore: safeOffset + page.count < matches.count
        )
    }

    private func searchableContent(for draft: RedCodeMessageDraft) -> String {
        let trimmed = draft.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        switch draft.messageType.lowercased() {
        case "image":
            return "[图片]"
        case "video":
            return "[视频]"
        case "audio":
            return "[语音]"
        case "file":
            return "[文件]"
        case "mixed":
            return "[多媒体消息]"
        case "system":
            return "[系统消息]"
        default:
            return "[消息]"
        }
    }

    private func makeSnippet(content: String, query: String) -> String? {
        guard let range = content.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return nil
        }
        let lower = content.index(range.lowerBound, offsetBy: -12, limitedBy: content.startIndex) ?? content.startIndex
        let upper = content.index(range.upperBound, offsetBy: 12, limitedBy: content.endIndex) ?? content.endIndex
        return String(content[lower..<upper])
    }
}

private final class Stopwatch {
    private var startTime: DispatchTime?
    private(set) var elapsedMilliseconds = 0

    func start() {
        startTime = DispatchTime.now()
    }

    func stop() {
        guard let startTime else {
            return
        }
        elapsedMilliseconds = Int((DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000)
    }
}
