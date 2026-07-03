public enum AppSessionState: Equatable, Sendable {
    case unauthenticated
    case authenticated(userID: String)

    public var isAuthenticated: Bool {
        switch self {
        case .authenticated:
            true
        case .unauthenticated:
            false
        }
    }
}
