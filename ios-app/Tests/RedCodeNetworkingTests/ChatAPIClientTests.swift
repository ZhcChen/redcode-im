import XCTest
@testable import RedCodeNetworking

final class ChatAPIClientTests: XCTestCase {
    func testFetchChatsMapsBackendSummariesAndSortsPinnedFirst() async throws {
        let transport = MockChatHTTPTransport(
            data: Data(
                """
                [
                  {
                    "room_id": "r2",
                    "name": "private room",
                    "room_type": "private",
                    "friend_remark": "Bob",
                    "friend_avatar_object_key": "users/u2/avatar.png",
                    "unread_count": 0,
                    "is_pinned": false,
                    "is_muted": true
                  },
                  {
                    "room_id": "r1",
                    "name": "general",
                    "room_type": "group",
                    "avatar_url": "https://cdn.example.test/r1.png",
                    "room_avatar_object_key": "rooms/r1/avatar.png",
                    "unread_count": 3,
                    "is_pinned": true,
                    "is_muted": false,
                    "last_message": {
                      "id": "m1",
                      "content": "",
                      "message_type": "image",
                      "created_at": "2026-07-03T10:00:00Z",
                      "sender_id": "u1",
                      "sender_username": "alice"
                    }
                  }
                ]
                """.utf8
            ),
            statusCode: 200
        )
        let client = ChatAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let chats = try await client.fetchChats(token: "access-token")

        let recordedRequest = await transport.recordedLastRequest()
        let request = try XCTUnwrap(recordedRequest)
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8010/chats")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertEqual(chats.map(\.roomID), ["r1", "r2"])
        XCTAssertEqual(chats[0].displayName, "general")
        XCTAssertEqual(chats[0].roomType, .group)
        XCTAssertEqual(chats[0].avatarObjectKey, "rooms/r1/avatar.png")
        XCTAssertEqual(chats[0].lastMessagePreview, "[图片]")
        XCTAssertEqual(chats[0].unreadCount, 3)
        XCTAssertTrue(chats[0].isPinned)
        XCTAssertEqual(chats[1].displayName, "Bob")
        XCTAssertEqual(chats[1].avatarObjectKey, "users/u2/avatar.png")
        XCTAssertTrue(chats[1].isMuted)
    }

    func testLoadMessagesBuildsQueryAndMapsQuotesAndAttachments() async throws {
        let transport = MockChatHTTPTransport(
            data: Data(
                """
                [
                  {
                    "id": "m2",
                    "room_id": "r1",
                    "sender_id": "u2",
                    "sender_username": "alice",
                    "sender_nickname": "Alice",
                    "content": "world",
                    "message_type": "text",
                    "created_at": "2026-07-03T10:01:00Z"
                  },
                  {
                    "id": "m1",
                    "room_id": "r1",
                    "sender_id": "u1",
                    "sender_username": "bear",
                    "content": "hello",
                    "message_type": "image",
                    "status": "sent",
                    "created_at": "2026-07-03T10:00:00Z",
                    "is_pinned": true,
                    "pinned_at": "2026-07-03T10:02:00Z",
                    "pinned_by": "u2",
                    "quoted_message": {
                      "id": "q1",
                      "room_id": "r1",
                      "sender_id": "u2",
                      "sender_username": "alice",
                      "content": "quote",
                      "message_type": "text",
                      "created_at": "2026-07-03T09:59:00Z",
                      "is_deleted": false
                    },
                    "parts": [
                      {
                        "position": 0,
                        "part_type": "image",
                        "attachment": {
                          "key": "messages/r1/image.png",
                          "name": "image.png",
                          "mime": "image/png",
                          "size": 128,
                          "width": 32,
                          "height": 32,
                          "thumbnail_key": "messages/r1/thumb.png"
                        }
                      }
                    ],
                    "reactions": [
                      {
                        "reaction_key": "👍",
                        "count": 2,
                        "has_self": true
                      }
                    ]
                  }
                ]
                """.utf8
            ),
            statusCode: 200
        )
        let client = ChatAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let messages = try await client.loadMessages(
            roomID: "r1",
            token: "access-token",
            limit: 2,
            beforeID: "m0",
            sinceID: nil
        )

        let recordedRequest = await transport.recordedLastRequest()
        let request = try XCTUnwrap(recordedRequest)
        XCTAssertEqual(
            request.url?.absoluteString,
            "http://127.0.0.1:8010/rooms/r1/messages?limit=2&before_id=m0"
        )
        XCTAssertEqual(messages.map(\.id), ["m1", "m2"])
        XCTAssertEqual(messages[0].senderName, "bear")
        XCTAssertEqual(messages[0].messageType, .image)
        XCTAssertEqual(messages[0].status, .sent)
        XCTAssertTrue(messages[0].isPinned)
        XCTAssertEqual(messages[0].quotedMessage?.id, "q1")
        XCTAssertEqual(messages[0].attachments.first?.key, "messages/r1/image.png")
        XCTAssertEqual(messages[0].attachments.first?.mimeType, "image/png")
        XCTAssertEqual(messages[0].attachments.first?.thumbnailKey, "messages/r1/thumb.png")
        XCTAssertEqual(messages[0].reactions.first?.reactionKey, "👍")
        XCTAssertEqual(messages[0].reactions.first?.count, 2)
        XCTAssertEqual(messages[0].reactions.first?.hasSelf, true)
        XCTAssertEqual(messages[1].senderName, "Alice")
    }

