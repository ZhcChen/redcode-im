public enum AppRoute: Hashable, Sendable {
    case login
    case resetPassword
    case chat(roomID: String)
    case contact(userID: String)
    case groupSettings(roomID: String)
    case settings
}
