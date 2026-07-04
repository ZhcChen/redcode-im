import XCTest
@testable import RedCodeCore
@testable import RedCodeFeatures
@testable import RedCodeNetworking
@testable import RedCodeStorage

@MainActor
final class ContactsControllerTests: XCTestCase {
    func testRefreshContactsPersistsRemoteContactsAndPendingBadge() async throws {
        let cache = SwiftDataContactCacheStore(
            container: try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        )
        try cache.saveContacts([
            RedCodeContactDraft(userID: "cached", username: "cached-user")
        ])
        let api = MockFriendAPIService(
            friends: [
                FriendInfo(
                    id: "friendship-1",
                    user: AuthUser(id: "user-2", username: "bob", nickname: "Bob"),
                    createdAt: Date(timeIntervalSince1970: 200)
                ),
            ],
            incomingRequests: [
                FriendRequestInfo(
                    id: "request-1",
                    requester: AuthUser(id: "user-3", username: "alice", nickname: "Alice"),
                    addressee: AuthUser(id: "me", username: "me"),
                    status: .pending,
                    isIncoming: true
                ),
            ]
        )
        let controller = ContactsController(api: api, cacheStore: cache)

        try await controller.refreshContacts(token: "access-token")

        XCTAssertEqual(controller.contacts.map(\.userID), ["user-2"])
        XCTAssertEqual(controller.contacts.first?.displayName, "Bob")
        XCTAssertEqual(controller.pendingIncomingCount, 1)
        XCTAssertEqual(try cache.loadContacts().map(\.userID), ["user-2"])
        XCTAssertFalse(controller.isLoading)
        XCTAssertNil(controller.errorMessage)
        let calls = await api.calls
        XCTAssertEqual(calls, [
            .fetchFriends(token: "access-token"),
            .fetchFriendRequests(direction: "incoming", status: "pending", token: "access-token"),
        ])
    }

    func testEnsurePrivateChatBuildsChatSummary() async throws {
        let cache = SwiftDataContactCacheStore(
            container: try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        )
        let api = MockFriendAPIService(
            ensureResult: EnsurePrivateChatResult(
                roomID: "room-1",
                roomName: "Bob",
                friendID: "user-2",
                friendName: "Bob",
                friendAvatarObjectKey: "users/user-2/avatar.png"
            )
        )
        let controller = ContactsController(api: api, cacheStore: cache)

        let chat = try await controller.ensurePrivateChat(
            contact: ContactSummary(userID: "user-2", username: "bob", nickname: "Bob"),
            token: "access-token"
        )

        XCTAssertEqual(chat.roomID, "room-1")
        XCTAssertEqual(chat.displayName, "Bob")
        XCTAssertEqual(chat.friendUserID, "user-2")
        XCTAssertEqual(chat.avatarObjectKey, "users/user-2/avatar.png")
        let calls = await api.calls
        XCTAssertEqual(calls, [.ensurePrivateChat(friendUserID: "user-2", token: "access-token")])
    }

    func testDeleteContactRollsBackWhenAPIRequestFails() async throws {
        let cache = SwiftDataContactCacheStore(
            container: try RedCodeStorageSchema.makeModelContainer(inMemory: true)
        )
        try cache.saveContacts([
            RedCodeContactDraft(userID: "user-2", username: "bob", nickname: "Bob")
        ])
        let api = MockFriendAPIService(deleteError: TestFailure.deleteFailed)
        let controller = ContactsController(api: api, cacheStore: cache)
        try controller.loadCachedContacts()

        do {
            try await controller.deleteContact(userID: "user-2", token: "access-token")
            XCTFail("Expected delete failure")
        } catch TestFailure.deleteFailed {
            // expected
        }

        XCTAssertEqual(controller.contacts.map(\.userID), ["user-2"])
        XCTAssertEqual(try cache.loadContacts().map(\.userID), ["user-2"])
        XCTAssertNotNil(controller.errorMessage)
    }

