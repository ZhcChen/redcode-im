public enum AppTab: String, CaseIterable, Identifiable, Equatable, Sendable {
    case chats
    case contacts
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .chats:
            "聊天"
        case .contacts:
            "联系人"
        case .settings:
            "设置"
        }
    }

    public var systemImageName: String {
        switch self {
        case .chats:
            "message"
        case .contacts:
            "person.2"
        case .settings:
            "gearshape"
        }
    }
}
