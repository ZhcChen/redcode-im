import XCTest
@testable import RedCodeNetworking

final class RoomAPIClientTests: XCTestCase {
    func testCreateGroupPostsBackendPayloadAndDecodesRoomEnvelope() async throws {
        let transport = MockRoomHTTPTransport(
            data: Data(
                """
                {
                  "room": {
                    "id": "room-1",
                    "name": "interop",
                    "description": "smoke",
                    "room_type": "group",
                    "owner_id": "user-1",
                    "avatar_url": "https://cdn.example.test/room.png",
                    "avatar_object_key": "rooms/room-1/avatar.png"
                  }
                }
                """.utf8
            ),
            statusCode: 200
        )
        let client = RoomAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let room = try await client.createGroup(
            name: " interop ",
            description: " smoke ",
            memberIDs: [" member-1 ", "", "member-2"],
            token: "access-token"
        )

        let recordedRequest = await transport.recordedLastRequest()
        let request = try XCTUnwrap(recordedRequest)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8010/rooms")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertEqual(json["name"] as? String, "interop")
        XCTAssertEqual(json["description"] as? String, "smoke")
        XCTAssertEqual(json["room_type"] as? String, "group")
        XCTAssertEqual(json["member_ids"] as? [String], ["member-1", "member-2"])
        XCTAssertEqual(room.id, "room-1")
        XCTAssertEqual(room.roomType, "group")
        XCTAssertEqual(room.ownerID, "user-1")
        XCTAssertEqual(room.avatarObjectKey, "rooms/room-1/avatar.png")
    }

    func testUpdateRoomUsesPatchAndDecodesRoomEnvelope() async throws {
        let transport = MockRoomHTTPTransport(
            data: Data(
                """
                {
                  "success": true,
                  "message": "ok",
                  "room": {
                    "id": "room-1",
                    "name": "Renamed",
                    "description": "new",
                    "room_type": "group",
                    "owner_id": "user-1"
                  }
                }
                """.utf8
            ),
            statusCode: 200
        )
        let client = RoomAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let room = try await client.updateRoom(
            roomID: "room-1",
            name: " Renamed ",
            description: " new ",
            token: "access-token"
        )

        let recordedRequest = await transport.recordedLastRequest()
        let request = try XCTUnwrap(recordedRequest)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8010/rooms/room-1")
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(json["name"] as? String, "Renamed")
        XCTAssertEqual(json["description"] as? String, "new")
        XCTAssertEqual(room.name, "Renamed")
    }

    func testMembersSettingsAndManagementEndpointsUseBackendContract() async throws {
        let transport = MockRoomHTTPTransport(
            data: Data(
                """
                {
                  "settings": {
                    "room_id": "room-1",
                    "join_approval_required": true,
                    "member_can_invite": false,
                    "member_can_add_friends": true,
                    "require_admin_to_add_friends": false,
                    "max_members": 200,
                    "global_mute_enabled": true,
                    "global_mute_reason": "quiet"
                  },
                  "my_mute": {
                    "is_muted": false
                  }
                }
                """.utf8
            ),
            statusCode: 200
        )
        let client = RoomAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let snapshot = try await client.fetchGroupSettings(roomID: "room-1", token: "access-token")

        let recordedRequest = await transport.recordedLastRequest()
        let request = try XCTUnwrap(recordedRequest)
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8010/rooms/room-1/settings")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(snapshot.settings.roomID, "room-1")
        XCTAssertTrue(snapshot.settings.joinApprovalRequired)
        XCTAssertFalse(snapshot.settings.memberCanInvite)
        XCTAssertEqual(snapshot.settings.maxMembers, 200)
        XCTAssertEqual(snapshot.settings.globalMuteReason, "quiet")
        XCTAssertEqual(snapshot.myMute?.isMuted, false)
    }

    func testAddMembersPostsNormalizedIDsAndDecodesResult() async throws {
        let transport = MockRoomHTTPTransport(
            data: Data(
                """
                {
                  "success": true,
                  "added_user_ids": ["user-1", "user-2"],
                  "skipped_user_ids": ["user-3"]
                }
                """.utf8
            ),
            statusCode: 200
        )
        let client = RoomAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let result = try await client.addMembers(
            roomID: "room-1",
            userIDs: [" user-1 ", "user-2", "user-1", ""],
            token: "access-token"
        )

        let recordedRequest = await transport.recordedLastRequest()
        let request = try XCTUnwrap(recordedRequest)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8010/rooms/room-1/members/add")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(json["user_ids"] as? [String], ["user-1", "user-2"])
        XCTAssertEqual(result.addedUserIDs, ["user-1", "user-2"])
        XCTAssertEqual(result.skippedUserIDs, ["user-3"])
    }

    func testRoomPinNotificationAndOperationLogEndpoints() async throws {
        let pinTransport = MockRoomHTTPTransport(data: Data(#"{"is_pinned":true}"#.utf8), statusCode: 200)
        let pinClient = RoomAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: pinTransport)
        )

        try await pinClient.setRoomPinned(roomID: "room-1", pinned: true, token: "access-token")

        let recordedPinRequest = await pinTransport.recordedLastRequest()
        let pinRequest = try XCTUnwrap(recordedPinRequest)
        XCTAssertEqual(pinRequest.url?.absoluteString, "http://127.0.0.1:8010/rooms/room-1/pin")
        XCTAssertEqual(pinRequest.httpMethod, "POST")

        let muteTransport = MockRoomHTTPTransport(data: Data(#"{"notification_settings":2}"#.utf8), statusCode: 200)
        let muteClient = RoomAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: muteTransport)
        )
        try await muteClient.updateNotificationSettings(roomID: "room-1", notificationSettings: 2, token: "access-token")
        let recordedMuteRequest = await muteTransport.recordedLastRequest()
        let muteRequest = try XCTUnwrap(recordedMuteRequest)
        let muteBody = try XCTUnwrap(muteRequest.httpBody)
        let muteJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: muteBody) as? [String: Any])
        XCTAssertEqual(muteRequest.url?.absoluteString, "http://127.0.0.1:8010/rooms/room-1/notification-settings")
        XCTAssertEqual(muteJSON["notification_settings"] as? Int, 2)

        let logsTransport = MockRoomHTTPTransport(
            data: Data(
                """
                {
                  "logs": [
                    {
                      "id": "log-1",
                      "room_id": "room-1",
                      "operator_id": "user-1",
                      "operation_type": "update_group_settings",
                      "operation_data": {"max_members": 200},
                      "created_at": "2026-07-04T00:00:00Z"
                    }
                  ],
                  "total": 1
                }
                """.utf8
            ),
            statusCode: 200
        )
        let logsClient = RoomAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: logsTransport)
        )
        let logs = try await logsClient.listOperationLogs(roomID: "room-1", limit: 10, offset: 5, token: "access-token")
        let recordedLogsRequest = await logsTransport.recordedLastRequest()
        let logsRequest = try XCTUnwrap(recordedLogsRequest)
        XCTAssertEqual(logsRequest.url?.absoluteString, "http://127.0.0.1:8010/rooms/room-1/operation-logs?limit=10&offset=5")
        XCTAssertEqual(logs.map(\.operationType), ["update_group_settings"])
    }
}

private actor MockRoomHTTPTransport: HTTPTransport {
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
