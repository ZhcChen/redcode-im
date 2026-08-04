import Foundation
import RedCodeCore

public protocol FriendAPIService: Sendable {
    func searchUsers(keyword: String, limit: Int, token: String) async throws -> [AuthUser]
    func fetchFriends(token: String) async throws -> [FriendInfo]
    func sendFriendRequest(targetUserID: String, message: String?, token: String) async throws -> FriendRequestInfo
    func fetchFriendRequests(direction: String?, status: String?, token: String) async throws -> [FriendRequestInfo]
    func respondFriendRequest(requestID: String, action: FriendRequestAction, token: String) async throws -> FriendRequestInfo
    func ensurePrivateChat(friendUserID: String, token: String) async throws -> EnsurePrivateChatResult
    func deleteFriend(friendUserID: String, token: String) async throws
}

public struct FriendAPIClient: FriendAPIService {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public init(environment: RedCodeEnvironment) {
        self.apiClient = APIClient(environment: environment)
    }

    public func searchUsers(keyword: String, limit: Int = 20, token: String) async throws -> [AuthUser] {
        let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKeyword.isEmpty else {
            return []
        }
        return try await apiClient.get(
            FriendAPIEndpoint.searchUsers(keyword: normalizedKeyword, limit: limit),
            bearerToken: token,
            as: [AuthUser].self
        )
    }

    public func fetchFriends(token: String) async throws -> [FriendInfo] {
        try await apiClient.get(
            FriendAPIEndpoint.friends,
            bearerToken: token,
            as: [FriendInfo].self
        )
        .sortedForContacts()
    }

    public func sendFriendRequest(
        targetUserID: String,
        message: String? = nil,
        token: String
    ) async throws -> FriendRequestInfo {
        try await apiClient.post(
            FriendAPIEndpoint.createFriendRequest,
            body: CreateFriendRequestPayload(targetUserID: targetUserID, message: message),
            bearerToken: token,
            as: FriendRequestInfo.self
        )
    }

    public func fetchFriendRequests(
        direction: String? = nil,
        status: String? = nil,
        token: String
    ) async throws -> [FriendRequestInfo] {
        try await apiClient.get(
            FriendAPIEndpoint.friendRequests(direction: direction, status: status),
            bearerToken: token,
            as: [FriendRequestInfo].self
        )
    }

    public func respondFriendRequest(
        requestID: String,
        action: FriendRequestAction,
        token: String
    ) async throws -> FriendRequestInfo {
        try await apiClient.post(
            FriendAPIEndpoint.respondFriendRequest(requestID: requestID),
            body: RespondFriendRequestPayload(action: action),
            bearerToken: token,
            as: FriendRequestInfo.self
        )
    }

    public func ensurePrivateChat(friendUserID: String, token: String) async throws -> EnsurePrivateChatResult {
        try await apiClient.post(
            FriendAPIEndpoint.ensurePrivateChat(friendUserID: friendUserID),
            bearerToken: token,
            as: EnsurePrivateChatResult.self
        )
    }

    public func deleteFriend(friendUserID: String, token: String) async throws {
        try await apiClient.deleteNoResponse(
            FriendAPIEndpoint.deleteFriend(friendUserID: friendUserID),
            bearerToken: token
        )
    }
}

private extension Array where Element == FriendInfo {
    func sortedForContacts() -> [FriendInfo] {
        sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }
}
