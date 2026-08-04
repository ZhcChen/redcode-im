import Foundation
import Combine
import RedCodeCore
import RedCodeNetworking
import RedCodeStorage

public struct ContactSummary: Equatable, Identifiable, Sendable {
    public var id: String { userID }

    public let userID: String
    public let username: String
    public let nickname: String?
    public let avatarURL: String?
    public let avatarObjectKey: String?
    public let friendshipStatus: String
    public let updatedAt: Date

    public init(
        userID: String,
        username: String,
        nickname: String? = nil,
        avatarURL: String? = nil,
        avatarObjectKey: String? = nil,
        friendshipStatus: String = "accepted",
        updatedAt: Date = Date()
    ) {
        self.userID = userID
        self.username = username
        self.nickname = nickname
        self.avatarURL = avatarURL
        self.avatarObjectKey = avatarObjectKey
        self.friendshipStatus = friendshipStatus
        self.updatedAt = updatedAt
    }

    public var displayName: String {
        if let nickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines), !nickname.isEmpty {
            return nickname
        }
        return username
    }
}

@MainActor
public final class ContactsController: ObservableObject {
    @Published public private(set) var contacts: [ContactSummary] = []
    @Published public private(set) var pendingIncomingCount = 0
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    private let api: any FriendAPIService
    private let cacheStore: any ContactCacheStore

    public init(
        api: any FriendAPIService,
        cacheStore: any ContactCacheStore
    ) {
        self.api = api
        self.cacheStore = cacheStore
    }

    public func loadCachedContacts() throws {
        contacts = try cacheStore.loadContacts().map(ContactSummary.init(cacheDraft:)).sortedForContacts()
    }

    public func refreshContacts(token: String) async throws {
        try await runThrowingLoadingOperation {
            let cached = try cacheStore.loadContacts().map(ContactSummary.init(cacheDraft:))
            if !cached.isEmpty {
                contacts = cached.sortedForContacts()
            }

            let remoteContacts = try await api.fetchFriends(token: token)
                .map(ContactSummary.init(friendInfo:))
                .sortedForContacts()
            contacts = remoteContacts
            try cacheStore.saveContacts(remoteContacts.map(\.cacheDraft))

            let requests = try await api.fetchFriendRequests(direction: "incoming", status: "pending", token: token)
            pendingIncomingCount = requests.count
        }
    }

    public func refreshIncomingRequestBadge(token: String) async throws {
        let requests = try await api.fetchFriendRequests(direction: "incoming", status: "pending", token: token)
        pendingIncomingCount = requests.count
    }

    public func ensurePrivateChat(contact: ContactSummary, token: String) async throws -> ChatSummary {
        do {
            let result = try await api.ensurePrivateChat(friendUserID: contact.userID, token: token)
            return ChatSummary(
                roomID: result.roomID,
                displayName: result.friendName,
                roomType: result.roomType,
                avatarURL: result.friendAvatarURL,
                avatarObjectKey: result.friendAvatarObjectKey,
                friendUserID: result.friendID
            )
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func deleteContact(userID: String, token: String) async throws {
        let previous = contacts
        contacts = contacts.filter { $0.userID != userID }
        try cacheStore.remove(userID: userID)

        do {
            try await api.deleteFriend(friendUserID: userID, token: token)
        } catch {
            contacts = previous
            try cacheStore.saveContacts(previous.map(\.cacheDraft))
            errorMessage = error.localizedDescription
            throw error
        }
    }

    private func runThrowingLoadingOperation(_ operation: () async throws -> Void) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

@MainActor
public final class AddFriendController: ObservableObject {
    @Published public private(set) var searchResults: [AuthUser] = []
    @Published public private(set) var incomingRequests: [FriendRequestInfo] = []
    @Published public private(set) var outgoingRequests: [FriendRequestInfo] = []
    @Published public private(set) var isSearching = false
    @Published public private(set) var isLoadingRequests = false
    @Published public private(set) var errorMessage: String?

    private let api: any FriendAPIService

    public init(api: any FriendAPIService) {
        self.api = api
    }

    public func searchUsers(keyword: String, token: String) async throws {
        let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKeyword.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            searchResults = try await api.searchUsers(keyword: normalizedKeyword, limit: 20, token: token)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func loadRequests(token: String) async throws {
        isLoadingRequests = true
        errorMessage = nil
        defer { isLoadingRequests = false }

        do {
            incomingRequests = try await api.fetchFriendRequests(
                direction: "incoming",
                status: "pending",
                token: token
            )
            outgoingRequests = try await api.fetchFriendRequests(
                direction: "outgoing",
                status: "pending",
                token: token
            )
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func sendFriendRequest(targetUserID: String, message: String?, token: String) async throws -> FriendRequestInfo {
        do {
            let request = try await api.sendFriendRequest(
                targetUserID: targetUserID,
                message: message,
                token: token
            )
            outgoingRequests = ([request] + outgoingRequests.filter { $0.id != request.id })
            return request
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func respondRequest(
        requestID: String,
        action: FriendRequestAction,
        token: String
    ) async throws -> FriendRequestInfo {
        do {
            let request = try await api.respondFriendRequest(requestID: requestID, action: action, token: token)
            incomingRequests = incomingRequests.filter { $0.id != requestID }
            return request
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

private extension ContactSummary {
    init(friendInfo: FriendInfo) {
        self.init(
            userID: friendInfo.user.id,
            username: friendInfo.user.username,
            nickname: friendInfo.displayName,
            avatarURL: friendInfo.user.avatarURL,
            avatarObjectKey: friendInfo.user.avatarObjectKey,
            friendshipStatus: "accepted",
            updatedAt: friendInfo.createdAt ?? Date()
        )
    }

    init(cacheDraft draft: RedCodeContactDraft) {
        self.init(
            userID: draft.userID,
            username: draft.username,
            nickname: draft.nickname,
            avatarURL: draft.avatarURL,
            avatarObjectKey: draft.avatarObjectKey,
            friendshipStatus: draft.friendshipStatus,
            updatedAt: draft.updatedAt
        )
    }

    var cacheDraft: RedCodeContactDraft {
        RedCodeContactDraft(
            userID: userID,
            username: username,
            nickname: nickname,
            avatarURL: avatarURL,
            avatarObjectKey: avatarObjectKey,
            friendshipStatus: friendshipStatus,
            updatedAt: updatedAt
        )
    }
}

private extension Array where Element == ContactSummary {
    func sortedForContacts() -> [ContactSummary] {
        sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }
}
