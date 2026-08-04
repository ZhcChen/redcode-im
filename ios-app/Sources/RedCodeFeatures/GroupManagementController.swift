import Foundation
import Combine
import RedCodeNetworking
import RedCodeStorage

public struct GroupSummary: Equatable, Identifiable, Sendable {
    public var id: String { roomID }

    public let roomID: String
    public let name: String
    public let ownerID: String?
    public let currentUserRole: String?
    public let memberCount: Int
    public let avatarURL: String?
    public let avatarObjectKey: String?
    public let updatedAt: Date

    public init(
        roomID: String,
        name: String,
        ownerID: String? = nil,
        currentUserRole: String? = nil,
        memberCount: Int = 0,
        avatarURL: String? = nil,
        avatarObjectKey: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.roomID = roomID
        self.name = name
        self.ownerID = ownerID
        self.currentUserRole = currentUserRole
        self.memberCount = memberCount
        self.avatarURL = avatarURL
        self.avatarObjectKey = avatarObjectKey
        self.updatedAt = updatedAt
    }

    public var chatSummary: ChatSummary {
        ChatSummary(
            roomID: roomID,
            displayName: name,
            roomType: .group,
            avatarURL: avatarURL,
            avatarObjectKey: avatarObjectKey
        )
    }
}

@MainActor
public final class GroupManagementController: ObservableObject {
    @Published public private(set) var groups: [GroupSummary] = []
    @Published public private(set) var currentGroup: GroupSummary?
    @Published public private(set) var members: [RoomMember] = []
    @Published public private(set) var settingsSnapshot: GroupSettingsSnapshot?
    @Published public private(set) var admins: [GroupAdmin] = []
    @Published public private(set) var mutes: [GroupMute] = []
    @Published public private(set) var rules: [GroupRule] = []
    @Published public private(set) var joinRequests: [GroupJoinRequest] = []
    @Published public private(set) var operationLogs: [GroupOperationLog] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isSaving = false
    @Published public private(set) var errorMessage: String?

    private let api: any RoomAPIService
    private let cacheStore: any GroupCacheStore

    public init(
        api: any RoomAPIService,
        cacheStore: any GroupCacheStore
    ) {
        self.api = api
        self.cacheStore = cacheStore
    }

    public func loadCachedGroups() throws {
        groups = try cacheStore.loadGroups().map(GroupSummary.init(cacheDraft:)).sortedForGroups()
    }

    public func refreshGroups(token: String) async throws {
        try await runLoadingOperation {
            let remoteGroups = try await api.listRooms(token: token)
                .filter { $0.roomType.lowercased() == "group" }
                .map { GroupSummary(roomInfo: $0) }
                .sortedForGroups()
            groups = remoteGroups
            try cacheStore.saveGroups(remoteGroups.map(\.cacheDraft))
        }
    }

    public func createGroup(
        name: String,
        description: String?,
        memberIDs: [String],
        token: String
    ) async throws -> ChatSummary {
        try await runSavingOperation {
            let room = try await api.createGroup(
                name: name,
                description: description,
                memberIDs: memberIDs,
                token: token
            )
            let group = GroupSummary(roomInfo: room, memberCount: memberIDs.count + 1)
            currentGroup = group
            groups = ([group] + groups.filter { $0.roomID != group.roomID }).sortedForGroups()
            try cacheStore.upsert(group.cacheDraft)
            return group.chatSummary
        }
    }

    public func loadGroupBundle(roomID: String, token: String, currentUserID: String) async throws {
        try await runLoadingOperation {
            async let roomTask = api.getRoom(roomID: roomID, token: token)
            async let membersTask = api.listMembers(roomID: roomID, token: token)
            async let settingsTask = api.fetchGroupSettings(roomID: roomID, token: token)
            let (room, roomMembers, settings) = try await (roomTask, membersTask, settingsTask)
            let currentRole = roomMembers.first { $0.userID == currentUserID }?.role
            let group = GroupSummary(roomInfo: room, currentUserRole: currentRole, memberCount: roomMembers.count)

            currentGroup = group
            members = roomMembers.sortedForMembers(ownerID: room.ownerID)
            settingsSnapshot = settings
            groups = ([group] + groups.filter { $0.roomID != group.roomID }).sortedForGroups()
            try cacheStore.upsert(group.cacheDraft)
        }
    }