    func testSendTextMessageTrimsContentAndDecodesMessageEnvelope() async throws {
        let transport = MockChatHTTPTransport(
            data: Data(
                """
                {
                  "message": {
                    "id": "m1",
                    "room_id": "r1",
                    "sender_id": "u1",
                    "sender_username": "bear",
                    "content": "hello",
                    "message_type": "text",
                    "created_at": "2026-07-03T10:00:00Z"
                  }
                }
                """.utf8
            ),
            statusCode: 200
        )
        let client = ChatAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let message = try await client.sendTextMessage(
            roomID: "r1",
            content: " hello ",
            quotedMessageID: " q1 ",
            token: "access-token"
        )

        let recordedRequest = await transport.recordedLastRequest()
        let request = try XCTUnwrap(recordedRequest)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8010/rooms/r1/messages")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(json["content"], "hello")
        XCTAssertEqual(json["quoted_message_id"], "q1")
        XCTAssertEqual(message.id, "m1")
        XCTAssertEqual(message.content, "hello")
    }

    func testSendRichMessagePostsPartsPayload() async throws {
        let transport = MockChatHTTPTransport(
            data: Data(
                """
                {
                  "message": {
                    "id": "m-media",
                    "room_id": "r1",
                    "sender_id": "u1",
                    "sender_username": "bear",
                    "content": "[图片]",
                    "message_type": "image",
                    "created_at": "2026-07-04T10:00:00Z",
                    "parts": [
                      {
                        "position": 0,
                        "part_type": "image",
                        "attachment": {
                          "key": "messages/r1/images_20260704/abc.png",
                          "name": "abc.png",
                          "mime": "image/png",
                          "size": 11
                        }
                      }
                    ]
                  }
                }
                """.utf8
            ),
            statusCode: 200
        )
        let client = ChatAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let message = try await client.sendRichMessage(
            roomID: "r1",
            parts: [
                .attachment(
                    type: .image,
                    key: "messages/r1/images_20260704/abc.png",
                    name: "abc.png",
                    mime: "image/png",
                    size: 11
                ),
            ],
            token: "access-token"
        )

        let recordedRequest = await transport.recordedLastRequest()
        let request = try XCTUnwrap(recordedRequest)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let parts = try XCTUnwrap(json["parts"] as? [[String: Any]])

        XCTAssertNil(json["content"])
        XCTAssertEqual(parts.first?["type"] as? String, "image")
        XCTAssertEqual(parts.first?["key"] as? String, "messages/r1/images_20260704/abc.png")
        XCTAssertEqual(parts.first?["mime"] as? String, "image/png")
        XCTAssertEqual(message.id, "m-media")
        XCTAssertEqual(message.messageType, .image)
        XCTAssertEqual(message.attachments.first?.key, "messages/r1/images_20260704/abc.png")
    }

    func testMarkMessagesAsReadPostsBackendPayload() async throws {
        let transport = MockChatHTTPTransport(
            data: Data(#"{"success":true,"message":"ok"}"#.utf8),
            statusCode: 200
        )
        let client = ChatAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        try await client.markMessagesAsRead(roomID: "r1", messageID: "m1", token: "access-token")

        let recordedRequest = await transport.recordedLastRequest()
        let request = try XCTUnwrap(recordedRequest)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8010/rooms/r1/messages/read")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(json["message_id"], "m1")
    }

    func testDeleteAndPinOperationsUseBackendRoutes() async throws {
        let deleteTransport = MockChatHTTPTransport(
            data: Data(#"{"success":true}"#.utf8),
            statusCode: 200
        )
        let deleteClient = ChatAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: deleteTransport)
        )

        try await deleteClient.deleteChat(roomID: "r1", token: "access-token")
        let recordedDeleteRequest = await deleteTransport.recordedLastRequest()
        var request = try XCTUnwrap(recordedDeleteRequest)
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8010/chats/r1")
        XCTAssertEqual(request.httpMethod, "DELETE")

        let pinTransport = MockChatHTTPTransport(
            data: Data(#"{"room_id":"r1","is_pinned":true}"#.utf8),
            statusCode: 200
        )
        let pinClient = ChatAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: pinTransport)
        )

