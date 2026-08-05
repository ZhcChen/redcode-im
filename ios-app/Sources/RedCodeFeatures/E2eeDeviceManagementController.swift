import Combine
import Foundation
import RedCodeCore

public protocol E2eeDeviceManaging: Sendable {
    func listDevices(token: String) async throws -> [E2eeDeviceInfo]
    func approveDevice(accountID: String, target: E2eeDeviceInfo, token: String) async throws -> E2eeDeviceInfo
    func revokeDevice(deviceID: String, token: String) async throws -> E2eeDeviceInfo
}

extension E2eeDeviceManager: E2eeDeviceManaging {}

@MainActor
public protocol E2eeSessionStateRefreshing: AnyObject {
    var status: E2eeSessionStatus { get }
    func onForeground() async throws
}

extension E2eeSessionLifecycle: E2eeSessionStateRefreshing {}

@MainActor
public final class E2eeDeviceManagementController: ObservableObject {
    @Published public private(set) var devices: [E2eeDeviceInfo] = []
    @Published public private(set) var currentDeviceID: String?
    @Published public private(set) var isE2eeRuntime = false
    @Published public private(set) var isLoading = false
    @Published public private(set) var operatingDeviceID: String?
    @Published public private(set) var errorMessage: String?

    private let currentSession: @MainActor () -> AuthSession?
    private let deviceManager: any E2eeDeviceManaging
    private let lifecycle: any E2eeSessionStateRefreshing
    private let roomIDs: @MainActor (String) async throws -> [String]
    private let roomEventHandler: any E2eeRoomEventHandling

    public init(
        currentSession: @escaping @MainActor () -> AuthSession?,
        deviceManager: any E2eeDeviceManaging,
        lifecycle: any E2eeSessionStateRefreshing,
        roomIDs: @escaping @MainActor (String) async throws -> [String],
        roomEventHandler: any E2eeRoomEventHandling
    ) {
        self.currentSession = currentSession
        self.deviceManager = deviceManager
        self.lifecycle = lifecycle
        self.roomIDs = roomIDs
        self.roomEventHandler = roomEventHandler
    }

    public func refresh() async {
        let status = lifecycle.status
        switch status {
        case .plaintext, .signedOut:
            devices = []
            currentDeviceID = nil
            isE2eeRuntime = false
            isLoading = false
            errorMessage = nil
            return
        case .ready(_, let deviceID):
            currentDeviceID = deviceID
        case .blocked:
            currentDeviceID = nil
        }

        isE2eeRuntime = true
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let session = try requireSession()
            devices = try await deviceManager.listDevices(token: session.token).sortedForManagement()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func approve(_ device: E2eeDeviceInfo) async {
        await operate(deviceID: device.id) {
            let session = try self.requireSession()
            _ = try await self.deviceManager.approveDevice(
                accountID: session.user.id,
                target: device,
                token: session.token
            )
        }
    }

    public func revoke(_ device: E2eeDeviceInfo) async {
        await operate(deviceID: device.id) {
            let session = try self.requireSession()
            let currentDeviceID: String? = if case .ready(_, let deviceID) = self.lifecycle.status {
                deviceID
            } else {
                nil
            }
            _ = try await self.deviceManager.revokeDevice(deviceID: device.id, token: session.token)
            if device.id == currentDeviceID {
                let refreshError: Error?
                do {
                    try await self.lifecycle.onForeground()
                    refreshError = nil
                } catch {
                    refreshError = error
                }
                if case .ready = self.lifecycle.status {
                    throw refreshError ?? E2eeSessionLifecycleError("当前 E2EE 设备撤销后仍处于 Ready 状态")
                }
            } else {
                var firstReconcileError: Error?
                for roomID in try await self.roomIDs(session.token) {
                    do {
                        try await self.roomEventHandler.reconcile(roomID: roomID)
                    } catch {
                        firstReconcileError = firstReconcileError ?? error
                    }
                }
                if let firstReconcileError {
                    throw firstReconcileError
                }
            }
        }
    }

    private func operate(deviceID: String, operation: () async throws -> Void) async {
        guard operatingDeviceID == nil else { return }
        operatingDeviceID = deviceID
        errorMessage = nil
        let operationError: Error?
        do {
            try await operation()
            operationError = nil
        } catch {
            operationError = error
        }
        await refresh()
        operatingDeviceID = nil
        if let operationError {
            errorMessage = operationError.localizedDescription
        }
    }

    private func requireSession() throws -> AuthSession {
        guard let session = currentSession(), session.isValid else {
            throw E2eeSessionLifecycleError("E2EE 认证会话缺失")
        }
        if case .ready(let accountID, _) = lifecycle.status, session.user.id != accountID {
            throw E2eeSessionLifecycleError("E2EE 账号与认证会话不匹配")
        }
        return session
    }
}

private extension Array where Element == E2eeDeviceInfo {
    func sortedForManagement() -> [E2eeDeviceInfo] {
        sorted {
            if ($0.status == "pending_approval") != ($1.status == "pending_approval") {
                return $0.status == "pending_approval"
            }
            let labelOrder = $0.deviceLabel.localizedCaseInsensitiveCompare($1.deviceLabel)
            return labelOrder == .orderedSame ? $0.id < $1.id : labelOrder == .orderedAscending
        }
    }
}
