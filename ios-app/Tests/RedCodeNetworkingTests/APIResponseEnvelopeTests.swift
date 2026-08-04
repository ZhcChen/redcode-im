import XCTest
@testable import RedCodeNetworking

final class APIResponseEnvelopeTests: XCTestCase {
    func testEnvelopeDecodesDataPayload() throws {
        let data = Data(
            """
            {"success":true,"message":"ok","data":{"id":"m1","content":"hello"}}
            """.utf8
        )

        let envelope = try JSONDecoder().decode(
            APIResponseEnvelope<SamplePayload>.self,
            from: data
        )

        XCTAssertEqual(envelope.success, true)
        XCTAssertEqual(envelope.message, "ok")
        XCTAssertEqual(envelope.payload, SamplePayload(id: "m1", content: "hello"))
    }

    func testEnvelopeDecodesItemPayload() throws {
        let data = Data(
            """
            {"item":{"id":"m2","content":"world"}}
            """.utf8
        )

        let envelope = try JSONDecoder().decode(
            APIResponseEnvelope<SamplePayload>.self,
            from: data
        )

        XCTAssertEqual(envelope.payload, SamplePayload(id: "m2", content: "world"))
    }
}

private struct SamplePayload: Decodable, Equatable, Sendable {
    let id: String
    let content: String
}
