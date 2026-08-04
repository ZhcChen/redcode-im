import XCTest
@testable import RedCodeCore
@testable import RedCodeNetworking

final class MediaAPIClientTests: XCTestCase {
    func testMessageAttachmentUploadDownloadFlowUsesBackendContractAndDirectUpload() async throws {
        let apiTransport = QueueMediaHTTPTransport(responses: [
            .json(
                """
                {
                  "success": true,
                  "message": "ok",
                  "key": "messages/r1/images_20260704/abc.png",
                  "signature": {
                    "url": "http://storage.local/mock-bucket/messages/r1/images_20260704/abc.png",
                    "method": "PUT",
                    "headers": {
                      "x-amz-content-sha256": "UNSIGNED-PAYLOAD"
                    },
                    "key": "messages/r1/images_20260704/abc.png"
                  }
                }
                """
            ),
            .json(#"{"success":true,"message":"committed"}"#),
            .json(
                """
                {
                  "success": true,
                  "message": "ok",
                  "download_url": "http://storage.local/mock-bucket/messages/r1/images_20260704/abc.png?download=1"
                }
                """
            ),
        ])
        let directTransport = QueueMediaHTTPTransport(responses: [
            .empty(statusCode: 200),
            .data(Data("image-bytes".utf8), statusCode: 200),
        ])
        let client = MediaAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: apiTransport),
            directTransport: directTransport
        )
        let metadata = MediaUploadMetadata(
            fileName: "avatar.png",
            contentType: "image/png",
            fileSize: 11,
            hashValue: "abc123",
            hashAlgorithm: 2
        )

        let descriptor = try await client.requestMessageAttachmentUpload(
            roomID: "r1",
            partType: .image,
            metadata: metadata,
            token: "access-token"
        )
        try await client.upload(data: Data("hello".utf8), using: try XCTUnwrap(descriptor.signature), defaultContentType: "image/png")
        try await client.commitMessageAttachmentUpload(
            roomID: "r1",
            key: descriptor.key,
            metadata: metadata,
            token: "access-token"
        )
        let downloadURL = try await client.messageAttachmentDownloadURL(
            roomID: "r1",
            key: descriptor.key,
            token: "access-token",
            expiresInSeconds: 600
        )
        let downloaded = try await client.download(from: try XCTUnwrap(downloadURL))

        XCTAssertEqual(descriptor.key, "messages/r1/images_20260704/abc.png")
        XCTAssertEqual(String(data: downloaded, encoding: .utf8), "image-bytes")

        let apiRequests = await apiTransport.recordedRequests()
        XCTAssertEqual(apiRequests.map(\.httpMethod), ["POST", "POST", "GET"])
        XCTAssertEqual(apiRequests[0].url?.absoluteString, "http://127.0.0.1:8010/rooms/r1/messages/attachments/signature")
        XCTAssertEqual(apiRequests[0].value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        let signatureBody = try XCTUnwrap(apiRequests[0].httpBody)
        let signatureJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: signatureBody) as? [String: Any])
        XCTAssertEqual(signatureJSON["part_type"] as? String, "image")
        XCTAssertEqual(signatureJSON["filename"] as? String, "avatar.png")
        XCTAssertEqual(signatureJSON["content_type"] as? String, "image/png")
        XCTAssertEqual(signatureJSON["file_size"] as? Int, 11)
        XCTAssertEqual(signatureJSON["hash_alg"] as? Int, 2)

        let directRequests = await directTransport.recordedRequests()
        XCTAssertEqual(directRequests[0].httpMethod, "PUT")
        XCTAssertEqual(directRequests[0].value(forHTTPHeaderField: "Content-Type"), "image/png")
        XCTAssertEqual(directRequests[0].value(forHTTPHeaderField: "x-amz-content-sha256"), "UNSIGNED-PAYLOAD")
        XCTAssertEqual(directRequests[1].httpMethod, "GET")
    }
}

private actor QueueMediaHTTPTransport: HTTPTransport {
    struct Response: Sendable {
        let data: Data
        let statusCode: Int

        static func json(_ value: String, statusCode: Int = 200) -> Response {
            Response(data: Data(value.utf8), statusCode: statusCode)
        }

        static func data(_ data: Data, statusCode: Int = 200) -> Response {
            Response(data: data, statusCode: statusCode)
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
