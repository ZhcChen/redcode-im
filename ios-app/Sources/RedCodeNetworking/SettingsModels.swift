import Foundation

public struct MessageRuntimeSettings: Codable, Equatable, Sendable {
    public let serverStorageMode: String
    public let contentAuditMode: String
    public let updatedAt: String?
    public let updatedBy: String?

    public init(
        serverStorageMode: String = "persist",
        contentAuditMode: String = "plaintext",
        updatedAt: String? = nil,
        updatedBy: String? = nil
    ) {
        self.serverStorageMode = serverStorageMode.isEmpty ? "persist" : serverStorageMode
        self.contentAuditMode = contentAuditMode.isEmpty ? "plaintext" : contentAuditMode
        self.updatedAt = updatedAt
        self.updatedBy = updatedBy
    }

    public static let defaults = MessageRuntimeSettings()

    public var isRelayOnly: Bool {
        serverStorageMode == "relay_only"
    }

    public var isE2EE: Bool {
        contentAuditMode == "e2ee"
    }

    public var runtimeNoticeTitle: String {
        isE2EE ? "当前配置目标：端到端加密" : "当前配置目标：明文可审计"
    }

    public var runtimeNoticeDescription: String {
        if isRelayOnly {
            return isE2EE
                ? "服务器仅做实时转发且不保存聊天记录，按当前配置目标不应被服务端审计。"
                : "服务器仅做实时转发且不保存聊天记录，消息内容仍可被服务端审计。"
        }
        return isE2EE
            ? "消息会保存在服务器，按当前配置目标不应被服务端审计。"
            : "消息会保存在服务器，管理员可审计消息内容。"
    }

    private enum CodingKeys: String, CodingKey {
        case serverStorageMode = "server_storage_mode"
        case contentAuditMode = "content_audit_mode"
        case updatedAt = "updated_at"
        case updatedBy = "updated_by"
    }
}

public struct GeneralSettings: Codable, Equatable, Sendable {
    public let appName: String
    public let messageRuntime: MessageRuntimeSettings

    public init(
        appName: String = "",
        messageRuntime: MessageRuntimeSettings = .defaults
    ) {
        self.appName = appName
        self.messageRuntime = messageRuntime
    }

    private enum CodingKeys: String, CodingKey {
        case appName = "app_name"
        case messageRuntime = "message_runtime"
    }
}

public struct DocumentContent: Codable, Equatable, Sendable {
    public let title: String
    public let content: String
    public let updatedAt: String?

    public init(title: String, content: String, updatedAt: String? = nil) {
        self.title = title
        self.content = content
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case content
        case updatedAt = "updated_at"
    }
}

public struct SubmitFeedbackRequest: Codable, Equatable, Sendable {
    public let content: String
    public let contact: String?

    public init(content: String, contact: String? = nil) throws {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            throw NetworkFailure(kind: .unknown, message: "反馈内容不能为空")
        }
        self.content = trimmedContent
        self.contact = contact?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

public struct SubmitFeedbackResponse: Codable, Equatable, Sendable {
    public let success: Bool
    public let message: String

    public init(success: Bool, message: String) {
        self.success = success
        self.message = message
    }
}

public struct AppVersionInfo: Codable, Equatable, Sendable {
    public let id: String
    public let platform: String
    public let version: String
    public let buildNumber: Int
    public let channel: String
    public let downloadKey: String
    public let downloadURL: String?
    public let appStoreURL: String?
    public let fileSize: Int?
    public let checksum: String?
    public let signature: String?
    public let releaseNotes: String?
    public let mandatory: Bool
    public let isActive: Bool
    public let createdAt: String?
    public let updatedAt: String?
    public let releasedAt: String?

    public init(
        id: String,
        platform: String,
        version: String,
        buildNumber: Int,
        channel: String,
        downloadKey: String,
        downloadURL: String? = nil,
        appStoreURL: String? = nil,
        fileSize: Int? = nil,
        checksum: String? = nil,
        signature: String? = nil,
        releaseNotes: String? = nil,
        mandatory: Bool = false,
        isActive: Bool = false,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        releasedAt: String? = nil
    ) {
        self.id = id
        self.platform = platform
        self.version = version
        self.buildNumber = buildNumber
        self.channel = channel
        self.downloadKey = downloadKey
        self.downloadURL = downloadURL
        self.appStoreURL = appStoreURL
        self.fileSize = fileSize
        self.checksum = checksum
        self.signature = signature
        self.releaseNotes = releaseNotes
        self.mandatory = mandatory
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.releasedAt = releasedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case platform
        case version
        case buildNumber = "build_number"
        case channel
        case downloadKey = "download_key"
        case downloadURL = "download_url"
        case appStoreURL = "app_store_url"
        case fileSize = "file_size"
        case checksum
        case signature
        case releaseNotes = "release_notes"
        case mandatory
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case releasedAt = "released_at"
    }
}

public struct VersionCheckResult: Codable, Equatable, Sendable {
    public let hasUpdate: Bool
    public let currentVersion: String?
    public let latest: AppVersionInfo?

    public init(
        hasUpdate: Bool,
        currentVersion: String? = nil,
        latest: AppVersionInfo? = nil
    ) {
        self.hasUpdate = hasUpdate
        self.currentVersion = currentVersion
        self.latest = latest
    }

    private enum CodingKeys: String, CodingKey {
        case hasUpdate = "has_update"
        case currentVersion = "current_version"
        case latest = "version"
    }
}

public struct VersionDownloadURLResponse: Codable, Equatable, Sendable {
    public let success: Bool
    public let message: String
    public let version: AppVersionInfo?
    public let downloadURL: String?

    public init(
        success: Bool,
        message: String,
        version: AppVersionInfo? = nil,
        downloadURL: String? = nil
    ) {
        self.success = success
        self.message = message
        self.version = version
        self.downloadURL = downloadURL
    }

    private enum CodingKeys: String, CodingKey {
        case success
        case message
        case version
        case downloadURL = "download_url"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
