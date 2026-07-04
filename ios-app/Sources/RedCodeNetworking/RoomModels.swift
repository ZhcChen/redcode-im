import Foundation

public struct RoomInfo: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let roomType: String
    public let description: String?
    public let avatarURL: String?
    public let avatarObjectKey: String?
    public let ownerID: String?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: String,
        name: String,
        roomType: String,
        description: String? = nil,
        avatarURL: String? = nil,
        avatarObjectKey: String? = nil,
        ownerID: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.roomType = roomType
        self.description = description
        self.avatarURL = avatarURL
        self.avatarObjectKey = avatarObjectKey
        self.ownerID = ownerID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeString(forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "群聊"
        roomType = try container.decodeIfPresent(String.self, forKey: .roomType) ?? "group"
        description = try container.decodeIfPresent(String.self, forKey: .description)
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        avatarObjectKey = try container.decodeIfPresent(String.self, forKey: .avatarObjectKey)
        ownerID = try container.decodeIfPresent(String.self, forKey: .ownerID)
        createdAt = container.decodeFlexibleDate(forKey: .createdAt)
        updatedAt = container.decodeFlexibleDate(forKey: .updatedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case roomType = "room_type"
        case description
        case avatarURL = "avatar_url"
        case avatarObjectKey = "avatar_object_key"
        case ownerID = "owner_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct RoomMember: Decodable, Equatable, Identifiable, Sendable {
    public var id: String { userID }

    public let userID: String
    public let username: String
    public let nickname: String?
    public let avatarURL: String?
    public let avatarObjectKey: String?
    public let role: String
    public let joinedAt: Date?

    public init(
        userID: String,
        username: String,
        nickname: String? = nil,
        avatarURL: String? = nil,
        avatarObjectKey: String? = nil,
        role: String = "member",
        joinedAt: Date? = nil
    ) {
        self.userID = userID
        self.username = username
        self.nickname = nickname
        self.avatarURL = avatarURL
        self.avatarObjectKey = avatarObjectKey
        self.role = role
        self.joinedAt = joinedAt
    }

    public var displayName: String {
        if let nickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines), !nickname.isEmpty {
            return nickname
        }
        return username
    }

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case username
        case nickname
        case avatarURL = "avatar_url"
        case avatarObjectKey = "avatar_object_key"
        case role
        case joinedAt = "joined_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decodeString(forKey: .userID)
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? userID
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        avatarObjectKey = try container.decodeIfPresent(String.self, forKey: .avatarObjectKey)
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? "member"
        joinedAt = container.decodeFlexibleDate(forKey: .joinedAt)
    }
}

public struct GroupSettingsInfo: Decodable, Equatable, Identifiable, Sendable {
    public var id: String { roomID }

    public let roomID: String
    public let joinApprovalRequired: Bool
    public let memberCanInvite: Bool
    public let memberCanAddFriends: Bool
    public let requireAdminToAddFriends: Bool
    public let maxMembers: Int
    public let globalMuteEnabled: Bool
    public let globalMuteUntil: Date?
    public let globalMuteReason: String?
    public let globalMuteSetBy: String?

    public init(
        roomID: String,
        joinApprovalRequired: Bool = false,
        memberCanInvite: Bool = true,
        memberCanAddFriends: Bool = true,
        requireAdminToAddFriends: Bool = false,
        maxMembers: Int = 500,
        globalMuteEnabled: Bool = false,
        globalMuteUntil: Date? = nil,
        globalMuteReason: String? = nil,
        globalMuteSetBy: String? = nil
    ) {
        self.roomID = roomID
        self.joinApprovalRequired = joinApprovalRequired
        self.memberCanInvite = memberCanInvite
        self.memberCanAddFriends = memberCanAddFriends
        self.requireAdminToAddFriends = requireAdminToAddFriends
        self.maxMembers = maxMembers
        self.globalMuteEnabled = globalMuteEnabled
        self.globalMuteUntil = globalMuteUntil
        self.globalMuteReason = globalMuteReason
        self.globalMuteSetBy = globalMuteSetBy
    }

