import Foundation

public enum PushAPIEndpoint: Sendable {
    public static let devices = APIEndpoint(method: .post, path: "/push/devices")

    public static func unregisterDevice(deviceID: String) -> APIEndpoint {
        APIEndpoint(
            method: .delete,
            path: "/push/devices/\(deviceID.trimmingCharacters(in: .whitespacesAndNewlines))"
        )
    }
}
