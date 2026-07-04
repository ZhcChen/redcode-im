import Foundation
import RedCodeCore

public protocol MediaAPIService: Sendable {
    func requestUserAvatarUpload(metadata: MediaUploadMetadata, token: String) async throws -> DirectUploadDescriptor
    func commitUserAvatarUpload(key: String, token: String) async throws -> MediaCommitResult
    func userAvatarDownloadURL(userID: String?, token: String, expiresInSeconds: Int) async throws -> URL?

    func requestRoomAvatarUpload(
        roomID: String,
        metadata: MediaUploadMetadata,
        token: String
    ) async throws -> DirectUploadDescriptor
    func commitRoomAvatarUpload(roomID: String, key: String, token: String) async throws -> MediaCommitResult
    func roomAvatarDownloadURL(roomID: String, token: String, expiresInSeconds: Int) async throws -> URL?

    func requestMessageAttachmentUpload(
        roomID: String,
        partType: MediaPartType,
        metadata: MediaUploadMetadata,
        token: String
    ) async throws -> DirectUploadDescriptor
    func commitMessageAttachmentUpload(
        roomID: String,
        key: String,
        metadata: MediaUploadMetadata,
        token: String
    ) async throws
    func messageAttachmentDownloadURL(
        roomID: String,
        key: String,
        token: String,
        expiresInSeconds: Int
    ) async throws -> URL?

    func upload(data: Data, using signature: DirectUploadSignature, defaultContentType: String?) async throws
    func download(from url: URL) async throws -> Data
}

public struct MediaAPIClient: MediaAPIService {
    private let apiClient: APIClient
    private let directTransport: any HTTPTransport

    public init(apiClient: APIClient, directTransport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.apiClient = apiClient
        self.directTransport = directTransport
    }

    public init(environment: RedCodeEnvironment, directTransport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.apiClient = APIClient(environment: environment)
        self.directTransport = directTransport
    }

    public func requestUserAvatarUpload(metadata: MediaUploadMetadata, token: String) async throws -> DirectUploadDescriptor {
        let response = try await apiClient.post(
            MediaAPIEndpoint.userAvatarDirectUpload,
            body: AvatarDirectUploadRequest(metadata: metadata),
            bearerToken: token,
            as: DirectUploadResponse.self
        )
        return try uploadDescriptor(from: response)
    }

    public func commitUserAvatarUpload(key: String, token: String) async throws -> MediaCommitResult {
        let response = try await apiClient.post(
            MediaAPIEndpoint.userAvatarCommit,
            body: AvatarCommitRequest(key: key),
            bearerToken: token,
            as: MediaCommitResponse.self
        )
        return MediaCommitResult(success: response.success, message: response.message, avatarURL: response.avatarURL)
    }

    public func userAvatarDownloadURL(
        userID: String?,
        token: String,
        expiresInSeconds: Int = 3_600
    ) async throws -> URL? {
        let response = try await apiClient.get(
            MediaAPIEndpoint.userAvatarDownloadURL(userID: userID, expiresInSeconds: expiresInSeconds),
            bearerToken: token,
            as: DownloadURLResponse.self
        )
        return response.success ? response.downloadURL : nil
    }

    public func requestRoomAvatarUpload(
        roomID: String,
        metadata: MediaUploadMetadata,
        token: String
    ) async throws -> DirectUploadDescriptor {
        let response = try await apiClient.post(
            MediaAPIEndpoint.roomAvatarDirectUpload(roomID: roomID),
            body: AvatarDirectUploadRequest(metadata: metadata),
            bearerToken: token,
            as: DirectUploadResponse.self
        )
        return try uploadDescriptor(from: response)
    }

    public func commitRoomAvatarUpload(roomID: String, key: String, token: String) async throws -> MediaCommitResult {
        let response = try await apiClient.post(
            MediaAPIEndpoint.roomAvatarCommit(roomID: roomID),
            body: AvatarCommitRequest(key: key),
            bearerToken: token,
            as: MediaCommitResponse.self
        )
        return MediaCommitResult(success: response.success, message: response.message, avatarURL: response.avatarURL)
    }