    private enum CodingKeys: String, CodingKey {
        case roomID = "room_id"
        case joinApprovalRequired = "join_approval_required"
        case memberCanInvite = "member_can_invite"
        case memberCanAddFriends = "member_can_add_friends"
        case requireAdminToAddFriends = "require_admin_to_add_friends"
        case maxMembers = "max_members"
        case globalMuteEnabled = "global_mute_enabled"
        case globalMuteUntil = "global_mute_until"
        case globalMuteReason = "global_mute_reason"
        case globalMuteSetBy = "global_mute_set_by"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        roomID = try container.decodeString(forKey: .roomID)
        joinApprovalRequired = try container.decodeIfPresent(Bool.self, forKey: .joinApprovalRequired) ?? false
        memberCanInvite = try container.decodeIfPresent(Bool.self, forKey: .memberCanInvite) ?? true
        memberCanAddFriends = try container.decodeIfPresent(Bool.self, forKey: .memberCanAddFriends) ?? true
        requireAdminToAddFriends = try container.decodeIfPresent(Bool.self, forKey: .requireAdminToAddFriends) ?? false
        maxMembers = try container.decodeFlexibleInt(forKey: .maxMembers) ?? 500
        globalMuteEnabled = try container.decodeIfPresent(Bool.self, forKey: .globalMuteEnabled) ?? false
        globalMuteUntil = container.decodeFlexibleDate(forKey: .globalMuteUntil)
        globalMuteReason = try container.decodeIfPresent(String.self, forKey: .globalMuteReason)
        globalMuteSetBy = try container.decodeIfPresent(String.self, forKey: .globalMuteSetBy)
    }
}

public struct MyMuteInfo: Decodable, Equatable, Sendable {
    public let isMuted: Bool
    public let reason: String?
    public let mutedAt: Date?
    public let muteUntil: Date?

    public init(isMuted: Bool, reason: String? = nil, mutedAt: Date? = nil, muteUntil: Date? = nil) {
        self.isMuted = isMuted
        self.reason = reason
        self.mutedAt = mutedAt
        self.muteUntil = muteUntil
    }

    private enum CodingKeys: String, CodingKey {
        case isMuted = "is_muted"
        case reason
        case mutedAt = "muted_at"
        case muteUntil = "mute_until"
    }
}

public struct GroupSettingsSnapshot: Decodable, Equatable, Sendable {
    public let settings: GroupSettingsInfo
    public let myMute: MyMuteInfo?

    public init(settings: GroupSettingsInfo, myMute: MyMuteInfo? = nil) {
        self.settings = settings
        self.myMute = myMute
    }

    private enum CodingKeys: String, CodingKey {
        case settings
        case myMute = "my_mute"
    }
}

public struct AddMembersResult: Decodable, Equatable, Sendable {
    public let addedUserIDs: [String]
    public let skippedUserIDs: [String]

    public init(addedUserIDs: [String], skippedUserIDs: [String] = []) {
        self.addedUserIDs = addedUserIDs
        self.skippedUserIDs = skippedUserIDs
    }

    private enum CodingKeys: String, CodingKey {
        case addedUserIDs = "added_user_ids"
        case skippedUserIDs = "skipped_user_ids"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        addedUserIDs = try container.decodeIfPresent([String].self, forKey: .addedUserIDs) ?? []
        skippedUserIDs = try container.decodeIfPresent([String].self, forKey: .skippedUserIDs) ?? []
    }
}

public enum JoinRequestStatus: String, Codable, Equatable, Sendable {
    case pending
    case approved
    case rejected

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            switch intValue {
            case 1:
                self = .approved
            case 2:
                self = .rejected
            default:
                self = .pending
            }
            return
        }
        let raw = (try? container.decode(String.self))?.lowercased() ?? "pending"
        self = JoinRequestStatus(rawValue: raw) ?? .pending
    }
}

public struct GroupJoinRequest: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let roomID: String
    public let applicantID: String
    public let message: String?
    public let status: JoinRequestStatus
    public let reviewerID: String?
    public let reviewMessage: String?
    public let createdAt: Date?
    public let reviewedAt: Date?

    public init(
        id: String,
        roomID: String,
        applicantID: String,
        message: String? = nil,
        status: JoinRequestStatus = .pending,
        reviewerID: String? = nil,
        reviewMessage: String? = nil,
        createdAt: Date? = nil,
        reviewedAt: Date? = nil
    ) {
        self.id = id
        self.roomID = roomID
        self.applicantID = applicantID
        self.message = message
        self.status = status
        self.reviewerID = reviewerID
        self.reviewMessage = reviewMessage
        self.createdAt = createdAt
        self.reviewedAt = reviewedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case roomID = "room_id"
        case applicantID = "applicant_id"
        case message
        case status
        case reviewerID = "reviewer_id"
        case reviewMessage = "review_message"
        case createdAt = "created_at"
        case reviewedAt = "reviewed_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeString(forKey: .id)
        roomID = try container.decodeString(forKey: .roomID)
        applicantID = try container.decodeString(forKey: .applicantID)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        status = try container.decodeIfPresent(JoinRequestStatus.self, forKey: .status) ?? .pending
        reviewerID = try container.decodeIfPresent(String.self, forKey: .reviewerID)
        reviewMessage = try container.decodeIfPresent(String.self, forKey: .reviewMessage)
        createdAt = container.decodeFlexibleDate(forKey: .createdAt)
        reviewedAt = container.decodeFlexibleDate(forKey: .reviewedAt)
    }
}

