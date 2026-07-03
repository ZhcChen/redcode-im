import Foundation

public struct EmailAddress: Equatable, Hashable, Sendable {
    public let value: String

    public init(_ rawValue: String) throws {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard EmailAddress.isValid(normalized) else {
            throw RedCodeError.authentication("邮箱格式不正确")
        }
        self.value = normalized
    }

    public static func normalize(_ rawValue: String) throws -> String {
        try EmailAddress(rawValue).value
    }

    private static func isValid(_ value: String) -> Bool {
        let backendPattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return value.range(of: backendPattern, options: .regularExpression) != nil
    }
}
