package com.redcode.im.androidapp.e2ee

import java.util.Base64
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test
import kotlinx.coroutines.test.runTest

class E2eeDeviceManagerTest {
    @Test
    fun listsSignsApprovesAndRevokesThroughExistingApiContract() = runTest {
        val storage = E2eeSecureStateStore(InMemoryE2eeStateCipher(), InMemoryE2eeStateBlobStore()) { true }
        val accountId = "11111111-1111-1111-1111-111111111111"
        val approverId = "22222222-2222-2222-2222-222222222222"
        val target = E2eeDeviceInfo(
            id = "33333333-3333-3333-3333-333333333333",
            deviceLabel = "Pixel",
            protocolVersion = 1,
            credentialFingerprint = Base64.getEncoder().encodeToString(ByteArray(32) { 7 }),
            status = "pending_approval",
        )
        storage.write(accountId, byteArrayOf(1, 2, 3))
        storage.writeProfile(
            accountId,
            E2eeDeviceProfile(deviceId = approverId, deviceLabel = "Android", registered = true),
        )
        val api = RecordingDeviceApi(target)
        val signer = RecordingApprovalSigner(byteArrayOf(9, 8, 7))
        val manager = E2eeDeviceManager(storage, api, signer)

        assertEquals(listOf(target), manager.listDevices("token"))
        assertEquals("active", manager.approveDevice(accountId, target, "token").status)
        assertEquals("revoked", manager.revokeDevice(target.id, "token").status)
        assertArrayEquals(byteArrayOf(1, 2, 3), signer.state)
        assertEquals(target.id, api.approvedTargetId)
        assertEquals(approverId, api.approverId)
        assertArrayEquals(byteArrayOf(9, 8, 7), api.signature)
        assertEquals(target.id, api.revokedDeviceId)
    }
}

private class RecordingApprovalSigner(
    private val signature: ByteArray,
) : E2eeDeviceApprovalSigner {
    var state: ByteArray? = null
    override fun signDeviceApproval(state: ByteArray, payload: ByteArray): E2eeCommandResult {
        this.state = state
        return E2eeCommandResult(listOf(signature))
    }
}

private class RecordingDeviceApi(
    private val target: E2eeDeviceInfo,
) : E2eeMlsApi {
    var approvedTargetId: String? = null
    var approverId: String? = null
    var signature: ByteArray? = null
    var revokedDeviceId: String? = null

    override suspend fun fetchRootIdentity(userId: String, token: String) = ByteArray(0)
    override suspend fun registerDevice(deviceId: String, deviceLabel: String, material: E2eeRegistrationMaterial, token: String) = "active"
    override suspend fun publishKeyPackages(deviceId: String, keyPackages: List<ByteArray>, token: String) = 0
    override suspend fun fetchKeyPackageInventory(deviceId: String, token: String) = E2eeKeyPackageInventory(0, 100)
    override suspend fun listDevices(token: String) = listOf(target)
    override suspend fun approveDevice(targetDeviceId: String, approverDeviceId: String, signature: ByteArray, token: String): E2eeDeviceInfo {
        approvedTargetId = targetDeviceId
        approverId = approverDeviceId
        this.signature = signature
        return target.copy(status = "active")
    }
    override suspend fun revokeDevice(deviceId: String, token: String): E2eeDeviceInfo {
        revokedDeviceId = deviceId
        return target.copy(status = "revoked")
    }
}