public struct GroupAdmin: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let roomID: String
    public let adminID: String
    public let appointedBy: String
    public let role: String
    public let permissions: [String]
    public let appointedAt: Date?

    public init(
        id: String,
        roomID: String,
        adminID: String,
        appointedBy: String,
        role: String = "admin",
        permissions: [String] = [],
        appointedAt: Date? = nil
    ) {
        self.id = id
        self.roomID = roomID
        self.adminID = adminID
        self.appointedBy = appointedBy
        self.role = role
        self.permissions = permissions
        self.appointedAt = appointedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case roomID = "room_id"
        case adminID = "admin_id"
        case appointedBy = "appointed_by"
        case role
        case permissions
        case appointedAt = "appointed_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeString(forKey: .id)
        roomID = try container.decodeString(forKey: .roomID)
        adminID = try container.decodeString(forKey: .adminID)
        appointedBy = try container.decodeString(forKey: .appointedBy)
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? "admin"
        permissions = try container.decodeIfPresent([String].self, forKey: .permissions) ?? []
        appointedAt = container.decodeFlexibleDate(forKey: .appointedAt)
    }
}

public struct GroupMute: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let roomID: String
    public let userID: String
    public let mutedBy: String
    public let reason: String?
    public let muteDurationHours: Int
    public let mutedAt: Date?
    public let unmutedAt: Date?
    public let isActive: Bool

    public init(
        id: String,
        roomID: String,
        userID: String,
        mutedBy: String,
        reason: String? = nil,
        muteDurationHours: Int = 0,
        mutedAt: Date? = nil,
        unmutedAt: Date? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.roomID = roomID
        self.userID = userID
        self.mutedBy = mutedBy
        self.reason = reason
        self.muteDurationHours = muteDurationHours
        self.mutedAt = mutedAt
        self.unmutedAt = unmutedAt
        self.isActive = isActive
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case roomID = "room_id"
        case userID = "user_id"
        case mutedBy = "muted_by"
        case reason
        case muteDurationHours = "mute_duration_hours"
        case mutedAt = "muted_at"
        case unmutedAt = "unmuted_at"
        case isActive = "is_active"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeString(forKey: .id)
        roomID = try container.decodeString(forKey: .roomID)
        userID = try container.decodeString(forKey: .userID)
        mutedBy = try container.decodeString(forKey: .mutedBy)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        muteDurationHours = try container.decodeFlexibleInt(forKey: .muteDurationHours) ?? 0
        mutedAt = container.decodeFlexibleDate(forKey: .mutedAt)
        unmutedAt = container.decodeFlexibleDate(forKey: .unmutedAt)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
    }
}

public struct GroupRule: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let roomID: String
    public let title: String
    public let content: String
    public let creatorID: String
    public let orderIndex: Int
    public let isActive: Bool
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: String,
        roomID: String,
        title: String,
        content: String,
        creatorID: String,
        orderIndex: Int = 0,
        isActive: Bool = true,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.roomID = roomID
        self.title = title
        self.content = content
        self.creatorID = creatorID
        self.orderIndex = orderIndex
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case roomID = "room_id"
        case title
        case content
        case creatorID = "creator_id"
        case orderIndex = "order_index"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeString(forKey: .id)
        roomID = try container.decodeString(forKey: .roomID)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        creatorID = try container.decodeIfPresent(String.self, forKey: .creatorID) ?? ""
        orderIndex = try container.decodeFlexibleInt(forKey: .orderIndex) ?? 0
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        createdAt = container.decodeFlexibleDate(forKey: .createdAt)
        updatedAt = container.decodeFlexibleDate(forKey: .updatedAt)
    }
}

