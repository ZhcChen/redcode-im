import RedCodeCore

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

    public static func from(session: AuthSession?) -> AppSessionState {
        guard let session, session.isValid else {
            return .unauthenticated
        }

        return .authenticated(userID: session.user.id)
    }
}
