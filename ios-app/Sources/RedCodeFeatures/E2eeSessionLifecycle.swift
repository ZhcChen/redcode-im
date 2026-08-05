import Combine
import Foundation
import RedCodeCore
import RedCodeNetworking

public enum E2eeSessionStatus: Equatable, Sendable {
    case signedOut
    case plaintext
    case ready(accountID: String, deviceID: String)
    case blocked(message: String)
}

public protocol E2eeRuntimeSettingsProviding: Sendable {
    func fetchMessageRuntime() async throws -> MessageRuntimeSettings
}

public struct SettingsE2eeRuntimeProvider: E2eeRuntimeSettingsProviding {
    private let settings: any SettingsAPIService

    public init(settings: any SettingsAPIService) {
        self.settings = settings
    }

    public func fetchMessageRuntime() async throws -> MessageRuntimeSettings {
        try await settings.fetchGeneralSettings().messageRuntime
    }
}

public protocol E2eeAppDeviceLifecycle: Sendable {
    func ensureReady(accountID: String, deviceLabel: String, token: String) async throws -> E2eeDeviceProfile
    func topUpKeyPackages(accountID: String, token: String) async throws -> Int
}

extension E2eeDeviceLifecycle: E2eeAppDeviceLifecycle {}

public protocol E2eeAccountSecureStateClearing: Sendable {
    func delete(accountID: String) async throws
}

public struct E2eeAccountSecureStateCleaner: E2eeAccountSecureStateClearing {
    private let operation: @Sendable (String) async throws -> Void

    public init(operation: @escaping @Sendable (String) async throws -> Void) {
        self.operation = operation
    }

    public func delete(accountID: String) async throws {
        try await operation(accountID)
    }
}

public struct E2eeSessionLifecycleError: Error, Equatable, LocalizedError, Sendable {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? { message }
}

@MainActor
public final class E2eeSessionLifecycle: ObservableObject {
    @Published public private(set) var status: E2eeSessionStatus = .signedOut

    private struct ActiveSession: Equatable, Sendable {
        let accountID: String
        let token: String
    }

    private let settings: any E2eeRuntimeSettingsProviding
    private let devices: any E2eeAppDeviceLifecycle
    private let secureState: any E2eeAccountSecureStateClearing
    private let deviceLabel: String
    private var activeSession: ActiveSession?
    private var preparationTask: Task<E2eeSessionStatus, Error>?
    private var preparationID: UUID?

    public init(
        settings: any E2eeRuntimeSettingsProviding,
        devices: any E2eeAppDeviceLifecycle,
        secureState: any E2eeAccountSecureStateClearing,
        deviceLabel: String
    ) {
        self.settings = settings
        self.devices = devices
        self.secureState = secureState
        self.deviceLabel = deviceLabel
    }

    public func onAuthenticated(session: AuthSession) async throws {
        let accountID = session.user.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = session.token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accountID.isEmpty else {
            throw E2eeSessionLifecycleError("E2EE 账号标识不能为空")
        }
        guard !token.isEmpty else {
            throw E2eeSessionLifecycleError("E2EE 认证 token 不能为空")
        }

        if let previous = activeSession, previous.accountID != accountID {
            cancelPreparation()
            activeSession = nil
            do {
                try await secureState.delete(accountID: previous.accountID)
            } catch {
                status = .blocked(message: Self.message(for: error))
                throw error
            }
        }
        let current = ActiveSession(accountID: accountID, token: token)
        activeSession = current
        try await refreshAndPrepare(current)
    }

    public func onForeground() async throws {
        guard let activeSession else { return }
        try await refreshAndPrepare(activeSession)
    }

    public func onLogout() async throws {
        let accountID = activeSession?.accountID
        activeSession = nil
        cancelPreparation()
        status = .signedOut
        if let accountID {
            try await secureState.delete(accountID: accountID)
        }
    }

    public func requireE2eeReady() throws -> (accountID: String, deviceID: String) {
        guard case .ready(let accountID, let deviceID) = status else {
            let message = if case .blocked(let message) = status {
                message
            } else {
                "当前设备未进入 E2EE ready 状态"
            }
            throw E2eeSessionLifecycleError(message)
        }
        return (accountID, deviceID)
    }

    private func refreshAndPrepare(_ session: ActiveSession) async throws {
        if let preparationTask {
            try await apply(preparationTask, to: session)
            return
        }

        let taskID = UUID()
        let settings = self.settings
        let devices = self.devices
        let deviceLabel = self.deviceLabel
        let task = Task<E2eeSessionStatus, Error> {
            let runtime = try await settings.fetchMessageRuntime()
            try Self.validate(runtime)
            guard runtime.isE2EE else { return .plaintext }

            let profile = try await devices.ensureReady(
                accountID: session.accountID,
                deviceLabel: deviceLabel,
                token: session.token
            )
            guard profile.deviceStatus == "active" else {
                throw E2eeSessionLifecycleError(
                    "E2EE 设备状态为 \(profile.deviceStatus)，拒绝进入加密消息链"
                )
            }
            _ = try await devices.topUpKeyPackages(accountID: session.accountID, token: session.token)
            return .ready(accountID: session.accountID, deviceID: profile.deviceId)
        }
        preparationTask = task
        preparationID = taskID
        defer {
            if preparationID == taskID {
                preparationTask = nil
                preparationID = nil
            }
        }
        try await apply(task, to: session)
    }

    private func apply(_ task: Task<E2eeSessionStatus, Error>, to session: ActiveSession) async throws {
        do {
            let nextStatus = try await task.value
            guard activeSession == session else { return }
            status = nextStatus
        } catch {
            guard activeSession == session else { throw error }
            status = .blocked(message: Self.message(for: error))
            throw error
        }
    }

    private func cancelPreparation() {
        preparationTask?.cancel()
        preparationTask = nil
        preparationID = nil
    }

    private static func validate(_ runtime: MessageRuntimeSettings) throws {
        guard ["persist", "relay_only"].contains(runtime.serverStorageMode) else {
            throw E2eeSessionLifecycleError("未知的消息存储模式：\(runtime.serverStorageMode)")
        }
        guard ["plaintext", "e2ee"].contains(runtime.contentAuditMode) else {
            throw E2eeSessionLifecycleError("未知的消息审计模式：\(runtime.contentAuditMode)")
        }
    }

    private static func message(for error: Error) -> String {
        if let error = error as? E2eeSessionLifecycleError { return error.message }
        if let error = error as? E2eeDeviceNotReadyError { return error.message }
        return error.localizedDescription
    }
}
