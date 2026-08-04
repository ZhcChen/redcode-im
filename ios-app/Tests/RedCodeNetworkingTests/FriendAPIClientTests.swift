import XCTest
@testable import RedCodeNetworking

final class FriendAPIClientTests: XCTestCase {
    func testSearchUsersBuildsQueryAndAuthHeader() async throws {
        let transport = MockFriendHTTPTransport(
            data: Data(
                """
                [
                  {
                    "id": "user-2",
                    "username": "bob",
                    "email": "bob@example.test",
                    "nickname": "Bob",
                    "avatar_object_key": "users/user-2/avatar.png",
                    "status": "active"
                  }
                ]
                """.utf8
            ),
            statusCode: 200
        )
        let client = FriendAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let users = try await client.searchUsers(keyword: " bob ", limit: 10, token: "access-token")

        let recordedRequest = await transport.recordedLastRequest()
        let request = try XCTUnwrap(recordedRequest)
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8010/users/search?keyword=bob&limit=10")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertEqual(users.map(\.id), ["user-2"])
        XCTAssertEqual(users.first?.displayName, "Bob")
        XCTAssertEqual(users.first?.avatarObjectKey, "users/user-2/avatar.png")
    }

    func testSearchUsersSkipsBlankKeyword() async throws {
        let transport = MockFriendHTTPTransport(data: Data("[]".utf8), statusCode: 200)
        let client = FriendAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let users = try await client.searchUsers(keyword: "   ", token: "access-token")
        let recordedRequest = await transport.recordedLastRequest()

        XCTAssertTrue(users.isEmpty)
        XCTAssertNil(recordedRequest)
    }

    func testFetchFriendsDecodesBackendShapeAndSortsByDisplayName() async throws {
        let transport = MockFriendHTTPTransport(
            data: Data(
                """
                [
                  {
                    "id": "friendship-2",
                    "user": {
                      "id": "user-2",
                      "username": "bob",
                      "email": "bob@example.test",
                      "nickname": null,
                      "avatar_url": "https://cdn.example.test/bob.png",
                      "avatar_object_key": "users/user-2/avatar.png",
                      "status": "active"
                    },
                    "created_at": "2026-07-04T10:00:00.123Z",
                    "friend_remark": null
                  },
                  {
                    "id": "friendship-1",
                    "user": {
                      "id": "user-1",
                      "username": "alice",
                      "email": "alice@example.test",
                      "nickname": "Alice",
                      "avatar_url": null,
                      "avatar_object_key": null,
                      "status": "active"
                    },
                    "created_at": "2026-07-04T09:00:00Z",
                    "friend_remark": "A Friend"
                  }
                ]
                """.utf8
            ),
            statusCode: 200
        )
        let client = FriendAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let friends = try await client.fetchFriends(token: "access-token")

        let recordedRequest = await transport.recordedLastRequest()
        let request = try XCTUnwrap(recordedRequest)
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8010/friends")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(friends.map(\.id), ["friendship-1", "friendship-2"])
        XCTAssertEqual(friends[0].displayName, "A Friend")
        XCTAssertEqual(friends[0].remark, "A Friend")
        XCTAssertNotNil(friends[0].createdAt)
        XCTAssertEqual(friends[1].displayName, "bob")
        XCTAssertEqual(friends[1].user.avatarObjectKey, "users/user-2/avatar.png")
    }

    func testSendFriendRequestTrimsPayloadAndDecodesRequest() async throws {
        let transport = MockFriendHTTPTransport(
            data: Data(friendRequestResponseJSON(status: "pending", isIncoming: false).utf8),
            statusCode: 200
        )
        let client = FriendAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let requestInfo = try await client.sendFriendRequest(
            targetUserID: " user-2 ",
            message: " hello ",
            token: "access-token"
        )

        let recordedRequest = await transport.recordedLastRequest()
        let request = try XCTUnwrap(recordedRequest)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8010/friends/requests")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(json["target_user_id"], "user-2")
        XCTAssertEqual(json["message"], "hello")
        XCTAssertEqual(requestInfo.id, "request-1")
        XCTAssertEqual(requestInfo.status, .pending)
        XCTAssertEqual(requestInfo.counterparty.id, "user-2")
    }

