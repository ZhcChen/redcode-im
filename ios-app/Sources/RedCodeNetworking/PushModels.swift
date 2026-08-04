import Foundation

public struct RegisterPushDeviceRequest: Codable, Equatable, Sendable {
    public let deviceID: String
    public let platform: String
    public let channel: String
    public let deviceToken: String

    public init(
        deviceID: String,
        platform: String = "ios",
        channel: String = "fcm",
        deviceToken: String
    ) throws {
        let normalizedDeviceID = deviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedToken = deviceToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedDeviceID.isEmpty else {
            throw NetworkFailure(kind: .unknown, message: "device_id 不能为空")
        }
        guard !normalizedToken.isEmpty else {
            throw NetworkFailure(kind: .unknown, message: "device_token 不能为空")
        }
        self.deviceID = normalizedDeviceID
        self.platform = platform.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.channel = channel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.deviceToken = normalizedToken
    }

    private enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case platform
        case channel
        case deviceToken = "device_token"
    }
}

public struct RegisterPushDeviceResponse: Codable, Equatable, Sendable {
    public let success: Bool
    public let message: String
    public let deviceID: String

    public init(success: Bool, message: String, deviceID: String) {
        self.success = success
        self.message = message
        self.deviceID = deviceID
    }

    private enum CodingKeys: String, CodingKey {
        case success
        case message
        case deviceID = "device_id"
    }
}

public struct UnregisterPushDeviceResponse: Codable, Equatable, Sendable {
    public let success: Bool
    public let message: String

    public init(success: Bool, message: String) {
        self.success = success
        self.message = message
    }
}
