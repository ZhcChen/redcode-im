import Foundation
import RedCodeCore

public protocol PushAPIService: Sendable {
    func registerDevice(
        token: String,
        deviceID: String,
        deviceToken: String,
        platform: String,
        channel: String
    ) async throws -> RegisterPushDeviceResponse

    func unregisterDevice(token: String, deviceID: String) async throws -> UnregisterPushDeviceResponse
}

public struct PushAPIClient: PushAPIService {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public init(environment: RedCodeEnvironment) {
        self.apiClient = APIClient(environment: environment)
    }

    public func registerDevice(
        token: String,
        deviceID: String,
        deviceToken: String,
        platform: String = "ios",
        channel: String = "fcm"
    ) async throws -> RegisterPushDeviceResponse {
        let request = try RegisterPushDeviceRequest(
            deviceID: deviceID,
            platform: platform,
            channel: channel,
            deviceToken: deviceToken
        )
        return try await apiClient.post(
            PushAPIEndpoint.devices,
            body: request,
            bearerToken: token,
            as: RegisterPushDeviceResponse.self
        )
    }

    public func unregisterDevice(
        token: String,
        deviceID: String
    ) async throws -> UnregisterPushDeviceResponse {
        try await apiClient.delete(
            PushAPIEndpoint.unregisterDevice(deviceID: deviceID),
            bearerToken: token,
            as: UnregisterPushDeviceResponse.self
        )
    }
}