public struct GroupOperationLog: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let roomID: String
    public let operatorID: String
    public let targetUserID: String?
    public let operationType: String
    public let operationData: JSONValue?
    public let createdAt: Date?

    public init(
        id: String,
        roomID: String,
        operatorID: String,
        targetUserID: String? = nil,
        operationType: String,
        operationData: JSONValue? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.roomID = roomID
        self.operatorID = operatorID
        self.targetUserID = targetUserID
        self.operationType = operationType
        self.operationData = operationData
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case roomID = "room_id"
        case operatorID = "operator_id"
        case targetUserID = "target_user_id"
        case operationType = "operation_type"
        case operationData = "operation_data"
        case createdAt = "created_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeString(forKey: .id)
        roomID = try container.decodeString(forKey: .roomID)
        operatorID = try container.decodeString(forKey: .operatorID)
        targetUserID = try container.decodeIfPresent(String.self, forKey: .targetUserID)
        operationType = try container.decodeIfPresent(String.self, forKey: .operationType) ?? ""
        operationData = try container.decodeIfPresent(JSONValue.self, forKey: .operationData)
        createdAt = container.decodeFlexibleDate(forKey: .createdAt)
    }
}

public struct GroupDetailInfo: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let avatarURL: String?
    public let avatarObjectKey: String?
    public let roomType: String
    public let ownerID: String
    public let joinApprovalRequired: Bool
    public let memberCanInvite: Bool
    public let memberCanAddFriends: Bool
    public let requireAdminToAddFriends: Bool
    public let maxMembers: Int
    public let globalMuteEnabled: Bool
    public let currentMemberCount: Int
    public let pendingRequestCount: Int

    public init(
        id: String,
        name: String,
        description: String? = nil,
        avatarURL: String? = nil,
        avatarObjectKey: String? = nil,
        roomType: String = "group",
        ownerID: String,
        joinApprovalRequired: Bool = false,
        memberCanInvite: Bool = true,
        memberCanAddFriends: Bool = true,
        requireAdminToAddFriends: Bool = false,
        maxMembers: Int = 500,
        globalMuteEnabled: Bool = false,
        currentMemberCount: Int = 0,
        pendingRequestCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.avatarURL = avatarURL
        self.avatarObjectKey = avatarObjectKey
        self.roomType = roomType
        self.ownerID = ownerID
        self.joinApprovalRequired = joinApprovalRequired
        self.memberCanInvite = memberCanInvite
        self.memberCanAddFriends = memberCanAddFriends
        self.requireAdminToAddFriends = requireAdminToAddFriends
        self.maxMembers = maxMembers
        self.globalMuteEnabled = globalMuteEnabled
        self.currentMemberCount = currentMemberCount
        self.pendingRequestCount = pendingRequestCount
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case avatarURL = "avatar_url"
        case avatarObjectKey = "avatar_object_key"
        case roomType = "room_type"
        case ownerID = "owner_id"
        case joinApprovalRequired = "join_approval_required"
        case memberCanInvite = "member_can_invite"
        case memberCanAddFriends = "member_can_add_friends"
        case requireAdminToAddFriends = "require_admin_to_add_friends"
        case maxMembers = "max_members"
        case globalMuteEnabled = "global_mute_enabled"
        case currentMemberCount = "current_member_count"
        case pendingRequestCount = "pending_request_count"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeString(forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "群聊"
        description = try container.decodeIfPresent(String.self, forKey: .description)
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        avatarObjectKey = try container.decodeIfPresent(String.self, forKey: .avatarObjectKey)
        roomType = try container.decodeIfPresent(String.self, forKey: .roomType) ?? "group"
        ownerID = try container.decodeIfPresent(String.self, forKey: .ownerID) ?? ""
        joinApprovalRequired = try container.decodeIfPresent(Bool.self, forKey: .joinApprovalRequired) ?? false
        memberCanInvite = try container.decodeIfPresent(Bool.self, forKey: .memberCanInvite) ?? true
        memberCanAddFriends = try container.decodeIfPresent(Bool.self, forKey: .memberCanAddFriends) ?? true
        requireAdminToAddFriends = try container.decodeIfPresent(Bool.self, forKey: .requireAdminToAddFriends) ?? false
        maxMembers = try container.decodeFlexibleInt(forKey: .maxMembers) ?? 500
        globalMuteEnabled = try container.decodeIfPresent(Bool.self, forKey: .globalMuteEnabled) ?? false
        currentMemberCount = try container.decodeFlexibleInt(forKey: .currentMemberCount) ?? 0
        pendingRequestCount = try container.decodeFlexibleInt(forKey: .pendingRequestCount) ?? 0
    }
}