    func testFetchFriendRequestsBuildsQueryAndDecodesStatus() async throws {
        let transport = MockFriendHTTPTransport(
            data: Data("[\(friendRequestResponseJSON(status: "accepted", isIncoming: true))]".utf8),
            statusCode: 200
        )
        let client = FriendAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let requests = try await client.fetchFriendRequests(
            direction: "incoming",
            status: "accepted",
            token: "access-token"
        )

        let recordedRequest = await transport.recordedLastRequest()
        let request = try XCTUnwrap(recordedRequest)
        XCTAssertEqual(
            request.url?.absoluteString,
            "http://127.0.0.1:8010/friends/requests?direction=incoming&status=accepted"
        )
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(requests.map(\.id), ["request-1"])
        XCTAssertEqual(requests.first?.status, .accepted)
        XCTAssertEqual(requests.first?.counterparty.id, "user-1")
        XCTAssertNotNil(requests.first?.respondedAt)
    }

    func testRespondFriendRequestUsesAcceptDeclinePayload() async throws {
        let transport = MockFriendHTTPTransport(
            data: Data(friendRequestResponseJSON(status: "declined", isIncoming: true).utf8),
            statusCode: 200
        )
        let client = FriendAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let requestInfo = try await client.respondFriendRequest(
            requestID: "request-1",
            action: .decline,
            token: "access-token"
        )

        let recordedRequest = await transport.recordedLastRequest()
        let request = try XCTUnwrap(recordedRequest)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8010/friends/requests/request-1/respond")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(json["action"], "decline")
        XCTAssertEqual(requestInfo.status, .declined)
    }

    func testEnsurePrivateChatPostsWithoutBodyAndDecodesResult() async throws {
        let transport = MockFriendHTTPTransport(
            data: Data(
                """
                {
                  "room_id": "room-1",
                  "room_name": "Bob",
                  "room_type": "private",
                  "friend_id": "user-2",
                  "friend_name": "Bob",
                  "friend_avatar": "https://cdn.example.test/bob.png",
                  "friend_avatar_object_key": "users/user-2/avatar.png"
                }
                """.utf8
            ),
            statusCode: 200
        )
        let client = FriendAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let result = try await client.ensurePrivateChat(friendUserID: "user-2", token: "access-token")

        let recordedRequest = await transport.recordedLastRequest()
        let request = try XCTUnwrap(recordedRequest)
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8010/friends/user-2/chat")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNil(request.httpBody)
        XCTAssertNil(request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertEqual(result.roomID, "room-1")
        XCTAssertEqual(result.roomType, .privateChat)
        XCTAssertEqual(result.friendAvatarObjectKey, "users/user-2/avatar.png")
    }

    func testDeleteFriendUsesBackendRoute() async throws {
        let transport = MockFriendHTTPTransport(
            data: Data(#"{"success":true,"message":"ok"}"#.utf8),
            statusCode: 200
        )
        let client = FriendAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        try await client.deleteFriend(friendUserID: "user-2", token: "access-token")

        let recordedRequest = await transport.recordedLastRequest()
        let request = try XCTUnwrap(recordedRequest)
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8010/friends/user-2")
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertNil(request.httpBody)
    }

    private func friendRequestResponseJSON(status: String, isIncoming: Bool) -> String {
        """
        {
          "id": "request-1",
          "requester": {
            "id": "user-1",
            "username": "alice",
            "email": "alice@example.test",
            "nickname": "Alice",
            "avatar_url": null,
            "avatar_object_key": null,
            "status": "active"
          },
          "addressee": {
            "id": "user-2",
            "username": "bob",
            "email": "bob@example.test",
            "nickname": "Bob",
            "avatar_url": null,
            "avatar_object_key": "users/user-2/avatar.png",
            "status": "active"
          },
          "status": "\(status)",
          "message": "hello",
          "created_at": "2026-07-04T10:00:00Z",
          "responded_at": "2026-07-04T10:01:00Z",
          "is_incoming": \(isIncoming)
        }
        """
    }
}

private actor MockFriendHTTPTransport: HTTPTransport {
    private let data: Data
    private let statusCode: Int
    private(set) var lastRequest: URLRequest?

    init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: [:]
        )!
        return (data, response)
    }

    func recordedLastRequest() -> URLRequest? {
        lastRequest
    }
}