    func testAddFriendControllerSearchesSendsAndResponds() async throws {
        let alice = AuthUser(id: "user-3", username: "alice", nickname: "Alice")
        let me = AuthUser(id: "me", username: "me")
        let request = FriendRequestInfo(
            id: "request-1",
            requester: alice,
            addressee: me,
            status: .pending,
            message: "hi",
            isIncoming: true
        )
        let api = MockFriendAPIService(
            searchResults: [alice],
            incomingRequests: [request],
            outgoingRequests: [
                FriendRequestInfo(
                    id: "request-out",
                    requester: me,
                    addressee: alice,
                    status: .pending
                ),
            ],
            sentRequest: request,
            respondedRequest: FriendRequestInfo(
                id: "request-1",
                requester: alice,
                addressee: me,
                status: .accepted,
                respondedAt: Date(),
                isIncoming: true
            )
        )
        let controller = AddFriendController(api: api)

        try await controller.searchUsers(keyword: " alice ", token: "access-token")
        try await controller.loadRequests(token: "access-token")
        _ = try await controller.sendFriendRequest(
            targetUserID: "user-3",
            message: " hello ",
            token: "access-token"
        )
        let responded = try await controller.respondRequest(
            requestID: "request-1",
            action: .accept,
            token: "access-token"
        )

        XCTAssertEqual(controller.searchResults.map(\.id), ["user-3"])
        XCTAssertEqual(controller.incomingRequests.map(\.id), [])
        XCTAssertEqual(controller.outgoingRequests.map(\.id), ["request-1", "request-out"])
        XCTAssertEqual(responded.status, .accepted)
        let calls = await api.calls
        XCTAssertEqual(calls, [
            .searchUsers(keyword: "alice", limit: 20, token: "access-token"),
            .fetchFriendRequests(direction: "incoming", status: "pending", token: "access-token"),
            .fetchFriendRequests(direction: "outgoing", status: "pending", token: "access-token"),
            .sendFriendRequest(targetUserID: "user-3", message: " hello ", token: "access-token"),
            .respondFriendRequest(requestID: "request-1", action: .accept, token: "access-token"),
        ])
    }
}

private enum FriendAPICall: Equatable, Sendable {
    case searchUsers(keyword: String, limit: Int, token: String)
    case fetchFriends(token: String)
    case sendFriendRequest(targetUserID: String, message: String?, token: String)
    case fetchFriendRequests(direction: String?, status: String?, token: String)
    case respondFriendRequest(requestID: String, action: FriendRequestAction, token: String)
    case ensurePrivateChat(friendUserID: String, token: String)
    case deleteFriend(friendUserID: String, token: String)
}

private enum TestFailure: Error {
    case deleteFailed
}

private actor MockFriendAPIService: FriendAPIService {
    private(set) var calls: [FriendAPICall] = []

    private let searchResults: [AuthUser]
    private let friends: [FriendInfo]
    private let incomingRequests: [FriendRequestInfo]
    private let outgoingRequests: [FriendRequestInfo]
    private let sentRequest: FriendRequestInfo?
    private let respondedRequest: FriendRequestInfo?
    private let ensureResult: EnsurePrivateChatResult
    private let deleteError: Error?

    init(
        searchResults: [AuthUser] = [],
        friends: [FriendInfo] = [],
        incomingRequests: [FriendRequestInfo] = [],
        outgoingRequests: [FriendRequestInfo] = [],
        sentRequest: FriendRequestInfo? = nil,
        respondedRequest: FriendRequestInfo? = nil,
        ensureResult: EnsurePrivateChatResult = EnsurePrivateChatResult(
            roomID: "room-default",
            roomName: "Default",
            friendID: "friend-default",
            friendName: "Default"
        ),
        deleteError: Error? = nil
    ) {
        self.searchResults = searchResults
        self.friends = friends
        self.incomingRequests = incomingRequests
        self.outgoingRequests = outgoingRequests
        self.sentRequest = sentRequest
        self.respondedRequest = respondedRequest
        self.ensureResult = ensureResult
        self.deleteError = deleteError
    }

    func searchUsers(keyword: String, limit: Int, token: String) async throws -> [AuthUser] {
        calls.append(.searchUsers(keyword: keyword, limit: limit, token: token))
        return searchResults
    }

    func fetchFriends(token: String) async throws -> [FriendInfo] {
        calls.append(.fetchFriends(token: token))
        return friends
    }

    func sendFriendRequest(targetUserID: String, message: String?, token: String) async throws -> FriendRequestInfo {
        calls.append(.sendFriendRequest(targetUserID: targetUserID, message: message, token: token))
        return sentRequest ?? FriendRequestInfo(
            id: "sent",
            requester: AuthUser(id: "me", username: "me"),
            addressee: AuthUser(id: targetUserID, username: targetUserID),
            status: .pending
        )
    }

    func fetchFriendRequests(direction: String?, status: String?, token: String) async throws -> [FriendRequestInfo] {
        calls.append(.fetchFriendRequests(direction: direction, status: status, token: token))
        if direction == "outgoing" {
            return outgoingRequests
        }
        return incomingRequests
    }

    func respondFriendRequest(
        requestID: String,
        action: FriendRequestAction,
        token: String
    ) async throws -> FriendRequestInfo {
        calls.append(.respondFriendRequest(requestID: requestID, action: action, token: token))
        return respondedRequest ?? FriendRequestInfo(
            id: requestID,
            requester: AuthUser(id: "other", username: "other"),
            addressee: AuthUser(id: "me", username: "me"),
            status: action == .accept ? .accepted : .declined,
            isIncoming: true
        )
    }

    func ensurePrivateChat(friendUserID: String, token: String) async throws -> EnsurePrivateChatResult {
        calls.append(.ensurePrivateChat(friendUserID: friendUserID, token: token))
        return ensureResult
    }

    func deleteFriend(friendUserID: String, token: String) async throws {
        calls.append(.deleteFriend(friendUserID: friendUserID, token: token))
        if let deleteError {
            throw deleteError
        }
    }
}
