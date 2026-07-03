import Foundation

public enum RoomAPIEndpoint: Sendable {
    public static let rooms = APIEndpoint(method: .post, path: "/rooms")
}