        try await pinClient.setMessagePinned(
            roomID: "r1",
            messageID: "m1",
            pinned: true,
            token: "access-token"
        )
        let recordedPinRequest = await pinTransport.recordedLastRequest()
        request = try XCTUnwrap(recordedPinRequest)
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8010/rooms/r1/messages/m1/pin")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNil(request.httpBody)
    }

    func testReactionOperationsUseBackendRoutesAndDecodeSummaries() async throws {
        let addTransport = MockChatHTTPTransport(
            data: Data(
                """
                {
                  "success": true,
                  "message": "ok",
                  "summaries": [
                    {"reaction_key": "👍", "count": 3, "has_self": true}
                  ]
                }
                """.utf8
            ),
            statusCode: 200
        )
        let addClient = ChatAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: addTransport)
        )

        let added = try await addClient.addMessageReaction(
            roomID: "r1",
            messageID: "m1",
            reactionKey: "👍",
            token: "access-token"
        )

        var recordedRequest = await addTransport.recordedLastRequest()
        var request = try XCTUnwrap(recordedRequest)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8010/rooms/r1/messages/m1/reactions")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(json["reaction_key"], "👍")
        XCTAssertEqual(added, [MessageReactionSummary(reactionKey: "👍", count: 3, hasSelf: true)])

        let removeTransport = MockChatHTTPTransport(
            data: Data(#"{"success":true,"summaries":[]}"#.utf8),
            statusCode: 200
        )
        let removeClient = ChatAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: removeTransport)
        )

        let removed = try await removeClient.removeMessageReaction(
            roomID: "r1",
            messageID: "m1",
            reactionKey: "❤️",
            token: "access-token"
        )

        recordedRequest = await removeTransport.recordedLastRequest()
        request = try XCTUnwrap(recordedRequest)
        XCTAssertEqual(
            request.url?.absoluteString,
            "http://127.0.0.1:8010/rooms/r1/messages/m1/reactions?reaction_key=%E2%9D%A4%EF%B8%8F"
        )
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertTrue(removed.isEmpty)

        let fetchTransport = MockChatHTTPTransport(
            data: Data(#"{"success":true,"summaries":[{"reaction_key":"😂","count":1,"has_self":false}]}"#.utf8),
            statusCode: 200
        )
        let fetchClient = ChatAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: fetchTransport)
        )

        let fetched = try await fetchClient.fetchMessageReactions(
            roomID: "r1",
            messageID: "m1",
            token: "access-token"
        )

        recordedRequest = await fetchTransport.recordedLastRequest()
        request = try XCTUnwrap(recordedRequest)
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8010/rooms/r1/messages/m1/reactions")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(fetched, [MessageReactionSummary(reactionKey: "😂", count: 1, hasSelf: false)])
    }

    func testSearchMessagesBuildsQueryAndDecodesBackendResponse() async throws {
        let transport = MockChatHTTPTransport(
            data: Data(
                """
                {
                  "results": [
                    {
                      "id": "m1",
                      "room_id": "r1",
                      "room_name": "General",
                      "sender_id": "u1",
                      "sender_name": "Alice",
                      "content": "hello redcode",
                      "message_type": "text",
                      "timestamp": "2026-07-04T10:00:00Z",
                      "matched_text": "hello redcode",
                      "relevance_score": 1.0
                    }
                  ],
                  "stats": {
                    "total_results": 2,
                    "search_time_ms": 7,
                    "query": "redcode"
                  },
                  "has_more": true
                }
                """.utf8
            ),
            statusCode: 200
        )
        let client = ChatAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let response = try await client.searchMessages(
            query: " redcode ",
            roomID: "r1",
            messageType: .text,
            limit: 25,
            offset: 50,
            token: "access-token"
        )

        let recordedRequest = await transport.recordedLastRequest()
        let request = try XCTUnwrap(recordedRequest)
        XCTAssertEqual(
            request.url?.absoluteString,
            "http://127.0.0.1:8010/messages/search?query=redcode&limit=25&offset=50&room_id=r1&message_type=text"
        )
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertEqual(response.results.map(\.id), ["m1"])
        XCTAssertEqual(response.results.first?.roomName, "General")
        XCTAssertEqual(response.results.first?.messageType, .text)
        XCTAssertEqual(response.stats.totalResults, 2)
        XCTAssertEqual(response.stats.searchTimeMilliseconds, 7)
        XCTAssertTrue(response.hasMore)
    }

    func testSearchMessagesSkipsBlankQuery() async throws {
        let transport = MockChatHTTPTransport(data: Data(), statusCode: 200)
        let client = ChatAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let response = try await client.searchMessages(
            query: "  ",
            roomID: nil,
            messageType: nil,
            limit: 50,
            offset: 0,
            token: "access-token"
        )

        XCTAssertTrue(response.results.isEmpty)
        XCTAssertEqual(response.stats.query, "")
        XCTAssertFalse(response.hasMore)
        let recordedRequest = await transport.recordedLastRequest()
        XCTAssertNil(recordedRequest)
    }
}

private actor MockChatHTTPTransport: HTTPTransport {
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
