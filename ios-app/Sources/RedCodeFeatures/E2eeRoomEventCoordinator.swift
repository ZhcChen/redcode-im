import Foundation
import RedCodeCore

@MainActor
public protocol E2eeRoomEventHandling: AnyObject {
    func reconcile(roomID: String) async throws
}

@MainActor
public final class PlaintextE2eeRoomEventHandler: E2eeRoomEventHandling {
    public static let shared = PlaintextE2eeRoomEventHandler()

    private init() {}

    public func reconcile(roomID: String) async throws {}
}

public protocol E2eeGroupReconciling: Sendable {
    func reconcileGroup(accountID: String, roomID: String, token: String) async throws
}

extension E2eeDirectMessageCoordinator: E2eeGroupReconciling {}

@MainActor
public final class E2eeRoomEventCoordinator: E2eeRoomEventHandling {
    private struct InFlightReconcile {
        let id: UUID
        let task: Task<Void, Error>
    }

    private let sessionStatus: E2eeSessionLifecycle
    private let currentSession: @MainActor () -> AuthSession?
    private let coordinator: any E2eeGroupReconciling
    private var inFlightByRoomID: [String: InFlightReconcile] = [:]

    public init(
        sessionStatus: E2eeSessionLifecycle,
        currentSession: @escaping @MainActor () -> AuthSession?,
        coordinator: any E2eeGroupReconciling
    ) {
        self.sessionStatus = sessionStatus
        self.currentSession = currentSession
        self.coordinator = coordinator
    }

    public func reconcile(roomID: String) async throws {
        let roomID = roomID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !roomID.isEmpty else {
            throw E2eeSessionLifecycleError("E2EE 房间标识不能为空")
        }

        switch sessionStatus.status {
        case .plaintext:
            return
        case .signedOut:
            throw E2eeSessionLifecycleError("E2EE 会话未登录")
        case .blocked(let message):
            throw E2eeSessionLifecycleError(message)
        case .ready(let accountID, _):
            guard let session = currentSession() else {
                throw E2eeSessionLifecycleError("E2EE 认证会话缺失")
            }
            guard session.user.id == accountID else {
                throw E2eeSessionLifecycleError("E2EE 账号与认证会话不匹配")
            }
            let token = session.token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else {
                throw E2eeSessionLifecycleError("E2EE 认证 token 不能为空")
            }
            if let inFlight = inFlightByRoomID[roomID] {
                try await inFlight.task.value
                return
            }
            let id = UUID()
            let coordinator = self.coordinator
            let task = Task {
                try await coordinator.reconcileGroup(accountID: accountID, roomID: roomID, token: token)
            }
            inFlightByRoomID[roomID] = InFlightReconcile(id: id, task: task)
            defer {
                if inFlightByRoomID[roomID]?.id == id {
                    inFlightByRoomID.removeValue(forKey: roomID)
                }
            }
            try await task.value
        }
    }
}
