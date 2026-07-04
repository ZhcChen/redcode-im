import XCTest
@testable import RedCodeCore
@testable import RedCodeNetworking

final class EmojiAPIClientTests: XCTestCase {
    func testFetchMyPacksHydratesItemsAndUsesBackendRoute() async throws {
        let transport = QueueEmojiHTTPTransport(responses: [
            .json(
                """
                [
                  {
                    "pack": {
                      "id": "pack-1",
                      "name": "RedCode",
                      "icon_url": "https://cdn.example.test/icon.png",
                      "icon_object_key": "emoji-packs/icons/redcode.png",
                      "description": "built in",
                      "is_active": true,
                      "pack_type": 0,
                      "created_at": "2026-07-04T10:00:00Z",
                      "updated_at": "2026-07-04T10:00:00Z"
                    },
                    "items": [
                      {
                        "id": "item-2",
                        "pack_id": "pack-1",
                        "image_url": "",
                        "image_object_key": "emoji-items/two.gif",
                        "name": "two",
                        "sort_order": 2,
                        "created_at": "2026-07-04T10:00:02Z"
                      },
                      {
                        "id": "item-1",
                        "pack_id": "pack-1",
                        "image_url": "",
                        "image_object_key": "emoji-items/one.gif",
                        "name": "one",
                        "sort_order": 1,
                        "created_at": "2026-07-04T10:00:01Z"
                      }
                    ]
                  }
                ]
                """
            ),
        ])
        let client = EmojiAPIClient(apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport))

        let packs = try await client.fetchMyPacks(token: "access-token")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.map(\.httpMethod), ["GET"])
        XCTAssertEqual(requests.first?.url?.absoluteString, "http://127.0.0.1:8010/emoji-packs/my")
        XCTAssertEqual(requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertEqual(packs.map(\.id), ["pack-1"])
        XCTAssertEqual(packs.first?.iconObjectKey, "emoji-packs/icons/redcode.png")
        XCTAssertEqual(packs.first?.items.map(\.id), ["item-1", "item-2"])
        XCTAssertEqual(packs.first?.items.first?.imageObjectKey, "emoji-items/one.gif")
    }

    func testAvailableSearchActionsSuiteAndDownloadURLUseBackendContracts() async throws {
        let transport = QueueEmojiHTTPTransport(responses: [
            .json(
                """
                [
                  {
                    "id": "pack-2",
                    "name": "Available",
                    "icon_url": null,
                    "description": null,
                    "is_active": true,
                    "pack_type": 1,
                    "parent_id": null,
                    "created_at": "2026-07-04T10:00:00Z",
                    "updated_at": "2026-07-04T10:00:00Z"
                  }
                ]
                """
            ),
            .json(
                """
                [
                  {
                    "id": "pack-3",
                    "name": "Smile",
                    "icon_url": null,
                    "description": "search result",
                    "is_active": true,
                    "pack_type": 0,
                    "parent_id": "pack-2",
                    "created_at": "2026-07-04T10:00:00Z",
                    "updated_at": "2026-07-04T10:00:00Z"
                  }
                ]
                """
            ),
            .json(#"{"success":true,"message":"添加成功"}"#),
            .json(#"{"success":true,"message":"删除成功"}"#),
            .json(#"{"success":true,"message":"成功添加 2 个贴纸","count":2}"#),
            .json(
                """
                [
                  {
                    "pack": {
                      "id": "pack-3",
                      "name": "Smile",
                      "icon_url": null,
                      "description": null,
                      "is_active": true,
                      "pack_type": 0,
                      "parent_id": "pack-2",
                      "created_at": "2026-07-04T10:00:00Z",
                      "updated_at": "2026-07-04T10:00:00Z"
                    },
                    "items": []
                  }
                ]
                """
            ),
            .json(
                """
                {
                  "success": true,
                  "message": "ok",
                  "download_url": "http://127.0.0.1:19080/mock-bucket/emoji-items/smile.gif"
                }
                """
            ),
        ])
        let client = EmojiAPIClient(apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport))

        let available = try await client.fetchAvailablePacks(token: "access-token")
        let search = try await client.searchPacks(keyword: " smile ", token: "access-token")
        try await client.addPack(packID: "pack-3", token: "access-token")
        try await client.removePack(packID: "pack-3", token: "access-token")
        let addedCount = try await client.addSuite(suiteID: "pack-2", token: "access-token")
        let suitePacks = try await client.fetchSuitePacks(suiteID: "pack-2", token: "access-token")
        let downloadURL = try await client.emojiDownloadURL(
            objectKey: "emoji-items/smile.gif",
            token: "access-token",
            expiresInSeconds: 600
        )

        XCTAssertEqual(available.first?.packType, .suite)
        XCTAssertEqual(search.map(\.id), ["pack-3"])
        XCTAssertEqual(addedCount, 2)
        XCTAssertEqual(suitePacks.map(\.id), ["pack-3"])
        XCTAssertEqual(downloadURL?.absoluteString, "http://127.0.0.1:19080/mock-bucket/emoji-items/smile.gif")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.map(\.httpMethod), ["GET", "GET", "POST", "DELETE", "POST", "GET", "GET"])
        XCTAssertEqual(requests[0].url?.absoluteString, "http://127.0.0.1:8010/emoji-packs/available")
        XCTAssertEqual(requests[1].url?.absoluteString, "http://127.0.0.1:8010/emoji-packs/search?keyword=smile")
        XCTAssertEqual(requests[2].url?.absoluteString, "http://127.0.0.1:8010/emoji-packs/pack-3/add")
        XCTAssertEqual(requests[3].url?.absoluteString, "http://127.0.0.1:8010/emoji-packs/pack-3/remove")
        XCTAssertEqual(requests[4].url?.absoluteString, "http://127.0.0.1:8010/emoji-packs/suites/pack-2/add")
        XCTAssertEqual(requests[5].url?.absoluteString, "http://127.0.0.1:8010/emoji-packs/suites/pack-2/packs")
        XCTAssertEqual(
            requests[6].url?.absoluteString,
            "http://127.0.0.1:8010/emoji-packs/download-url?object_key=emoji-items/smile.gif&expires_in_seconds=600"
        )
    }

    func testSearchPacksSkipsBlankKeyword() async throws {
        let transport = QueueEmojiHTTPTransport(responses: [])
        let client = EmojiAPIClient(apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport))

        let results = try await client.searchPacks(keyword: "  \n ", token: "access-token")

        XCTAssertTrue(results.isEmpty)
        let requests = await transport.recordedRequests()
        XCTAssertTrue(requests.isEmpty)
    }
}

private actor QueueEmojiHTTPTransport: HTTPTransport {
    struct Response: Sendable {
        let data: Data
        let statusCode: Int

        static func json(_ value: String, statusCode: Int = 200) -> Response {
            Response(data: Data(value.utf8), statusCode: statusCode)
        }

        static func empty(statusCode: Int = 204) -> Response {
            Response(data: Data(), statusCode: statusCode)
        }
    }

    private var responses: [Response]
    private var requests: [URLRequest] = []

    init(responses: [Response]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let response = responses.isEmpty ? .empty() : responses.removeFirst()
        return (
            response.data,
            HTTPURLResponse(
                url: request.url!,
                statusCode: response.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: [:]
            )!
        )
    }

    func recordedRequests() -> [URLRequest] {
        requests
    }
}
