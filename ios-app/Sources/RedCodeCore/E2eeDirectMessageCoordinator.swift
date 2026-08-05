import Foundation

public struct E2eeDirectMessageError: Error, Equatable, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
}

public enum E2eeMessageSource: Equatable, Sendable { case webSocket, history }

public struct E2eeIncomingMessage: Sendable {
    public let messageID: String; public let roomID: String; public let ciphertext: Data?
    public let plaintext: String?; public let source: E2eeMessageSource
    public init(messageID: String, roomID: String, ciphertext: Data?, plaintext: String? = nil, source: E2eeMessageSource) {
        self.messageID = messageID; self.roomID = roomID; self.ciphertext = ciphertext; self.plaintext = plaintext; self.source = source
    }
}

public struct E2eeAttachmentPart: Equatable, Sendable {
    public let partKey: String
    public let objectKey: String
    public let name: String
    public let mimeType: String
    public let size: Int64
    public let partPosition: UInt32
    public let nonce: Data
    public let dek: Data

    public init(
        partKey: String,
        objectKey: String,
        name: String,
        mimeType: String,
        size: Int64,
        partPosition: UInt32,
        nonce: Data,
        dek: Data
    ) {
        self.partKey = partKey
        self.objectKey = objectKey
        self.name = name
        self.mimeType = mimeType
        self.size = size
        self.partPosition = partPosition
        self.nonce = nonce
        self.dek = dek
    }
}

public struct E2eeDecryptedMessage: Equatable, Sendable {
    public let messageID: String; public let roomID: String; public let text: String; public let epoch: UInt64; public let encrypted: Bool
    public let attachmentParts: [E2eeAttachmentPart]

    public init(messageID: String, roomID: String, text: String, epoch: UInt64, encrypted: Bool, attachmentParts: [E2eeAttachmentPart] = []) {
        self.messageID = messageID
        self.roomID = roomID
        self.text = text
        self.epoch = epoch
        self.encrypted = encrypted
        self.attachmentParts = attachmentParts
    }
}

public protocol E2eeDirectSessionCore: Sendable {
    func createGroup(state: Data, roomID: String) throws -> E2eeCommandResult
    func addMember(state: Data, roomID: String, keyPackage: Data) throws -> E2eeCommandResult
    func joinGroup(state: Data, welcome: Data) throws -> E2eeCommandResult
    func encrypt(state: Data, roomID: String, plaintext: Data) throws -> E2eeCommandResult
    func decrypt(state: Data, roomID: String, ciphertext: Data) throws -> E2eeCommandResult
    func processCommit(state: Data, roomID: String, commit: Data) throws -> E2eeCommandResult
    func removeMember(state: Data, roomID: String, identity: String) throws -> E2eeCommandResult
    func listMembers(state: Data, roomID: String) throws -> E2eeCommandResult
}

extension E2eeCommandClient: E2eeDirectSessionCore {}

private struct DirectMessageMetadata: Codable, Sendable {
    var trustedIdentityFingerprints: [String: String] = [:]
    var processedMessageIDs: [String: [String]] = [:]
    var pendingApplication: PendingApplication?
    var attachmentPartsByMessageID: [String: [StoredAttachmentPart]]?
    var attachmentMessageIDs: [String]?
}

private struct PendingApplication: Codable, Sendable {
    let roomID: String; let senderDeviceID: String; let epoch: UInt64
    let ciphertext: String; let nextState: String; let idempotencyKey: String; let controlMessageID: String
    let attachmentParts: [StoredAttachmentPart]?
}

private struct StoredAttachmentPart: Codable, Sendable {
    let partKey: String
    let objectKey: String
    let name: String
    let mimeType: String
    let size: Int64
    let partPosition: UInt32
    let nonce: String
    let dek: String
}

private struct ApplicationPayload: Codable, Sendable {
    let version: Int
    let type: String
    let text: String?
    let parts: [StoredAttachmentPart]?
}

