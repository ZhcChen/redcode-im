import XCTest
@testable import RedCodeNetworking

final class PushAPIClientTests: XCTestCase {
    func testRegisterDeviceSendsBackendPayloadAndBearerToken() async throws {
        let transport = PushQueueHTTPTransport(responses: [
            .json(#"{"success":true,"message":"ok","device_id":"device-1"}"#),
        ])
        let client = PushAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let response = try await client.registerDevice(
            token: "access-token",
            deviceID: " device-1 ",
            deviceToken: " fcm-token ",
            platform: " iOS ",
            channel: " FCM "
        )

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8010/push/devices")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertEqual(json["device_id"], "device-1")
        XCTAssertEqual(json["device_token"], "fcm-token")
        XCTAssertEqual(json["platform"], "ios")
        XCTAssertEqual(json["channel"], "fcm")
        XCTAssertEqual(response.deviceID, "device-1")
        XCTAssertTrue(response.success)
    }

    func testUnregisterDeviceUsesDeleteDeviceEndpoint() async throws {
        let transport = PushQueueHTTPTransport(responses: [
            .json(#"{"success":true,"message":"deleted"}"#),
        ])
        let client = PushAPIClient(
            apiClient: APIClient(environment: .simulatorDevelopment(), transport: transport)
        )

        let response = try await client.unregisterDevice(token: "access-token", deviceID: " device-1 ")

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8010/push/devices/device-1")
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertEqual(response.message, "deleted")
        XCTAssertTrue(response.success)
    }
}

private struct PushQueueHTTPResponse: Sendable {
    let data: Data
    let statusCode: Int

    static func json(_ value: String, statusCode: Int = 200) -> PushQueueHTTPResponse {
        PushQueueHTTPResponse(data: Data(value.utf8), statusCode: statusCode)
    }
}

private actor PushQueueHTTPTransport: HTTPTransport {
    private var responses: [PushQueueHTTPResponse]
    private var requests: [URLRequest] = []

    init(responses: [PushQueueHTTPResponse]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let next = responses.removeFirst()
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: next.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: [:]
        )!
        return (next.data, response)
    }

    func recordedRequests() -> [URLRequest] {
        requests
    }
}
