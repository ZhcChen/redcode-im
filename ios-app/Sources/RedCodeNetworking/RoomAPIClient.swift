import Foundation
import RedCodeCore

public protocol RoomAPIService: Sendable {
    func createGroup(
        name: String,
        description: String?,
        memberIDs: [String],
        token: String
    ) async throws -> RoomInfo
}

public struct RoomAPIClient: RoomAPIService {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public init(environment: RedCodeEnvironment) {
        self.apiClient = APIClient(environment: environment)
    }

    public func createGroup(
        name: String,
        description: String? = nil,
        memberIDs: [String],
        token: String
    ) async throws -> RoomInfo {
        let request = CreateGroupRoomRequest(
            name: name,
            description: description,
            memberIDs: memberIDs
        )
        let response = try await apiClient.post(
            RoomAPIEndpoint.rooms,
            body: request,
            bearerToken: token,
            as: CreateRoomResponse.self
        )
        return response.room
    }
}