public actor E2eeDirectMessageCoordinator {
    private let storage: any E2eeDirectMessageStorage
    private let lifecycle: any E2eeDirectDeviceLifecycle
    private let api: any E2eeMLSApi
    private let core: any E2eeDirectSessionCore
    private let newID: @Sendable () -> String

    public init(storage: any E2eeDirectMessageStorage, lifecycle: any E2eeDirectDeviceLifecycle, api: any E2eeMLSApi, core: any E2eeDirectSessionCore = E2eeCommandClient(), newID: @escaping @Sendable () -> String = { UUID().uuidString }) {
        self.storage = storage; self.lifecycle = lifecycle; self.api = api; self.core = core; self.newID = newID
    }

    public func sendText(accountID: String, deviceLabel: String, roomID: String, peerUserID: String, text: String, token: String) async throws -> String {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw E2eeDirectMessageError("加密消息内容不能为空") }
        return try await prepareAndSend(
            accountID: accountID,
            deviceLabel: deviceLabel,
            roomID: roomID,
            peerUserID: peerUserID,
            payload: ApplicationPayload(version: 1, type: "text", text: text, parts: nil),
            attachmentParts: [],
            token: token
        )
    }

    public func sendAttachment(
        accountID: String,
        deviceLabel: String,
        roomID: String,
        peerUserID: String?,
        parts: [E2eeAttachmentPart],
        text: String?,
        token: String
    ) async throws -> String {
        guard !parts.isEmpty else { throw E2eeDirectMessageError("E2EE 附件列表不能为空") }
        try parts.forEach(requireValidAttachmentPart)
        let stored = parts.map(StoredAttachmentPart.init)
        let text = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await prepareAndSend(
            accountID: accountID,
            deviceLabel: deviceLabel,
            roomID: roomID,
            peerUserID: peerUserID,
            payload: ApplicationPayload(
                version: 1,
                type: "attachment",
                text: text?.isEmpty == false ? text : nil,
                parts: stored
            ),
            attachmentParts: stored,
            token: token
        )
    }

    private func prepareAndSend(
        accountID: String,
        deviceLabel: String,
        roomID: String,
        peerUserID: String?,
        payload: ApplicationPayload,
        attachmentParts: [StoredAttachmentPart],
        token: String
    ) async throws -> String {
        let profile = try await lifecycle.ensureReady(accountID: accountID, deviceLabel: deviceLabel, token: token)
        try requireActive(profile)
        let peerUserIDs = if let peerUserID {
            [peerUserID]
        } else {
            try await api.listRoomMemberDevices(roomID: roomID, token: token)
                .map(\.userID)
                .filter { $0 != accountID }
        }
        for peerUserID in Set(peerUserIDs) {
            try await verifyIdentity(accountID: accountID, peerUserID: peerUserID, token: token)
        }
        try await syncControls(accountID: accountID, roomID: roomID, profile: profile, token: token)
        try await reconcileGroup(accountID: accountID, roomID: roomID, profile: profile, token: token)
        guard var state = try await storage.readState(accountID: accountID) else { throw E2eeDirectMessageError("E2EE 协议状态缺失") }
        var epoch = try await api.getRoomEpoch(roomID: roomID, token: token)
        if epoch.activeEpoch == 0 {
            state = try await bootstrap(accountID: accountID, roomID: roomID, profile: profile, state: state, revision: epoch.membershipRevision, token: token)
            epoch = try await api.getRoomEpoch(roomID: roomID, token: token)
        }
        guard epoch.status == "active" else { throw E2eeDirectMessageError("房间 E2EE 状态尚未就绪") }
        guard let latestProfile = try await storage.readProfile(accountID: accountID), let commitID = latestProfile.lastCommitMessageIds[roomID] else { throw E2eeDirectMessageError("房间缺少当前 E2EE Commit 索引") }
        let plaintext = try JSONEncoder().encode(payload)
        let encrypted = try core.encrypt(state: state, roomID: roomID, plaintext: plaintext)
        let encryptedEpoch = try encrypted.epoch(2)
        guard encryptedEpoch == epoch.activeEpoch else { throw E2eeDirectMessageError("本地 E2EE epoch 已过期") }
        var metadata = try await readMetadata(accountID)
        guard metadata.pendingApplication == nil else { throw E2eeDirectMessageError("存在待手动重试的 E2EE 消息") }
        metadata.pendingApplication = PendingApplication(
            roomID: roomID, senderDeviceID: profile.deviceId, epoch: encryptedEpoch,
            ciphertext: try encrypted.field(1).base64EncodedString(), nextState: try encrypted.field(0).base64EncodedString(),
            idempotencyKey: newID(), controlMessageID: commitID,
            attachmentParts: attachmentParts.isEmpty ? nil : attachmentParts
        )
        try await writeMetadata(accountID, metadata)
        return try await resumePending(accountID: accountID, token: token)
    }

    public func retryPendingSend(accountID: String, token: String) async throws -> String {
        try await resumePending(accountID: accountID, token: token)
    }

    public func hasPendingSend(accountID: String) async throws -> Bool {
        try await readMetadata(accountID).pendingApplication != nil
    }

    public func decryptIncoming(accountID: String, deviceLabel: String, input: E2eeIncomingMessage, token: String) async throws -> E2eeDecryptedMessage {
        guard !input.messageID.isEmpty, !input.roomID.isEmpty else { throw E2eeDirectMessageError("E2EE 消息标识无效") }
        var metadata = try await readMetadata(accountID)
        guard !(metadata.processedMessageIDs[input.roomID] ?? []).contains(input.messageID) else { throw E2eeDirectMessageError("E2EE 消息已处理") }
        guard let ciphertext = input.ciphertext else {
            guard let text = input.plaintext, !text.isEmpty else { throw E2eeDirectMessageError("历史消息内容为空") }
            remember(input.messageID, roomID: input.roomID, metadata: &metadata)
            try await writeMetadata(accountID, metadata)
            return E2eeDecryptedMessage(messageID: input.messageID, roomID: input.roomID, text: text, epoch: 0, encrypted: false)
        }
        guard !ciphertext.isEmpty else { throw E2eeDirectMessageError("E2EE 密文不能为空") }
        let profile = try await lifecycle.ensureReady(accountID: accountID, deviceLabel: deviceLabel, token: token)
        try requireActive(profile)
        try await syncControls(accountID: accountID, roomID: input.roomID, profile: profile, token: token)
        guard let state = try await storage.readState(accountID: accountID) else { throw E2eeDirectMessageError("E2EE 协议状态缺失") }
        let decrypted: E2eeCommandResult
        do { decrypted = try core.decrypt(state: state, roomID: input.roomID, ciphertext: ciphertext) }
        catch { throw E2eeDirectMessageError("E2EE 消息解密失败") }
        guard let payload = try? JSONDecoder().decode(ApplicationPayload.self, from: decrypted.field(1)),
              payload.version == 1,
              ["text", "attachment"].contains(payload.type) else {
            throw E2eeDirectMessageError("E2EE 消息负载格式无效")
        }
        let attachmentParts: [E2eeAttachmentPart]
        if payload.type == "attachment" {
            guard let storedParts = payload.parts, !storedParts.isEmpty else {
                throw E2eeDirectMessageError("E2EE 附件负载为空")
            }
            attachmentParts = try storedParts.map(E2eeAttachmentPart.init)
            try attachmentParts.forEach(requireValidAttachmentPart)
            metadata = rememberAttachmentParts(storedParts, messageID: input.messageID, metadata: metadata)
        } else {
            guard let text = payload.text, !text.isEmpty, payload.parts?.isEmpty != false else {
                throw E2eeDirectMessageError("E2EE 消息负载格式无效")
            }
            attachmentParts = []
        }
        try await storage.writeState(accountID: accountID, state: decrypted.field(0))
        remember(input.messageID, roomID: input.roomID, metadata: &metadata)
        try await writeMetadata(accountID, metadata)
        return E2eeDecryptedMessage(
            messageID: input.messageID,
            roomID: input.roomID,
            text: payload.text ?? "[加密附件]",
            epoch: try decrypted.epoch(2),
            encrypted: true,
            attachmentParts: attachmentParts
        )
    }

    private func verifyIdentity(accountID: String, peerUserID: String, token: String) async throws {
        let identity = try await api.fetchIdentity(userID: peerUserID, token: token)
        guard identity.protocolVersion == 1, identity.fingerprint.count >= 16 else { throw E2eeDirectMessageError("E2EE 对端身份无效") }
        var metadata = try await readMetadata(accountID)
        let fingerprint = identity.fingerprint.base64EncodedString()
        if let previous = metadata.trustedIdentityFingerprints[peerUserID], previous != fingerprint { throw E2eeDirectMessageError("对端 E2EE 身份已变化，发送已阻断") }
        if metadata.trustedIdentityFingerprints[peerUserID] == nil {
            metadata.trustedIdentityFingerprints[peerUserID] = fingerprint
            try await writeMetadata(accountID, metadata)
        }
    }

    private func resumePending(accountID: String, token: String) async throws -> String {
        var metadata = try await readMetadata(accountID)
        guard let pending = metadata.pendingApplication, let ciphertext = Data(base64Encoded: pending.ciphertext), let nextState = Data(base64Encoded: pending.nextState) else { throw E2eeDirectMessageError("没有待重试的 E2EE 消息") }
        let id = try await api.sendEncryptedMessage(E2eeEncryptedMessageRequest(roomID: pending.roomID, senderDeviceID: pending.senderDeviceID, epoch: pending.epoch, ciphertext: ciphertext, idempotencyKey: pending.idempotencyKey, controlMessageID: pending.controlMessageID), token: token)
        try await storage.writeState(accountID: accountID, state: nextState)
        metadata.pendingApplication = nil
        if let parts = pending.attachmentParts, !parts.isEmpty {
            metadata = rememberAttachmentParts(parts, messageID: id, metadata: metadata)
        }
        try await writeMetadata(accountID, metadata)
        return id
    }

    public func findAttachmentPart(accountID: String, messageID: String, objectKey: String) async throws -> E2eeAttachmentPart? {
        guard let stored = try await readMetadata(accountID).attachmentPartsByMessageID?[messageID]?
            .first(where: { $0.objectKey == objectKey }) else {
            return nil
        }
        let part = try E2eeAttachmentPart(stored)
        try requireValidAttachmentPart(part)
        return part
    }

    private func bootstrap(accountID: String, roomID: String, profile: E2eeDeviceProfile, state initial: Data, revision: UInt64, token: String) async throws -> Data {
        let peers = try await api.listRoomMemberDevices(roomID: roomID, token: token).filter { $0.userID != accountID }
        guard !peers.contains(where: { $0.devices.isEmpty }) else { throw E2eeDirectMessageError("房间存在没有可用 E2EE 设备的成员") }
        let devices = peers.flatMap(\.devices)
        guard !devices.isEmpty else { throw E2eeDirectMessageError("房间没有其他可用的 E2EE 设备") }
        var state = try core.createGroup(state: initial, roomID: roomID).field(0)
        var lastCommitID = ""
        for device in devices {
            let claimed = try await api.claimKeyPackage(roomID: roomID, consumerDeviceID: profile.deviceId, targetDeviceID: device.id, token: token)
            let added = try core.addMember(state: state, roomID: roomID, keyPackage: claimed.keyPackage)
            state = try added.field(0); let epoch = try added.epoch(3); lastCommitID = newID()
            try await api.submitControlMessage(E2eeOutgoingControlMessage(roomID: roomID, messageID: lastCommitID, epoch: epoch, membershipRevision: revision, senderDeviceID: profile.deviceId, contentType: "commit", envelope: try added.field(1)), token: token)
            try await api.submitControlMessage(E2eeOutgoingControlMessage(roomID: roomID, messageID: newID(), epoch: epoch, membershipRevision: revision, senderDeviceID: profile.deviceId, contentType: "welcome", envelope: try added.field(2), recipientDeviceID: device.id), token: token)
        }
        try await storage.writeState(accountID: accountID, state: state)
        var profile = profile; profile.lastCommitMessageIds[roomID] = lastCommitID
        try await storage.writeProfile(accountID: accountID, profile: profile)
        return state
    }

    public func reconcileGroup(accountID: String, roomID: String, token: String) async throws {
        guard let profile = try await storage.readProfile(accountID: accountID) else { throw E2eeDirectMessageError("E2EE 设备档案缺失") }
        try await reconcileGroup(accountID: accountID, roomID: roomID, profile: profile, token: token)
    }

    private func reconcileGroup(accountID: String, roomID: String, profile: E2eeDeviceProfile, token: String) async throws {
        let roomEpoch = try await api.getRoomEpoch(roomID: roomID, token: token)
        guard roomEpoch.status == "rekey_required", profile.lastCommitMessageIds[roomID] != nil else { return }
        guard var state = try await storage.readState(accountID: accountID) else { throw E2eeDirectMessageError("E2EE 协议状态缺失") }
        let serverMembers = Set(try await api.listRoomMemberDevices(roomID: roomID, token: token).flatMap { member in member.devices.map { "\(member.userID)/\($0.id)" } })
        let localMembers = try decodeMembers(core.listMembers(state: state, roomID: roomID).field(0))
        var lastCommitID: String?
        for identity in localMembers.subtracting(serverMembers) {
            let removed = try core.removeMember(state: state, roomID: roomID, identity: identity)
            state = try removed.field(0); lastCommitID = newID()
            try await api.submitControlMessage(E2eeOutgoingControlMessage(roomID: roomID, messageID: lastCommitID!, epoch: try removed.epoch(2), membershipRevision: roomEpoch.membershipRevision, senderDeviceID: profile.deviceId, contentType: "commit", envelope: try removed.field(1)), token: token)
        }
        for identity in serverMembers.subtracting(localMembers) {
            let deviceID = String(identity.split(separator: "/", maxSplits: 1)[1])
            let claimed = try await api.claimKeyPackage(roomID: roomID, consumerDeviceID: profile.deviceId, targetDeviceID: deviceID, token: token)
            let added = try core.addMember(state: state, roomID: roomID, keyPackage: claimed.keyPackage)
            state = try added.field(0); let epoch = try added.epoch(3); lastCommitID = newID()
            try await api.submitControlMessage(E2eeOutgoingControlMessage(roomID: roomID, messageID: lastCommitID!, epoch: epoch, membershipRevision: roomEpoch.membershipRevision, senderDeviceID: profile.deviceId, contentType: "commit", envelope: try added.field(1)), token: token)
            try await api.submitControlMessage(E2eeOutgoingControlMessage(roomID: roomID, messageID: newID(), epoch: epoch, membershipRevision: roomEpoch.membershipRevision, senderDeviceID: profile.deviceId, contentType: "welcome", envelope: try added.field(2), recipientDeviceID: deviceID), token: token)
        }
        if let lastCommitID {
            try await storage.writeState(accountID: accountID, state: state)
            var profile = profile; profile.lastCommitMessageIds[roomID] = lastCommitID
            try await storage.writeProfile(accountID: accountID, profile: profile)
        }
    }

    private func decodeMembers(_ data: Data) throws -> Set<String> {
        var offset = 0
        func readUInt32() throws -> Int {
            guard offset + 4 <= data.count else { throw E2eeDirectMessageError("E2EE 成员列表已截断") }
            let value = data[offset..<offset + 4].withUnsafeBytes { Int($0.loadUnaligned(as: UInt32.self).bigEndian) }
            offset += 4; return value
        }
        let count = try readUInt32(); var members = Set<String>()
        for _ in 0..<count {
            let length = try readUInt32(); guard offset + length <= data.count, let value = String(data: data[offset..<offset + length], encoding: .utf8) else { throw E2eeDirectMessageError("E2EE 成员列表已截断") }
            members.insert(value); offset += length
        }
        guard offset == data.count else { throw E2eeDirectMessageError("E2EE 成员列表包含多余数据") }
        return members
    }

    private func syncControls(accountID: String, roomID: String, profile: E2eeDeviceProfile, token: String) async throws {
        guard var state = try await storage.readState(accountID: accountID) else { throw E2eeDirectMessageError("E2EE 协议状态缺失") }
        let controls = try await api.listControlMessages(roomID: roomID, deviceID: profile.deviceId, afterSequence: profile.lastControlSequences[roomID] ?? 0, token: token)
        guard !controls.isEmpty else { return }
        var profile = profile; var index = 0
        if profile.lastCommitMessageIds[roomID] == nil {
            guard let welcomeIndex = controls.firstIndex(where: { $0.contentType == "welcome" }) else { return }
            let welcome = controls[welcomeIndex]
            guard let commit = controls[...welcomeIndex].last(where: { $0.contentType == "commit" && $0.epoch == welcome.epoch }) else { throw E2eeDirectMessageError("Welcome 缺少对应的 E2EE Commit") }
            let joined = try core.joinGroup(state: state, welcome: welcome.envelope)
            guard try joined.epoch(1) == welcome.epoch else { throw E2eeDirectMessageError("Welcome epoch 与本地状态不一致") }
            state = try joined.field(0); profile.lastCommitMessageIds[roomID] = commit.id; index = welcomeIndex + 1
        }
        for control in controls.dropFirst(index) {
            guard control.contentType == "commit" else { throw E2eeDirectMessageError("已入群设备收到意外 Welcome") }
            let committed = try core.processCommit(state: state, roomID: roomID, commit: control.envelope)
            guard try committed.epoch(1) == control.epoch else { throw E2eeDirectMessageError("Commit epoch 与本地状态不一致") }
            state = try committed.field(0); profile.lastCommitMessageIds[roomID] = control.id
        }
        profile.lastControlSequences[roomID] = controls.last!.sequenceNumber
        try await storage.writeState(accountID: accountID, state: state)
        try await storage.writeProfile(accountID: accountID, profile: profile)
        for control in controls { try await api.consumeControlMessage(roomID: roomID, messageID: control.id, deviceID: profile.deviceId, token: token) }
    }

    private func requireActive(_ profile: E2eeDeviceProfile) throws { if profile.deviceStatus != "active" { throw E2eeDirectMessageError("E2EE 设备未批准或已撤销") } }
    private func readMetadata(_ accountID: String) async throws -> DirectMessageMetadata {
        guard let data = try await storage.readMetadata(accountID: accountID, key: Self.metadataKey) else { return DirectMessageMetadata() }
        guard let metadata = try? JSONDecoder().decode(DirectMessageMetadata.self, from: data) else { throw E2eeDirectMessageError("E2EE 单聊元数据已损坏") }
        return metadata
    }
    private func writeMetadata(_ accountID: String, _ metadata: DirectMessageMetadata) async throws { try await storage.writeMetadata(accountID: accountID, key: Self.metadataKey, data: JSONEncoder().encode(metadata)) }
    private func remember(_ messageID: String, roomID: String, metadata: inout DirectMessageMetadata) { metadata.processedMessageIDs[roomID] = Array(((metadata.processedMessageIDs[roomID] ?? []) + [messageID]).suffix(512)) }
    private func rememberAttachmentParts(_ parts: [StoredAttachmentPart], messageID: String, metadata: DirectMessageMetadata) -> DirectMessageMetadata {
        var metadata = metadata
        var indexed = metadata.attachmentPartsByMessageID ?? [:]
        var messageIDs = metadata.attachmentMessageIDs ?? indexed.keys.sorted()
        indexed[messageID] = parts
        messageIDs.removeAll { $0 == messageID }
        messageIDs.append(messageID)
        if messageIDs.count > 512 {
            let removed = messageIDs.prefix(messageIDs.count - 512)
            for removedMessageID in removed {
                indexed.removeValue(forKey: removedMessageID)
            }
            messageIDs.removeFirst(messageIDs.count - 512)
        }
        metadata.attachmentPartsByMessageID = indexed
        metadata.attachmentMessageIDs = messageIDs
        return metadata
    }
    private func requireValidAttachmentPart(_ part: E2eeAttachmentPart) throws {
        guard UUID(uuidString: part.partKey) != nil,
              !part.objectKey.isEmpty,
              !part.name.isEmpty,
              !part.mimeType.isEmpty,
              part.size >= 0,
              part.nonce.count == 12,
              part.dek.count == 32 else {
            throw E2eeDirectMessageError("E2EE 附件密钥参数不完整")
        }
    }
    private static let metadataKey = "direct-message"
}

private extension StoredAttachmentPart {
    init(_ part: E2eeAttachmentPart) {
        self.init(
            partKey: part.partKey,
            objectKey: part.objectKey,
            name: part.name,
            mimeType: part.mimeType,
            size: part.size,
            partPosition: part.partPosition,
            nonce: part.nonce.base64EncodedString(),
            dek: part.dek.base64EncodedString()
        )
    }
}

private extension E2eeAttachmentPart {
    init(_ stored: StoredAttachmentPart) throws {
        guard let nonce = Data(base64Encoded: stored.nonce),
              let dek = Data(base64Encoded: stored.dek) else {
            throw E2eeDirectMessageError("E2EE 附件密钥材料已损坏")
        }
        self.init(
            partKey: stored.partKey,
            objectKey: stored.objectKey,
            name: stored.name,
            mimeType: stored.mimeType,
            size: stored.size,
            partPosition: stored.partPosition,
            nonce: nonce,
            dek: dek
        )
    }
}
