import Foundation

public struct AccountName: Equatable, Hashable, Sendable {
    public let value: String

    public init(_ rawValue: String) throws {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard AccountName.isValid(normalized) else {
            throw RedCodeError.authentication("账号格式不正确")
        }
        self.value = normalized
    }

    public static func normalize(_ rawValue: String) throws -> String {
        try AccountName(rawValue).value
    }

    private static func isValid(_ value: String) -> Bool {
        guard (3...20).contains(value.count) else {
            return false
        }

        return value.range(of: #"^[a-z0-9._-]+$"#, options: .regularExpression) != nil
    }
}
