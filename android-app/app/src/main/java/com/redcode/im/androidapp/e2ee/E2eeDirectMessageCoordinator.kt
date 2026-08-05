package com.redcode.im.androidapp.e2ee

import java.util.Base64
import java.util.UUID
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class E2eeDirectMessageException(message: String, cause: Throwable? = null) : Exception(message, cause)

enum class E2eeMessageSource { WebSocket, History }

data class E2eeIncomingMessage(
    val messageId: String,
    val roomId: String,
    val ciphertext: ByteArray?,
    val plaintext: String? = null,
    val source: E2eeMessageSource,
)

data class E2eeDecryptedMessage(val messageId: String, val roomId: String, val text: String, val epoch: Long, val encrypted: Boolean)

interface E2eeIncomingDecryptor {
    suspend fun decryptIncoming(
        accountId: String,
        deviceLabel: String,
        input: E2eeIncomingMessage,
        token: String,
    ): E2eeDecryptedMessage
}

interface E2eeTextSender {
    suspend fun sendText(
        accountId: String,
        deviceLabel: String,
        roomId: String,
        peerUserId: String?,
        text: String,
        token: String,
    ): String

    suspend fun retryPendingSend(accountId: String, token: String): String

    suspend fun hasPendingSend(accountId: String): Boolean
}

interface E2eeDirectSessionCore {
    fun createGroup(state: ByteArray, roomId: String): E2eeCommandResult
    fun addMember(state: ByteArray, roomId: String, keyPackage: ByteArray): E2eeCommandResult
    fun joinGroup(state: ByteArray, welcome: ByteArray): E2eeCommandResult
    fun encrypt(state: ByteArray, roomId: String, plaintext: ByteArray): E2eeCommandResult
    fun decrypt(state: ByteArray, roomId: String, ciphertext: ByteArray): E2eeCommandResult
    fun processCommit(state: ByteArray, roomId: String, commit: ByteArray): E2eeCommandResult
    fun removeMember(state: ByteArray, roomId: String, identity: String): E2eeCommandResult
    fun listMembers(state: ByteArray, roomId: String): E2eeCommandResult
}

interface E2eeDirectDeviceLifecycle {
    suspend fun ensureReady(accountId: String, deviceLabel: String, token: String): E2eeDeviceProfile
}

class E2eeCommandSessionCore(private val command: E2eeCommandClient = E2eeCommandClient()) : E2eeDirectSessionCore {
    override fun createGroup(state: ByteArray, roomId: String) = command.createGroup(state, roomId)
    override fun addMember(state: ByteArray, roomId: String, keyPackage: ByteArray) = command.addMember(state, roomId, keyPackage)
    override fun joinGroup(state: ByteArray, welcome: ByteArray) = command.joinGroup(state, welcome)
    override fun encrypt(state: ByteArray, roomId: String, plaintext: ByteArray) = command.encrypt(state, roomId, plaintext)
    override fun decrypt(state: ByteArray, roomId: String, ciphertext: ByteArray) = command.decrypt(state, roomId, ciphertext)
    override fun processCommit(state: ByteArray, roomId: String, commit: ByteArray) = command.processCommit(state, roomId, commit)
    override fun removeMember(state: ByteArray, roomId: String, identity: String) = command.removeMember(state, roomId, identity)
    override fun listMembers(state: ByteArray, roomId: String) = command.listMembers(state, roomId)
}

@Serializable
private data class DirectMessageMetadata(
    val trustedIdentityFingerprints: Map<String, String> = emptyMap(),
    val processedMessageIds: Map<String, List<String>> = emptyMap(),
    val pendingApplication: PendingApplication? = null,
)

@Serializable
private data class PendingApplication(
    val roomId: String,
    val senderDeviceId: String,
    val epoch: Long,
    val ciphertext: String,
    val nextState: String,
    val idempotencyKey: String,
    val controlMessageId: String,
)