public struct CreateGroupRoomRequest: Encodable, Equatable, Sendable {
    public let name: String
    public let description: String?
    public let roomType: String
    public let memberIDs: [String]

    public init(name: String, description: String? = nil, memberIDs: [String]) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.description = description?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.roomType = "group"
        self.memberIDs = memberIDs.normalizedIDs()
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case roomType = "room_type"
        case memberIDs = "member_ids"
    }
}

public struct UpdateRoomRequest: Encodable, Equatable, Sendable {
    public let name: String?
    public let description: String?

    public init(name: String? = nil, description: String? = nil) {
        self.name = name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.description = description?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

public struct AddGroupMembersRequest: Encodable, Equatable, Sendable {
    public let userIDs: [String]

    public init(userIDs: [String]) {
        self.userIDs = userIDs.normalizedIDs()
    }

    private enum CodingKeys: String, CodingKey {
        case userIDs = "user_ids"
    }
}

public struct UpdateNotificationSettingsRequest: Encodable, Equatable, Sendable {
    public let notificationSettings: Int

    public init(notificationSettings: Int) {
        self.notificationSettings = notificationSettings
    }

    private enum CodingKeys: String, CodingKey {
        case notificationSettings = "notification_settings"
    }
}

public struct UpdateGroupSettingsRequest: Encodable, Equatable, Sendable {
    public let joinApprovalRequired: Bool?
    public let memberCanInvite: Bool?
    public let memberCanAddFriends: Bool?
    public let requireAdminToAddFriends: Bool?
    public let maxMembers: Int?

    public init(
        joinApprovalRequired: Bool? = nil,
        memberCanInvite: Bool? = nil,
        memberCanAddFriends: Bool? = nil,
        requireAdminToAddFriends: Bool? = nil,
        maxMembers: Int? = nil
    ) {
        self.joinApprovalRequired = joinApprovalRequired
        self.memberCanInvite = memberCanInvite
        self.memberCanAddFriends = memberCanAddFriends
        self.requireAdminToAddFriends = requireAdminToAddFriends
        self.maxMembers = maxMembers
    }

    private enum CodingKeys: String, CodingKey {
        case joinApprovalRequired = "join_approval_required"
        case memberCanInvite = "member_can_invite"
        case memberCanAddFriends = "member_can_add_friends"
        case requireAdminToAddFriends = "require_admin_to_add_friends"
        case maxMembers = "max_members"
    }
}

public struct UpdateGlobalMuteRequest: Encodable, Equatable, Sendable {
    public let enabled: Bool
    public let reason: String?
    public let durationMinutes: Int?

    public init(enabled: Bool, reason: String? = nil, durationMinutes: Int? = nil) {
        self.enabled = enabled
        self.reason = reason?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.durationMinutes = durationMinutes
    }

    private enum CodingKeys: String, CodingKey {
        case enabled
        case reason
        case durationMinutes = "duration_minutes"
    }
}

public struct AppointAdminRequest: Encodable, Equatable, Sendable {
    public let userID: String
    public let role: String
    public let permissions: [String]?

    public init(userID: String, role: String = "admin", permissions: [String]? = nil) {
        self.userID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.role = role
        self.permissions = permissions
    }

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case role
        case permissions
    }
}

public struct MuteUserRequest: Encodable, Equatable, Sendable {
    public let userID: String
    public let reason: String?
    public let muteDurationHours: Int?

    public init(userID: String, reason: String? = nil, muteDurationHours: Int? = nil) {
        self.userID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.reason = reason?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.muteDurationHours = muteDurationHours
    }

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case reason
        case muteDurationHours = "mute_duration_hours"
    }
}

public struct CreateRuleRequest: Encodable, Equatable, Sendable {
    public let title: String
    public let content: String
    public let orderIndex: Int?

    public init(title: String, content: String, orderIndex: Int? = nil) {
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        self.orderIndex = orderIndex
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case content
        case orderIndex = "order_index"
    }
}

