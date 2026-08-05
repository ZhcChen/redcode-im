package com.redcode.im.androidapp.e2ee

import java.nio.ByteBuffer
import java.util.UUID

interface E2eeDeviceManaging {
    suspend fun listDevices(token: String): List<E2eeDeviceInfo>
    suspend fun approveDevice(accountId: String, target: E2eeDeviceInfo, token: String): E2eeDeviceInfo
    suspend fun revokeDevice(deviceId: String, token: String): E2eeDeviceInfo
}

fun interface E2eeDeviceApprovalSigner {
    fun signDeviceApproval(state: ByteArray, payload: ByteArray): E2eeCommandResult
}

private class CoreDeviceApprovalSigner(
    private val core: E2eeCommandClient,
) : E2eeDeviceApprovalSigner {
    override fun signDeviceApproval(state: ByteArray, payload: ByteArray): E2eeCommandResult =
        core.signDeviceApproval(state, payload)
}

class E2eeDeviceManager(
    private val storage: E2eeSecureStateStore,
    private val api: E2eeMlsApi,
    private val signer: E2eeDeviceApprovalSigner = CoreDeviceApprovalSigner(E2eeCommandClient()),
) : E2eeDeviceManaging {
    override suspend fun listDevices(token: String): List<E2eeDeviceInfo> = api.listDevices(token)

    override suspend fun approveDevice(accountId: String, target: E2eeDeviceInfo, token: String): E2eeDeviceInfo {
        val profile = storage.readProfile(accountId) ?: throw E2eeDirectMessageException("E2EE 设备档案缺失")
        if (profile.deviceStatus != "active") throw E2eeDirectMessageException("待批准或已撤销设备不能批准其他设备")
        val state = storage.read(accountId) ?: throw E2eeDirectMessageException("E2EE 设备状态缺失")
        val fingerprint = runCatching { java.util.Base64.getDecoder().decode(target.credentialFingerprint) }
            .getOrElse { throw E2eeDirectMessageException("E2EE 设备指纹格式无效") }
        if (target.protocolVersion != 1 || fingerprint.size != 32) {
            throw E2eeDirectMessageException("E2EE 设备协议或指纹无效")
        }
        val payload = deviceApprovalPayload(accountId, profile.deviceId, target.id, target.protocolVersion, fingerprint)
        val signature = signer.signDeviceApproval(state, payload).field(0)
        return api.approveDevice(target.id, profile.deviceId, signature, token)
    }

    override suspend fun revokeDevice(deviceId: String, token: String): E2eeDeviceInfo = api.revokeDevice(deviceId, token)
}

internal fun deviceApprovalPayload(userId: String, approverDeviceId: String, targetDeviceId: String, protocolVersion: Int, credentialFingerprint: ByteArray): ByteArray {
    require(protocolVersion in 1..0xffff && credentialFingerprint.size <= 0xffff) { "E2EE 批准负载参数无效" }
    val domain = "redcode-im/e2ee/device-approval/v1\u0000".toByteArray()
    return ByteBuffer.allocate(domain.size + 16 * 3 + 2 + 2 + credentialFingerprint.size).apply {
        put(domain); putUuid(userId); putUuid(approverDeviceId); putUuid(targetDeviceId)
        putShort(protocolVersion.toShort()); putShort(credentialFingerprint.size.toShort()); put(credentialFingerprint)
    }.array()
}

private fun ByteBuffer.putUuid(value: String) {
    val uuid = UUID.fromString(value)
    putLong(uuid.mostSignificantBits); putLong(uuid.leastSignificantBits)
}