class E2eeDirectMessageCoordinator(
    private val storage: E2eeSecureStateStore,
    private val lifecycle: E2eeDirectDeviceLifecycle,
    private val api: E2eeMlsApi,
    private val core: E2eeDirectSessionCore = E2eeCommandSessionCore(),
    private val newId: () -> String = { UUID.randomUUID().toString() },
) : E2eeIncomingDecryptor, E2eeTextSender {
    private val mutex = Mutex()

    override suspend fun sendText(accountId: String, deviceLabel: String, roomId: String, peerUserId: String?, text: String, token: String): String = mutex.withLock {
        val normalized = text.trim()
        if (normalized.isEmpty()) throw E2eeDirectMessageException("加密消息内容不能为空")
        val profile = lifecycle.ensureReady(accountId, deviceLabel, token)
        requireActive(profile)
        val peerUserIds =
            peerUserId?.let(::listOf)
                ?: api.listRoomMemberDevices(roomId, token)
                    .map { it.userId }
                    .filterNot { it == accountId }
                    .distinct()
        peerUserIds.forEach { verifyIdentity(accountId, it, token) }
        syncControls(accountId, roomId, profile, token)
        reconcileGroup(accountId, roomId, profile, token)
        var state = storage.read(accountId) ?: throw E2eeDirectMessageException("E2EE 协议状态缺失")
        var epoch = api.getRoomEpoch(roomId, token)
        if (epoch.activeEpoch == 0L) {
            state = bootstrap(accountId, roomId, profile, state, epoch.membershipRevision, token)
            epoch = api.getRoomEpoch(roomId, token)
        }
        if (epoch.status != "active") throw E2eeDirectMessageException("房间 E2EE 状态尚未就绪")
        val refreshedProfile = storage.readProfile(accountId) ?: throw E2eeDirectMessageException("E2EE 设备档案缺失")
        val commitId = refreshedProfile.lastCommitMessageIds[roomId]
            ?: throw E2eeDirectMessageException("房间缺少当前 E2EE Commit 索引")
        val payload = Json.encodeToString(TextPayload(text = normalized)).toByteArray()
        val encrypted = core.encrypt(state, roomId, payload)
        val encryptedEpoch = encrypted.epoch(2)
        if (encryptedEpoch != epoch.activeEpoch) throw E2eeDirectMessageException("本地 E2EE epoch 已过期")
        val pending = PendingApplication(
            roomId = roomId,
            senderDeviceId = profile.deviceId,
            epoch = encryptedEpoch,
            ciphertext = Base64.getEncoder().encodeToString(encrypted.field(1)),
            nextState = Base64.getEncoder().encodeToString(encrypted.field(0)),
            idempotencyKey = newId(),
            controlMessageId = commitId,
        )
        val metadata = readMetadata(accountId)
        if (metadata.pendingApplication != null) throw E2eeDirectMessageException("存在待手动重试的 E2EE 消息")
        writeMetadata(accountId, metadata.copy(pendingApplication = pending))
        resumePendingSend(accountId, token)
    }

    override suspend fun retryPendingSend(accountId: String, token: String): String = mutex.withLock {
        resumePendingSend(accountId, token)
    }

    override suspend fun hasPendingSend(accountId: String): Boolean = mutex.withLock {
        readMetadata(accountId).pendingApplication != null
    }

    override suspend fun decryptIncoming(accountId: String, deviceLabel: String, input: E2eeIncomingMessage, token: String): E2eeDecryptedMessage = mutex.withLock {
        if (input.messageId.isBlank() || input.roomId.isBlank()) throw E2eeDirectMessageException("E2EE 消息标识无效")
        val metadata = readMetadata(accountId)
        if (metadata.processedMessageIds[input.roomId].orEmpty().contains(input.messageId)) {
            throw E2eeDirectMessageException("E2EE 消息已处理")
        }
        if (input.ciphertext == null) {
            val text = input.plaintext?.takeIf { it.isNotBlank() } ?: throw E2eeDirectMessageException("历史消息内容为空")
            rememberMessage(accountId, metadata, input.roomId, input.messageId)
            return@withLock E2eeDecryptedMessage(input.messageId, input.roomId, text, 0, false)
        }
        if (input.ciphertext.isEmpty()) throw E2eeDirectMessageException("E2EE 密文不能为空")
        val profile = lifecycle.ensureReady(accountId, deviceLabel, token)
        requireActive(profile)
        syncControls(accountId, input.roomId, profile, token)
        val state = storage.read(accountId) ?: throw E2eeDirectMessageException("E2EE 协议状态缺失")
        val decrypted = try {
            core.decrypt(state, input.roomId, input.ciphertext)
        } catch (error: Exception) {
            throw E2eeDirectMessageException("E2EE 消息解密失败", error)
        }
        val payload = try {
            Json.decodeFromString<TextPayload>(decrypted.field(1).toString(Charsets.UTF_8))
        } catch (error: Exception) {
            throw E2eeDirectMessageException("E2EE 消息负载格式无效", error)
        }
        if (payload.version != 1 || payload.type != "text" || payload.text.isBlank()) {
            throw E2eeDirectMessageException("E2EE 消息负载格式无效")
        }
        storage.write(accountId, decrypted.field(0))
        rememberMessage(accountId, metadata, input.roomId, input.messageId)
        E2eeDecryptedMessage(input.messageId, input.roomId, payload.text, decrypted.epoch(2), true)
    }

    private suspend fun verifyIdentity(accountId: String, peerUserId: String, token: String) {
        val identity = api.fetchIdentity(peerUserId, token)
        if (identity.protocolVersion != 1 || identity.fingerprint.size < 16) throw E2eeDirectMessageException("E2EE 对端身份无效")
        val metadata = readMetadata(accountId)
        val fingerprint = Base64.getEncoder().encodeToString(identity.fingerprint)
        val previous = metadata.trustedIdentityFingerprints[peerUserId]
        if (previous != null && previous != fingerprint) throw E2eeDirectMessageException("对端 E2EE 身份已变化，发送已阻断")
        if (previous == null) writeMetadata(accountId, metadata.copy(trustedIdentityFingerprints = metadata.trustedIdentityFingerprints + (peerUserId to fingerprint)))
    }

    private suspend fun resumePendingSend(accountId: String, token: String): String {
        val metadata = readMetadata(accountId)
        val pending = metadata.pendingApplication ?: throw E2eeDirectMessageException("没有待重试的 E2EE 消息")
        val messageId = api.sendEncryptedMessage(
            E2eeEncryptedMessageRequest(
                roomId = pending.roomId,
                senderDeviceId = pending.senderDeviceId,
                epoch = pending.epoch,
                ciphertext = Base64.getDecoder().decode(pending.ciphertext),
                idempotencyKey = pending.idempotencyKey,
                controlMessageId = pending.controlMessageId,
            ),
            token,
        )
        storage.write(accountId, Base64.getDecoder().decode(pending.nextState))
        writeMetadata(accountId, metadata.copy(pendingApplication = null))
        return messageId
    }

    private suspend fun bootstrap(accountId: String, roomId: String, profile: E2eeDeviceProfile, initialState: ByteArray, revision: Long, token: String): ByteArray {
        val peers = api.listRoomMemberDevices(roomId, token).filter { it.userId != accountId }
        if (peers.any { it.devices.isEmpty() }) throw E2eeDirectMessageException("房间存在没有可用 E2EE 设备的成员")
        val devices = peers.flatMap { it.devices }
        if (devices.isEmpty()) throw E2eeDirectMessageException("房间没有其他可用的 E2EE 设备")
        var state = core.createGroup(initialState, roomId).field(0)
        var lastCommitId: String? = null
        for (device in devices) {
            val claimed = api.claimKeyPackage(roomId, profile.deviceId, device.id, token)
            val added = core.addMember(state, roomId, claimed.keyPackage)
            state = added.field(0)
            val epoch = added.epoch(3)
            val commitId = newId()
            api.submitControlMessage(E2eeOutgoingControlMessage(roomId, commitId, epoch, revision, profile.deviceId, "commit", added.field(1)), token)
            api.submitControlMessage(E2eeOutgoingControlMessage(roomId, newId(), epoch, revision, profile.deviceId, "welcome", added.field(2), device.id), token)
            lastCommitId = commitId
        }
        storage.write(accountId, state)
        storage.writeProfile(accountId, profile.copy(lastCommitMessageIds = profile.lastCommitMessageIds + (roomId to lastCommitId!!)))
        return state
    }

    suspend fun reconcileGroup(accountId: String, roomId: String, token: String) = mutex.withLock {
        val profile = storage.readProfile(accountId) ?: throw E2eeDirectMessageException("E2EE 设备档案缺失")
        reconcileGroup(accountId, roomId, profile, token)
    }

    private suspend fun reconcileGroup(accountId: String, roomId: String, profile: E2eeDeviceProfile, token: String) {
        val roomEpoch = api.getRoomEpoch(roomId, token)
        if (roomEpoch.status != "rekey_required" || !profile.lastCommitMessageIds.containsKey(roomId)) return
        var state = storage.read(accountId) ?: throw E2eeDirectMessageException("E2EE 协议状态缺失")
        val serverMembers = api.listRoomMemberDevices(roomId, token)
            .flatMap { member -> member.devices.map { "${member.userId}/${it.id}" } }.toSet()
        val localMembers = decodeMembers(core.listMembers(state, roomId).field(0))
        var lastCommitId: String? = null
        for (identity in localMembers.filterNot { it in serverMembers }) {
            val removed = core.removeMember(state, roomId, identity)
            state = removed.field(0)
            lastCommitId = newId()
            api.submitControlMessage(
                E2eeOutgoingControlMessage(roomId, lastCommitId, removed.epoch(2), roomEpoch.membershipRevision, profile.deviceId, "commit", removed.field(1)), token,
            )
        }
        for (identity in serverMembers.filterNot { it in localMembers }) {
            val deviceId = identity.substringAfter('/')
            val claimed = api.claimKeyPackage(roomId, profile.deviceId, deviceId, token)
            val added = core.addMember(state, roomId, claimed.keyPackage)
            state = added.field(0)
            val epoch = added.epoch(3)
            lastCommitId = newId()
            api.submitControlMessage(E2eeOutgoingControlMessage(roomId, lastCommitId, epoch, roomEpoch.membershipRevision, profile.deviceId, "commit", added.field(1)), token)
            api.submitControlMessage(E2eeOutgoingControlMessage(roomId, newId(), epoch, roomEpoch.membershipRevision, profile.deviceId, "welcome", added.field(2), deviceId), token)
        }
        if (lastCommitId != null) {
            storage.write(accountId, state)
            storage.writeProfile(accountId, profile.copy(lastCommitMessageIds = profile.lastCommitMessageIds + (roomId to lastCommitId)))
        }
    }

    private fun decodeMembers(bytes: ByteArray): Set<String> {
        if (bytes.size < 4) throw E2eeDirectMessageException("E2EE 成员列表格式无效")
        var offset = 0
        fun readInt(): Int {
            if (offset + 4 > bytes.size) throw E2eeDirectMessageException("E2EE 成员列表已截断")
            val value = ((bytes[offset].toInt() and 0xff) shl 24) or ((bytes[offset + 1].toInt() and 0xff) shl 16) or ((bytes[offset + 2].toInt() and 0xff) shl 8) or (bytes[offset + 3].toInt() and 0xff)
            offset += 4
            return value
        }
        val members = buildSet {
            repeat(readInt()) {
                val length = readInt()
                if (length < 0 || offset + length > bytes.size) throw E2eeDirectMessageException("E2EE 成员列表已截断")
                add(bytes.copyOfRange(offset, offset + length).toString(Charsets.UTF_8))
                offset += length
            }
        }
        if (offset != bytes.size) throw E2eeDirectMessageException("E2EE 成员列表包含多余数据")
        return members
    }

    private suspend fun syncControls(accountId: String, roomId: String, profile: E2eeDeviceProfile, token: String) {
        var state = storage.read(accountId) ?: throw E2eeDirectMessageException("E2EE 协议状态缺失")
        val controls = api.listControlMessages(roomId, profile.deviceId, profile.lastControlSequences[roomId] ?: 0, token)
        if (controls.isEmpty()) return
        var joined = profile.lastCommitMessageIds.containsKey(roomId)
        var lastCommit = profile.lastCommitMessageIds[roomId]
        var index = 0
        if (!joined) {
            val welcomeIndex = controls.indexOfFirst { it.contentType == "welcome" }
            if (welcomeIndex < 0) return
            val welcome = controls[welcomeIndex]
            val commit = controls.take(welcomeIndex + 1).lastOrNull { it.contentType == "commit" && it.epoch == welcome.epoch }
                ?: throw E2eeDirectMessageException("Welcome 缺少对应的 E2EE Commit")
            val result = core.joinGroup(state, welcome.envelope)
            if (result.epoch(1) != welcome.epoch) throw E2eeDirectMessageException("Welcome epoch 与本地状态不一致")
            state = result.field(0)
            joined = true
            lastCommit = commit.id
            index = welcomeIndex + 1
        }
        if (joined) for (control in controls.drop(index)) {
            if (control.contentType != "commit") throw E2eeDirectMessageException("已入群设备收到意外 Welcome")
            val result = core.processCommit(state, roomId, control.envelope)
            if (result.epoch(1) != control.epoch) throw E2eeDirectMessageException("Commit epoch 与本地状态不一致")
            state = result.field(0)
            lastCommit = control.id
        }
        storage.write(accountId, state)
        storage.writeProfile(accountId, profile.copy(lastControlSequences = profile.lastControlSequences + (roomId to controls.last().sequenceNo), lastCommitMessageIds = lastCommit?.let { profile.lastCommitMessageIds + (roomId to it) } ?: profile.lastCommitMessageIds))
        for (control in controls) api.consumeControlMessage(roomId, control.id, profile.deviceId, token)
    }

    private fun requireActive(profile: E2eeDeviceProfile) {
        if (profile.deviceStatus != "active") throw E2eeDirectMessageException("E2EE 设备未批准或已撤销")
    }

    private fun readMetadata(accountId: String): DirectMessageMetadata = storage.readMetadata(accountId, METADATA_KEY)?.let {
        try { Json.decodeFromString<DirectMessageMetadata>(it.toString(Charsets.UTF_8)) }
        catch (error: Exception) { throw E2eeStateCorruptedException("E2EE 单聊元数据已损坏") }
    } ?: DirectMessageMetadata()

    private fun writeMetadata(accountId: String, metadata: DirectMessageMetadata) =
        storage.writeMetadata(accountId, METADATA_KEY, Json.encodeToString(metadata).toByteArray())

    private fun rememberMessage(accountId: String, metadata: DirectMessageMetadata, roomId: String, messageId: String) {
        val ids = (metadata.processedMessageIds[roomId].orEmpty() + messageId).takeLast(512)
        writeMetadata(accountId, metadata.copy(processedMessageIds = metadata.processedMessageIds + (roomId to ids)))
    }

    @Serializable private data class TextPayload(val version: Int = 1, val type: String = "text", val text: String)
    private companion object { const val METADATA_KEY = "direct-message" }
}