    public func roomAvatarDownloadURL(
        roomID: String,
        token: String,
        expiresInSeconds: Int = 3_600
    ) async throws -> URL? {
        let response = try await apiClient.get(
            MediaAPIEndpoint.roomAvatarDownloadURL(roomID: roomID, expiresInSeconds: expiresInSeconds),
            bearerToken: token,
            as: DownloadURLResponse.self
        )
        return response.success ? response.downloadURL : nil
    }

    public func requestMessageAttachmentUpload(
        roomID: String,
        partType: MediaPartType,
        metadata: MediaUploadMetadata,
        token: String
    ) async throws -> DirectUploadDescriptor {
        let response = try await apiClient.post(
            MediaAPIEndpoint.messageAttachmentSignature(roomID: roomID),
            body: MessageAttachmentSignatureRequest(partType: partType, metadata: metadata),
            bearerToken: token,
            as: DirectUploadResponse.self
        )
        return try uploadDescriptor(from: response)
    }

    public func commitMessageAttachmentUpload(
        roomID: String,
        key: String,
        metadata: MediaUploadMetadata,
        token: String
    ) async throws {
        let response = try await apiClient.post(
            MediaAPIEndpoint.messageAttachmentCommit(roomID: roomID),
            body: MessageAttachmentCommitRequest(key: key, metadata: metadata),
            bearerToken: token,
            as: MediaCommitResponse.self
        )
        guard response.success else {
            throw NetworkFailure(kind: .server, message: response.message)
        }
    }

    public func messageAttachmentDownloadURL(
        roomID: String,
        key: String,
        token: String,
        expiresInSeconds: Int = 600
    ) async throws -> URL? {
        let response = try await apiClient.get(
            MediaAPIEndpoint.messageAttachmentDownloadURL(
                roomID: roomID,
                key: key,
                expiresInSeconds: expiresInSeconds
            ),
            bearerToken: token,
            as: DownloadURLResponse.self
        )
        return response.success ? response.downloadURL : nil
    }

    public func upload(data: Data, using signature: DirectUploadSignature, defaultContentType: String? = nil) async throws {
        var request = URLRequest(url: signature.url)
        request.httpMethod = signature.method.rawValue
        request.httpBody = data
        for (name, value) in signature.headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        if let defaultContentType, !defaultContentType.isEmpty {
            request.setValue(request.value(forHTTPHeaderField: "Content-Type") ?? defaultContentType, forHTTPHeaderField: "Content-Type")
        }

        let (responseData, response) = try await performDirectRequest(request)
        guard (200...299).contains(response.statusCode) else {
            throw NetworkFailure.http(
                statusCode: response.statusCode,
                message: String(data: responseData, encoding: .utf8) ?? "Direct upload failed"
            )
        }
    }

    public func download(from url: URL) async throws -> Data {
        let (data, response) = try await performDirectRequest(URLRequest(url: url))
        guard (200...299).contains(response.statusCode) else {
            throw NetworkFailure.http(
                statusCode: response.statusCode,
                message: String(data: data, encoding: .utf8) ?? "Download failed"
            )
        }
        return data
    }

    private func uploadDescriptor(from response: DirectUploadResponse) throws -> DirectUploadDescriptor {
        guard response.success else {
            throw NetworkFailure(kind: .server, message: response.message)
        }
        guard let key = response.key?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            throw NetworkFailure(kind: .decoding, message: "上传签名响应缺少 key")
        }
        return DirectUploadDescriptor(key: key, signature: response.signature)
    }

    private func performDirectRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await directTransport.data(for: request)
        } catch let error as NetworkFailure {
            throw error
        } catch {
            throw NetworkFailure.transport(error)
        }
    }
}