public struct UpdateRuleRequest: Encodable, Equatable, Sendable {
    public let title: String?
    public let content: String?
    public let orderIndex: Int?
    public let isActive: Bool?

    public init(title: String? = nil, content: String? = nil, orderIndex: Int? = nil, isActive: Bool? = nil) {
        self.title = title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.content = content?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.orderIndex = orderIndex
        self.isActive = isActive
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case content
        case orderIndex = "order_index"
        case isActive = "is_active"
    }
}

public struct CreateJoinRequestRequest: Encodable, Equatable, Sendable {
    public let message: String?

    public init(message: String? = nil) {
        self.message = message?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

public struct ReviewJoinRequestRequest: Encodable, Equatable, Sendable {
    public let status: JoinRequestStatus
    public let reviewMessage: String?

    public init(status: JoinRequestStatus, reviewMessage: String? = nil) {
        self.status = status
        self.reviewMessage = reviewMessage?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case reviewMessage = "review_message"
    }
}

public struct CreateInvitationsRequest: Encodable, Equatable, Sendable {
    public let userIDs: [String]
    public let message: String?

    public init(userIDs: [String], message: String? = nil) {
        self.userIDs = userIDs.normalizedIDs()
        self.message = message?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case userIDs = "user_ids"
        case message
    }
}

struct CreateRoomResponse: Decodable, Sendable {
    let room: RoomInfo
}

struct RoomDetailResponse: Decodable, Sendable {
    let room: RoomInfo
}

struct UpdateRoomResponse: Decodable, Sendable {
    let room: RoomInfo?
}

struct GroupSettingsResponse: Decodable, Sendable {
    let settings: GroupSettingsInfo
    let myMute: MyMuteInfo?

    private enum CodingKeys: String, CodingKey {
        case settings
        case myMute = "my_mute"
    }
}

struct CreateRuleResponse: Decodable, Sendable {
    let rule: GroupRule
}

struct ListRulesResponse: Decodable, Sendable {
    let rules: [GroupRule]
}

struct CreateJoinRequestResponse: Decodable, Sendable {
    let request: GroupJoinRequest
}

struct ListJoinRequestsResponse: Decodable, Sendable {
    let requests: [GroupJoinRequest]
}

struct AppointAdminResponse: Decodable, Sendable {
    let admin: GroupAdmin
}

struct ListAdminsResponse: Decodable, Sendable {
    let admins: [GroupAdmin]
}

struct MuteUserResponse: Decodable, Sendable {
    let mute: GroupMute
}

struct ListMutedUsersResponse: Decodable, Sendable {
    let mutes: [GroupMute]
}

struct ListOperationLogsResponse: Decodable, Sendable {
    let logs: [GroupOperationLog]
    let total: Int?
}

struct GroupDetailResponse: Decodable, Sendable {
    let info: GroupDetailInfo
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension Array where Element == String {
    func normalizedIDs() -> [String] {
        var seen = Set<String>()
        return compactMap { rawID in
            let id = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, seen.insert(id).inserted else {
                return nil
            }
            return id
        }
    }
}

private extension KeyedDecodingContainer {
    func decodeString(forKey key: Key) throws -> String {
        if let value = try decodeIfPresent(String.self, forKey: key), !value.isEmpty {
            return value
        }
        if let value = try decodeIfPresent(UUID.self, forKey: key) {
            return value.uuidString
        }
        throw DecodingError.keyNotFound(
            key,
            DecodingError.Context(codingPath: codingPath, debugDescription: "Missing string for \(key.stringValue)")
        )
    }

    func decodeFlexibleDate(forKey key: Key) -> Date? {
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return RoomDateParser.parse(string)
        }
        if let double = try? decodeIfPresent(Double.self, forKey: key) {
            let seconds = double > 1_000_000_000_000 ? double / 1000 : double
            return Date(timeIntervalSince1970: seconds)
        }
        return nil
    }

    func decodeFlexibleInt(forKey key: Key) throws -> Int? {
        if let int = try decodeIfPresent(Int.self, forKey: key) {
            return int
        }
        if let int64 = try decodeIfPresent(Int64.self, forKey: key) {
            return Int(int64)
        }
        if let double = try decodeIfPresent(Double.self, forKey: key) {
            return Int(double)
        }
        if let string = try decodeIfPresent(String.self, forKey: key) {
            return Int(string)
        }
        return nil
    }
}

private enum RoomDateParser {
    static func parse(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else {
            return nil
        }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
