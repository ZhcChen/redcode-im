import XCTest
@testable import RedCodeCore
@testable import RedCodeNetworking

final class MediaAPIClientLiveTests: XCTestCase {
    func testLiveMessageAttachmentUploadDownloadAgainstComposeMockStorage() async throws {
        guard ProcessInfo.processInfo.environment["RED_CODE_IOS_LIVE_MEDIA_SMOKE"] == "1" else {
            throw XCTSkip("Set RED_CODE_IOS_LIVE_MEDIA_SMOKE=1 when the local Compose API with external-mock is running")
        }

        let environment = RedCodeEnvironment.simulatorDevelopment()
        let authClient = AuthAPIClient(environment: environment)
        let roomClient = RoomAPIClient(environment: environment)
        let chatClient = ChatAPIClient(environment: environment)
        let mediaClient = MediaAPIClient(environment: environment)
        let suffix = UUID().uuidString.lowercased().prefix(8)
        let owner = try await registerAndLogin(authClient: authClient, username: "iosmedia\(suffix)")
        let member = try await registerAndLogin(authClient: authClient, username: "iosmedm\(suffix)")
        let room = try await roomClient.createGroup(
            name: "ios media \(suffix)",
            description: "media live smoke",
            memberIDs: [member.user.id],
            token: owner.token
        )
        let payload = Data("ios-media-smoke-\(suffix)".utf8)
        let metadata = MediaUploadMetadata(
            fileName: "smoke.png",
            contentType: "image/png",
            fileSize: Int64(payload.count)
        )

        let descriptor = try await mediaClient.requestMessageAttachmentUpload(
            roomID: room.id,
            partType: .image,
            metadata: metadata,
            token: owner.token
        )
        try await mediaClient.upload(
            data: payload,
            using: try XCTUnwrap(descriptor.signature),
            defaultContentType: metadata.contentType
        )
        try await mediaClient.commitMessageAttachmentUpload(
            roomID: room.id,
            key: descriptor.key,
            metadata: metadata,
            token: owner.token
        )
        let sent = try await chatClient.sendRichMessage(
            roomID: room.id,
            parts: [
                .attachment(
                    type: .image,
                    key: descriptor.key,
                    name: metadata.fileName,
                    mime: metadata.contentType,
                    size: metadata.fileSize
                ),
            ],
            token: owner.token
        )
        let downloadURL = try await mediaClient.messageAttachmentDownloadURL(
            roomID: room.id,
            key: descriptor.key,
            token: member.token,
            expiresInSeconds: 600
        )
        let downloaded = try await mediaClient.download(from: try XCTUnwrap(downloadURL))

        XCTAssertEqual(sent.messageType, .image)
        XCTAssertEqual(sent.attachments.first?.key, descriptor.key)
        XCTAssertEqual(downloaded, payload)
    }

    private func registerAndLogin(authClient: AuthAPIClient, username: String) async throws -> AuthSession {
        let password = "secret123"
        _ = try await authClient.register(username: username, password: password, nickname: username)
        return try await authClient.login(username: username, password: password)
    }
}
