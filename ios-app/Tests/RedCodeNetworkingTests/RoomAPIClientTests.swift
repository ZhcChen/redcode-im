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