    public func refreshMembers(roomID: String, token: String, currentUserID: String? = nil) async throws {
        do {
            let roomMembers = try await api.listMembers(roomID: roomID, token: token)
            members = roomMembers.sortedForMembers(ownerID: currentGroup?.ownerID)
            if let currentUserID,
               let role = roomMembers.first(where: { $0.userID == currentUserID })?.role,
               let group = currentGroup {
                currentGroup = group.replacing(currentUserRole: role, memberCount: roomMembers.count)
            }
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func renameGroup(roomID: String, name: String, description: String?, token: String) async throws -> ChatSummary {
        let previousGroup = currentGroup
        return try await runSavingOperation {
            let room = try await api.updateRoom(roomID: roomID, name: name, description: description, token: token)
            let group = GroupSummary(
                roomInfo: room,
                currentUserRole: currentGroup?.currentUserRole,
                memberCount: members.count
            )
            currentGroup = group
            groups = ([group] + groups.filter { $0.roomID != roomID }).sortedForGroups()
            try cacheStore.upsert(group.cacheDraft)
            return group.chatSummary
        } onError: {
            self.currentGroup = previousGroup
        }
    }

    public func addMembers(roomID: String, userIDs: [String], token: String, currentUserID: String) async throws -> AddMembersResult {
        try await runSavingOperation {
            let result = try await api.addMembers(roomID: roomID, userIDs: userIDs, token: token)
            try await refreshMembers(roomID: roomID, token: token, currentUserID: currentUserID)
            return result
        }
    }

    public func removeMember(roomID: String, userID: String, token: String, currentUserID: String) async throws {
        try await runSavingOperation {
            try await api.removeMember(roomID: roomID, userID: userID, token: token)
            members = members.filter { $0.userID != userID }
            try await refreshMembers(roomID: roomID, token: token, currentUserID: currentUserID)
        }
    }

    public func updateNotificationSettings(roomID: String, isMuted: Bool, token: String) async throws {
        try await runSavingOperation {
            try await api.updateNotificationSettings(roomID: roomID, notificationSettings: isMuted ? 2 : 0, token: token)
        }
    }

    public func setRoomPinned(roomID: String, pinned: Bool, token: String) async throws {
        try await runSavingOperation {
            try await api.setRoomPinned(roomID: roomID, pinned: pinned, token: token)
        }
    }

    public func leaveGroup(roomID: String, token: String) async throws {
        try await runSavingOperation {
            try await api.leaveRoom(roomID: roomID, token: token)
            currentGroup = nil
            members = []
            groups = groups.filter { $0.roomID != roomID }
            try cacheStore.remove(roomID: roomID)
        }
    }

    public func dissolveGroup(roomID: String, token: String) async throws {
        try await runSavingOperation {
            try await api.dissolveRoom(roomID: roomID, token: token)
            currentGroup = nil
            members = []
            groups = groups.filter { $0.roomID != roomID }
            try cacheStore.remove(roomID: roomID)
        }
    }

    public func refreshManagementLists(roomID: String, token: String) async throws {
        try await runLoadingOperation {
            async let adminsTask = api.listAdmins(roomID: roomID, token: token)
            async let mutesTask = api.listMutes(roomID: roomID, token: token)
            async let rulesTask = api.listRules(roomID: roomID, token: token)
            async let requestsTask = api.listJoinRequests(roomID: roomID, token: token)
            async let logsTask = api.listOperationLogs(roomID: roomID, limit: 20, offset: 0, token: token)
            let (admins, mutes, rules, requests, logs) = try await (
                adminsTask,
                mutesTask,
                rulesTask,
                requestsTask,
                logsTask
            )
            self.admins = admins
            self.mutes = mutes
            self.rules = rules
            self.joinRequests = requests
            self.operationLogs = logs
        }
    }

    public func appointAdmin(roomID: String, userID: String, token: String) async throws {
        try await runSavingOperation {
            let admin = try await api.appointAdmin(roomID: roomID, userID: userID, token: token)
            admins = ([admin] + admins.filter { $0.adminID != userID })
        }
    }

    public func removeAdmin(roomID: String, adminID: String, token: String) async throws {
        try await runSavingOperation {
            try await api.removeAdmin(roomID: roomID, adminID: adminID, token: token)
            admins = admins.filter { $0.adminID != adminID }
        }
    }

    public func muteUser(roomID: String, userID: String, reason: String?, hours: Int?, token: String) async throws {
        try await runSavingOperation {
            let mute = try await api.muteUser(
                roomID: roomID,
                userID: userID,
                reason: reason,
                muteDurationHours: hours,
                token: token
            )
            mutes = ([mute] + mutes.filter { $0.userID != userID })
        }
    }

    public func unmuteUser(roomID: String, userID: String, token: String) async throws {
        try await runSavingOperation {
            try await api.unmuteUser(roomID: roomID, userID: userID, token: token)
            mutes = mutes.filter { $0.userID != userID }
        }
    }

    public func updateGlobalMute(roomID: String, enabled: Bool, reason: String?, token: String) async throws {
        try await runSavingOperation {
            settingsSnapshot = try await api.updateGlobalMute(
                roomID: roomID,
                enabled: enabled,
                reason: reason,
                durationMinutes: nil,
                token: token
            )
        }
    }

    public func createRule(roomID: String, title: String, content: String, token: String) async throws {
        try await runSavingOperation {
            let rule = try await api.createRule(roomID: roomID, title: title, content: content, token: token)
            rules = ([rule] + rules.filter { $0.id != rule.id }).sortedForRules()
        }
    }

    public func updateRule(roomID: String, ruleID: String, title: String?, content: String?, isActive: Bool?, token: String) async throws {
        try await runSavingOperation {
            let rule = try await api.updateRule(
                roomID: roomID,
                ruleID: ruleID,
                title: title,
                content: content,
                isActive: isActive,
                token: token
            )
            rules = ([rule] + rules.filter { $0.id != ruleID }).sortedForRules()
        }
    }

    public func deleteRule(roomID: String, ruleID: String, token: String) async throws {
        try await runSavingOperation {
            try await api.deleteRule(roomID: roomID, ruleID: ruleID, token: token)
            rules = rules.filter { $0.id != ruleID }
        }
    }

    public func reviewJoinRequest(
        roomID: String,
        requestID: String,
        status: JoinRequestStatus,
        reviewMessage: String?,
        token: String
    ) async throws {
        try await runSavingOperation {
            let request = try await api.reviewJoinRequest(
                roomID: roomID,
                requestID: requestID,
                status: status,
                reviewMessage: reviewMessage,
                token: token
            )
            joinRequests = ([request] + joinRequests.filter { $0.id != requestID })
        }
    }

    public func canManage(currentUserID: String) -> Bool {
        if currentGroup?.ownerID == currentUserID {
            return true
        }
        let role = currentGroup?.currentUserRole
            ?? members.first(where: { $0.userID == currentUserID })?.role
        return role == "owner" || role == "admin"
    }

    public func isOwner(currentUserID: String) -> Bool {
        currentGroup?.ownerID == currentUserID
            || members.first(where: { $0.userID == currentUserID })?.role == "owner"
    }

    private func runLoadingOperation(_ operation: () async throws -> Void) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    private func runSavingOperation<T>(
        _ operation: () async throws -> T,
        onError: (() -> Void)? = nil
    ) async throws -> T {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            return try await operation()
        } catch {
            onError?()
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

private extension GroupSummary {
    init(roomInfo: RoomInfo, currentUserRole: String? = nil, memberCount: Int = 0) {
        self.init(
            roomID: roomInfo.id,
            name: roomInfo.name,
            ownerID: roomInfo.ownerID,
            currentUserRole: currentUserRole,
            memberCount: memberCount,
            avatarURL: roomInfo.avatarURL,
            avatarObjectKey: roomInfo.avatarObjectKey,
            updatedAt: roomInfo.updatedAt ?? Date()
        )
    }

    init(cacheDraft draft: RedCodeGroupDraft) {
        self.init(
            roomID: draft.roomID,
            name: draft.name,
            ownerID: draft.ownerID,
            currentUserRole: draft.currentUserRole,
            memberCount: draft.memberCount,
            avatarURL: draft.avatarURL,
            avatarObjectKey: draft.avatarObjectKey,
            updatedAt: draft.updatedAt
        )
    }

    var cacheDraft: RedCodeGroupDraft {
        RedCodeGroupDraft(
            roomID: roomID,
            name: name,
            ownerID: ownerID,
            currentUserRole: currentUserRole,
            memberCount: memberCount,
            avatarURL: avatarURL,
            avatarObjectKey: avatarObjectKey,
            updatedAt: updatedAt
        )
    }

    func replacing(currentUserRole: String?, memberCount: Int) -> GroupSummary {
        GroupSummary(
            roomID: roomID,
            name: name,
            ownerID: ownerID,
            currentUserRole: currentUserRole,
            memberCount: memberCount,
            avatarURL: avatarURL,
            avatarObjectKey: avatarObjectKey,
            updatedAt: Date()
        )
    }
}

private extension Array where Element == GroupSummary {
    func sortedForGroups() -> [GroupSummary] {
        sorted { $0.updatedAt > $1.updatedAt }
    }
}

private extension Array where Element == RoomMember {
    func sortedForMembers(ownerID: String?) -> [RoomMember] {
        sorted { lhs, rhs in
            if lhs.userID == ownerID { return true }
            if rhs.userID == ownerID { return false }
            if lhs.role != rhs.role {
                return roleRank(lhs.role) < roleRank(rhs.role)
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    private func roleRank(_ role: String) -> Int {
        switch role {
        case "owner":
            0
        case "admin":
            1
        default:
            2
        }
    }
}

private extension Array where Element == GroupRule {
    func sortedForRules() -> [GroupRule] {
        sorted { lhs, rhs in
            if lhs.orderIndex != rhs.orderIndex {
                return lhs.orderIndex < rhs.orderIndex
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}
